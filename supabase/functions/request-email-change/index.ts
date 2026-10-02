// Deploy with: supabase functions deploy request-email-change
// Secrets (already set for send-verification-email): RESEND_API_KEY,
// VERIFY_FROM_EMAIL, VERIFY_REDIRECT_URL, SUPABASE_URL, SUPABASE_ANON_KEY,
// SUPABASE_SERVICE_ROLE_KEY (platform-injected). Optional:
// EMAIL_CHANGE_REDIRECT_URL (defaults to VERIFY_REDIRECT_URL with
// verify-email.html -> bullpen-tracker.html).
//
// Change Email, one email (Joel, Oct 2 2026). Replaces the client calling
// supabase.auth.updateUser({ email }), which made Supabase send its own
// unbranded "Confirm your new email address" from its default sender, while
// Knuckleball's verification email went to the OLD address.
//
// Trust model:
//  - begin_email_change() runs as the CALLER (their JWT): it records the
//    request on their own login, rate-limits (one send per 10 minutes) and
//    cancels any outstanding verification link.
//  - The admin client is used for exactly ONE call: generateLink(), which
//    makes Supabase prepare the email-change link for THIS caller's own login
//    (the email comes from their verified JWT, never the request body)
//    WITHOUT sending anything. Same narrow admin use as invite-pitcher.
//  - The link goes only to the new address, in a fixed template; the only
//    interpolated value is the link itself, HTML-escaped (P0-01 relay rules).
//  - Clicking it applies the change; the tracker then calls
//    confirm_email_change(), which sets verification.
// Requires "Secure email change" OFF (one link completes the change).

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

  let body: { email?: unknown }
  try { body = await req.json() } catch { return json({ error: 'invalid_json' }, 400) }
  const newEmail = typeof body.email === 'string' ? body.email.trim().toLowerCase() : ''

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const callerClient = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } }
  })
  const { data: { user }, error: userErr } = await callerClient.auth.getUser()
  if (userErr || !user || !user.email) return json({ error: 'Unauthorized' }, 401)

  const resendApiKey = Deno.env.get('RESEND_API_KEY')
  const fromEmail = Deno.env.get('VERIFY_FROM_EMAIL')
  const verifyBase = Deno.env.get('VERIFY_REDIRECT_URL')
  const redirectTo = Deno.env.get('EMAIL_CHANGE_REDIRECT_URL')
    || (verifyBase ? verifyBase.replace('verify-email.html', 'bullpen-tracker.html') : '')
  if (!resendApiKey || !fromEmail || !redirectTo) return json({ error: 'Server email config missing' }, 500)

  const { data: begun, error: beginErr } = await callerClient.rpc('begin_email_change', { p_email: newEmail })
  if (beginErr) return json({ error: 'Could not start the change: ' + beginErr.message }, 500)
  if (!begun || begun.ok !== true) {
    const code = begun && begun.error ? begun.error : 'unknown'
    return json({ error: code, retry_after_seconds: begun?.retry_after_seconds ?? null }, code === 'too_soon' ? 429 : 400)
  }

  const admin = createClient(supabaseUrl, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { autoRefreshToken: false, persistSession: false }
  })
  const { data: linkData, error: linkErr } = await admin.auth.admin.generateLink({
    type: 'email_change_new',
    email: user.email,                     // the caller's own login, from their JWT
    newEmail: begun.new_email,
    options: { redirectTo: `${redirectTo}?email_change=1` }
  })
  const actionLink = linkData?.properties?.action_link
  if (linkErr || !actionLink) {
    await callerClient.rpc('abandon_email_change')
    // Most often: the address already belongs to another account.
    return json({ error: 'email_unavailable' }, 400)
  }

  const html =
    `<p>Hello,</p>` +
    `<p>Someone asked to change the email address on a Knuckleball account to this address. ` +
    `If that was you, confirm it here:</p>` +
    `<p><a href="${escapeHtml(actionLink)}">Confirm my new email</a></p>` +
    `<p>Until you do, the account keeps its current email address. ` +
    `If you didn't ask for this, ignore this email and nothing will change.</p>` +
    `<p>Knuckleball LLC</p>`

  const resendRes = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${resendApiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      from: fromEmail,
      to: [begun.new_email],                 // the validated, recorded address
      subject: 'Confirm your new Knuckleball email',
      html
    })
  })
  if (!resendRes.ok) {
    await callerClient.rpc('abandon_email_change')
    return json({ error: 'send_failed' }, 502)
  }
  return json({ ok: true })
})
