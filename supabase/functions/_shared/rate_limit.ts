// H1 Part 2 (P1-06): the one sending-limit check every email/report function calls before it
// sends. Limits live in public.rate_limit_config (tunable without a deploy); the check-and-record
// is public.rate_limit_take(), callable only with the service role, so this file uses the admin
// client for exactly that one RPC -- the caller's id comes from their verified JWT, never the body.
//
// Env: RESEND_DAILY_QUOTA (the Resend plan's daily email quota; free plan = 100). The daily
// circuit breaker trips at 90% of it. ALERT_EMAIL (Joel) gets one email the first time it trips
// each day. Generating a report without emailing it never counts against email limits.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

export type RateKind = 'report_email' | 'report_generate' | 'verify_email' | 'guardian_email' | 'removal_notice' | 'email_change'

export type RateResult = { ok: true } | { ok: false; status: number; body: Record<string, unknown> }

export async function takeRateLimit(actorId: string, kind: RateKind, recipients: string[] = []): Promise<RateResult> {
  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { autoRefreshToken: false, persistSession: false }
  })
  const quota = Number(Deno.env.get('RESEND_DAILY_QUOTA') || '100')
  const cap = kind === 'report_generate' ? null : Math.max(0, Math.floor(quota * 0.9))
  const { data, error } = await admin.rpc('rate_limit_take', {
    p_actor: actorId, p_kind: kind, p_recipients: recipients, p_global_cap: cap
  })
  // Fail closed: if the limit can't be checked, nothing is sent.
  if (error || !data) {
    return { ok: false, status: 500, body: { error: 'Could not check sending limits: ' + (error?.message || 'no answer') } }
  }
  if (data.alert === true) await sendBreakerAlert(quota)
  if (data.ok !== true) {
    return { ok: false, status: 429, body: { error: data.message, code: 'rate_limited', limit: data.limit, retry_at: data.retry_at } }
  }
  return { ok: true }
}

async function sendBreakerAlert(quota: number): Promise<void> {
  const to = Deno.env.get('ALERT_EMAIL')
  const key = Deno.env.get('RESEND_API_KEY')
  const from = Deno.env.get('VERIFY_FROM_EMAIL') || Deno.env.get('REPORT_FROM_EMAIL')
  if (!to || !key || !from) return
  try {
    await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from, to: [to],
        subject: 'Knuckleball: daily email limit reached',
        html: `<p>Knuckleball has sent 90% of its daily email quota (${quota}/day), so email sends are paused until the 24-hour window clears. ` +
              `Reports can still be generated and viewed.</p><p>You get this at most once a day. Limits: public.rate_limit_config; ` +
              `quota: the RESEND_DAILY_QUOTA function secret.</p>`
      })
    })
  } catch { /* best effort: the refusal itself already protects the quota */ }
}
