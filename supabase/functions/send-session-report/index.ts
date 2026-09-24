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
  // Empty/omitted means "generate (or fetch) the report and hand back its
  // URL, but don't email anyone" -- the View-report-before-ever-sending
  // path. Generation and eligibility are unaffected either way; only the
  // Resend call at the end is conditional on this being non-empty.
  emails?: string[]
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

  const { sessionId, pitcherId, pitcherName, pitches } = body
  const emails = body.emails ?? []
  if (!sessionId || !pitcherId || !pitcherName || !Array.isArray(pitches)) {
    return new Response(JSON.stringify({ error: 'sessionId, pitcherId, pitcherName, and pitches are required' }), { status: 400, headers: corsHeaders })
  }
  if (!Array.isArray(emails) || emails.length > MAX_RECIPIENTS || !emails.every((e) => typeof e === 'string' && EMAIL_RE.test(e))) {
    return new Response(JSON.stringify({ error: `emails must be an array of up to ${MAX_RECIPIENTS} valid addresses (or omitted/empty to generate without sending)` }), { status: 400, headers: corsHeaders })
  }

  // R0 item (g), extended in U4b Phase 2: nobody receives a report for a
  // pitcher's sessions unless BOTH their email is verified AND they're
  // currently on a team -- the latter is a deliberate, temporary
  // restriction until solo/team-less pitcher accounts are supported (Joel,
  // Sept 2026). is_pitcher_report_eligible runs as the CALLER's own JWT
  // (never service-role), so it never grants more than any authenticated
  // caller could already ask for a yes/no answer to.
  const { data: eligible, error: eligibleErr } = await callerClient.rpc('is_pitcher_report_eligible', {
    p_pitcher_id: pitcherId
  })
  if (eligibleErr) {
    return new Response(JSON.stringify({ error: 'Could not verify pitcher eligibility: ' + eligibleErr.message }), { status: 500, headers: corsHeaders })
  }
  if (!eligible) {
    return new Response(JSON.stringify({ error: 'No report can be sent for this pitcher\'s sessions until their account email is verified and they\'re on a team.' }), { status: 403, headers: corsHeaders })
  }

  // Design principle (CLAUDE.md): "Reports are never generated from an
  // unsynced session." Fetching this row through the caller's own
  // RLS-scoped client both proves the session is really synced AND that
  // this caller (pitcher or their team's coach) actually has rights to it
  // -- a caller with no relationship to sessionId simply gets no row back,
  // same as any other RLS-filtered read.
  const { data: session, error: sessionErr } = await callerClient
    .from('sessions')
    .select('id, pitcher_id, report_path, kind')
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
  // G1: a game session has no target on any pitch, so compute.ts's
  // isExactHit()/miss-tendency math (which assumes one) would silently
  // produce NaN rather than a real report. Refuse before buildReportHtml
  // is ever called instead of teaching compute.ts to cope with a shape it
  // should never see -- a game session simply isn't reportable yet.
  if (session.kind && session.kind !== 'bullpen') {
    return new Response(JSON.stringify({ error: 'Reports for Live Game sessions are coming soon -- only bullpen sessions can be reported right now.' }), { status: 400, headers: corsHeaders })
  }

  // Coach-side gate (added after a Joel-directed staging investigation,
  // Sept 2026): is_pitcher_report_eligible above only ever checks the
  // PITCHER named in the payload -- an unverified coach could otherwise
  // sign up, get a team + invite link, have a verified pitcher join and
  // chart a pen, and still generate/view/send that pen's report, since
  // nothing checked the COACH's own identity. The session-ownership read
  // just above already proves that if the caller isn't the pitcher
  // themselves, RLS has confirmed they're this session's team coach (only
  // "Pitchers manage own sessions" or "Coaches manage sessions for their
  // team" can pass it) -- so right here, and only here, is where it's
  // actually true to say "this caller is acting as a coach." Reuses
  // my_verification_status() (the same RPC that already powers the
  // verify-your-email banner) rather than inventing a new function for it.
  // Deliberately NOT folded into is_pitcher_report_eligible itself -- that
  // function's name and job stay "is the pitcher eligible," unchanged;
  // this is a second, independent question about the caller.
  if (user.id !== pitcherId) {
    const { data: callerStatus, error: callerStatusErr } = await callerClient.rpc('my_verification_status')
    if (callerStatusErr) {
      return new Response(JSON.stringify({ error: 'Could not verify your own account status: ' + callerStatusErr.message }), { status: 500, headers: corsHeaders })
    }
    // Fail closed on anything but an explicit true, matching R0's own
    // stated posture (state.myVerification defaults to emailConfirmed:
    // false client-side until proven otherwise) -- an empty/malformed
    // result must never read as "verified."
    const callerVerified = Array.isArray(callerStatus) && callerStatus[0]?.email_confirmed === true
    if (!callerVerified) {
      return new Response(JSON.stringify({ error: 'Your own account email must be verified before you can generate or share a report for your team.' }), { status: 403, headers: corsHeaders })
    }
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

  // Generation (above) and eligibility already happened unconditionally --
  // an empty/omitted emails array means "View report" before ever sending:
  // hand back the URL, skip Resend entirely.
  if (emails.length) {
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
  }

  // reportPath included alongside reportUrl so the client can update its
  // own local session state (for the "View report" link) without having
  // to parse a URL or re-fetch the session. emailed tells the caller
  // whether Resend was actually invoked, for status-message wording.
  return new Response(JSON.stringify({ ok: true, reportUrl, reportPath, emailed: emails.length > 0 }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
})
