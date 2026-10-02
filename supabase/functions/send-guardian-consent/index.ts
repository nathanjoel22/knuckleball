// Deploy with: supabase functions deploy send-guardian-consent
// Secrets (already set for send-verification-email): RESEND_API_KEY,
// VERIFY_FROM_EMAIL, VERIFY_REDIRECT_URL, SUPABASE_URL, SUPABASE_ANON_KEY.
// Optional: GUARDIAN_REDIRECT_URL (defaults to VERIFY_REDIRECT_URL with
// verify-email.html -> guardian-consent.html).
//
// P1-10 (Oct 2 2026): asks a 13-17 player's parent or guardian to approve
// the account. Same trust model as send-verification-email -- the CALLER's
// own JWT, never service-role. claim_guardian_send() (SECURITY DEFINER,
// auth.uid()-scoped) returns the recipient and link token for the caller's
// own login only, and refuses a second send within 10 minutes.
//
// Relay rules (P0-01's lesson -- the recipient is an address the user typed):
//  - there is NO recipient or body parameter: the address is the stored
//    guardian_email, nothing else;
//  - the message is a fixed template; the player's name is the only value
//    interpolated, HTML-escaped (and kept out of the subject line);
//  - at most one send per 10 minutes per account (enforced in the database).

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

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405)

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return json({ error: 'Missing Authorization header' }, 401)

  const callerClient = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } }
  })
  const { data: { user }, error: userErr } = await callerClient.auth.getUser()
  if (userErr || !user) return json({ error: 'Unauthorized' }, 401)

  const { data: claim, error: claimErr } = await callerClient.rpc('claim_guardian_send')
  if (claimErr) return json({ error: 'Could not prepare the email: ' + claimErr.message }, 500)
  if (!claim || claim.ok !== true) {
    const code = claim && claim.error ? claim.error : 'unknown'
    return json({ error: code, retry_after_seconds: claim?.retry_after_seconds ?? null }, code === 'too_soon' ? 429 : 400)
  }

  const resendApiKey = Deno.env.get('RESEND_API_KEY')
  const fromEmail = Deno.env.get('VERIFY_FROM_EMAIL')
  const verifyBase = Deno.env.get('VERIFY_REDIRECT_URL')
  const redirectBase = Deno.env.get('GUARDIAN_REDIRECT_URL') || (verifyBase ? verifyBase.replace('verify-email.html', 'guardian-consent.html') : '')
  if (!resendApiKey || !fromEmail || !redirectBase) return json({ error: 'Server email config missing' }, 500)

  const link = `${redirectBase}?t=${encodeURIComponent(claim.token)}`
  const name = escapeHtml(String(claim.name || 'A player'))
  const sport = claim.sport === 'softball' ? 'softball' : 'baseball'

  const html =
    `<p>Hello,</p>` +
    `<p><strong>${name}</strong> signed up for Knuckleball, a pitch-charting app for ${sport} pitchers and their coaches, ` +
    `and listed you as a parent or guardian. Because they told us they're 13 to 17, we need a parent or guardian to approve the account.</p>` +
    `<p>Until you approve, they can still chart their pitching, but they can't view or send reports.</p>` +
    `<p><a href="${escapeHtml(link)}">Review and approve the account</a></p>` +
    `<p>The page explains what's stored and who can see it, with links to our Privacy Policy and Terms. ` +
    `If you don't recognize this, you can ignore this email and nothing will be approved.</p>` +
    `<p>Knuckleball LLC</p>`

  const resendRes = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${resendApiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      from: fromEmail,
      to: [claim.email],                       // the STORED guardian address -- never a request parameter
      subject: 'A Knuckleball account needs a parent or guardian\'s approval',
      html
    })
  })
  if (!resendRes.ok) return json({ error: 'Resend send failed: ' + (await resendRes.text()) }, 502)

  return json({ ok: true })
})
