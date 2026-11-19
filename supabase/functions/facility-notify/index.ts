// Deploy with: supabase functions deploy facility-notify
// Secrets: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY (platform-injected), RESEND_API_KEY,
//          VERIFY_FROM_EMAIL (or REPORT_FROM_EMAIL), OPERATOR_EMAILS (the first address gets the email),
//          RESEND_DAILY_QUOTA (via _shared/rate_limit.ts).
//
// R7 Stage B (Joel, Nov 19 2026; plans/r7-preconditions.md item 5): one plain email to the operator for each facility
// that signed itself up on the New account form. login.html calls it right after create_facility_self, with the new
// manager's own JWT; the app retries it once later if that call didn't get through (kb:facNotify).
//
// The caller can only announce their OWN facility: the admin client claims the row where manager_login = the caller's
// verified id, created_via = 'self_serve' and notified_at is null (setting notified_at), so a facility is announced at
// most once, whoever calls and however often. Nothing from the body is used. The admin client is used for that
// claim (organizations has no client grant), for undoing it if the send fails, and for the sending limit.
// Answers { ok: true, sent: true } or { ok: true, sent: false } (nothing to announce).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { takeRateLimit } from '../_shared/rate_limit.ts'
import { escapeEmailHtml } from '../_shared/email.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
}
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405)
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return json({ error: 'Missing Authorization header' }, 401)
  const caller = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: authHeader } } })
  const { data: { user }, error: userErr } = await caller.auth.getUser()
  if (userErr || !user) return json({ error: 'Unauthorized' }, 401)

  const to = (Deno.env.get('OPERATOR_EMAILS') || '').split(',').map(e => e.trim()).filter(Boolean)[0]
  const key = Deno.env.get('RESEND_API_KEY')
  const from = Deno.env.get('VERIFY_FROM_EMAIL') || Deno.env.get('REPORT_FROM_EMAIL')
  if (!to || !key || !from) return json({ error: 'Email is not set up.' }, 500)

  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { autoRefreshToken: false, persistSession: false } })
  const { data: claimed, error: cErr } = await admin.from('organizations').update({ notified_at: new Date().toISOString() })
    .eq('manager_login', user.id).eq('created_via', 'self_serve').is('notified_at', null)
    .select('id, name, created_at')
  if (cErr) return json({ error: cErr.message }, 500)
  const org: any = (claimed || [])[0]
  if (!org) return json({ ok: true, sent: false })
  const release = () => admin.from('organizations').update({ notified_at: null }).eq('id', org.id)

  const limited = await takeRateLimit(user.id, 'facility_notify', [to])
  if (!limited.ok) { await release(); return json(limited.body, limited.status) }

  const { data: mgr } = await admin.from('profiles').select('full_name').eq('id', user.id).maybeSingle()
  const lines = [
    `A facility signed itself up on Knuckleball.`,
    `Facility: ${org.name}`,
    `Manager: ${(mgr && mgr.full_name) || '(no name)'} <${user.email || ''}>`,
    `Created: ${new Date(org.created_at).toUTCString()}`,
    `It's listed on the operator page under Facilities.`
  ]
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      from, to: [to], subject: `New facility: ${org.name}`,
      text: lines.join('\n'),
      html: lines.map(l => `<p>${escapeEmailHtml(l)}</p>`).join('')
    })
  })
  if (!res.ok) { await release(); return json({ error: 'Could not send the email.' }, 502) }
  return json({ ok: true, sent: true })
})
