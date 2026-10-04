// Deploy with: supabase functions deploy send-session-report
// Requires these secrets set on your Supabase project (see SETUP.md):
//   RESEND_API_KEY, REPORT_FROM_EMAIL, SUPABASE_URL, SUPABASE_ANON_KEY,
//   SUPABASE_SERVICE_ROLE_KEY (platform-injected, not set by hand)
// Optional: REPORT_SITE_ORIGIN (staging only: http://localhost:8080; unset = live site)
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
//
// P1-15: also handles { action: 'deleteReport', sessionId }, the one other
// place this function's service-role access is needed -- the `reports`
// bucket has no DELETE policy either (no policy of any kind, confirmed
// empirically against storage.objects), so removing a report object can
// only happen with the service-role key, same as placing one. Reuses the
// exact same caller-JWT trust model: the session lookup below goes through
// callerClient, so RLS is what proves this caller may touch this session,
// same as every other branch in this file. Restricted to sessions that are
// ALREADY soft-deleted (delete_session sets deleted_at first) -- this must
// never be reachable against a live session's report, which someone may
// already have the link to.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { takeRateLimit } from '../_shared/rate_limit.ts'
import { buildReportHtml, type ReportPayload } from './template.ts'
import { escapeHtml, useSportPalette, asSport } from './helpers.ts'
import type { Pitch, HistoryEntry } from './compute.ts'
// G2 approach (g): the game-report renderer, called below when
// session.kind === 'game'. summary always comes from compute_game_summary
// (drafting decision 1) -- GameSummary just names its return shape.
import { buildGameReportHtml, type GameReportPayload, type GameSummary } from './template_game.ts'
import type { GamePitch } from './compute_game.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
}

const MAX_RECIPIENTS = 3
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
// Where the emailed report link opens. Production leaves this unset (the live
// site). Staging sets REPORT_SITE_ORIGIN=http://localhost:8080 so its report
// links open on the local staging site, which reads staging's storage --
// the live site only reads production's, so staging links there were always
// "Report not available".
const REPORT_SITE_ORIGIN = (() => {
  const v = (Deno.env.get('REPORT_SITE_ORIGIN') || '').trim().replace(/\/+$/, '')
  return /^https?:\/\/[A-Za-z0-9.-]+(:\d+)?$/.test(v) ? v : 'https://knuckleballonline.com'
})()

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
  // Bullpen shape (Pitch[]) or game shape (GamePitch[]) depending on the
  // session's own kind -- see the branch on session.kind below. Kept as
  // Pitch[] here (matching every field this interface already had) with an
  // explicit cast at the one place a game payload is actually built from
  // it, rather than widening this whole interface's type for one branch.
  pitches: Pitch[]
  history: HistoryEntry[]
  // G2: present only when the client is reporting a kind='game' session
  // (buildGameReportPayload, bullpen-tracker.html). opponent/recentPens/
  // gameTrend are trusted from the client -- same accepted trust model the
  // bullpen path's own pitches/history already have (CLAUDE.md's own
  // "client-computed reports" landmine, unchanged posture, not widened).
  // summary is deliberately NOT accepted here -- that's the one number
  // that must come from compute_game_summary, fetched server-side below,
  // never the client (drafting decision 1).
  opponent?: string | null
  recentPens?: GameReportPayload['recentPens']
  gameTrend?: GameReportPayload['gameTrend']
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

  let rawBody: Record<string, unknown>
  try { rawBody = await req.json() } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), { status: 400, headers: corsHeaders })
  }

  // P1-15 deleteReport branch -- handled entirely separately from the
  // generate/send path below, before any of that path's field validation
  // (a delete request has no pitches/pitcherName/etc to validate).
  if (rawBody.action === 'deleteReport') {
    const delSessionId = rawBody.sessionId
    if (typeof delSessionId !== 'string' || !delSessionId) {
      return new Response(JSON.stringify({ error: 'sessionId is required' }), { status: 400, headers: corsHeaders })
    }

    const { data: delSession, error: delSessionErr } = await callerClient
      .from('sessions')
      .select('id, report_path, deleted_at')
      .eq('id', delSessionId)
      .maybeSingle()
    if (delSessionErr) {
      return new Response(JSON.stringify({ error: 'Could not look up session: ' + delSessionErr.message }), { status: 500, headers: corsHeaders })
    }
    if (!delSession) {
      return new Response(JSON.stringify({ error: 'Session not found or not accessible with your account.' }), { status: 403, headers: corsHeaders })
    }
    // The whole point of this guard: a live session's report must never be
    // reachable through this action, even by its own pitcher or head coach.
    if (!delSession.deleted_at) {
      return new Response(JSON.stringify({ error: 'Session is not deleted -- refusing to remove its report.' }), { status: 400, headers: corsHeaders })
    }
    if (!delSession.report_path) {
      return new Response(JSON.stringify({ ok: true }), { status: 200, headers: corsHeaders })
    }

    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const adminClient = createClient(supabaseUrl, serviceKey)
    const { error: removeErr } = await adminClient.storage.from('reports').remove([delSession.report_path])
    if (removeErr) {
      return new Response(JSON.stringify({ error: 'Could not remove stored report: ' + removeErr.message }), { status: 500, headers: corsHeaders })
    }

    // Through the caller's own client, same as the write in the generate
    // path below -- the FOR ALL policies already grant this UPDATE.
    const { error: clearErr } = await callerClient
      .from('sessions')
      .update({ report_path: null, report_generated_at: null })
      .eq('id', delSessionId)
    if (clearErr) {
      // The object is already gone at this point -- report_path pointing
      // at nothing is a display inconsistency, not a data-safety issue, so
      // this is reported but not treated as a full failure.
      return new Response(JSON.stringify({ ok: true, warning: 'Report file removed, but the session row could not be updated: ' + clearErr.message }), { status: 200, headers: corsHeaders })
    }

    return new Response(JSON.stringify({ ok: true }), { status: 200, headers: corsHeaders })
  }

  const body = rawBody as unknown as ReportRequestBody
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
    // H1: name the actual reason (P1-10 added age and guardian conditions the old text didn't
    // mention). pitcher_report_block answers only for the pitcher or their coach.
    const { data: block } = await callerClient.rpc('pitcher_report_block', { p_pitcher_id: pitcherId })
    const reason = typeof block === 'string' ? block : 'not_on_team'
    const REASONS: Record<string, string> = {
      unverified: 'No report can be sent until this player\'s account email is verified.',
      age_not_answered: 'No report can be sent until this player answers the one-time age question in the app.',
      guardian_pending: 'No report can be sent until this player\'s parent or guardian approves their account.',
      consent_missing: 'No report can be sent for this player until their parent\'s consent is recorded.',
      not_on_team: 'No report can be sent until this player is on a team.'
    }
    return new Response(JSON.stringify({ error: REASONS[reason] || REASONS.not_on_team, code: reason }), { status: 403, headers: corsHeaders })
  }

  // Design principle (CLAUDE.md): "Reports are never generated from an
  // unsynced session." Fetching this row through the caller's own
  // RLS-scoped client both proves the session is really synced AND that
  // this caller (pitcher or their team's coach) actually has rights to it
  // -- a caller with no relationship to sessionId simply gets no row back,
  // same as any other RLS-filtered read.
  const { data: session, error: sessionErr } = await callerClient
    .from('sessions')
    .select('id, pitcher_id, report_path, kind, deleted_at, sport')
    .eq('id', sessionId)
    .maybeSingle()
  if (sessionErr) {
    return new Response(JSON.stringify({ error: 'Could not look up session: ' + sessionErr.message }), { status: 500, headers: corsHeaders })
  }
  if (!session) {
    return new Response(JSON.stringify({ error: 'Session not found, not synced yet, or not accessible with your account.' }), { status: 403, headers: corsHeaders })
  }
  // P1-15: a deleted session must never generate or resend a report, even
  // for a caller who still technically has RLS access to the row (RLS on
  // sessions doesn't know about deleted_at -- see the precondition report).
  // The UI already can't reach this (tombstones aren't sent/viewed), so
  // this only matters against a direct call, which is exactly when it
  // matters most.
  if (session.deleted_at) {
    return new Response(JSON.stringify({ error: 'This session has been deleted. No report can be generated or sent for it.' }), { status: 410, headers: corsHeaders })
  }
  if (session.pitcher_id !== pitcherId) {
    return new Response(JSON.stringify({ error: 'pitcherId does not match the session\'s pitcher.' }), { status: 400, headers: corsHeaders })
  }
  // G2 approach (g): the kind='game' refusal that used to sit here is gone
  // -- decision 10 is explicit that it comes off client and server in the
  // SAME deploy as everything else. A game session now branches to its own
  // payload/renderer a few lines down (session.kind === 'game'); a bullpen
  // falls through to the exact same buildReportHtml call this file has
  // always used, untouched (acceptance 14: byte-for-byte identical output).

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
  // S4 (Amendment 11 unchanged in substance): "is the caller this pitcher"
  // now means "does the caller's LOGIN own this pitcher profile" (a login can
  // own a second-sport profile; in Stage B, a parent owns players).
  const { data: ownsPitcher, error: ownsErr } = await callerClient.rpc('is_my_profile', { p: pitcherId })
  if (ownsErr) {
    return new Response(JSON.stringify({ error: 'Could not check profile ownership: ' + ownsErr.message }), { status: 500, headers: corsHeaders })
  }
  if (ownsPitcher !== true) {
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

  // H1 Part 3b (Joel, Oct 3): a report is emailed only to the report contacts saved in the
  // player's Profile (edited only by the pitcher, or the parent for a parent-created player).
  // Coaches send to those contacts and can't add others. Read through the caller's own client.
  if (emails.length) {
    const { data: prof, error: profErr } = await callerClient
      .from('profiles').select('contact_emails').eq('id', pitcherId).maybeSingle()
    if (profErr || !prof) {
      return new Response(JSON.stringify({ error: 'Could not read the player\'s report contacts.' }), { status: 500, headers: corsHeaders })
    }
    const saved = new Set(Object.values((prof.contact_emails || {}) as Record<string, unknown>)
      .filter((v): v is string => typeof v === 'string' && v.trim() !== '').map((v) => v.trim().toLowerCase()))
    const notSaved = emails.filter((e) => !saved.has(e.trim().toLowerCase()))
    if (notSaved.length) {
      return new Response(JSON.stringify({ error: 'Reports can only be emailed to the report contacts saved in the player\'s Profile.', code: 'recipient_not_saved' }), { status: 400, headers: corsHeaders })
    }
  }

  // H1 Part 2: sending limits. Emailing counts as a report email (whether or not a file is
  // generated); generating without emailing counts only against the generation limit; a plain
  // re-view of an existing report counts against nothing.
  if (emails.length || !session.report_path) {
    const limit = await takeRateLimit(user.id, emails.length ? 'report_email' : 'report_generate', emails)
    if (!limit.ok) return new Response(JSON.stringify(limit.body), { status: limit.status, headers: corsHeaders })
  }

  let reportPath: string = session.report_path

  if (!reportPath) {
    // Never regenerated once set -- this branch only runs the FIRST time a
    // report is requested for a given session. Every later "resend" reuses
    // the same frozen file, so the payload the client sends after this
    // point can drift (new prior-session history, say) without the report
    // itself ever silently changing underneath a link someone already has.
    let html: string

    if (session.kind === 'game') {
      // G2 approach (g): the ONE definition (drafting decision 1) -- called
      // fresh here, never trusted from the client, so this can never
      // disagree with what History's own game row already showed for the
      // same session. Everything else in the payload (pitches, opponent,
      // recentPens, gameTrend) is client-supplied, same accepted trust
      // model the bullpen path above has always used for its own
      // pitches/history.
      const { data: summary, error: summaryErr } = await callerClient.rpc('compute_game_summary', { p_session_id: sessionId })
      if (summaryErr) {
        return new Response(JSON.stringify({ error: 'compute_game_summary failed: ' + summaryErr.message }), { status: 500, headers: corsHeaders })
      }
      if (summary && typeof summary === 'object' && 'error' in (summary as Record<string, unknown>)) {
        return new Response(JSON.stringify({ error: 'compute_game_summary: ' + (summary as Record<string, unknown>).error }), { status: 400, headers: corsHeaders })
      }

      // G3 item 2: no-pitch events, read with the CALLER's own client (RLS),
      // never the service-role client and never from the client payload.
      const { data: evRows, error: evErr } = await callerClient
        .from('game_events')
        .select('event_type, at_bat_index, seq, inning_before, balls_before, strikes_before, runner_advances')
        .eq('session_id', sessionId)
        .order('seq', { ascending: true, nullsFirst: true })
      if (evErr) {
        return new Response(JSON.stringify({ error: 'game events read failed: ' + evErr.message }), { status: 500, headers: corsHeaders })
      }

      const gamePayload: GameReportPayload = {
        sport: asSport(session.sport),   // S1: the session row's sport
        sessionId: body.sessionId,
        pitcherId: body.pitcherId,
        pitcherName: body.pitcherName,
        uniformNumber: body.uniformNumber ?? null,
        teamName: body.teamName ?? null,
        date: body.date,
        opponent: body.opponent ?? null,
        chartingPerspective: body.chartingPerspective ?? null,
        loggedByCoach: !!body.loggedByCoach,
        pitchTypes: Array.isArray(body.pitchTypes) ? body.pitchTypes : [],
        gridSize: body.gridSize,
        pitches: body.pitches as unknown as GamePitch[],
        recentPens: body.recentPens,
        gameTrend: Array.isArray(body.gameTrend) ? body.gameTrend : [],
        summary: summary as unknown as GameSummary,
        events: (evRows ?? []).map((e: Record<string, unknown>) => ({
          eventType: String(e.event_type),
          atBatIndex: (e.at_bat_index as number | null) ?? null,
          seq: (e.seq as number | null) ?? null,
          inningBefore: (e.inning_before as number | null) ?? null,
          ballsBefore: (e.balls_before as number | null) ?? null,
          strikesBefore: (e.strikes_before as number | null) ?? null,
          runnerAdvances: (e.runner_advances as unknown[] | null) ?? null
        }))
      }
      try {
        useSportPalette(asSport(session.sport))   // S1: every render sets its own palette (module state persists between requests)
        html = buildGameReportHtml(gamePayload)
      } catch (err) {
        return new Response(JSON.stringify({ error: 'Report generation failed: ' + (err as Error).message }), { status: 500, headers: corsHeaders })
      }
    } else {
      const payload: ReportPayload = {
        sessionId: body.sessionId,
        pitcherId: body.pitcherId,
        sport: asSport(session.sport),   // S1: the session row's sport, whatever the payload says
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
      try {
        useSportPalette(asSport(session.sport))   // S1
        html = buildReportHtml(payload)
      } catch (err) {
        return new Response(JSON.stringify({ error: 'Report generation failed: ' + (err as Error).message }), { status: 500, headers: corsHeaders })
      }
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
