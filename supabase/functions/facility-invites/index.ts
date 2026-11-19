// Deploy with: supabase functions deploy facility-invites
// Secrets: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY (platform-injected),
//          OPERATOR_EMAILS (comma-separated login emails allowed to use it -- Joel's operator login),
//          optional REPORT_SITE_ORIGIN (staging: the local staging site, as for report links).
//
// Facility signup links (Joel, Oct 31 2026): operator.html's form, instead of pasting SQL. A facility emails Joel; Joel
// fills in the facility's name, the manager's email and each side's level, and gets the one-time link to send them
// (facility-signup.html?t=..., 14 days, that email only -- F1-A). Never sends email itself: the page offers a
// ready-made message in Joel's own mail app.
//
//   POST { action: 'list' }                       the newest 50 links with their state (open / used / expired)
//   POST { action: 'create', facility_name, manager_email, baseball_level, softball_level }
//   POST { action: 'cancel', token }               an unused link stops working now
// Refuses anyone not in OPERATOR_EMAILS (403). Uses the admin client only after that check.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
}
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

const SITE_ORIGIN = (() => {
  const v = (Deno.env.get('REPORT_SITE_ORIGIN') || '').trim().replace(/\/+$/, '')
  return /^https?:\/\/[A-Za-z0-9.-]+(:\d+)?$/.test(v) ? v : 'https://knuckleballonline.com'
})()
const linkFor = (token: string) => `${SITE_ORIGIN}/facility-signup.html?t=${token}`
const BB_LEVELS = ['little_league', 'high_school', 'college']
const SB_LEVELS = ['little_league', 'high_school_up']
// Why a link for this email can't work (create_facility's own refusals), in plain words.
const EMAIL_BLOCKS: Record<string, string> = {
  facility: 'This email already runs a facility on Knuckleball.',
  in_use: 'This email already has a Knuckleball account on a team. A facility needs an email that is new to Knuckleball (or a +facility version of it).',
  not_coach: 'This email already has a pitcher or parent account. A facility needs an email that is new to Knuckleball (or a +facility version of it).'
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405)
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return json({ error: 'Missing Authorization header' }, 401)
  const caller = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: authHeader } } })
  const { data: { user }, error: userErr } = await caller.auth.getUser()
  if (userErr || !user || !user.email) return json({ error: 'Unauthorized' }, 401)
  const operators = (Deno.env.get('OPERATOR_EMAILS') || '').split(',').map(e => e.trim().toLowerCase()).filter(Boolean)
  if (!operators.includes(user.email.toLowerCase())) return json({ error: 'This page is for the Knuckleball operator only.' }, 403)

  let body: Record<string, unknown>
  try { body = await req.json() } catch { return json({ error: 'invalid_json' }, 400) }
  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { autoRefreshToken: false, persistSession: false } })
  const action = String(body.action || 'list')

  if (action === 'list') {
    const { data, error } = await admin.from('facility_invites')
      .select('token, facility_name, manager_email, baseball_level, softball_level, created_at, expires_at, used_at')
      .order('created_at', { ascending: false }).limit(50)
    if (error) return json({ error: error.message }, 500)
    const now = Date.now()
    return json({ ok: true, invites: (data || []).map((i: any) => {
      const state = i.used_at ? 'used' : (new Date(i.expires_at).getTime() < now ? 'expired' : 'open')
      return { facility_name: i.facility_name, manager_email: i.manager_email, created_at: i.created_at, expires_at: i.expires_at,
               used_at: i.used_at, state, token: state === 'open' ? i.token : null, link: state === 'open' ? linkFor(i.token) : null }
    }) })
  }

  if (action === 'create') {
    const name = String(body.facility_name || '').trim()
    const email = String(body.manager_email || '').trim().toLowerCase()
    const bb = String(body.baseball_level || ''), sb = String(body.softball_level || '')
    if (name.length < 2 || name.length > 60) return json({ error: 'Facility name: 2 to 60 characters.' }, 400)
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) || email.length > 254) return json({ error: "That email doesn't look right." }, 400)
    if (!BB_LEVELS.includes(bb) || !SB_LEVELS.includes(sb)) return json({ error: 'Pick a level for each side.' }, 400)
    const { data: status, error: sErr } = await admin.rpc('facility_email_status', { p_email: email })
    if (sErr) return json({ error: sErr.message }, 500)
    if (EMAIL_BLOCKS[String(status)]) return json({ error: EMAIL_BLOCKS[String(status)], code: status }, 409)
    const { data, error } = await admin.from('facility_invites')
      .insert({ facility_name: name, manager_email: email, baseball_level: bb, softball_level: sb })
      .select('token, expires_at').single()
    if (error) return json({ error: error.message }, 500)
    return json({ ok: true, link: linkFor(data.token), expires_at: data.expires_at, existing_login: status === 'free' })
  }

  if (action === 'cancel') {
    const token = String(body.token || '')
    if (!/^[0-9a-f]{64}$/.test(token)) return json({ error: 'invalid token' }, 400)
    const { data, error } = await admin.from('facility_invites').update({ expires_at: new Date().toISOString() })
      .eq('token', token).is('used_at', null).select('token')
    if (error) return json({ error: error.message }, 500)
    return json({ ok: true, cancelled: (data || []).length })
  }
  return json({ error: 'unknown action' }, 400)
})
