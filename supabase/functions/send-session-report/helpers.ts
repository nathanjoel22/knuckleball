// ============================================================================
// Geometry + formatting helpers for the U4/U4b HTML report renderer.
// Grid size is a PARAMETER everywhere (U2b will pass 7 instead of 5) --
// nothing here hardcodes 5 except the DEFAULT.
// ============================================================================

export const TYPE_PALETTE_HEX = ['#E8A83D', '#6FA287', '#C17A45', '#C0453B', '#7C9CBF', '#B98CCB', '#D4C15B', '#4FA8A8']

// Lockstep with is_default_velo_reading() in
// supabase/migrations/20260921090000_u8_team_leaderboard.sql and
// isDefaultVeloReading()/U6_CUTOFF_TS in bullpen-tracker.html. The CLIENT
// applies this rule when building the payload (nulling out velo on any
// affected pitch before it's ever sent), so the renderer never needs its own
// copy of the cutoff value -- it just trusts velo as given. This constant
// exists here ONLY so a local test harness can build realistic fixtures the
// same way the client does; the deployed renderer does not import it.
export const U6_CUTOFF_TS = 1789965601000

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
  return TYPE_PALETTE_HEX[idx >= 0 ? idx % TYPE_PALETTE_HEX.length : 0]
}
