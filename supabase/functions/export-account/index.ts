// A1 (Joel, Oct 14 2026): "Download my data" -- everything Knuckleball holds about the signed-in login, as a ZIP,
// returned to the browser (nothing is emailed). plans/a1-account-deletion-export.md rule 1.
//
// Deploy: supabase functions deploy export-account
// Secrets: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY, optional REPORT_SITE_ORIGIN (staging).
//
// The caller is verified from their JWT; every query below is filtered to the caller's OWN profiles (all profiles
// on the login, S4) and, for a coach, the teams they coach -- read with the admin client because a few of those
// rows (the login's own consent records) aren't client-readable. Secret columns are never exported.
// 3 exports per user per day (H1's rate_limit_take, kind account_export -- not an email).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { takeRateLimit } from '../_shared/rate_limit.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Expose-Headers': 'content-disposition'
}
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
const SITE = (() => {
  const v = (Deno.env.get('REPORT_SITE_ORIGIN') || '').trim().replace(/\/+$/, '')
  return /^https?:\/\/[A-Za-z0-9.-]+(:\d+)?$/.test(v) ? v : 'https://knuckleballonline.com'
})()

// Never exported: tokens and in-flight verification state.
const PROFILE_SECRET = new Set(['email_verify_token', 'guardian_consent_token', 'email_verify_token_sent_at'])

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405)
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return json({ error: 'Missing Authorization header' }, 401)
  const caller = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } }
  })
  const { data: { user }, error: userErr } = await caller.auth.getUser()
  if (userErr || !user) return json({ error: 'Unauthorized' }, 401)

  const limit = await takeRateLimit(user.id, 'account_export', [])
  if (!limit.ok) return json(limit.body, limit.status)

  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { autoRefreshToken: false, persistSession: false }
  })
  try {
    const files = await buildExport(admin, user)
    const zip = makeZip(files)
    await admin.from('account_deletion_log').insert({ kind: 'export', profiles: 0 })   // an audit tick, counts only
    const day = new Date().toISOString().slice(0, 10)
    return new Response(new Blob([zip as BlobPart]), { headers: { ...corsHeaders, 'Content-Type': 'application/zip',
      'Content-Disposition': `attachment; filename="knuckleball-data-${day}.zip"` } })
  } catch (e) {
    return json({ error: 'Export failed: ' + String((e as Error).message || e) }, 500)
  }
})

async function all(q: any): Promise<any[]> {   // page through PostgREST's 1000-row cap
  const out: any[] = []
  for (let from = 0; ; from += 1000) {
    const { data, error } = await q().range(from, from + 999)
    if (error) throw new Error(error.message)
    out.push(...(data || []))
    if (!data || data.length < 1000) return out
  }
}

async function buildExport(admin: any, user: { id: string; email?: string }) {
  // every profile on the login (all columns except the secrets)
  const { data: profRows, error: pErr } = await admin.from('profiles').select('*').eq('account_id', user.id)
  if (pErr) throw new Error(pErr.message)
  const profiles = (profRows || []).map((p: any) => Object.fromEntries(Object.entries(p).filter(([k]) => !PROFILE_SECRET.has(k))))
  const ids: string[] = profiles.map((p: any) => p.id)
  if (!ids.length) throw new Error('no profile on this login')

  const memberships = await all(() => admin.from('pitcher_teams').select('pitcher_id, team_id, uniform_number, joined_at, teams(name, sport)').in('pitcher_id', ids))
  const staff = await all(() => admin.from('team_coaches').select('coach_id, team_id, role, teams(name, sport)').in('coach_id', ids))
  const headed = await all(() => admin.from('teams').select('id, name, sport, level, archived_at, created_at').in('coach_id', ids))
  const coachedTeams = [...new Set([...headed.map((t: any) => t.id), ...staff.map((s: any) => s.team_id)])]

  // sessions: pitched by, charted by, or (a coach) on a team they coach
  const byId = new Map<string, any>()
  const add = (rows: any[]) => rows.forEach((r) => byId.set(r.id, r))
  add(await all(() => admin.from('sessions').select('*').in('pitcher_id', ids)))
  add(await all(() => admin.from('sessions').select('*').in('logged_by', ids)))
  if (coachedTeams.length) add(await all(() => admin.from('sessions').select('*').in('team_id', coachedTeams)))
  const sessions = [...byId.values()].sort((a, b) => String(a.started_at).localeCompare(String(b.started_at)))
  const sids = sessions.map((s) => s.id)
  const chunk = <T,>(a: T[], n: number) => Array.from({ length: Math.ceil(a.length / n) }, (_, i) => a.slice(i * n, i * n + n))
  let pitches: any[] = [], events: any[] = []
  for (const c of chunk(sids, 150)) {
    pitches = pitches.concat(await all(() => admin.from('pitches').select('*').in('session_id', c).order('ts')))
    events = events.concat(await all(() => admin.from('game_events').select('*').in('session_id', c)))
  }
  const notes = await all(() => admin.from('session_notes').select('*').in('author_id', ids))
  // F1-C1 (decision D): the chat messages this login wrote (a deleted one included -- it's still theirs)
  const chat = await all(() => admin.from('chat_messages').select('id, thread_id, author_name, author_role, body, created_at, deleted_at, pinned_at')
    .eq('author_login', user.id).order('created_at'))
  // F1-G: who is linked to the players this login created, and the players this login is linked to
  const linksOnMine = await all(() => admin.from('player_links').select('player_id, login, role, created_at, profiles!player_links_player_id_fkey(full_name)').in('player_id', ids))
  const names = new Map<string, string>()
  for (const c of chunk([...new Set(linksOnMine.map((l: any) => l.login))], 150)) {
    (await all(() => admin.from('profiles').select('id, full_name').in('id', c))).forEach((p: any) => names.set(p.id, p.full_name))
  }
  const linksIHave = await all(() => admin.from('player_links').select('player_id, role, created_at, profiles!player_links_player_id_fkey(full_name)').eq('login', user.id))
  const links = [
    ...linksOnMine.map((l: any) => ({ direction: 'has access to your player', player: l.profiles?.full_name ?? null, person: names.get(l.login) ?? null, role: l.role, since: l.created_at })),
    ...linksIHave.map((l: any) => ({ direction: 'you have access to', player: l.profiles?.full_name ?? null, person: null, role: l.role, since: l.created_at }))
  ]

  const profileJson = {
    exported_at: new Date().toISOString(),
    login: { id: user.id, email: user.email ?? null },
    profiles, memberships, coaching_staff: staff, teams_headed: headed
  }
  const reports = sessions.filter((s) => s.report_path && !s.deleted_at)
    .map((s) => `${String(s.started_at).slice(0, 10)}  ${s.kind}  ${SITE}/report.html?r=${s.report_path}`)
  return [
    { name: 'profile.json', data: JSON.stringify(profileJson, null, 2) },
    { name: 'sessions.csv', data: toCsv(sessions) },
    { name: 'pitches.csv', data: toCsv(pitches) },
    { name: 'game_events.csv', data: toCsv(events) },
    { name: 'notes.csv', data: toCsv(notes) },
    { name: 'chat_messages.csv', data: toCsv(chat) },
    { name: 'player_access.csv', data: toCsv(links) },
    { name: 'reports.txt', data: (reports.length ? reports.join('\n') : 'No reports.') + '\n' },
    { name: 'README.txt', data: README(sessions.length, pitches.length, events.length, notes.length, chat.length, links.length) }
  ]
}

function toCsv(rows: any[]): string {
  if (!rows.length) return ''
  const cols = [...rows.reduce((set: Set<string>, r: any) => { Object.keys(r).forEach((k) => set.add(k)); return set }, new Set<string>())]
  const cell = (v: unknown) => {
    if (v === null || v === undefined) return ''
    const s = typeof v === 'object' ? JSON.stringify(v) : String(v)
    return /[",\r\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s
  }
  return [cols.join(','), ...rows.map((r) => cols.map((c) => cell(r[c])).join(','))].join('\r\n') + '\r\n'
}

const README = (ns: number, np: number, ne: number, nn: number, nc: number, nl: number) => `Knuckleball -- your data
Exported ${new Date().toISOString()}. Everything Knuckleball holds about this login.

profile.json     Every profile on this login (a login can hold several: a coach, a pitcher, a parent's players):
                 name, sport, role, throws, uniform numbers, report contacts, age attestation and consent records,
                 plus your team memberships, coaching staff roles and the teams you head.
sessions.csv     ${ns} sessions: the ones you pitched, the ones you charted, and (for a coach) your teams' sessions.
                 kind = bullpen or game; started_at / ended_at; team_id; charting_perspective; opponent (games);
                 deleted_at / pitch_count mark a deleted session (its pitches are gone).
pitches.csv      ${np} pitches, every stored column. Coordinates are the CATCHER'S view as stored (rows 0-4 top to
                 bottom, columns 0-4 left to right from behind the plate); reports draw them in the pitcher's view.
                 target_* = where it was aimed, actual_* = where it went; velo in mph; result / in_play_outcome /
                 spray_box / runners_after for games.
game_events.csv  ${ne} Live Game events that aren't pitches (steals, balks, automatic balls/strikes, ...).
notes.csv        ${nn} notes you wrote on sessions.
chat_messages.csv ${nc} chat messages you wrote at a training facility (body is the text; deleted_at marks one you deleted).
player_access.csv ${nl} links: who else can see a player you created (a parent/guardian, the player's own sign-in, or
                 friends and family), and the players you can see.
reports.txt      Links to the session reports. Anyone with a link can open it; links stop working when the
                 session or the account is deleted.

Columns that are ids (uuid) tie the files together: pitches.session_id -> sessions.id, sessions.pitcher_id ->
profile.json profiles[].id, and so on. Questions: nate@knuckleballonline.com
`

// ---------- a minimal ZIP writer (stored, no compression) -- no new dependency ----------
const CRC_TABLE = (() => {
  const t = new Uint32Array(256)
  for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0 }
  return t
})()
function crc32(b: Uint8Array): number {
  let c = 0xFFFFFFFF
  for (let i = 0; i < b.length; i++) c = CRC_TABLE[(c ^ b[i]) & 0xFF] ^ (c >>> 8)
  return (c ^ 0xFFFFFFFF) >>> 0
}
function makeZip(files: { name: string; data: string }[]): Uint8Array {
  const enc = new TextEncoder()
  const d = new Date()
  const dosTime = (d.getHours() << 11) | (d.getMinutes() << 5) | (d.getSeconds() >> 1)
  const dosDate = ((d.getFullYear() - 1980) << 9) | ((d.getMonth() + 1) << 5) | d.getDate()
  const parts: Uint8Array[] = [], central: Uint8Array[] = []
  let offset = 0
  for (const f of files) {
    const name = enc.encode(f.name), data = enc.encode(f.data), crc = crc32(data)
    const local = new Uint8Array(30 + name.length), lv = new DataView(local.buffer)
    lv.setUint32(0, 0x04034b50, true); lv.setUint16(4, 20, true); lv.setUint16(6, 0x0800, true); lv.setUint16(8, 0, true)
    lv.setUint16(10, dosTime, true); lv.setUint16(12, dosDate, true); lv.setUint32(14, crc, true)
    lv.setUint32(18, data.length, true); lv.setUint32(22, data.length, true); lv.setUint16(26, name.length, true); lv.setUint16(28, 0, true)
    local.set(name, 30)
    const cen = new Uint8Array(46 + name.length), cv = new DataView(cen.buffer)
    cv.setUint32(0, 0x02014b50, true); cv.setUint16(4, 20, true); cv.setUint16(6, 20, true); cv.setUint16(8, 0x0800, true); cv.setUint16(10, 0, true)
    cv.setUint16(12, dosTime, true); cv.setUint16(14, dosDate, true); cv.setUint32(16, crc, true)
    cv.setUint32(20, data.length, true); cv.setUint32(24, data.length, true); cv.setUint16(28, name.length, true)
    cv.setUint32(42, offset, true); cen.set(name, 46)
    parts.push(local, data); central.push(cen)
    offset += local.length + data.length
  }
  const cenSize = central.reduce((n, c) => n + c.length, 0)
  const end = new Uint8Array(22), ev = new DataView(end.buffer)
  ev.setUint32(0, 0x06054b50, true); ev.setUint16(8, files.length, true); ev.setUint16(10, files.length, true)
  ev.setUint32(12, cenSize, true); ev.setUint32(16, offset, true)
  const all = [...parts, ...central, end], out = new Uint8Array(all.reduce((n, p) => n + p.length, 0))
  let o = 0; for (const p of all) { out.set(p, o); o += p.length }
  return out
}
