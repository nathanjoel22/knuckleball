// Deploy with: supabase functions deploy send-session-report
// Requires these secrets set on your Supabase project (see SETUP.md):
//   RESEND_API_KEY, REPORT_FROM_EMAIL, SUPABASE_URL, SUPABASE_ANON_KEY,
//   SUPABASE_SERVICE_ROLE_KEY (platform-injected, not set by hand)
//
// U4/U4b: PDF generation is retired. This function now builds a frozen,
// self-contained HTML report (buildReportHtml, in template.ts) and uploads
// it to the public `reports` storage bucket instead of attaching a PDF.
// The emailed message is a link to report.html?r=<token>, not an
// attachment. See CLAUDE.md's "Charting surface decisions" and
// supabase/migrations/20260922120000_u4_reports_storage.sql.
//
// Unlike the old PDF version, this function DOES read (and once, write)
// the database -- but only the one `sessions` row named by the caller's own
// payload, through the CALLER's own RLS-scoped client, never service-role.
// Service-role is used for exactly one thing: uploading the object to the
// `reports` bucket, which has no INSERT policy for authenticated users by
// design (see the migration's comments on why there's no SELECT policy
// either). This mirrors invite-pitcher's precedent of an admin client
// scoped to one specific operation, never used for anything else.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { buildReportHtml, type ReportPayload } from './template.ts'
import { escapeHtml } from './helpers.ts'
import type { Pitch, HistoryEntry } from './compute.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
}

const MAX_RECIPIENTS = 3
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
const REPORT_SITE_ORIGIN = 'https://knuckleballonline.com'

// Must match TOKEN_RE in report.html EXACTLY -- that check is the only
// thing standing between a crafted ?r= value and report.html becoming a
// fetch-anything proxy for the reports bucket.
function randomReportToken(): string {
  const bytes = new Uint8Array(32)
  crypto.getRandomValues(bytes)
  return [...bytes].map(b => b.toString(16).padStart(2, '0')).join('') + '.html'
}

interface ReportRequestBody extends Omit<ReportPayload, 'pitches' | 'history'> {
  emails: string[]
  sessionId: string
  pitches: Pitch[]
  history: HistoryEntry[]
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers: corsHeaders })

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Missing Authorization header' }), { status: 401, headers: corsHeaders })
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!

  // Scoped to the calling user's own session -- every read/write this
  // function does against `sessions` goes through THIS client, so RLS (not
  // this function's own logic) is what decides which session a caller may
  // touch. Same client used for the identity check, same as before.
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } }
  })

  const { data: { user }, error: userErr } = await callerClient.auth.getUser()
  if (userErr || !user) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: corsHeaders })
  }

  let body: ReportRequestBody
  try { body = await req.json() } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), { status: 400, headers: corsHeaders })
  }

  const { emails, sessionId, pitcherId, pitcherName, pitches } = body
  if (!emails?.length || !sessionId || !pitcherId || !pitcherName || !Array.isArray(pitches)) {
    return new Response(JSON.stringify({ error: 'emails, sessionId, pitcherId, pitcherName, and pitches are required' }), { status: 400, headers: corsHeaders })
  }
  if (!Array.isArray(emails) || emails.length > MAX_RECIPIENTS || !emails.every((e) => typeof e === 'string' && EMAIL_RE.test(e))) {
    return new Response(JSON.stringify({ error: `emails must be an array of up to ${MAX_RECIPIENTS} valid addresses` }), { status: 400, headers: corsHeaders })
  }

  // R0 item (g): if the pitcher of record hasn't verified their account
  // email, nobody receives a report for their sessions until they do --
  // unchanged from the PDF version. is_pitcher_verified runs as the
  // CALLER's own JWT (never service-role), so it never grants more than
  // any authenticated caller could already ask for a yes/no answer to.
  const { data: verified, error: verifiedErr } = await callerClient.rpc('is_pitcher_verified', {
    p_pitcher_id: pitcherId
  })
  if (verifiedErr) {
    return new Response(JSON.stringify({ error: 'Could not verify pitcher eligibility: ' + verifiedErr.message }), { status: 500, headers: corsHeaders })
  }
  if (!verified) {
    return new Response(JSON.stringify({ error: 'This pitcher\'s account email is not yet verified. No report can be sent for their sessions until they verify.' }), { status: 403, headers: corsHeaders })
  }

  // Design principle (CLAUDE.md): "Reports are never generated from an
  // unsynced session." Fetching this row through the caller's own
  // RLS-scoped client both proves the session is really synced AND that
  // this caller (pitcher or their team's coach) actually has rights to it
  // -- a caller with no relationship to sessionId simply gets no row back,
  // same as any other RLS-filtered read.
  const { data: session, error: sessionErr } = await callerClient
    .from('sessions')
    .select('id, pitcher_id, report_path')
    .eq('id', sessionId)
    .maybeSingle()
  if (sessionErr) {
    return new Response(JSON.stringify({ error: 'Could not look up session: ' + sessionErr.message }), { status: 500, headers: corsHeaders })
  }
  if (!session) {
    return new Response(JSON.stringify({ error: 'Session not found, not synced yet, or not accessible with your account.' }), { status: 403, headers: corsHeaders })
  }
  if (session.pitcher_id !== pitcherId) {
    return new Response(JSON.stringify({ error: 'pitcherId does not match the session\'s pitcher.' }), { status: 400, headers: corsHeaders })
  }

  let reportPath: string = session.report_path

  if (!reportPath) {
    // Never regenerated once set -- this branch only runs the FIRST time a
    // report is requested for a given session. Every later "resend" reuses
    // the same frozen file, so the payload the client sends after this
    // point can drift (new prior-session history, say) without the report
    // itself ever silently changing underneath a link someone already has.
    const payload: ReportPayload = {
      sessionId: body.sessionId,
      pitcherId: body.pitcherId,
      pitcherName: body.pitcherName,
      uniformNumber: body.uniformNumber ?? null,
      teamName: body.teamName ?? null,
      date: body.date,
      chartingPerspective: body.chartingPerspective ?? null,
      loggedByCoach: !!body.loggedByCoach,
      pitchTypes: Array.isArray(body.pitchTypes) ? body.pitchTypes : [],
      gridSize: body.gridSize,
      pitches: body.pitches,
      history: Array.isArray(body.history) ? body.history : []
    }

    let html: string
    try {
      html = buildReportHtml(payload)
    } catch (err) {
      return new Response(JSON.stringify({ error: 'Report generation failed: ' + (err as Error).message }), { status: 500, headers: corsHeaders })
    }

    const token = randomReportToken()
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    // Service-role, used for exactly this one call -- the `reports` bucket
    // has no INSERT policy for authenticated users (see the migration), so
    // this is the only way to place the object. Never used for anything
    // else in this function.
    const adminClient = createClient(supabaseUrl, serviceKey)
    const { error: uploadErr } = await adminClient.storage
      .from('reports')
      .upload(token, html, { contentType: 'text/html; charset=utf-8', upsert: false })
    if (uploadErr) {
      return new Response(JSON.stringify({ error: 'Could not store report: ' + uploadErr.message }), { status: 500, headers: corsHeaders })
    }

    // Written through the CALLER's own client, not service-role -- the
    // existing "Pitchers manage own sessions" / "Coaches manage sessions
    // for their team" RLS policies already grant UPDATE on this row (they
    // don't restrict which columns), so this needs no elevated access.
    const { error: updateErr } = await callerClient
      .from('sessions')
      .update({ report_path: token, report_generated_at: new Date().toISOString() })
      .eq('id', sessionId)
    if (updateErr) {
      return new Response(JSON.stringify({ error: 'Report was stored but could not be recorded on the session: ' + updateErr.message }), { status: 500, headers: corsHeaders })
    }

    reportPath = token
  }

  const reportUrl = `${REPORT_SITE_ORIGIN}/report.html?r=${reportPath}`

  const resendApiKey = Deno.env.get('RESEND_API_KEY')
  const fromEmail = Deno.env.get('REPORT_FROM_EMAIL')
  if (!resendApiKey || !fromEmail) {
    return new Response(JSON.stringify({ error: 'Server email config missing' }), { status: 500, headers: corsHeaders })
  }

  const dateStr = body.date ? new Date(body.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : ''
  const resendRes = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${resendApiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      from: fromEmail,
      to: emails,
      subject: `Bullpen Session Report — ${pitcherName}${dateStr ? ' — ' + dateStr : ''}`,
      html: `<p>The bullpen session report for ${escapeHtml(pitcherName)}${dateStr ? ' (' + escapeHtml(dateStr) + ')' : ''} is ready.</p>` +
        `<p><a href="${reportUrl}">View the report</a></p>` +
        `<p style="color:#7C8C82;font-size:12px">This link works for anyone it's shared with -- there's no login required to view it.</p>`
    })
  })

  if (!resendRes.ok) {
    const errText = await resendRes.text()
    return new Response(JSON.stringify({ error: 'Resend send failed: ' + errText }), { status: 502, headers: corsHeaders })
  }

  return new Response(JSON.stringify({ ok: true, reportUrl }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
})
