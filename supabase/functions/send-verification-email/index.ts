// Deploy with: supabase functions deploy send-verification-email
// Requires these secrets set on your Supabase project (see SETUP.md):
//   RESEND_API_KEY, VERIFY_FROM_EMAIL, VERIFY_REDIRECT_URL, SUPABASE_URL, SUPABASE_ANON_KEY
//
// R0 follow-up: our own email-verification send, replacing reliance on
// Supabase's built-in confirmation email (which stops being sent at all
// once "Confirm email" is off). Mirrors send-session-report's trust
// model exactly -- runs with the CALLING user's own JWT, never
// service-role. generate_email_verify_token() is itself auth.uid()-scoped
// server-side, so this function can only ever send a verification link
// for the account that's calling it -- there is no pitcherId/email
// parameter to abuse.

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

  // Token generation happens server-side, scoped to this exact caller --
  // this function never sees or chooses whose token it is.
  const { data: token, error: tokenErr } = await callerClient.rpc('generate_email_verify_token')
  if (tokenErr || !token) {
    return new Response(JSON.stringify({ error: 'Could not generate a verification token: ' + (tokenErr?.message || 'unknown error') }), { status: 500, headers: corsHeaders })
  }

  const resendApiKey = Deno.env.get('RESEND_API_KEY')
  const fromEmail = Deno.env.get('VERIFY_FROM_EMAIL')
  const redirectBase = Deno.env.get('VERIFY_REDIRECT_URL')
  if (!resendApiKey || !fromEmail || !redirectBase) {
    return new Response(JSON.stringify({ error: 'Server email config missing' }), { status: 500, headers: corsHeaders })
  }

  const verifyLink = `${redirectBase}?t=${encodeURIComponent(token)}`
  const toEmail = user.email!

  const resendRes = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${resendApiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      from: fromEmail,
      to: [toEmail],
      subject: 'Verify your Knuckleball email',
      html: `<p>Click the link below to verify your Knuckleball account email.</p><p><a href="${escapeHtml(verifyLink)}">${escapeHtml(verifyLink)}</a></p><p>If you didn't create a Knuckleball account, you can ignore this email.</p>`
    })
  })

  if (!resendRes.ok) {
    const errText = await resendRes.text()
    return new Response(JSON.stringify({ error: 'Resend send failed: ' + errText }), { status: 502, headers: corsHeaders })
  }

  return new Response(JSON.stringify({ ok: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
})
