// Deploy with: supabase functions deploy send-removal-notice
// Requires these secrets set on your Supabase project (see SETUP.md):
//   RESEND_API_KEY, REPORT_FROM_EMAIL, SUPABASE_URL, SUPABASE_ANON_KEY
//
// R0 follow-up: notify a player by email when a coach removes them from a
// roster. Runs with the CALLING coach's own JWT, never service-role --
// same trust model as send-session-report and send-verification-email.
// get_removal_notice_info is the only place that resolves WHO to email
// and WHAT team name to use, and it verifies both "is this caller really
// the coach of this team" and "is this pitcher really on it right now"
// server-side before returning anything -- this function never trusts a
// client-supplied email address or team name.
//
// Called BEFORE the client deletes the pitcher_teams row (see
// bullpen-tracker.html's removeRosterPitcher) -- once that row is gone,
// get_removal_notice_info has nothing left to verify against. The
// removal itself proceeds regardless of whether this call or the email
// send succeeds; this is a best-effort notice, not a gate.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
}

function escapeHtml(str: string): string {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
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

  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } }
  })

  const { data: { user }, error: userErr } = await callerClient.auth.getUser()
  if (userErr || !user) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: corsHeaders })
  }

  let body: any
  try { body = await req.json() } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), { status: 400, headers: corsHeaders })
  }

  const { pitcherId, teamId } = body
  if (!pitcherId || !teamId) {
    return new Response(JSON.stringify({ error: 'pitcherId and teamId are required' }), { status: 400, headers: corsHeaders })
  }

  const { data: rows, error: infoErr } = await callerClient.rpc('get_removal_notice_info', {
    p_pitcher_id: pitcherId,
    p_team_id: teamId
  })
  if (infoErr || !rows || !rows.length) {
    return new Response(JSON.stringify({ error: 'Not authorized to notify this pitcher: ' + (infoErr?.message || 'not found') }), { status: 403, headers: corsHeaders })
  }
  const { email: toEmail, team_name: teamName } = rows[0]

  const resendApiKey = Deno.env.get('RESEND_API_KEY')
  const fromEmail = Deno.env.get('REPORT_FROM_EMAIL')
  if (!resendApiKey || !fromEmail) {
    return new Response(JSON.stringify({ error: 'Server email config missing' }), { status: 500, headers: corsHeaders })
  }

  const resendRes = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${resendApiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      from: fromEmail,
      to: [toEmail],
      subject: `Removed from ${teamName}`,
      html: `<p>This email serves to notify you that you have been removed from the ${escapeHtml(teamName)} team. We can't wait to see you back out there soon!</p>`
    })
  })

  if (!resendRes.ok) {
    const errText = await resendRes.text()
    return new Response(JSON.stringify({ error: 'Resend send failed: ' + errText }), { status: 502, headers: corsHeaders })
  }

  return new Response(JSON.stringify({ ok: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
})
