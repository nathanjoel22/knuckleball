// ============================================================================
// Geometry + formatting helpers for the U4/U4b HTML report renderer.
// Grid size is a PARAMETER everywhere (U2b will pass 7 instead of 5) --
// nothing here hardcodes 5 except the DEFAULT.
// ============================================================================

export const TYPE_PALETTE_HEX = ['#E8A83D', '#6FA287', '#C17A45', '#C0453B', '#7C9CBF', '#B98CCB', '#D4C15B', '#4FA8A8']
// S1 (Track S): each sport's 8 pitch colors, by position in the pitcher's
// own list -- must match SPORTS[sport].palette in bullpen-tracker.html, in
// order. TYPE_PALETTE_HEX above stays the baseball list.
export const SPORT_PALETTE_HEX: Record<string, string[]> = {
  baseball: TYPE_PALETTE_HEX,
  softball: ['#E27BA2', '#7FB8E0', '#6C5B7B', '#F6B26B', '#4FA3A5', '#9B8ADB', '#B36B5E', '#8C8C8C']
}
export type Sport = 'baseball' | 'softball'
export function asSport(v: unknown): Sport { return v === 'softball' ? 'softball' : 'baseball' }
// One report is built in one synchronous pass, so the session's palette is
// set once (index.ts, right before rendering) and every colorForType call in
// that pass reads it -- no other request can interleave.
let activePalette: string[] = TYPE_PALETTE_HEX
export function useSportPalette(sport: Sport): void { activePalette = SPORT_PALETTE_HEX[sport] ?? TYPE_PALETTE_HEX }
// S1: the softball report theme = the baseball CSS with its THEME colors
// swapped (docs/softball-theme-reference.html). A baseball report's CSS is
// the untouched original text, byte for byte.
const SOFTBALL_THEME_SWAP: [string, string][] = [
  ['#0F241B', '#234B6E'],   // dark anchor
  ['#E8F3EC', '#EAF4FB'],   // panel
  ['#CFE6D7', '#BFDCEF'],   // border
  ['#2E4A40', '#3A5A78'],   // secondary text
  ['#527065', '#5F7A91'],   // tertiary text
  ['#5B6B61', '#5F7A91'],
  ['#F7FAF8', '#F7FAFD'],   // page
  ['#B7C2B4', '#BCCBD8'],   // light text on the dark header
  ['#E8A83D', '#F2A7C3']    // accent (only ever on the dark header)
]
export function themedCss(css: string, sport: Sport): string {
  if (sport !== 'softball') return css
  return SOFTBALL_THEME_SWAP.reduce((out, [from, to]) => out.split(from).join(to), css)
}

// Lockstep with is_default_velo_reading() in
// supabase/migrations/20260921090000_u8_team_leaderboard.sql and
// isDefaultVeloReading()/U6_CUTOFF_TS in bullpen-tracker.html. The CLIENT
// applies this rule when building the payload (nulling out velo on any
// affected pitch before it's ever sent), so the renderer never needs its own
// copy of the cutoff value -- it just trusts velo as given. This constant
// exists here ONLY so a local test harness can build realistic fixtures the
// same way the client does; the deployed renderer does not import it.
export const U6_CUTOFF_TS = 1789965601000

// U11 (7): "Times to home" line, shared by both reports -- '' when no pitch
// in the session was timed (the normal case).
export function timesToHomeLine(pitches: { timeToPlate?: number | null }[]): string {
  const ts = pitches.map(p => p.timeToPlate).filter((v): v is number => typeof v === 'number' && isFinite(v))
  if (!ts.length) return ''
  const best = Math.min(...ts), avg = ts.reduce((a, b) => a + b, 0) / ts.length
  return `<p class="caption"><strong>Times to home</strong> (from the stretch): ${ts.length} timed · best ${best.toFixed(2)} s · average ${avg.toFixed(2)} s</p>`
}

export function escapeHtml(str: unknown): string {
  return String(str ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
}

// Every number that reaches the template goes through this: a client-supplied
// payload could send a string, an object, NaN, Infinity, or nothing at all.
// Returns null (never NaN, never a raw client value) so callers can treat
// "no valid number" as "omit this," matching the honesty rules.
export function safeNum(v: unknown): number | null {
  // Number(null) is 0 and Number('') is 0 in JS -- both finite, both wrong.
  // A missing/no-reading velocity must become "omit this," never a fake 0.
  if (v === null || v === undefined || v === '') return null
  const n = typeof v === 'number' ? v : Number(v)
  return Number.isFinite(n) ? n : null
}

export function pct(numerator: number, denominator: number): number | null {
  if (!denominator) return null
  return Math.round((numerator / denominator) * 100)
}

export function isStrikeCell(row: number, col: number, gridSize = 5): boolean {
  const inset = Math.floor(gridSize / 2) - 1 // 5->1, 7->2, matching the 3x3-of-5 / 5x5-of-7 strike zone
  return row >= inset && row < gridSize - inset && col >= inset && col < gridSize - inset
}

// D8: box 1/4/7 (or the 7x7 equivalent) is ALWAYS the inside column, from the
// BATTER'S own side -- never stored, always computed at render time from the
// physical cell + which side is at the plate. Only valid/meaningful inside a
// fixed-batter-side block; callers must never call this for a mixed-side plot.
export function zoneNumber(row: number, col: number, batterSide: 'R' | 'L', gridSize = 5): number | null {
  if (!isStrikeCell(row, col, gridSize)) return null
  const inset = Math.floor(gridSize / 2) - 1
  const zoneSize = gridSize - inset * 2 // 3 for a 5-grid, 3 for a 7-grid (7x7's strike zone is still 3x3 per U2)
  const rr = row - inset
  const rawCol = col - inset
  const cc = batterSide === 'R' ? rawCol : (zoneSize - 1 - rawCol)
  return rr * zoneSize + cc + 1
}

// Canonical vocabulary (Joel, Sept 10 2026) -- exact strings, no synonyms, no
// regularizing "low and away" to "low and out." Keyed by the SAME 1-9 numbers
// zoneNumber() produces for a 3x3 strike zone.
export const ZONE_NAMES: Record<number, string> = {
  1: 'up and in', 2: 'middle up', 3: 'up and out',
  4: 'middle in', 5: 'middle middle', 6: 'middle out',
  7: 'low and in', 8: 'middle low', 9: 'low and away'
}

export function colorForType(type: string, allTypes: string[]): string {
  const idx = allTypes.indexOf(type)
  return activePalette[idx >= 0 ? idx % activePalette.length : 0]
}
