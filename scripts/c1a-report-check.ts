// C1 Stage A (report side): every FULL session (both parts charted -- every session that exists today) must build the
// same report, byte for byte, before and after C1. This builds pen and game reports from fixture payloads with the
// report function as it is on origin/main (copied to a folder, see BEFORE below) and with the working copy, and compares
// the HTML. It also renders the partial cases (Intent only / Outcome only pens, an Intent-only game, an Outcome &
// Response only game) and writes every output to OUT so they can be looked at.
//
// usage:
//   B=<scratch>/report-before; mkdir -p $B && for f in $(git ls-tree --name-only origin/main supabase/functions/send-session-report/); do git show origin/main:$f > $B/$(basename $f); done
//   deno run --allow-read --allow-write --allow-env scripts/c1a-report-check.ts $B <out-dir>
// exit 1 on any difference.
const BEFORE = Deno.args[0]
const OUT = Deno.args[1]
if (!BEFORE || !OUT) { console.error('usage: c1a-report-check.ts <report-before dir> <out dir>'); Deno.exit(2) }
const abs = (p: string) => p.startsWith('/') ? p : Deno.cwd() + '/' + p
const here = new URL('../supabase/functions/send-session-report/', import.meta.url).href
const before = {
  pen: await import('file://' + abs(BEFORE) + '/template.ts'),
  game: await import('file://' + abs(BEFORE) + '/template_game.ts'),
  helpers: await import('file://' + abs(BEFORE) + '/helpers.ts')
}
const after = {
  pen: await import(here + 'template.ts'),
  game: await import(here + 'template_game.ts'),
  helpers: await import(here + 'helpers.ts')
}
await Deno.mkdir(OUT, { recursive: true })

// ---------- a seeded random, so every run builds the same fixtures ----------
let seed = 7
const rnd = () => { seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 }
const pick = <T>(a: T[]): T => a[Math.floor(rnd() * a.length)]
const clamp = (v: number) => Math.max(0, Math.min(4, v))
const T0 = Date.UTC(2026, 10, 18, 20, 0)

// ---------- comparisons (Stage B baselines, recent rows, hand, workload) ----------
const ws = (n: number) => ({
  n,
  avg: { spot_pct: 41, strike_pct: 61, velo: 83.2, pitches: 34, fp_strike_pct: 56, in_zone_pct: 46 },
  range: { spot_pct: [30, 50], strike_pct: [55, 66], velo: [82, 84.5], pitches: [25, 45], fp_strike_pct: [45, 65], in_zone_pct: [40, 52] },
  types: {
    'Four Seam Fastball': { n, avg: { spot_pct: 45, strike_pct: 64, velo: 84.1 }, range: { spot_pct: [35, 55], strike_pct: [55, 70], velo: [83, 85.5] } },
    'Curveball': { n, avg: { spot_pct: 30, strike_pct: 50 }, range: { spot_pct: [20, 40], strike_pct: [40, 60] } }
  }
})
const comparison = (level: string, sport: string, kind: string) => ({
  baselines: { level, windows: { '1m': ws(4), '3m': ws(9), '12m': ws(20), season: ws(12), ...(level === 'college' ? {} : { year_ago: ws(2) }) } },
  recent: [1, 2, 3, 4, 5].map(i => ({ pitches: 30 + i, strikes: 18 + i, hits: 10 + (i % 3), game: kind === 'game' ? { strikes: 40 + i, strike_pct_denominator: 70 } : null })),
  throws: 'R',
  workload: { level, age_group: sport === 'baseball' ? '15-16' : null, sport, seven_day: 131,
    parts: [{ kind: 'game', started_at: '2026-11-15T23:00:00Z', pitches: 61, this: false }, { kind: 'bullpen', started_at: '2026-11-16T15:00:00Z', pitches: 30, this: false },
      { kind, started_at: '2026-11-18T20:00:00Z', pitches: 40, this: true }] }
})
const LEVELS: Record<string, string[]> = { baseball: ['little_league', 'high_school', 'college'], softball: ['little_league', 'high_school_up'] }

// ---------- pens ----------
const PEN_TYPES = ['Four Seam Fastball', 'Curveball', 'Changeup', 'Slider']
type Mode = 'u14' | 'exact' | 'zone'
function penPitches(n: number, mode: Mode, opts: { radar?: boolean } = {}) {
  const out = []
  for (let i = 0; i < n; i++) {
    const type = pick(['Four Seam Fastball', 'Four Seam Fastball', 'Curveball', 'Changeup'])
    const tr = 1 + Math.floor(rnd() * 3), tc = 1 + Math.floor(rnd() * 3)
    const off = rnd() < 0.4 ? [0, 0] : [pick([-1, 0, 1, 2]), pick([-1, 0, 1, -2])]
    const ar = clamp(tr + off[0]), ac = clamp(tc + off[1])
    const exact = ar === tr && ac === tc
    const p: Record<string, unknown> = {
      type, velo: opts.radar === false ? null : (type === 'Four Seam Fastball' ? 80 + Math.floor(rnd() * 7) : rnd() < 0.5 ? 70 + Math.floor(rnd() * 6) : null),
      targetRow: tr, targetCol: tc, actualRow: ar, actualCol: ac, accuracyMode: null,
      inAccuracyZone: mode === 'zone' ? (exact || rnd() < 0.3) : null,
      batterSide: pick(['R', 'R', 'L', null]), ts: T0 + i * 20000, delivery: pick(['set', 'windup']), timeToPlate: null
    }
    if (mode === 'u14') p.accuracyHitKind = exact ? 'exact' : rnd() < 0.35 ? 'ra' : 'miss'
    out.push(p)
  }
  return out
}
const history = [3, 6, 9, 12, 15].map(d => ({ date: T0 - d * 86400000, dateLabel: `11/${18 - d}`, total: 30 + d, strikePct: 55 + d, commandPct: 35 + d, hasVelo: d % 2 === 0, avgVelo: d % 2 === 0 ? 82 : null }))
function penPayload(sport: string, mode: Mode, cmp: unknown, extra: Record<string, unknown> = {}) {
  return {
    sport, sessionId: 'a1b2c3d4-0000-4000-8000-00000000000' + (mode === 'u14' ? '1' : mode === 'zone' ? '2' : '3'), pitcherId: 'p1', pitcherName: 'Demo Pitcher', uniformNumber: 21,
    teamName: 'Demo Team', date: T0, chartingPerspective: 'behind_pitcher', loggedByCoach: true,
    pitchTypes: sport === 'softball' ? ['Fastball', 'Change-up', 'Drop ball'] : PEN_TYPES, gridSize: 5,
    pitches: sport === 'softball' ? penPitches(36, mode).map(p => ({ ...p, type: ({ 'Four Seam Fastball': 'Fastball', Curveball: 'Drop ball', Changeup: 'Change-up' } as Record<string, string>)[p.type as string] })) : penPitches(36, mode),
    history, raOn: mode === 'u14', purpose: null, comparison: cmp, ...extra
  }
}

// ---------- games ----------
const RESULTS = ['ball', 'ball', 'strike_looking', 'strike_swinging', 'foul', 'in_play', 'in_play']
function gamePitches(n: number, sport: string, intent: boolean, hitKinds: 'none' | 'exact' | 'ra') {
  const out = []
  let inning = 1, outs = 0, balls = 0, strikes = 0, ab = 1, runners = 0
  const types = sport === 'softball' ? ['Fastball', 'Change-up', 'Drop ball', 'Rise ball'] : ['Four Seam Fastball', 'Curveball', 'Changeup', 'Slider']
  let side = pick(['R', 'L'])
  for (let i = 0; i < n; i++) {
    const type = pick([types[0], types[0], types[1], types[2], types[3]])
    let result = pick(RESULTS)
    if (rnd() < 0.03) result = 'hbp'
    const ar = Math.floor(rnd() * 5), ac = Math.floor(rnd() * 5)
    const tr = intent ? 1 + Math.floor(rnd() * 3) : null, tc = intent ? 1 + Math.floor(rnd() * 3) : null
    const p: Record<string, unknown> = {
      type, velo: type === types[0] ? 78 + Math.floor(rnd() * 8) : null, actualRow: ar, actualCol: ac, targetRow: tr, targetCol: tc,
      batterSide: side, ts: T0 + i * 25000, result, inPlayOutcome: null, hitType: null, fielder: null,
      delivery: sport === 'softball' ? null : (runners ? 'set' : 'windup'), inning, outsBefore: outs, ballsBefore: balls, strikesBefore: strikes,
      atBatIndex: ab, timeToPlate: null, runnersBefore: runners, sprayBox: null, sprayField: null, bbType: null, runnersAfter: null,
      fielders: null, sacrifice: null, batterTo: null, runnerAdvances: null, runsScored: null, unearnedRuns: null, inheritedRuns: null, chargedPrev: false
    }
    if (intent && hitKinds !== 'none') p.accuracyHitKind = ar === tr && ac === tc ? 'exact' : (hitKinds === 'ra' && rnd() < 0.3 ? 'ra' : 'miss')
    let ends = false
    if (result === 'ball') { if (balls >= 3) { ends = true; runners = (runners << 1 | 1) & 7 } else balls++ }
    else if (result === 'strike_looking' || result === 'strike_swinging') { if (strikes >= 2) { ends = true; outs++ } else strikes++ }
    else if (result === 'foul') { if (strikes < 2) strikes++ }
    else if (result === 'hbp') { ends = true; runners = (runners << 1 | 1) & 7 }
    else if (result === 'in_play') {
      ends = true
      const o = pick(['hit', 'out', 'out', 'out', 'error', 'fc'])
      p.inPlayOutcome = o
      p.bbType = pick(['ground', 'line', 'fly', 'bunt'])
      p.sprayBox = 1 + Math.floor(rnd() * 25)
      p.sprayField = pick(['IF', 'OF', null])
      p.fielder = pick(['SS', '2B', 'CF', 'LF', '1B', '3B', 'RF'])
      if (o === 'out') { outs++; if (rnd() < 0.4) p.fielders = '1B' }
      if (o === 'hit') { p.hitType = pick(['1B', '1B', '2B', '3B', 'HR']); runners = (runners << 1 | 1) & 7; if (rnd() < 0.4) { p.runsScored = 1; p.unearnedRuns = 0; p.runnerAdvances = [{ from: 2, to: 4 }] } }
      if (o === 'error' || o === 'fc') runners = (runners << 1 | 1) & 7
      p.runnersAfter = runners
    }
    out.push(p)
    if (ends) {
      ab++; balls = 0; strikes = 0; side = pick(['R', 'L', 'R'])
      if (outs >= 3) { inning++; outs = 0; runners = 0 }
    }
  }
  return out
}
const summary = (n: number) => ({ pitches: n, strikes: Math.round(n * 0.62), strike_pct: 62, strike_pct_denominator: n, in_zone: Math.round(n * 0.45), in_zone_pct: 45,
  first_pitch_pitches: 17, first_pitch_strike_pct: 59, k: 5, bb: 2, h: 4, xbh: 1, outs_in_play: 7, errors: 1, hbp: 1, batters_faced: 19,
  outs_recorded: 12, outs_source: 'counter', final_inning: 4, final_inning_source: 'counter', pitch_count: n + 1, runs: 2, er: 1, ir: null, irs: null,
  bb_charged_prev: null, runners_left: 1, exit_runs: 0, exit_er: 0, exit_bb: 0, provisional: false })
const events = [
  { eventType: 'wild_pitch', atBatIndex: 3, seq: 1, inningBefore: 1, ballsBefore: 1, strikesBefore: 0, runnerAdvances: [{ from: 1, to: 2 }], runsScored: null, unearnedRuns: null, inheritedRuns: null },
  { eventType: 'stolen_base', atBatIndex: 5, seq: 2, inningBefore: 2, ballsBefore: 0, strikesBefore: 1, runnerAdvances: [{ from: 1, to: 2 }], runsScored: null, unearnedRuns: null, inheritedRuns: null },
  { eventType: 'auto_ball', atBatIndex: 7, seq: 3, inningBefore: 2, ballsBefore: 2, strikesBefore: 1, runnerAdvances: null, runsScored: null, unearnedRuns: null, inheritedRuns: null }
]
const recentPens = [{ type: 'Four Seam Fastball', usagePct: 55, strikePct: 64, commandPct: 41, commandLabel: 'exact' }, { type: 'Curveball', usagePct: 25, strikePct: 50, commandPct: 30, commandLabel: 'zone' }]
const gameTrend = [5, 10, 15].map(d => ({ date: T0 - d * 86400000, dateLabel: `11/${18 - d}`, strikePct: 58 + d % 7, firstPitchStrikePct: 50 + d % 5, k: 4, bb: 2, h: 5, hasVelo: true, avgVelo: 81, pitches: 70 }))
function gamePayload(sport: string, intent: boolean, hitKinds: 'none' | 'exact' | 'ra', cmp: unknown, extra: Record<string, unknown> = {}) {
  const pitches = gamePitches(72, sport, intent, hitKinds)
  return {
    sport, raOn: hitKinds === 'ra', comparison: cmp, sessionId: 'g9f8e7d6-0000-4000-8000-0000000000' + (intent ? '1' : '2') + (sport === 'softball' ? 's' : 'b'),
    pitcherId: 'p1', pitcherName: 'Demo Pitcher', uniformNumber: 21, teamName: 'Demo Team', date: T0, opponent: 'Visitors',
    chartingPerspective: 'behind_catcher', loggedByCoach: true,
    pitchTypes: sport === 'softball' ? ['Fastball', 'Change-up', 'Drop ball', 'Rise ball'] : ['Four Seam Fastball', 'Curveball', 'Changeup', 'Slider'],
    gridSize: 5, pitches, recentPens: sport === 'softball' ? undefined : recentPens,
    recentPenPitches: sport === 'softball' ? undefined : penPitches(40, 'exact').map(p => ({ type: p.type, actualRow: p.actualRow, actualCol: p.actualCol, targetRow: p.targetRow, targetCol: p.targetCol, inAccuracyZone: null })),
    gameTrend, summary: summary(pitches.length), events, ...extra
  }
}

// ---------- the byte comparisons ----------
let fails = 0, checks = 0
const save = (name: string, html: string) => Deno.writeTextFileSync(`${OUT}/${name}.html`, html)
// the footer prints today's date ("generated ...") -- both builds run now, so it matches
function same(name: string, kind: 'pen' | 'game', payload: Record<string, unknown>, afterExtra: Record<string, unknown> = {}) {
  const sport = payload.sport as 'baseball' | 'softball'
  before.helpers.useSportPalette(sport)
  const b = kind === 'pen' ? before.pen.buildReportHtml(structuredClone(payload)) : before.game.buildGameReportHtml(structuredClone(payload))
  after.helpers.useSportPalette(sport)
  const a = kind === 'pen' ? after.pen.buildReportHtml({ ...structuredClone(payload), ...afterExtra }) : after.game.buildGameReportHtml({ ...structuredClone(payload), ...afterExtra })
  checks++
  if (a !== b) {
    fails++
    let i = 0; while (i < a.length && a[i] === b[i]) i++
    console.log(`FAIL ${name}: differs at ${i}\n  before: ${JSON.stringify(b.slice(Math.max(0, i - 80), i + 120))}\n  after:  ${JSON.stringify(a.slice(Math.max(0, i - 80), i + 120))}`)
    save(name + '.before', b); save(name + '.after', a)
  } else console.log(`ok   ${name} (${a.length} bytes)`)
}
const FULL = { chartedIntent: true, chartedOutcome: true }
for (const sport of ['baseball', 'softball']) {
  for (const level of LEVELS[sport]) {
    const cmp = comparison(level, sport, 'bullpen'), gcmp = comparison(level, sport, 'game')
    for (const mode of ['u14', 'exact', 'zone'] as Mode[]) {
      same(`pen-${sport}-${mode}-${level}`, 'pen', penPayload(sport, mode, cmp))
      same(`pen-${sport}-${mode}-${level}-parts`, 'pen', penPayload(sport, mode, cmp), FULL)   // the new fields, both true
    }
    same(`pen-${sport}-u14-${level}-tagged`, 'pen', penPayload(sport, 'u14', cmp, { purpose: 'command' }), FULL)
    same(`game-${sport}-intent-${level}`, 'game', gamePayload(sport, true, 'exact', gcmp), FULL)
    same(`game-${sport}-intent-ra-${level}`, 'game', gamePayload(sport, true, 'ra', gcmp), FULL)   // an old game saved with RA on
    same(`game-${sport}-nointent-${level}`, 'game', gamePayload(sport, false, 'none', gcmp))
    same(`game-${sport}-nointent-${level}-parts`, 'game', gamePayload(sport, false, 'none', gcmp), FULL)
    // Outcome & Response only (C1): the same report as today's Intent-off game
    same(`game-${sport}-outcome-only-${level}`, 'game', gamePayload(sport, false, 'none', gcmp), { chartedIntent: false, chartedOutcome: true })
  }
  // no comparison at all (a first session), and an empty pen
  same(`pen-${sport}-u14-nocmp`, 'pen', penPayload(sport, 'u14', undefined), FULL)
  same(`pen-${sport}-empty`, 'pen', { ...penPayload(sport, 'exact', undefined), pitches: [] }, FULL)
  same(`game-${sport}-intent-nocmp`, 'game', gamePayload(sport, true, 'exact', undefined), FULL)
}
same('pen-baseball-noradar', 'pen', { ...penPayload('baseball', 'u14', comparison('high_school', 'baseball', 'bullpen')), pitches: penPitches(30, 'u14', { radar: false }) }, FULL)

// ---------- the partial cases: rendered for a look, and checked for what they must (and must not) say ----------
const need = (name: string, html: string, yes: (string | RegExp)[], no: (string | RegExp)[]) => {
  for (const y of yes) { checks++; const ok = typeof y === 'string' ? html.includes(y) : y.test(html); if (!ok) { fails++; console.log(`FAIL ${name}: missing ${y}`) } }
  for (const n of no) { checks++; const bad = typeof n === 'string' ? html.includes(n) : n.test(html); if (bad) { fails++; console.log(`FAIL ${name}: should not contain ${n}`) } }
}
const strip = (h: string) => h.replace(/<!--kr-email[\s\S]*?-->/, '')
after.helpers.useSportPalette('baseball')
for (const level of ['little_league', 'high_school', 'college']) {
  const cmp = comparison(level, 'baseball', 'bullpen'), gcmp = comparison(level, 'baseball', 'game')
  // Pen, Intent only: type, target, batter side; no location, no velocity
  const pi = penPayload('baseball', 'exact', cmp, { chartedIntent: true, chartedOutcome: false, raOn: false })
  pi.pitches = (pi.pitches as Record<string, unknown>[]).map(p => ({ ...p, actualRow: null, actualCol: null, velo: null, inAccuracyZone: null, accuracyHitKind: null }))
  const h1 = after.pen.buildReportHtml(pi); save(`partial-pen-intent-only-${level}`, h1)
  need(`pen intent only ${level}`, strip(h1), ['Intent only', 'Only the pitch calls were charted: no locations.', 'Called spots', 'Pitch mix'],
    [/\d+% strikes/, /on the spot \d/i, /\d+% accurate/, /\d mph/, 'Where misses went', 'NaN', 'undefined', 'Infinity'])
  // Pen, Outcome only: location, velocity; no target
  const po = penPayload('baseball', 'exact', cmp, { chartedIntent: false, chartedOutcome: true, raOn: false })
  po.pitches = (po.pitches as Record<string, unknown>[]).map(p => ({ ...p, targetRow: null, targetCol: null, inAccuracyZone: null, accuracyHitKind: null }))
  const h2 = after.pen.buildReportHtml(po); save(`partial-pen-outcome-only-${level}`, h2)
  need(`pen outcome only ${level}`, strip(h2), ['Outcome only', 'Only where each pitch landed was charted: no targets.', /\d+% strikes/],
    [/on the spot \d/i, /hit (its|the|your) spot/i, /\d+% accurate/, 'Where misses went', 'Filled = hit the spot', 'NaN', 'undefined', 'Infinity', /\b0% on the spot/])
  // Game, Intent only: type, target, batter side and nothing else
  const gi = gamePayload('baseball', true, 'exact', gcmp, { chartedIntent: true, chartedOutcome: false, raOn: false })
  gi.pitches = (gi.pitches as Record<string, unknown>[]).map(p => ({ type: p.type, velo: null, targetRow: p.targetRow, targetCol: p.targetCol, actualRow: null, actualCol: null,
    batterSide: p.batterSide, ts: p.ts, result: null, inPlayOutcome: null, hitType: null, fielder: null, delivery: null, inning: null, outsBefore: null,
    ballsBefore: null, strikesBefore: null, atBatIndex: null }))
  gi.events = []; delete (gi as Record<string, unknown>).summary
  const h3 = after.game.buildGameReportHtml(gi); save(`partial-game-intent-only-${level}`, h3)
  need(`game intent only ${level}`, strip(h3), ['Intent only', 'Only the pitch calls were charted: no locations, results or counts.', 'Called spots', 'Pitch mix', 'vs Right-Handed Batters'],
    ['Pitching line', 'Balls in play', 'At-bat log', 'Rest ·', 'Last 7 days', /\d+% strikes/, 'NaN', 'undefined', 'Infinity'])
  // Game, Outcome & Response only: today's Intent-off report
  const gr = gamePayload('baseball', false, 'none', gcmp, { chartedIntent: false, chartedOutcome: true })
  save(`partial-game-outcome-only-${level}`, after.game.buildGameReportHtml(gr))
}
// More Plays flags in the at-bat log (a full game that used them)
{
  const g = gamePayload('baseball', true, 'exact', comparison('college', 'baseball', 'game'), FULL)
  const ps = g.pitches as Record<string, unknown>[]
  const ip = ps.filter(p => p.result === 'in_play')
  ip[0].playFlags = ['infield_fly']; ip[0].inPlayOutcome = 'out'; ip[0].bbType = 'fly'
  ip[1].playFlags = ['ground_rule_double']; ip[1].inPlayOutcome = 'hit'; ip[1].hitType = '2B'
  ip[2].playFlags = ['fan_interference']
  const fo = ps.find(p => p.result === 'foul')!; fo.playFlags = ['foul_error']
  const h = after.game.buildGameReportHtml(g); save('game-more-plays-flags', h)
  need('more plays flags', h, ['IFR', 'GRD', 'fan interference', 'E on foul'], [])
}
console.log(`${fails} fail${fails === 1 ? '' : 's'} of ${checks} checks · outputs in ${OUT}`)
Deno.exit(fails ? 1 : 0)
