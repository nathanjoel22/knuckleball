// ============================================================================
// Pure computation over a report payload. No HTML here -- these functions
// return plain data so they can be unit-tested against a hand calculation
// independently of how the template renders them.
// ============================================================================
import { isStrikeCell, zoneNumber, pct, safeNum } from './helpers.ts'

export interface Pitch {
  type: string
  velo: number | null
  targetRow: number; targetCol: number
  actualRow: number; actualCol: number
  accuracyMode: string | null
  inAccuracyZone: boolean | null
  batterSide: 'R' | 'L' | null
  ts: number
  delivery?: 'set' | 'windup' | null   // U11 (6): bullpens carry it too now
  timeToPlate?: number | null           // U11 (7): seconds, when the charter timed it
  accuracyHitKind?: 'exact' | 'ra' | 'miss' | null   // U14: stored at tap 2; absent on every pitch from before U14
}

const THIN_SAMPLE = 5 // spec item 3: below this, show the count beside the percentage

export function isExactHit(p: Pitch): boolean {
  return p.actualRow === p.targetRow && p.actualCol === p.targetCol
}
// U14 (Joel, Oct 15): a session whose pitches carry a stored hit kind gets ONE accuracy number -- exact + RA hits over
// all pitches. Anything else (every session from before U14) takes exactly the code path it always did.
export function isU14(pitches: Pitch[]): boolean { return pitches.some(p => !!p.accuracyHitKind) }
export function isHit(p: Pitch): boolean {
  return p.accuracyHitKind ? (p.accuracyHitKind === 'exact' || p.accuracyHitKind === 'ra') : isExactHit(p)
}

// ---------- Summary (spec section 2) ----------
export function computeSummary(pitches: Pitch[], gridSize = 5) {
  const total = pitches.length
  const strikes = pitches.filter(p => isStrikeCell(p.actualRow, p.actualCol, gridSize)).length
  const zonePitches = pitches.filter(p => p.inAccuracyZone === true || p.inAccuracyZone === false)
  const hasZone = zonePitches.length > 0
  const exactHits = pitches.filter(isExactHit).length
  const u14 = isU14(pitches)
  const commandPct = u14 ? pct(pitches.filter(isHit).length, total)
    : hasZone
    ? pct(zonePitches.filter(p => p.inAccuracyZone === true).length, zonePitches.length)
    : pct(exactHits, total)
  const velos = pitches.map(p => safeNum(p.velo)).filter((v): v is number => v !== null)
  const hasVelo = velos.length > 0
  return {
    total,
    strikePct: pct(strikes, total),
    commandPct,
    commandLabel: u14 ? 'accuracy' as const : hasZone ? 'zone' as const : 'exact' as const,
    hasZone,
    peakVelo: hasVelo ? Math.max(...velos) : null,
    avgVelo: hasVelo ? Math.round(velos.reduce((a, b) => a + b, 0) / velos.length) : null,
    hasVelo
  }
}

// ---------- Command detail + miss tendency (spec section 4) ----------
export function computeCommandDetail(pitches: Pitch[], allTypes: string[], gridSize = 5) {
  const total = pitches.length
  const u14 = isU14(pitches)
  return allTypes.map(type => {
    const typePitches = pitches.filter(p => p.type === type)
    if (!typePitches.length) return null
    const strikes = typePitches.filter(p => isStrikeCell(p.actualRow, p.actualCol, gridSize)).length
    const exactHits = typePitches.filter(isExactHit).length
    const zonePitches = typePitches.filter(p => p.inAccuracyZone === true || p.inAccuracyZone === false)
    const velos = typePitches.map(p => safeNum(p.velo)).filter((v): v is number => v !== null)

    const misses = typePitches.filter(p => u14 ? !isHit(p) : !isExactHit(p))   // U14: an RA hit is not a miss
    let up = 0, down = 0, left = 0, right = 0
    for (const p of misses) {
      const dRow = p.actualRow - p.targetRow, dCol = p.actualCol - p.targetCol
      if (Math.abs(dRow) >= Math.abs(dCol)) { if (dRow < 0) up++; else down++ }
      else { if (dCol < 0) left++; else right++ }
    }
    const missTendency = misses.length
      ? { up: pct(up, misses.length)!, down: pct(down, misses.length)!, left: pct(left, misses.length)!, right: pct(right, misses.length)!, missCount: misses.length }
      : null // null = zero misses; the caller renders this as "on target every pitch," not an omission

    return {
      type,
      count: typePitches.length,
      thin: typePitches.length < THIN_SAMPLE,
      usagePct: pct(typePitches.length, total),
      strikePct: pct(strikes, typePitches.length),
      exactHitPct: pct(exactHits, typePitches.length),
      accuracyPct: pct(typePitches.filter(isHit).length, typePitches.length),   // U14: the one number
      zoneAccuracyPct: zonePitches.length ? pct(zonePitches.filter(p => p.inAccuracyZone === true).length, zonePitches.length) : null,
      hasZone: zonePitches.length > 0,
      avgVelo: velos.length ? Math.round(velos.reduce((a, b) => a + b, 0) / velos.length) : null,
      peakVelo: velos.length ? Math.max(...velos) : null,
      hasVelo: velos.length > 0,
      missTendency
    }
  }).filter((x): x is NonNullable<typeof x> => x !== null)
}

// ---------- vs RHB / vs LHB blocks (spec section 5, U4's own decision) ----------
export function computePerSideBlock(pitches: Pitch[], side: 'R' | 'L', allTypes: string[], gridSize = 5) {
  const sidePitches = pitches.filter(p => p.batterSide === side)
  if (!sidePitches.length) return null
  const strikes = sidePitches.filter(p => isStrikeCell(p.actualRow, p.actualCol, gridSize)).length
  const zonePitches = sidePitches.filter(p => p.inAccuracyZone === true || p.inAccuracyZone === false)
  const hasZone = zonePitches.length > 0
  const exactHits = sidePitches.filter(isExactHit).length
  const u14 = isU14(sidePitches)
  const commandPct = u14 ? pct(sidePitches.filter(isHit).length, sidePitches.length)
    : hasZone
    ? pct(zonePitches.filter(p => p.inAccuracyZone === true).length, zonePitches.length)
    : pct(exactHits, sidePitches.length)
  const usageByType = allTypes
    .map(type => ({ type, count: sidePitches.filter(p => p.type === type).length }))
    .filter(t => t.count > 0)
    .map(t => ({ ...t, usagePct: pct(t.count, sidePitches.length) }))
  return {
    side,
    total: sidePitches.length,
    strikePct: pct(strikes, sidePitches.length),
    commandPct,
    commandLabel: u14 ? 'accuracy' as const : hasZone ? 'zone' as const : 'exact' as const,
    u14,
    pitches: sidePitches,
    usageByType,
    // location breakdown: count of pitches landing in each of the 9 zones, this side's own numbering
    zoneCounts: (() => {
      const counts: Record<number, number> = {}
      for (const p of sidePitches) {
        const num = zoneNumber(p.actualRow, p.actualCol, side, gridSize)
        if (num !== null) counts[num] = (counts[num] || 0) + 1
      }
      return counts
    })()
  }
}

export function computeExcludedNullSide(pitches: Pitch[]): number {
  return pitches.filter(p => p.batterSide !== 'R' && p.batterSide !== 'L').length
}

// ---------- Velocity depth (spec section 6) ----------
export function computeVelocityDepth(pitches: Pitch[], allTypes: string[]) {
  const perType = allTypes.map(type => {
    const velos = pitches.filter(p => p.type === type).map(p => safeNum(p.velo)).filter((v): v is number => v !== null)
    if (!velos.length) return null
    return {
      type, count: velos.length, thin: velos.length < THIN_SAMPLE,
      avg: Math.round(velos.reduce((a, b) => a + b, 0) / velos.length),
      peak: Math.max(...velos), min: Math.min(...velos), range: Math.max(...velos) - Math.min(...velos)
    }
  }).filter((x): x is NonNullable<typeof x> => x !== null)

  // Drift: every pitch WITH a velocity reading, in the order it was thrown.
  const drift = pitches
    .map((p, i) => ({ order: i, velo: safeNum(p.velo), type: p.type, ts: p.ts }))
    .filter(p => p.velo !== null)
    .sort((a, b) => a.ts - b.ts)

  return { perType, hasVelo: perType.length > 0, drift }
}

// ---------- Workload and pitch mix (spec section 7) ----------
export function computeWorkload(pitches: Pitch[], allTypes: string[], recentSessionTotals: number[]) {
  const total = pitches.length
  const byType = allTypes
    .map(type => ({ type, count: pitches.filter(p => p.type === type).length }))
    .filter(t => t.count > 0)
    .map(t => ({ ...t, usagePct: pct(t.count, total) }))
  const recentAvg = recentSessionTotals.length
    ? Math.round(recentSessionTotals.reduce((a, b) => a + b, 0) / recentSessionTotals.length)
    : null
  return { total, byType, recentAvg }
}

// ---------- Trends (spec section 8, decision #4: 3+ prior sessions or omit) ----------
export interface HistoryEntry {
  date: number; dateLabel: string
  total: number; strikePct: number | null; commandPct: number | null; hasVelo: boolean; avgVelo: number | null
}
export function computeTrends(history: HistoryEntry[]): HistoryEntry[] | null {
  if (!Array.isArray(history) || history.length < 3) return null
  return history.slice(-6) // most recent up to 6, chronological
}
