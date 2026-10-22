// A1 (Joel, Oct 14 2026): delete my account, in the app, with a 7-day grace. plans/a1-account-deletion-export.md;
// decisions: plans/a1-preconditions.md ("Joel's answers").
//
// Deploy: supabase functions deploy delete-account
// Secrets: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY, RESEND_API_KEY, REPORT_FROM_EMAIL,
//          A1_CRON_SECRET (the scheduled run's shared secret; set by Joel), optional REPORT_SITE_ORIGIN (staging).
//
// Actions (POST JSON):
//   status  { profile? }          the caller's own schedule + the teams that block it  (caller's JWT)
//   request { confirm, profile? } mark for deletion -- 'DELETE' is checked by the database, not only here;
//                                 the whole login signs out everywhere; a confirmation email (and the guardian's
//                                 for a 13-17 login). profile = a managed player's id: the parent deletes that
//                                 player (no email to the child, no sign-out).
//   cancel  { profile? }          restore (signing in during the grace and choosing Restore)
//   execute                       the scheduled run: header x-a1-cron-secret must equal A1_CRON_SECRET. Purges
//                                 everything past its due date through a1_purge_profile(), removes the storage
//                                 files, emails the completion confirmation (Apple), then deletes the login.
// The caller-facing actions use the caller's own RLS client; the service role is used only for: the sending-limit
// check, the guardian address (never client-readable), global sign-out, and the whole scheduled run.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { takeRateLimit } from '../_shared/rate_limit.ts'
import { brandedEmail } from '../_shared/email.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-a1-cron-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
}
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

function escapeHtml(str: string): string {
  return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
}
const SITE = (() => {
  const v = (Deno.env.get('REPORT_SITE_ORIGIN') || '').trim().replace(/\/+$/, '')
  return /^https?:\/\/[A-Za-z0-9.-]+(:\d+)?$/.test(v) ? v : 'https://knuckleballonline.com'
})()
const fmtDate = (iso: string) => new Date(iso).toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric', timeZone: 'America/New_York' })

function adminClient() {
  return createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { autoRefreshToken: false, persistSession: false }
  })
}

async function sendEmail(to: string[], subject: string, html: string): Promise<boolean> {
  const key = Deno.env.get('RESEND_API_KEY'), from = Deno.env.get('REPORT_FROM_EMAIL')
  if (!key || !from || !to.length) return false
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ from, to, subject, html })
  })
  return res.ok
}

// Branded emails (Joel, Oct 22): the account's sport (read before anything is purged)
async function accountSport(admin: any, accountId: string): Promise<string | null> {
  const { data } = await admin.from('profiles').select('sport').eq('account_id', accountId).not('sport', 'is', null).limit(1).maybeSingle()
  return data ? data.sport : null
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405)
  let body: any
  try { body = await req.json() } catch { return json({ error: 'Invalid JSON body' }, 400) }
  const action = body && body.action

  // ---------- the scheduled run ----------
  if (action === 'execute') {
    const secret = Deno.env.get('A1_CRON_SECRET') || ''
    if (!secret || req.headers.get('x-a1-cron-secret') !== secret) return json({ error: 'Forbidden' }, 403)
    return json(await executeDue())
  }

  // ---------- the account holder's own actions ----------
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return json({ error: 'Missing Authorization header' }, 401)
  const caller = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } }
  })
  const { data: { user }, error: userErr } = await caller.auth.getUser()
  if (userErr || !user) return json({ error: 'Unauthorized' }, 401)
  const profile = typeof body.profile === 'string' ? body.profile : null

  if (action === 'status') {
    const { data, error } = await caller.rpc('account_deletion_status', { p_profile: profile })
    if (error) return json({ error: error.message }, 500)
    return json(data, data && data.error ? 403 : 200)
  }

  if (action === 'cancel') {
    const { data, error } = await caller.rpc('cancel_account_deletion', { p_profile: profile })
    if (error) return json({ error: error.message }, 500)
    return json(data, data && data.error ? 403 : 200)
  }

  if (action === 'request') {
    const { data, error } = await caller.rpc('request_account_deletion', { p_confirm: String(body.confirm ?? ''), p_profile: profile })
    if (error) return json({ error: error.message }, 500)
    if (data && data.error) {
      const status = data.error === 'still_head' ? 409 : (data.error === 'confirmation_mismatch' ? 400 : 403)
      return json(data, status)
    }
    if (data.status === 'already_scheduled') return json(data)
    const wholeLogin = !profile || profile === user.id
    const admin = adminClient()
    let emailed = false
    if (wholeLogin) {
      // Sign the login out everywhere: every refresh token is revoked now; the app also checks the mark on
      // every online load, so a device holding a still-valid access token shows the scheduled screen.
      const token = authHeader.replace(/^Bearer\s+/i, '')
      try { await admin.auth.admin.signOut(token, 'global') } catch { /* the mark itself is what matters */ }
      // The confirmation: the login's address, and a 13-17 login's guardian (never client-readable)
      const { data: prim } = await admin.from('profiles').select('age_attestation, guardian_email').eq('id', user.id).maybeSingle()
      const to = [user.email].filter(Boolean) as string[]
      if (prim && prim.age_attestation === 'minor_13_17' && prim.guardian_email) to.push(prim.guardian_email)
      const limit = await takeRateLimit(user.id, 'account_deletion', to)
      if (limit.ok) {
        const due = fmtDate(data.due_at)
        emailed = await sendEmail(to, `Your Knuckleball account will be deleted on ${due}`, brandedEmail({
          sport: await accountSport(admin, user.id),
          title: 'Your account is scheduled for deletion',
          paragraphs: [
            `We received a request to delete this Knuckleball account. It will be deleted for good on <strong>${escapeHtml(due)}</strong>, ` +
              `along with every profile on it, the sessions pitched on it and their reports.`,
            `Changed your mind? Sign in before then and choose <strong>Restore my account</strong>.`,
          ],
          button: { href: `${SITE}/login.html`, label: 'Sign in to Knuckleball' },
          footnote: "If you didn't ask for this, sign in and restore the account, then change your password.",
        }))
      }
    }
    return json({ ...data, emailed })
  }

  return json({ error: 'Unknown action' }, 400)
})

// Everything past its due date: managed players (the parent's login stays) and whole logins.
async function executeDue() {
  const admin = adminClient()
  const { data: due, error } = await admin.rpc('a1_due_deletions')
  if (error) return { error: error.message }
  const done: Record<string, unknown>[] = []
  for (const d of (due || []) as { profile_id: string; account_id: string; is_player: boolean }[]) {
    try { done.push(d.is_player ? await purgePlayer(admin, d.profile_id) : await purgeLogin(admin, d.account_id)) }
    catch (e) { done.push({ error: String((e as Error).message || e) }) }
  }
  return { ok: true, processed: done.length, results: done }
}

async function removeFiles(admin: any, reports: string[], profileIds: string[]): Promise<number> {
  let files = 0
  const names = reports.filter(Boolean)
  if (names.length) {
    const { data } = await admin.storage.from('reports').remove(names)
    files += (data || []).length
    // the U12 archive copies live in dated folders under the same file name
    const { data: folders } = await admin.storage.from('reports-archive').list('', { limit: 1000 })
    for (const f of (folders || [])) {
      if (f.id) continue   // a file at the top level (the manifests sit inside the dated folders)
      const { data: arch } = await admin.storage.from('reports-archive').remove(names.map((n) => `${f.name}/${n}`))
      files += (arch || []).length
    }
  }
  if (profileIds.length) {
    const { data } = await admin.storage.from('headshots').remove(profileIds.map((id) => `${id}.jpg`))
    files += (data || []).length
  }
  return files
}

async function purgePlayer(admin: any, playerId: string) {
  const { data, error } = await admin.rpc('a1_purge_profile', { p_profile: playerId })
  if (error || (data && data.error)) throw new Error(error?.message || data.error)
  const files = await removeFiles(admin, data.reports || [], [playerId])
  await admin.from('account_deletion_log').insert({ kind: 'player', profiles: 1 + (data.profiles || 0), tombstoned: data.tombstoned || 0,
    pitches: data.pitches || 0, notes: data.notes || 0, files })
  return { kind: 'player', ok: true }
}

async function purgeLogin(admin: any, accountId: string) {
  // Who to tell, read before anything is gone (Apple: confirm when deletion completes)
  // Load the login BEFORE purging anything: if Auth can't load it, the deleteUser below would fail too, after the
  // purge, leaving a login with no profile that nothing retries. Skipped here, it stays due for tomorrow's run.
  const { data: u, error: uErr } = await admin.auth.admin.getUserById(accountId)
  if (uErr || !u || !u.user) throw new Error('login not loadable, left for the next run: ' + (uErr?.message || 'not found'))
  const email = u.user.email || null
  const { data: prim } = await admin.from('profiles').select('age_attestation, guardian_email').eq('id', accountId).maybeSingle()
  const sport = await accountSport(admin, accountId)
  const to = [email].filter(Boolean) as string[]
  if (prim && prim.age_attestation === 'minor_13_17' && prim.guardian_email) to.push(prim.guardian_email)

  // Every profile on the login: the non-primary ones first (a1_purge_profile handles each one's managed players),
  // the primary last. Pending invites addressed to the login's email and its rate-limit rows go too.
  const { data: profs } = await admin.from('profiles').select('id').eq('account_id', accountId)
  const ids: string[] = (profs || []).map((p: any) => p.id).sort((a: string, b: string) => (a === accountId ? 1 : 0) - (b === accountId ? 1 : 0))
  let reports: string[] = [], tomb = 0, pitches = 0, notes = 0, nprof = 0
  const purged: string[] = []
  for (const id of ids) {
    const { data, error } = await admin.rpc('a1_purge_profile', { p_profile: id })
    if (error || (data && data.error)) throw new Error(error?.message || data.error)
    if (data.status === 'already_gone') continue
    reports = reports.concat(data.reports || []); tomb += data.tombstoned || 0; pitches += data.pitches || 0
    notes += data.notes || 0; nprof += 1 + (data.profiles || 0); purged.push(id)
  }
  if (email) {   // exact match, either case (a pattern match would treat _ and % in an address as wildcards)
    await admin.from('invites').delete().eq('email', email)
    if (email.toLowerCase() !== email) await admin.from('invites').delete().eq('email', email.toLowerCase())
  }
  const files = await removeFiles(admin, reports, purged)

  const sendOk = to.length > 0 && (await takeRateLimit(accountId, 'account_deletion', to)).ok
  // the login's own rate-limit rows (including the one the completion email just logged) go last
  await admin.from('rate_limit_events').delete().eq('actor', accountId)
  const { error: delErr } = await admin.auth.admin.deleteUser(accountId)
  if (delErr) throw new Error('auth delete: ' + delErr.message)
  // the completion confirmation (Apple), only once the login is really gone (its sending-limit slot was taken above)
  if (sendOk) await sendEmail(to, 'Your Knuckleball account has been deleted', brandedEmail({
    sport,
    title: 'Your account has been deleted',
    paragraphs: ['Your Knuckleball account has been deleted, as you asked: every profile on it, the sessions pitched on it and their reports.'],
    footnote: 'Copies in our backups are removed within 7 days. Thanks for charting with us.',
  }))
  await admin.from('account_deletion_log').insert({ kind: 'login', profiles: nprof, tombstoned: tomb, pitches, notes, files })
  return { kind: 'login', ok: true }
}
