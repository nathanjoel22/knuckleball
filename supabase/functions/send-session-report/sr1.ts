// ============================================================================
// SR1 Stage C (Joel, Nov 19 2026; plans/sr1-session-reports.md Stage C, decisions in plans/sr1c-preconditions.md):
// the answer-first report's shared parts -- the comparison read (Stage B's baselines, the last same-kind sessions, the
// throwing hand), the headline and "What stood out" rules, and the tabs / window switch / tiles / cards.
// Still no JavaScript in a stored report: tabs and windows are radio inputs + labels with :checked rules, and every
// id / name carries the session's first 8 characters so two reports drawn in one page never collide.
// Starting values are constants here (packet section 2); change them in one place.
// ============================================================================
import { escapeHtml, colorForType } from './helpers.ts'

// ---------- starting values ----------
export const DEFAULT_WINDOW = '3m'
export const WINDOWS: { key: string; label: string; caption: string }[] = [
  { key: '1m', label: '1 mo', caption: '1-month average' },
  { key: '3m', label: '3 mo', caption: '3-month average' },
  { key: '12m', label: '12 mo', caption: '12-month average' },
  { key: 'season', label: 'Season', caption: 'average this season' },
  { key: 'year_ago', label: 'Year ago', caption: 'average a year ago' }
]
const MISS_SHARE = 0.6, MISS_MIN = 5            // a pitch's misses going one way
const FADE_N = 10, FADE_MPH = 2                 // the fastball fade: last 10 vs first 10
const CLUSTER_SHARE = 0.5, CLUSTER_MIN = 4      // games: hits in one third of the zone
const SIDE_GAP = 15, SIDE_MIN = 10              // one batter side's strike % under the other
const INNING_MIN = 8                            // an inning's pitches before its strike % is judged
const TYPE_MIN = 5                              // a pitch type's pitches before its rate is judged this session
const STOOD_OUT_MAX = 3
// The fastball (Joel, Nov 19): baseball's four-seam and two-seam, softball's fastball -- the most thrown wins,
// a tie goes to the first in this list. Labelled by its own abbreviation.
const FASTBALLS = ['Four Seam Fastball', 'Two Seam Fastball', 'Fastball']
// The app's pitch catalogs' abbreviations (bullpen-tracker.html BASEBALL_ / SOFTBALL_PITCH_CATALOG)
const ABBR: Record<string, string> = {
  'Four Seam Fastball': '4SFB', 'Two Seam Fastball': '2SFB', 'Cutter': 'CU', 'Sinker': 'SK', 'Slider': 'SL', 'Sweeper': 'SW',
  'Curveball': 'CB', 'Slurve': 'SLV', 'Changeup': 'CH', 'Vulcan Changeup': 'VCH', 'Splitter': 'SP', 'Knuckleball': 'KN',
  'Fastball': 'FB', 'Change-up': 'CH', 'Drop ball': 'DR', 'Rise ball': 'RI', 'Curve ball': 'CB', 'Screwball': 'SC', 'Drop curve': 'DC'
}
export const abbrOf = (t: string) => ABBR[t] ?? t
const WORDS = ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten']
export const word = (n: number) => WORDS[n] ?? String(n)
const ORD = (n: number) => n + (n % 100 >= 11 && n % 100 <= 13 ? 'th' : (['th', 'st', 'nd', 'rd'][n % 10] ?? 'th'))
export { ORD as ordinal }
export const firstName = (name: string) => (String(name || '').trim().split(/\s+/)[0] || 'the pitcher')
const TAG_WORD: Record<string, string> = { command: 'command pen', velocity: 'velocity pen', short_pen: 'short pen' }
export const penWord = (purpose?: string | null) => TAG_WORD[purpose ?? ''] ?? 'pen'

// ---------- the comparison (read at save time, through the caller's own client) ----------
export interface WindowStats {
  n: number
  avg: Record<string, number> | null
  range: Record<string, [number, number]> | null
  types: Record<string, { n: number; avg: Record<string, number> | null; range: Record<string, [number, number]> | null }>
}
export interface Baselines { level: string | null; windows: Record<string, WindowStats> }
export interface RecentRow { pitches: number; strikes: number; hits: number; game: Record<string, number> | null }
export interface Workload { level: string | null; age_group: string | null; sport: string; seven_day: number; parts: { kind: string; started_at: string; pitches: number; this: boolean }[] }
export interface Comparison { baselines: Baselines | null; recent: RecentRow[]; throws: 'R' | 'L' | null; workload?: Workload | null }
export const NO_COMPARISON: Comparison = { baselines: null, recent: [], throws: null, workload: null }

// deno-lint-ignore no-explicit-any
export async function loadComparison(db: any, s: { id: string; pitcher_id: string; kind: string; purpose?: string | null; started_at: string }): Promise<Comparison> {
  const out: Comparison = { baselines: null, recent: [], throws: null, workload: null }
  try {   // SR1 D: the 7 days up to this session, level and age group (session_workload, caller's reach)
    const { data } = await db.rpc('session_workload', { p_session: s.id })
    if (data && typeof data === 'object' && !('error' in data)) out.workload = data as Workload
  } catch (_) { /* no workload cards */ }
  try {
    const { data } = await db.rpc('session_baselines', { p_session: s.id })
    if (data && typeof data === 'object' && !('error' in data) && data.windows) out.baselines = data as Baselines
  } catch (_) { /* no comparison: the report still builds */ }
  try {
    let q = db.from('session_stats').select('pitches, strikes, hits, game, started_at')
      .eq('pitcher_id', s.pitcher_id).eq('kind', s.kind).lt('started_at', s.started_at).gte('pitches', 10)
    if (s.kind === 'bullpen' && s.purpose) q = q.eq('purpose', s.purpose)
    const { data } = await q.order('started_at', { ascending: false }).limit(5)
    if (Array.isArray(data)) out.recent = data as RecentRow[]
  } catch (_) { /* no ranking */ }
  try {
    const { data } = await db.from('profiles').select('throws').eq('id', s.pitcher_id).maybeSingle()
    if (data && (data.throws === 'R' || data.throws === 'L')) out.throws = data.throws
  } catch (_) { /* left / right as drawn */ }
  return out
}

// ---------- SR1 Stage D: rest and the 7-day count (baseball only: Joel, Nov 19, "pitch count rules don't apply" to softball) ----------
// MLB / USA Baseball Pitch Smart, "Pitch Count Limits and Required Rest Recommendations",
// https://www.mlb.com/pitch-smart/pitching-guidelines (checked Nov 19, 2026). For each age group: the daily max and the
// top of each rest band (0, 1, 2, 3, 4 days). A count above the last band takes the last band (Joel, Nov 19).
export const PITCH_SMART: Record<string, { max: number; bands: number[] }> = {
  '7-8': { max: 50, bands: [20, 35, 50] },
  '9-10': { max: 75, bands: [20, 35, 50, 65, 75] },
  '11-12': { max: 85, bands: [20, 35, 50, 65, 85] },
  '13-14': { max: 95, bands: [20, 35, 50, 65, 95] },
  '15-16': { max: 95, bands: [30, 45, 60, 75, 95] },
  '17-18': { max: 105, bands: [30, 45, 60, 80, 105] },
  '19-22': { max: 120, bands: [30, 45, 60, 80, 105] }
}
// The 7-day guideline by level (packet decision 9): a heads-up past it, never "can't pitch"
export const SEVEN_DAY_GUIDE: Record<string, number> = { little_league: 100, high_school: 125, college: 150 }
const LEVEL_WORD: Record<string, string> = { little_league: 'little league', high_school: 'high school', college: 'college' }
const TZ = 'America/New_York'
export function restDays(age: string, pitches: number): number | null {
  const ps = PITCH_SMART[age]
  if (!ps || pitches <= 0) return null
  const i = ps.bands.findIndex(top => pitches <= top)
  return i === -1 ? ps.bands.length - 1 : i
}
const eastern = (ms: number) => { const p = new Intl.DateTimeFormat('en-US', { timeZone: TZ, year: 'numeric', month: 'numeric', day: 'numeric' }).formatToParts(new Date(ms))
  const g = (k: string) => Number(p.find(x => x.type === k)?.value); return Date.UTC(g('year'), g('month') - 1, g('day')) }
const dayFmt = (utcMidnight: number, opts: Intl.DateTimeFormatOptions) => new Date(utcMidnight).toLocaleDateString('en-US', { ...opts, timeZone: 'UTC' })
// back on the game's (Eastern) date + rest days + 1
export function backDate(gameMs: number, days: number): string {
  return dayFmt(eastern(gameMs) + (days + 1) * 86400000, { weekday: 'short', month: 'short', day: 'numeric' })
}
export function restCard(w: Workload | null | undefined, gamePitches: number, gameMs: number, independent: boolean): string {
  if (!w || w.sport !== 'baseball') return ''
  if (!w.age_group || !PITCH_SMART[w.age_group]) {
    return `<section class="kr-card kr-rest-none"><h3 class="kr-label">Rest</h3><p class="kr-sub">${independent
      ? 'No Pitch Smart age group set. Set it in Pitcher settings → Level.'
      : 'No Pitch Smart age group set for this team. The head coach sets it in Account → Team.'}</p></section>`
  }
  const d = restDays(w.age_group, gamePitches)
  if (d === null) return ''
  const ps = PITCH_SMART[w.age_group], age = w.age_group.replace('-', '–')
  const big = d === 0 ? `No rest day needed · back ${backDate(gameMs, 0)}` : `${d} day${d === 1 ? '' : 's'} · back ${backDate(gameMs, d)}`
  const over = gamePitches > ps.max ? ` Above Pitch Smart's daily max for ages ${age} (${ps.max}).` : ''
  return `<section class="kr-card kr-rest"><h3 class="kr-label">Rest · Pitch Smart ages ${age}</h3><div class="kr-rest-big">${big}</div><p class="kr-rest-sub">${gamePitches} game pitch${gamePitches === 1 ? '' : 'es'}.${over}</p></section>`
}
export function sevenDayCard(w: Workload | null | undefined, kid = false): string {
  if (!w || w.sport !== 'baseball') return ''
  const level = w.level && SEVEN_DAY_GUIDE[w.level] ? w.level : 'college'   // no level = college (Joel, Nov 19)
  const guide = SEVEN_DAY_GUIDE[level], n = w.seven_day, over = n > guide
  const mine = w.parts.find(x => x.this)
  const others = w.parts.filter(x => !x.this)
  const games = others.filter(x => x.kind === 'game').map(x => `${x.pitches} in ${dayFmt(eastern(Date.parse(x.started_at)), { weekday: 'long' })}'s game`)
  const pens = others.filter(x => x.kind !== 'game').map(x => x.pitches)
  const penText = !pens.length ? '' : pens.length === 1 ? `a pen of ${pens[0]}` : `pens of ${pens.slice(0, -1).join(', ')} and ${pens[pens.length - 1]}`
  const rest = [...games, penText].filter(Boolean)
  const head = mine ? `${mine.pitches} in this ${mine.kind === 'game' ? 'game' : 'pen'}` : ''
  const parts = rest.length ? `${head} + ${rest.join(' + ')} this week.` : `${head}, nothing else in the last 7 days.`
  const tail = kid   // SR1 E: a little league player's own version (packet Stage D)
    ? (over ? ` That's more than the ${guide} guideline. Talk with your coach about rest.` : ` Guideline: about ${guide} in 7 days.`)
    : over
    ? ` Above the ${guide} guideline for ${LEVEL_WORD[level]}. Keeping this pace makes fatigue or injury more likely. A heads-up, not a stop.`
    : ` Guideline for ${LEVEL_WORD[level]}: about ${guide} in 7 days.`
  const scale = Math.max(n, guide) * 1.08
  const bar = `<svg class="kr-7bar" viewBox="0 0 100 8" preserveAspectRatio="none" aria-hidden="true"><rect x="0" y="2.5" width="100" height="3" rx="1.5" fill="var(--kr-line)"/><rect x="0" y="2.5" width="${(100 * n / scale).toFixed(1)}" height="3" rx="1.5" fill="${over ? 'var(--kr-down)' : 'var(--kr-link)'}"/><rect x="${(100 * guide / scale - 0.4).toFixed(1)}" y="0" width="0.8" height="8" fill="var(--kr-ink)"/></svg>`
  return `<section class="kr-card kr-7d${over ? ' over' : ''}"><h3 class="kr-label">${over ? '⚠ ' : ''}Last 7 days</h3><div class="kr-7d-num">${n} pitch${n === 1 ? '' : 'es'}</div>${bar}<p class="kr-sub">${parts}${tail}</p></section>`
}

// ---------- SR1 Stage E: reader versions (decision 10) ----------
// One stored file carries its level's versions; the page showing it puts kr-as-player / kr-as-parent on an ancestor
// (report.html from &v=, History from who is looking). No class = the coach version. High school and college have no
// parent version: a parent sees the coach version (Joel, Nov 19).
export type Voice = 'coach' | 'you'
export type LevelGroup = 'll' | 'hs' | 'college'
export function levelGroup(level: string | null | undefined): LevelGroup {
  return level === 'little_league' ? 'll' : level === 'high_school' || level === 'high_school_up' ? 'hs' : 'college'
}
export const versionsFor = (g: LevelGroup) => g === 'll' ? ['coach', 'player', 'parent'] : ['coach', 'player']
// a block only some versions show (block-level); kr-ver-* classes
export const ver = (vs: string[], html: string, inline = false) => `<${inline ? 'span' : 'div'} class="kr-ver ${vs.map(v => 'kr-ver-' + v).join(' ')}">${html}</${inline ? 'span' : 'div'}>`

// ---------- SR1 Stage F: each version's email, frozen inside the report ----------
// The report file ends with one HTML comment holding each version's email summary (JSON), written at save, so a resend
// says exactly what the frozen report says. A report made before Stage F has none: it keeps the plain email.
export interface EmailVersion { subject: string; headline: string; stats: { v: string; l: string }[]; bullets: string[]; lines: { html: string; tone?: 'warn' | 'faint' }[]; button: string }
export function emailComment(m: Record<string, EmailVersion>): string {
  return `<!--kr-email ${JSON.stringify(m).replace(/--/g, '-\\u002d').replace(/>/g, '\\u003e')}-->`
}
export function readEmailComment(html: string): Record<string, EmailVersion> | null {
  const m = html.match(/<!--kr-email ([\s\S]*?)-->/)
  if (!m) return null
  try { return JSON.parse(m[1]) } catch (_) { return null }
}
export const shortDate = (ms: number) => new Date(ms).toLocaleDateString('en-US', { month: 'short', day: 'numeric', timeZone: TZ })
// the 7-day heads-up, only when over the line (baseball)
export function sevenDayEmailLine(w: Workload | null | undefined, kid = false): { html: string; tone: 'warn' } | null {
  if (!w || w.sport !== 'baseball') return null
  const level = w.level && SEVEN_DAY_GUIDE[w.level] ? w.level : 'college', g = SEVEN_DAY_GUIDE[level]
  if (w.seven_day <= g) return null
  return { tone: 'warn', html: kid ? `⚠ <strong>${w.seven_day} pitches in 7 days.</strong> That's more than the ${g} guideline. Talk with your coach about rest.`
    : `⚠ <strong>${w.seven_day} pitches in 7 days</strong>, above the ${g} guideline for ${LEVEL_WORD[level]}. A heads-up, not a stop.` }
}
export function restEmailLine(w: Workload | null | undefined, gamePitches: number, gameMs: number): { html: string } | null {
  if (!w || w.sport !== 'baseball' || !w.age_group || !PITCH_SMART[w.age_group]) return null
  const d = restDays(w.age_group, gamePitches)
  if (d === null) return null
  return { html: `<strong>Rest:</strong> ${d === 0 ? 'no rest day needed' : `${d} day${d === 1 ? '' : 's'}`} (Pitch Smart, ages ${w.age_group.replace('-', '–')}) · back <strong>${backDate(gameMs, d)}</strong>.` }
}
export function comparedEmailLine(c: Comparison, who: string, noun: string): { html: string; tone: 'faint' } | null {
  const n = c.baselines?.windows?.['3m']?.n ?? 0
  return n >= 3 ? { tone: 'faint', html: `Compared with ${who} 3-month average (${n} ${noun}s).` } : null
}

// ---------- small pure helpers ----------
export const pctOf = (a: number, b: number) => b ? Math.round(100 * a / b) : null
const r1 = (x: number) => Math.round(x * 10) / 10
const fmt1 = (x: number) => (Math.round(x * 10) / 10).toFixed(1).replace(/\.0$/, '')
export function pickFastball(pitches: { type: string; velo?: number | null }[]): { type: string | null; label: string; isFastball: boolean } {
  const count = (t: string) => pitches.filter(p => p.type === t).length
  const fb = FASTBALLS.map(t => ({ t, n: count(t) })).filter(x => x.n > 0).sort((a, b) => b.n - a.n)[0]
  if (fb) return { type: fb.t, label: abbrOf(fb.t), isFastball: true }
  const tally: Record<string, number> = {}
  pitches.forEach(p => { if (p.type) tally[p.type] = (tally[p.type] || 0) + 1 })
  const top = Object.entries(tally).sort((a, b) => b[1] - a[1])[0]
  return top ? { type: top[0], label: abbrOf(top[0]), isFastball: false } : { type: null, label: 'FB', isFastball: false }
}
export const gunned = (v: number | null | undefined): v is number => typeof v === 'number' && v > 0
export function avgVelo(ps: { velo?: number | null }[]): number | null {
  const v = ps.map(p => p.velo).filter(gunned)
  return v.length ? r1(v.reduce((a, b) => a + b, 0) / v.length) : null
}

// ---------- What stood out ----------
export interface StoodOut { mark: 'up' | 'down' | 'info'; text: string; size: number; kind: string; inning?: number; metric?: string; value?: number; dir?: string; type?: string }
export function outsideRange(cur: number | null, range: [number, number] | undefined, minWidth: number): { dir: 'above' | 'below'; size: number } | null {
  if (cur === null || !range) return null
  const [lo, hi] = range, w = Math.max(minWidth, hi - lo)
  if (cur > hi) return { dir: 'above', size: (cur - hi) / w }
  if (cur < lo) return { dir: 'below', size: (lo - cur) / w }
  return null
}
// whole numbers for % and pitches, one decimal for mph (the pictures' "normal 33–44%", "76.5–78.5")
export const rangeText = (r: [number, number], unit: string) => unit === 'mph' ? `${fmt1(r[0])}–${fmt1(r[1])}` : `${Math.round(r[0])}–${Math.round(r[1])}${unit}`
export function sortStoodOut(items: StoodOut[]): StoodOut[] {
  const order = ['rate', 'misses', 'fade', 'cluster', 'side', 'inning']
  return items.sort((a, b) => b.size - a.size || order.indexOf(a.kind) - order.indexOf(b.kind)).slice(0, STOOD_OUT_MAX)
}
// A pitch's miss directions from its target (bullpen). Up / down by row (row 0 is the top); arm / glove from the
// throwing hand -- stored columns are the catcher's frame, so a right-hander's arm side is the lower column. Without
// the hand: left / right as drawn (the pitcher's view mirrors the stored column).
export function missDirs(p: { targetRow: number; targetCol: number; actualRow: number; actualCol: number }, throws: 'R' | 'L' | null): string[] {
  const d: string[] = []
  if (p.actualRow < p.targetRow) d.push('up'); else if (p.actualRow > p.targetRow) d.push('down')
  if (p.actualCol !== p.targetCol) {
    const lower = p.actualCol < p.targetCol
    if (throws === 'R') d.push(lower ? 'arm' : 'glove')
    else if (throws === 'L') d.push(lower ? 'glove' : 'arm')
    else d.push(lower ? 'right' : 'left')
  }
  return d
}
export const DIR_WORDS: Record<string, string> = { up: 'up', down: 'down', arm: 'to the arm side', glove: 'to the glove side', left: 'to the left', right: 'to the right' }
export function missPattern(ps: { type: string; targetRow: number; targetCol: number; actualRow: number; actualCol: number }[], isHitFn: (p: never) => boolean, throws: 'R' | 'L' | null, types: string[]): StoodOut[] {
  const out: StoodOut[] = []
  for (const t of types) {
    const tp = ps.filter(p => p.type === t)
    const misses = tp.filter(p => !isHitFn(p as never))
    if (misses.length < MISS_MIN) continue
    const c: Record<string, number> = {}
    misses.forEach(m => missDirs(m, throws).forEach(d => { c[d] = (c[d] || 0) + 1 }))
    const top = Object.entries(c).sort((a, b) => b[1] - a[1])[0]
    if (!top || top[1] / misses.length < MISS_SHARE) continue
    const hits = tp.length - misses.length
    out.push({ mark: 'down', kind: 'misses', type: t, dir: top[0], size: (100 * top[1] / misses.length - 50) / 10,
      text: `${escapeHtml(t)}: ${top[1]} of ${misses.length} misses went ${DIR_WORDS[top[0]]}. Only ${hits} of ${tp.length} hit the spot.` })
  }
  return out
}
export function fadePattern(ps: { type: string; velo?: number | null }[], fbType: string | null, label: string): StoodOut | null {
  if (!fbType) return null
  const v = ps.filter(p => p.type === fbType).map(p => p.velo).filter(gunned)
  if (v.length < FADE_N * 2) return null
  const a = v.slice(0, FADE_N).reduce((x, y) => x + y, 0) / FADE_N, b = v.slice(-FADE_N).reduce((x, y) => x + y, 0) / FADE_N
  if (a - b < FADE_MPH) return null
  return { mark: 'info', kind: 'fade', size: (a - b) / FADE_MPH, value: r1(a - b),
    text: `${escapeHtml(label)} dropped ${fmt1(a - b)} mph over the last ${FADE_N} (${Math.round(a)} → ${Math.round(b)}).` }
}
export function sidePattern(ps: { batterSide: 'R' | 'L' | null }[], isStrike: (p: never) => boolean): StoodOut | null {
  const R = ps.filter(p => p.batterSide === 'R'), L = ps.filter(p => p.batterSide === 'L')
  if (R.length < SIDE_MIN || L.length < SIDE_MIN) return null
  const r = 100 * R.filter(p => isStrike(p as never)).length / R.length, l = 100 * L.filter(p => isStrike(p as never)).length / L.length
  if (Math.abs(r - l) < SIDE_GAP) return null
  return { mark: 'info', kind: 'side', size: Math.abs(r - l) / SIDE_GAP,
    text: `Strikes ${Math.round(r)}% vs right-handed batters, ${Math.round(l)}% vs left-handed.` }
}
export function clusterPattern(hits: { actualRow: number }[]): StoodOut | null {
  if (hits.length < CLUSTER_MIN) return null
  const band = (r: number) => r <= 1 ? 'up in' : r === 2 ? 'in the middle of' : 'down in'
  const c: Record<string, number> = {}
  hits.forEach(h => { const b = band(h.actualRow); c[b] = (c[b] || 0) + 1 })
  const top = Object.entries(c).sort((a, b) => b[1] - a[1])[0]
  if (top[1] / hits.length < CLUSTER_SHARE) return null
  return { mark: 'down', kind: 'cluster', size: (100 * top[1] / hits.length - 33) / 10,
    text: `${top[1]} of ${hits.length} hits came on pitches ${top[0]} the zone.` }
}
export const inningMin = INNING_MIN
export const typeMin = TYPE_MIN

// ---------- markup ----------
export const ids = (sessionId: string) => String(sessionId || 'x').replace(/[^a-zA-Z0-9]/g, '').slice(0, 8) || 'x'
// The radio inputs sit first in the page, before the header and the panels, so :checked ~ rules reach both.
export function radios(id: string, tabs: string[], windows: string[]): string {
  const t = tabs.map((_, i) => `<input class="kr-in kr-t${i + 1}" type="radio" name="kt-${id}" id="kt${i + 1}-${id}"${i === 0 ? ' checked' : ''}>`).join('')
  const w = windows.map(k => `<input class="kr-in kr-w-${k}" type="radio" name="kw-${id}" id="kw-${k}-${id}"${k === DEFAULT_WINDOW ? ' checked' : ''}>`).join('')
  return t + w
}
export function tabBar(id: string, tabs: string[]): string {
  return `<nav class="kr-tabs">${tabs.map((t, i) => `<label class="kr-tl kr-tl${i + 1}" for="kt${i + 1}-${id}">${escapeHtml(t)}</label>`).join('')}</nav>`
}
// SR1 E: one row of labels for every version; each label names its panel and the versions that show it
export function tabBarVersions(id: string, labels: TabLabel[]): string {
  return `<nav class="kr-tabs">${labels.map(l => `<label class="kr-tl kr-tl${l.panel} kr-ver ${l.versions.map(v => 'kr-ver-' + v).join(' ')}" for="kt${l.panel}-${id}">${escapeHtml(l.label)}</label>`).join('')}</nav>`
}
export function windowSwitch(id: string, windows: string[]): string {
  return `<div class="kr-ws">${windows.map(k => `<label class="kr-wl kr-wl-${k}" for="kw-${k}-${id}">${WINDOWS.find(w => w.key === k)?.label ?? k}</label>`).join('')}</div>`
}
// a block (or an inline run) shown only while its window is chosen
export const wb = (k: string, html: string) => `<div class="kr-wb kr-v-${k}">${html}</div>`
export const wi = (k: string, html: string) => `<span class="kr-wi kr-v-${k}">${html}</span>`
export type TabLabel = { panel: number; label: string; versions: string[] }
// SR1 G: a panel carries the versions whose tabs use it (print shows only those) and, after Summary, a print-only
// title line: this version's tab name, then `title` (the session and the window shown)
export const panel = (i: number, html: string, labels?: TabLabel[], title = '') => {
  if (!labels) return `<div class="kr-panel kr-p${i}">${html}</div>`
  const mine = labels.filter(l => l.panel === i)
  const vs = Array.from(new Set(mine.flatMap(l => l.versions)))
  const names = mine.map(l => `<span class="kr-ver ${l.versions.map(v => 'kr-ver-' + v).join(' ')}">${escapeHtml(l.label)}</span>`).join('')
  return `<div class="kr-panel kr-p${i} ${vs.map(v => 'kr-pv-' + v).join(' ')}">${i > 1 ? `<p class="kr-ptitle">${names} · ${title}</p>` : ''}${html}</div>`
}
const PRINT_WINDOW: Record<string, string> = { '1m': '1 month', '3m': '3 months', '12m': '12 months', season: 'this season', year_ago: 'a year ago' }
// SR1 G: "<name> · Bullpen · Nov 18, 2026 · compared with 3 months" (the window as chosen on screen)
export function printTitle(name: string, kind: string, date: string, wins: string[]): string {
  return `${escapeHtml(name)} · ${kind} · ${date}${wins.map(k => wi(k, ' · compared with ' + (PRINT_WINDOW[k] ?? k))).join('')}`
}
export const takeaway = (s: string) => `<h2 class="kr-takeaway">${s}</h2>`
export const card = (label: string, html: string, cls = '') => `<section class="kr-card${cls ? ' ' + cls : ''}">${label ? `<h3 class="kr-label">${label}</h3>` : ''}${html}</section>`

export interface TileSpec { label: string; cur: number | null; curText?: string; unit: '%' | 'mph' | ''; key: string; type?: string; sub?: string; plain?: boolean; neutral?: boolean }
// One tile for one window: value, change against the window's average, the range bar from 5 sessions.
export function tileFor(t: TileSpec, ws: WindowStats | undefined, noun: string): string {
  const val = t.curText ?? (t.cur === null ? '—' : (t.unit === 'mph' ? fmt1(t.cur) : String(t.cur)) + (t.unit === '%' ? '%' : ''))
  let change = '', bar = ''
  if (t.plain) change = t.sub ? `<div class="kr-chg kr-faint">${t.sub}</div>` : ''
  else if (t.cur === null) change = `<div class="kr-chg kr-faint">${t.sub ?? ''}</div>`
  else if (ws) {
    const src = t.type ? ws.types?.[t.type] : ws
    const n = t.type ? (src?.n ?? 0) : ws.n
    const avg = src?.avg?.[t.key], range = src?.range?.[t.key] as [number, number] | undefined
    if (avg === undefined || avg === null) {
      change = `<div class="kr-chg kr-faint">${n ? `only ${n} ${n === 1 ? noun : noun + 's'} · needs 3` : `no ${noun}s then`}</div>`
    } else {
      const d = t.unit === 'mph' ? r1(t.cur - r1(avg)) : t.cur - Math.round(avg)   // from the average as shown, so the two always agree
      const avgTxt = t.unit === 'mph' ? fmt1(avg) : String(Math.round(avg)) + (t.unit === '%' ? '%' : '')
      const cls = t.neutral || d === 0 ? 'kr-faint' : d > 0 ? 'kr-up' : 'kr-down'
      const dTxt = d === 0 ? `even with avg ${avgTxt}` : `${d > 0 ? '+' : '−'}${t.unit === 'mph' ? fmt1(Math.abs(d)) : Math.abs(d)}${t.unit === '%' ? ' pts' : ''} vs avg ${avgTxt}`
      change = `<div class="kr-chg ${cls}">${dTxt}</div>`
      if (range) bar = rangeBar(t.cur, range, t.neutral) + `<div class="kr-norm">normal ${rangeText(range, t.unit)}</div>`
    }
  }
  return `<div class="kr-tile"><div class="kr-tile-lbl">${escapeHtml(t.label)}</div><div class="kr-tile-val">${val}</div>${change}${bar}</div>`
}
function rangeBar(cur: number, [lo, hi]: [number, number], neutral?: boolean): string {
  let a = Math.min(lo, cur), b = Math.max(hi, cur)
  const pad = Math.max(1, (b - a) * 0.25); a -= pad; b += pad
  const x = (v: number) => (6 + 88 * (v - a) / (b - a)).toFixed(1)
  const dot = neutral || (cur >= lo && cur <= hi) ? 'var(--kr-ink)' : cur > hi ? 'var(--kr-up)' : 'var(--kr-down)'
  return `<svg class="kr-bar" viewBox="0 0 100 10" preserveAspectRatio="none" aria-hidden="true"><line x1="6" y1="5" x2="94" y2="5" stroke="var(--kr-line)" stroke-width="1.5"/><rect x="${x(lo)}" y="2.6" width="${(+x(hi) - +x(lo)).toFixed(1)}" height="4.8" rx="2.4" fill="var(--kr-band)"/><circle cx="${x(cur)}" cy="5" r="3.2" fill="${dot}"/></svg>`
}
export function windowCaption(first: string, k: string, ws: WindowStats | undefined, noun: string, extra: string, voice: Voice = 'coach'): string {
  const w = WINDOWS.find(x => x.key === k)
  const n = ws?.n ?? 0
  return `<p class="kr-wcap">Compared with ${voice === 'you' ? 'your' : escapeHtml(first) + "'s"} ${w?.caption ?? ''} · ${n} ${n === 1 ? noun : noun + 's'}${extra}${k === DEFAULT_WINDOW ? ' · default' : ''}</p>`
}
export function stoodOutCard(items: StoodOut[], hasRange: boolean, first: string, label = 'What stood out', voice: Voice = 'coach'): string {
  const mark = { up: '▲', down: '▼', info: 'i' }
  const rows = items.length
    ? items.map(it => `<li class="kr-so"><span class="kr-mk kr-mk-${it.mark}" aria-label="${it.mark === 'up' ? 'above' : it.mark === 'down' ? 'below' : 'note'}">${mark[it.mark]}</span><span>${it.text}</span></li>`).join('')
    : `<li class="kr-so kr-so-none">${hasRange ? `Nothing outside ${voice === 'you' ? 'your' : escapeHtml(first) + "'s"} normal range today.` : `Needs 5 sessions in the last 3 months to judge.`}</li>`
  return card(label, `<ul class="kr-sos">${rows}</ul><p class="caption">Always judged against the 3-month default, so it doesn't change with the window.</p>`)
}
export function spark(values: (number | null)[], color = 'var(--kr-link)'): string {
  const v = values.map((x, i) => ({ x: i, y: x })).filter((p): p is { x: number; y: number } => p.y !== null)
  if (v.length < 2) return ''
  const lo = Math.min(...v.map(p => p.y)), hi = Math.max(...v.map(p => p.y)), span = Math.max(1, hi - lo)
  const X = (i: number) => (4 + 152 * i / Math.max(1, values.length - 1)).toFixed(1), Y = (y: number) => (36 - 30 * (y - lo) / span).toFixed(1)
  const last = v[v.length - 1]
  return `<svg class="kr-spark" viewBox="0 0 160 40" aria-hidden="true"><polyline fill="none" stroke="${color}" stroke-width="2.4" stroke-linejoin="round" points="${v.map(p => X(p.x) + ',' + Y(p.y)).join(' ')}"/><circle cx="${X(last.x)}" cy="${Y(last.y)}" r="3.6" fill="${color}"/></svg>`
}
export function sparkCard(label: string, values: (number | null)[], valueText: string, sub: string, color?: string): string {
  return `<section class="kr-card kr-trend"><div><h3 class="kr-label">${escapeHtml(label)}</h3>${spark(values, color)}</div><div class="kr-trend-v"><div class="kr-trend-num">${valueText}</div><div class="caption">${escapeHtml(sub)}</div></div></section>`
}
export function simpleTable(head: string[], rows: string[][], hlRow = -1): string {
  return `<div class="table-scroll"><table class="data-table kr-tbl"><thead><tr>${head.map(h => `<th>${h}</th>`).join('')}</tr></thead><tbody>${
    rows.map((r, i) => `<tr${i === hlRow ? ' class="kr-hl"' : ''}>${r.map(c => `<td>${c}</td>`).join('')}</tr>`).join('')}</tbody></table></div>`
}
export const typeCell = (t: string, allTypes: string[]) => `<span class="dot" style="background:${colorForType(t, allTypes)}"></span>${escapeHtml(t)}`
export function footer(first: string, links: string, playerToo = false): string {
  const line = (who: string) => `<p>Numbers and patterns only: compared with ${who} own sessions, never graded.</p>`
  return `
  <footer class="report-footer kr-foot">
    ${playerToo ? ver(['coach', 'parent'], line(escapeHtml(first) + "'s")) + ver(['player'], line('your')) : line(escapeHtml(first) + "'s")}
    ${links}
  </footer>`
}

// The tab and window rules. Classes, not ids, so one stylesheet serves every report; `~` keeps each report's inputs
// to its own page (History's no-shadow fallback puts several in one document).
const NT = 8, WK = WINDOWS.map(w => w.key)
export const SR1_CSS = `
  .kr-in{ position:absolute; opacity:0; width:1px; height:1px; pointer-events:none; }
  .kr-ver{ display:none; } .kr-ver-coach{ display:block; } span.kr-ver-coach{ display:inline; } .kr-tl.kr-ver-coach{ display:block; }
  .kr-as-player .kr-ver-coach, .kr-as-parent .kr-ver-coach{ display:none; }
  .kr-as-player .kr-ver-player, .kr-as-parent .kr-ver-parent{ display:block; }
  .kr-as-player span.kr-ver-player, .kr-as-parent span.kr-ver-parent{ display:inline; }
  .kr-card.kr-work{ background:var(--kr-brand); border-color:var(--kr-brand); color:var(--kr-on-dark); }
  .kr-card.kr-work .kr-label, .kr-card.kr-work .kr-sub{ color:var(--kr-on-dark-dim); }
  .kr-tiles.kr-tiles-3{ grid-template-columns:repeat(3, 1fr); }
  .kr-word{ font-size:11.5px; font-weight:700; color:var(--kr-ink-faint); } .kr-word.kr-up{ color:var(--kr-up); }
  .kr-novelo{ border-top:1px dashed var(--kr-line); padding-top:10px; margin-top:6px; font-size:12px; color:var(--kr-ink-faint); }
  .report-header.kr-head{ border-radius:12px 12px 0 0; margin-bottom:0; padding-bottom:0; gap:8px; }
  .kr-head-top{ display:flex; justify-content:space-between; align-items:center; gap:12px; flex-wrap:wrap; }
  .kr-head h1{ font-size:30px; }
  .kr-head .brand-mark{ font-size:16px; }
  .kr-head .sport-tag{ align-self:center; font-size:10px; letter-spacing:0.1em; padding:4px 9px; }
  .kr-head-top{ flex-wrap:nowrap; }
  .kr-tabs{ display:flex; gap:22px; overflow-x:auto; -webkit-overflow-scrolling:touch; scrollbar-width:none; margin:8px -20px 0; padding:0 20px; }
  .kr-tabs::-webkit-scrollbar{ display:none; }
  .kr-tl{ flex:none; padding:12px 2px 11px; font-size:12.5px; font-weight:800; letter-spacing:0.04em; text-transform:uppercase; color:var(--kr-on-dark-dim); border-bottom:3px solid transparent; cursor:pointer; white-space:nowrap; }
  .kr-panel{ display:none; }
  ${Array.from({ length: NT }, (_, i) => `.kr-t${i + 1}:checked ~ .kr-main .kr-p${i + 1}{ display:block; } .kr-t${i + 1}:checked ~ .report-header .kr-tl${i + 1}{ color:var(--kr-on-dark); border-bottom-color:var(--kr-accent); }`).join('\n  ')}
  .kr-in:focus-visible ~ .report-header .kr-tabs{ outline:2px solid var(--kr-accent); outline-offset:2px; }
  .kr-main{ padding-top:18px; }
  .kr-wb, .kr-wi{ display:none; }
  ${WK.map(k => `.kr-w-${k}:checked ~ .kr-main .kr-wb.kr-v-${k}{ display:block; } .kr-w-${k}:checked ~ .kr-main .kr-wi.kr-v-${k}{ display:inline; } .kr-w-${k}:checked ~ .kr-main .kr-wl-${k}{ background:var(--kr-brand); color:var(--kr-on-dark); }`).join('\n  ')}
  .kr-card{ background:var(--kr-card); border:1px solid var(--kr-line); border-radius:12px; padding:16px; margin:0 0 14px; }
  .kr-label{ font-family:var(--kr-sans); font-size:10.5px; font-weight:800; letter-spacing:0.12em; text-transform:uppercase; color:var(--kr-ink-faint); margin:0 0 10px; }
  .kr-headline{ font-family:var(--kr-display); font-size:25px; font-weight:800; line-height:1.02; text-transform:none; letter-spacing:0; margin:0 0 8px; border:0; padding:0; }
  .kr-takeaway{ font-family:var(--kr-display); font-size:21px; font-weight:800; line-height:1.08; text-transform:none; letter-spacing:0; border:0; padding:0; margin:4px 0 14px; }
  .kr-sub{ margin:0; font-size:13px; color:var(--kr-ink-faint); }
  .kr-ws{ display:flex; border:1px solid var(--kr-line); border-radius:9px; overflow:hidden; background:var(--kr-card); max-width:520px; }
  .kr-wl{ flex:1; min-height:32px; display:flex; align-items:center; justify-content:center; font-size:10.5px; font-weight:800; cursor:pointer; color:var(--kr-ink); }
  .kr-wl + .kr-wl{ border-left:1px solid var(--kr-line); }
  .kr-wcap{ font-size:12px; color:var(--kr-ink-faint); margin:8px 0 12px; }
  .kr-tiles{ display:grid; grid-template-columns:1fr 1fr; gap:10px; margin:0 0 14px; }
  .kr-tile{ background:var(--kr-card); border:1px solid var(--kr-line); border-radius:12px; padding:12px 14px; min-width:0; }
  .kr-tile-lbl{ font-size:10.5px; font-weight:800; letter-spacing:0.08em; text-transform:uppercase; color:var(--kr-ink-faint); }
  .kr-tile-val{ font-family:var(--kr-display); font-size:28px; font-weight:900; line-height:1.1; font-variant-numeric:tabular-nums; }
  .kr-chg{ font-size:11.5px; font-weight:700; }
  .kr-up{ color:var(--kr-up); } .kr-down{ color:var(--kr-down); } .kr-faint{ color:var(--kr-ink-faint); }
  .kr-bar{ display:block; width:100%; height:12px; margin:6px 0 2px; }
  .kr-norm{ font-size:11.5px; font-weight:700; color:var(--kr-ink-faint); }
  .kr-strip{ display:grid; grid-template-columns:repeat(6, 1fr); background:var(--kr-card); border:1px solid var(--kr-line); border-radius:12px; padding:10px 6px; margin:0 0 14px; text-align:center; }
  .kr-strip b{ display:block; font-family:var(--kr-display); font-size:22px; font-weight:900; font-variant-numeric:tabular-nums; }
  .kr-strip span{ font-size:10.5px; font-weight:800; letter-spacing:0.08em; color:var(--kr-ink-faint); }
  .kr-sos{ list-style:none; margin:0; padding:0; display:flex; flex-direction:column; gap:10px; }
  .kr-so{ display:flex; gap:10px; align-items:flex-start; font-size:13.5px; line-height:1.4; }
  .kr-so-none{ color:var(--kr-ink-faint); }
  .kr-mk{ flex:none; width:22px; height:22px; border-radius:6px; display:flex; align-items:center; justify-content:center; color:#FFFFFF; font-size:11px; font-weight:800; }
  .kr-mk-up{ background:var(--kr-up); } .kr-mk-down{ background:var(--kr-down); } .kr-mk-info{ background:var(--kr-info); }
  .kr-tbl tr.kr-hl td{ background:var(--kr-hl); }
  .kr-tbl td, .kr-tbl th{ padding-left:6px; }
  .kr-trend{ display:flex; justify-content:space-between; align-items:center; gap:12px; }
  .kr-trend > div:first-child{ flex:1; min-width:0; }
  .kr-spark{ display:block; width:100%; max-width:220px; height:auto; }
  .kr-trend-num{ font-family:var(--kr-display); font-size:30px; font-weight:900; text-align:right; }
  .kr-trend-v .caption{ text-align:right; margin:0; }
  .kr-main .section{ margin:18px 0; }
  .kr-foot{ text-align:center; }
  .kr-chips{ display:flex; flex-wrap:wrap; gap:6px 14px; font-size:12px; color:var(--kr-ink-dim); margin:8px 0 0; }
  .kr-rest{ background:var(--kr-brand); border-color:var(--kr-brand); color:var(--kr-on-dark); }
  .kr-rest .kr-label{ color:var(--kr-on-dark-dim); }
  .kr-rest-big{ font-family:var(--kr-display); font-size:26px; font-weight:900; line-height:1.1; }
  .kr-rest-sub{ margin:6px 0 0; font-size:13px; color:var(--kr-on-dark-dim); }
  .kr-7d-num{ font-family:var(--kr-display); font-size:24px; font-weight:900; }
  .kr-7bar{ display:block; width:100%; height:10px; margin:6px 0 8px; }
  .kr-7d.over{ background:var(--kr-warn-bg); border-color:var(--kr-warn-line); }
  .kr-7d.over .kr-label{ color:var(--kr-down); }
  .kr-7d.over .kr-sub{ color:var(--kr-ink-dim); }
  .kr-ptitle{ display:none; }
  /* SR1 G: print every tab of the version on screen, one tab per page (hide before show: a panel two versions use) */
  @media print{
    .kr-tabs, .kr-ws{ display:none !important; }
    .report-header.kr-head{ border-radius:12px; padding-bottom:16px; margin-bottom:0; }
    .kr-panel{ display:none !important; }
    .kr-panel.kr-pv-coach{ display:block !important; }
    .kr-as-player .kr-panel.kr-pv-coach, .kr-as-parent .kr-panel.kr-pv-coach{ display:none !important; }
    .kr-as-player .kr-panel.kr-pv-player, .kr-as-parent .kr-panel.kr-pv-parent{ display:block !important; }
    .kr-panel:not(.kr-p1){ break-before:page; page-break-before:always; }
    .kr-ptitle{ display:block; margin:0 0 14px; padding-bottom:8px; border-bottom:2px solid var(--kr-ink); font-size:11px; font-weight:800; letter-spacing:0.08em; text-transform:uppercase; color:var(--kr-ink); }
    .kr-card, .kr-tile, .kr-tiles, .kr-strip, .kr-trend, .kr-so, .kr-takeaway{ break-inside:avoid; page-break-inside:avoid; }
    .kr-takeaway, .kr-label{ break-after:avoid; page-break-after:avoid; }
    .kr-main .section{ break-inside:auto; page-break-inside:auto; }   /* a tall older section may continue; its charts, rows and blocks still never split */
  }
  @media (min-width:640px){ .kr-tiles{ grid-template-columns:repeat(4, 1fr); } }
  @media (max-width:600px){ .kr-tabs{ margin:8px -20px 0; } .kr-head h1{ font-size:30px; } }
`
