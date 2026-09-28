// ============================================================================
// Pure computation for the G2 game report. Mirrors compute.ts's shape and
// conventions exactly (plain data out, no HTML, hand-testable).
//
// IMPORTANT: the numbers that ALSO appear in History's game row (strike %,
// in-zone %, first-pitch strike %, K/BB/H, outs/innings) are deliberately
// NOT recomputed here -- those come from public.compute_game_summary(),
// called once by index.ts through the caller's own RLS-scoped client, the
// same SQL function History calls client-side. That is the "one
// definition" drafting decision 1 asks for; duplicating it in TS here would
// be exactly the two-definitions risk it's written to avoid. Everything in
// this file is report-ONLY detail (per-type, per-inning, count buckets,
// per-side, velocity by inning, recent-pens, cross-game trend) that History
// never shows, so there is nothing for it to disagree with.
// ============================================================================
import { isStrikeCell, zoneNumber, pct, safeNum } from './helpers.ts'

export interface GamePitch {
  type: string
  velo: number | null
  actualRow: number; actualCol: number
  batterSide: 'R' | 'L' | null
  ts: number
  result: string
  inPlayOutcome: 'hit' | 'out' | 'error' | 'reached' | null
  hitType: '1B' | '2B' | '3B' | 'HR' | null
  fielder: string | null
  delivery: 'set' | 'windup' | null
  inning: number
  outsBefore: number
  ballsBefore: number
  strikesBefore: number
  atBatIndex: number | null
}

// Decision 2: exact strike/ball split, restated here (not imported from the
// client) because this runs in a different runtime -- kept byte-identical
// to bullpen-tracker.html's GAME_STRIKE_RESULTS and to
// compute_game_summary's own copy in the migration. All three must move
// together if this set ever changes.
const STRIKE_RESULTS = new Set(['strike_looking', 'strike_swinging', 'foul', 'in_play', 'sac_bunt', 'sac_fly', 'dropped_third'])
const EXCLUDED_FROM_PCT = new Set(['interference', 'other'])
const THIN_SAMPLE = 5

function isStrikeResult(p: GamePitch): boolean { return STRIKE_RESULTS.has(p.result) }
function countsTowardPct(p: GamePitch): boolean { return !EXCLUDED_FROM_PCT.has(p.result) }
function isSwing(p: GamePitch): boolean {
  // Decision 5: swings = swinging strikes + fouls + balls in play. Takes
  // (called strikes, balls) are not swings.
  return p.result === 'strike_swinging' || p.result === 'foul' || p.result === 'in_play'
}
function isWhiff(p: GamePitch): boolean { return p.result === 'strike_swinging' }
// Byte-identical to is_k in the compute_game_summary migration and to
// GAME_STRIKE_RESULTS-adjacent K logic in bullpen-tracker.html's
// gameStats() -- three copies across two runtimes plus SQL, kept in sync
// by comment cross-reference since none of the three can literally import
// the others.
function isK(p: GamePitch): boolean {
  return p.result === 'dropped_third' || ((p.result === 'strike_looking' || p.result === 'strike_swinging') && p.strikesBefore >= 2)
}
function isBB(p: GamePitch): boolean { return p.result === 'ball' && p.ballsBefore >= 3 }
function isHit(p: GamePitch): boolean { return p.result === 'in_play' && p.inPlayOutcome === 'hit' }

// ---------- By pitch type (content spec section 5) ----------
export function computeGameByType(pitches: GamePitch[], allTypes: string[], gridSize = 5) {
  const total = pitches.length
  return allTypes.map(type => {
    const tp = pitches.filter(p => p.type === type)
    if (!tp.length) return null
    const counted = tp.filter(countsTowardPct)
    const strikes = counted.filter(isStrikeResult)
    const inZone = tp.filter(p => isStrikeCell(p.actualRow, p.actualCol, gridSize))
    const swings = tp.filter(isSwing)
    const whiffs = tp.filter(isWhiff)
    const calledStrikes = tp.filter(p => p.result === 'strike_looking')
    const inPlay = tp.filter(p => p.result === 'in_play')
    const velos = tp.map(p => safeNum(p.velo)).filter((v): v is number => v !== null)
    return {
      type,
      count: tp.length,
      thin: tp.length < THIN_SAMPLE,
      usagePct: pct(tp.length, total),
      strikePct: counted.length ? pct(strikes.length, counted.length) : null,
      inZonePct: pct(inZone.length, tp.length),
      whiffPct: swings.length ? pct(whiffs.length, swings.length) : null,
      whiffSwings: swings.length,
      calledStrikePct: pct(calledStrikes.length, tp.length),
      inPlay: {
        h: inPlay.filter(p => p.inPlayOutcome === 'hit').length,
        out: inPlay.filter(p => p.inPlayOutcome === 'out').length,
        e: inPlay.filter(p => p.inPlayOutcome === 'error').length
      },
      avgVelo: velos.length ? Math.round(velos.reduce((a, b) => a + b, 0) / velos.length) : null,
      peakVelo: velos.length ? Math.max(...velos) : null,
      hasVelo: velos.length > 0
    }
  }).filter((x): x is NonNullable<typeof x> => x !== null)
}

// ---------- By inning (content spec section 6) ----------
export function computeGameByInning(pitches: GamePitch[], gridSize = 5) {
  const innings = Array.from(new Set(pitches.map(p => p.inning))).sort((a, b) => a - b)
  return innings.map(inning => {
    const ip = pitches.filter(p => p.inning === inning)
    const counted = ip.filter(countsTowardPct)
    const strikes = counted.filter(isStrikeResult)
    const inZone = ip.filter(p => isStrikeCell(p.actualRow, p.actualCol, gridSize))
    const bf = new Set(ip.map(p => p.atBatIndex).filter((n): n is number => n !== null)).size
    const k = ip.filter(isK).length
    const bb = ip.filter(isBB).length
    const h = ip.filter(isHit).length
    const velos = ip.map(p => safeNum(p.velo)).filter((v): v is number => v !== null)
    return {
      inning,
      pitches: ip.length,
      strikes: strikes.length,
      strikePct: counted.length ? pct(strikes.length, counted.length) : null,
      inZonePct: pct(inZone.length, ip.length),
      battersFaced: bf,
      k, bb, h,
      avgVelo: velos.length ? Math.round(velos.reduce((a, b) => a + b, 0) / velos.length) : null,
      peakVelo: velos.length ? Math.max(...velos) : null,
      hasVelo: velos.length > 0
    }
  })
}

// ---------- Results by count (content spec section 7) ----------
// Three fixed buckets. A pitch's own (ballsBefore, strikesBefore) places it;
// counts outside these six exact states (e.g. 1-1, 2-1, 2-2) belong to none
// of the three rows and are simply not shown here -- the same behavior the
// spec's row list implies (only first-pitch/ahead/behind are named).
const COUNT_BUCKETS: { key: string; label: string; states: [number, number][] }[] = [
  { key: 'first', label: 'First pitch (0-0)', states: [[0, 0]] },
  { key: 'ahead', label: 'Ahead (0-2, 1-2)', states: [[0, 2], [1, 2]] },
  { key: 'behind', label: 'Behind (2-0, 3-0, 3-1)', states: [[2, 0], [3, 0], [3, 1]] }
]
export function computeGameByCount(pitches: GamePitch[]) {
  const total = pitches.length
  if (total < 20) return null // whole-section omission threshold, not per-row
  return COUNT_BUCKETS.map(bucket => {
    const bp = pitches.filter(p => bucket.states.some(([b, s]) => p.ballsBefore === b && p.strikesBefore === s))
    const counted = bp.filter(countsTowardPct)
    const strikes = counted.filter(isStrikeResult)
    const inPlay = bp.filter(p => p.result === 'in_play')
    return {
      key: bucket.key, label: bucket.label,
      pitches: bp.length,
      strikePct: counted.length ? pct(strikes.length, counted.length) : null,
      inPlay: {
        h: inPlay.filter(p => p.inPlayOutcome === 'hit').length,
        out: inPlay.filter(p => p.inPlayOutcome === 'out').length,
        e: inPlay.filter(p => p.inPlayOutcome === 'error').length
      }
    }
  })
}

// ---------- vs RHB / vs LHB (content spec section 8) ----------
export function computeGamePerSideBlock(pitches: GamePitch[], side: 'R' | 'L', gridSize = 5) {
  const sp = pitches.filter(p => p.batterSide === side)
  if (!sp.length) return null
  const counted = sp.filter(countsTowardPct)
  const strikes = counted.filter(isStrikeResult)
  const inZone = sp.filter(p => isStrikeCell(p.actualRow, p.actualCol, gridSize))
  const swings = sp.filter(isSwing)
  const whiffs = sp.filter(isWhiff)
  const k = sp.filter(isK).length
  const bb = sp.filter(isBB).length
  const h = sp.filter(isHit).length
  const bf = new Set(sp.map(p => p.atBatIndex).filter((n): n is number => n !== null)).size
  return {
    side,
    total: sp.length,
    battersFaced: bf,
    strikePct: counted.length ? pct(strikes.length, counted.length) : null,
    inZonePct: pct(inZone.length, sp.length),
    whiffPct: swings.length ? pct(whiffs.length, swings.length) : null,
    k, bb, h,
    pitches: sp,
    zoneCounts: (() => {
      const counts: Record<number, number> = {}
      for (const p of sp) {
        const num = zoneNumber(p.actualRow, p.actualCol, side, gridSize)
        if (num !== null) counts[num] = (counts[num] || 0) + 1
      }
      return counts
    })()
  }
}

export function computeGameExcludedNullSide(pitches: GamePitch[]): number {
  return pitches.filter(p => p.batterSide !== 'R' && p.batterSide !== 'L').length
}

// ---------- Velocity by inning (content spec section 9) ----------
// Pooled across pitch types -- the fatigue view is about the PITCHER across
// the game, not a type x inning matrix; per-type avg/peak already lives in
// computeGameByType (section 5). Drift by pitch order reuses
// computeVelocityDepth from compute.ts unchanged (spec item 7: "the
// renderer goes through the one function anyway") -- not duplicated here.
export function computeGameVelocityByInning(pitches: GamePitch[]) {
  const innings = Array.from(new Set(pitches.map(p => p.inning))).sort((a, b) => a - b)
  return innings.map(inning => {
    const velos = pitches.filter(p => p.inning === inning).map(p => safeNum(p.velo)).filter((v): v is number => v !== null)
    if (!velos.length) return { inning, hasVelo: false as const, avg: null, peak: null }
    return {
      inning, hasVelo: true as const,
      avg: Math.round(velos.reduce((a, b) => a + b, 0) / velos.length),
      peak: Math.max(...velos)
    }
  })
}

// ---------- Recent bullpens vs this game (content spec section 10) ----------
// Input is already pooled per-type across the pitcher's last-5-bullpens by
// the CLIENT (bullpen-tracker.html has the raw pitches for those sessions
// already loaded for History; pooling there keeps this payload small --
// see the packet's own payload-size escalation clause). This function only
// pairs each recent-pen row with the matching game-type row; it invents
// nothing and never recomputes a pen's own numbers.
export interface RecentPenTypeRow {
  type: string
  usagePct: number
  strikePct: number | null       // location-based, same measurement as game in-zone % (decision 9's pairing)
  commandPct: number | null
  commandLabel: 'zone' | 'exact'
}
export function computeRecentPensComparison(recentPens: RecentPenTypeRow[] | undefined, gameByType: ReturnType<typeof computeGameByType>) {
  if (!recentPens || !recentPens.length) return null
  return gameByType.map(g => {
    const pen = recentPens.find(r => r.type === g.type)
    if (!pen) return null
    return {
      type: g.type,
      penUsagePct: pen.usagePct, penStrikePct: pen.strikePct, penCommandPct: pen.commandPct, penCommandLabel: pen.commandLabel,
      gameUsagePct: g.usagePct, gameInZonePct: g.inZonePct, gameStrikePct: g.strikePct, gameWhiffPct: g.whiffPct
    }
  }).filter((x): x is NonNullable<typeof x> => x !== null)
}

// ---------- Trends across games (content spec section 11) ----------
export interface GameHistoryEntry {
  date: number; dateLabel: string
  strikePct: number | null; firstPitchStrikePct: number | null
  k: number; bb: number; h: number
  hasVelo: boolean; avgVelo: number | null
  pitches: number
}
export function computeGameTrends(history: GameHistoryEntry[]): GameHistoryEntry[] | null {
  if (!Array.isArray(history) || history.length < 3) return null
  return history.slice(-6)
}

// ---------- At-bat log (content spec section 12) ----------
// Decision 3: an at-bat's outcome is its last pitch. "No ending" (game
// stopped mid-count, or New batter tapped early) means that last pitch's
// own result doesn't end an at-bat by itself -- byte-identical to
// applyGameResultProgression's endsAtBat logic in bullpen-tracker.html
// (restated here, can't be imported across runtimes), so "incomplete" here
// can never disagree with what actually happened live.
function pitchEndsAtBat(p: GamePitch): boolean {
  switch (p.result) {
    case 'ball': return p.ballsBefore >= 3
    case 'strike_looking': case 'strike_swinging': return p.strikesBefore >= 2
    case 'foul': return false
    default: return true // in_play, hbp, sac_bunt, sac_fly, dropped_third, interference, other
  }
}

const FIELDER_LABEL: Record<string, string> = {
  P: 'P', C: 'C', '1B': '1B', '2B': '2B', '3B': '3B', SS: 'SS', LF: 'LF', CF: 'CF', RF: 'RF'
}

// Honesty note: the example notation in the content spec ("F8", "E6") is
// traditional scorebook shorthand that also encodes batted-ball type (fly
// vs ground vs line drive) -- data this product never charts (only WHICH
// fielder recorded the play). Inventing a ball-flight type to produce that
// exact notation would violate the honesty rules (U4b decisions 1-5:
// never invent). This uses a plainer, equally scannable label instead --
// "Out (CF)" / "Error (SS)" -- that says only what was actually recorded.
function atBatEndingLabel(lastPitch: GamePitch, isDroppedThirdReached: boolean): string {
  const fielder = lastPitch.fielder ? (FIELDER_LABEL[lastPitch.fielder] ?? lastPitch.fielder) : null
  switch (lastPitch.result) {
    case 'dropped_third': return isDroppedThirdReached ? 'K (reached)' : 'K'
    case 'strike_looking': case 'strike_swinging': return lastPitch.strikesBefore >= 2 ? 'K' : ''
    case 'ball': return lastPitch.ballsBefore >= 3 ? 'BB' : ''
    case 'in_play': {
      if (lastPitch.inPlayOutcome === 'hit') return `${lastPitch.hitType ?? 'Hit'}${fielder ? ' to ' + fielder : ''}`
      if (lastPitch.inPlayOutcome === 'error') return `Error${fielder ? ' (' + fielder + ')' : ''}`
      return `Out${fielder ? ' (' + fielder + ')' : ''}`
    }
    case 'sac_bunt': return 'Sac bunt'
    case 'sac_fly': return 'Sac fly'
    case 'hbp': return 'HBP'
    case 'interference': return 'Interference'
    case 'other': return 'Other'
    default: return ''
  }
}

export function resultGlyph(p: GamePitch): { glyph: string; label: string } {
  switch (p.result) {
    case 'ball': return { glyph: '○', label: '' }
    case 'strike_looking': return { glyph: '●', label: 'looking' }
    case 'strike_swinging': return { glyph: '✕', label: 'swinging' }
    case 'foul': return { glyph: '◐', label: 'foul' }
    case 'in_play': return { glyph: '■', label: 'in play' }
    case 'hbp': return { glyph: '★', label: 'hbp' }
    case 'sac_bunt': return { glyph: '▲', label: 'sac bunt' }
    case 'sac_fly': return { glyph: '▲', label: 'sac fly' }
    case 'dropped_third': return { glyph: '✕', label: 'dropped 3rd' }
    case 'interference': return { glyph: '—', label: 'interference' }
    default: return { glyph: '—', label: 'other' }
  }
}

export interface AtBatLogEntry {
  atBatIndex: number
  inning: number
  side: 'R' | 'L' | null
  delivery: 'set' | 'windup' | null
  pitches: GamePitch[]
  ending: string   // '' when incomplete
  incomplete: boolean
}
export function computeAtBatLog(pitches: GamePitch[]): AtBatLogEntry[] {
  const byAtBat = new Map<number, GamePitch[]>()
  for (const p of pitches) {
    if (p.atBatIndex === null || p.atBatIndex === undefined) continue
    if (!byAtBat.has(p.atBatIndex)) byAtBat.set(p.atBatIndex, [])
    byAtBat.get(p.atBatIndex)!.push(p)
  }
  const indices = Array.from(byAtBat.keys()).sort((a, b) => a - b)
  return indices.map(idx => {
    const ps = byAtBat.get(idx)!.slice().sort((a, b) => a.ts - b.ts)
    const last = ps[ps.length - 1]
    const complete = pitchEndsAtBat(last)
    const droppedThirdReached = last.result === 'dropped_third' && last.inPlayOutcome === 'reached'
    return {
      atBatIndex: idx,
      inning: ps[0].inning,
      side: ps[0].batterSide,
      delivery: ps[0].delivery,
      pitches: ps,
      ending: complete ? atBatEndingLabel(last, droppedThirdReached) : '',
      incomplete: !complete
    }
  })
}
