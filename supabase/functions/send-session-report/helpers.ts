// ============================================================================
// Geometry + formatting helpers for the U4/U4b HTML report renderer.
// Grid size is a PARAMETER everywhere (U2b will pass 7 instead of 5) --
// nothing here hardcodes 5 except the DEFAULT.
// ============================================================================

export const TYPE_PALETTE_HEX = ['#FFB81C', '#22B573', '#FF6B35', '#E63946', '#3D8BFF', '#B15CFF', '#F2E14C', '#00B8C4']
// S1 (Track S): each sport's 8 pitch colors, by position in the pitcher's
// own list -- must match SPORTS[sport].palette in bullpen-tracker.html, in
// order. TYPE_PALETTE_HEX above stays the baseball list. D2 (Oct 13 2026): the
// Broadcast palettes; css/tokens.css --pitch-1..8 hold the same lists (pre-push checks all three).
export const SPORT_PALETTE_HEX: Record<string, string[]> = {
  baseball: TYPE_PALETTE_HEX,
  softball: ['#FF4F9A', '#2F9BFF', '#7A3FB8', '#FF9F1C', '#00A99D', '#7A53FF', '#CD4730', '#6C7684']
}
export type Sport = 'baseball' | 'softball'
export function asSport(v: unknown): Sport { return v === 'softball' ? 'softball' : 'baseball' }
// One report is built in one synchronous pass, so the session's palette is
// set once (index.ts, right before rendering) and every colorForType call in
// that pass reads it -- no other request can interleave.
let activePalette: string[] = TYPE_PALETTE_HEX
export function useSportPalette(sport: Sport): void { activePalette = SPORT_PALETTE_HEX[sport] ?? TYPE_PALETTE_HEX }
// D2 Stage D (Oct 13 2026): a NEW report carries its own colors and fonts as CSS variables
// (--kr-*), one :root block for its sport -- written into the report file itself, so a stored
// report never depends on the site's css/tokens.css and a later token change can't restyle a
// report someone already has the link to. Values = css/tokens.css (D2). The --kr- prefix keeps them
// apart from report.html's own tokens (the report is drawn inside that page). Replaces S1's
// softball hex swap; reports sent before D2 keep their own CSS and are never touched.
const REPORT_VARS: Record<Sport, Record<string, string>> = {
  baseball: {
    bg: '#F3F5F2', card: '#FFFFFF', surface: '#E8EDE9', line: '#D5DDD7', hair: '#E8EDE9',
    ink: '#07140F', 'ink-dim': '#26342D', 'ink-faint': '#56645C', axis: '#56645C', grid: '#E6EAE7',
    brand: '#061A12', 'on-dark': '#FFFFFF', 'on-dark-dim': '#C2CEC6', 'on-dark-faint': '#86978C',
    accent: '#FFB81C', 'accent-on-dark': '#FFB81C', 'on-accent': '#07140F', 'accent-ink': '#8A5A00', link: '#16593D', print: '#07140F'
  },
  softball: {
    bg: '#F4F7FB', card: '#FFFFFF', surface: '#E6F1FA', line: '#CFE0EE', hair: '#E6F1FA',
    ink: '#0B2540', 'ink-dim': '#2C4560', 'ink-faint': '#5A6E84', axis: '#5A6E84', grid: '#E3EAF2',
    brand: '#0B2540', 'on-dark': '#FFFFFF', 'on-dark-dim': '#C5D3E2', 'on-dark-faint': '#8A9BB0',
    accent: '#FF4F9A', 'accent-on-dark': '#FF79B3', 'on-accent': '#0B2540', 'accent-ink': '#B0175A', link: '#1F5C99', print: '#0B2540'
  }
}
const REPORT_FONTS =
  " --kr-sans:'Archivo', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;" +
  " --kr-display:'Big Shoulders Display', 'Archivo', 'Arial Narrow', sans-serif;" +
  " --kr-wordmark:'Black Ops One', 'Big Shoulders Display', 'Arial Black', sans-serif;"
export function reportVars(sport: Sport): string {
  const v = REPORT_VARS[sport] ?? REPORT_VARS.baseball
  return ':root{' + Object.entries(v).map(([k, val]) => ` --kr-${k}:${val};`).join('') + REPORT_FONTS + ' }'
}
// Result colors (game charts) -- data colors from the D2 pitch palette; swing-and-miss wears the sport's accent.
export const RESULT_COLOR = {
  ball: '#3D8BFF', called_strike: '#E63946', swinging_strike: 'var(--kr-accent)', foul: '#F2E14C', in_play: '#22B573', other: '#A7B0AA'
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
// Amendment 16 (Joel, Oct 6 2026): every location grid in a report is drawn in the PITCHER'S
// view -- looking in from the mound, the way pitchers and pitching coaches read a chart. It's a
// left-right mirror at DRAW time only: stored coordinates stay catcher-frame, and zone numbers
// still come from zoneNumber() with the stored (catcher-frame) column, so 1/4/7 stay inside for
// either batter. One setting for the whole report (the app has the same REPORT_VIEW).
export const REPORT_VIEW: 'pitcher' | 'catcher' = 'pitcher'
export const VIEW_NAME = REPORT_VIEW === 'pitcher' ? "pitcher's view" : "catcher's view"
// Stored column <-> drawn column. Its own inverse, so it converts both ways.
export function viewCol(col: number, gridSize = 5): number { return REPORT_VIEW === 'pitcher' ? gridSize - 1 - col : col }
// The header note: only when the charter stood on the other side from the view drawn.
export function viewNote(chartingPerspective: string | null | undefined): string {
  const chartedFromPitcher = chartingPerspective === 'behind_pitcher'
  if (chartedFromPitcher === (REPORT_VIEW === 'pitcher')) return ''
  return `<p class="header-note">Charted from behind the ${chartedFromPitcher ? 'pitcher' : 'catcher'}. Every plot in this report is drawn in the ${VIEW_NAME}.</p>`
}

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
