// RP1 (Joel, Nov 25 2026; plans/rp1-the-play.md): a game report names every ball in play's place -- "The Play" rows
// and the at-bat log -- and prints no box number. Builds game reports (both sports, every level) with the working copy
// and with origin/main, checks the named sentences and that nothing else in the report changed.
//
// usage:
//   B=<scratch>/report-before; mkdir -p $B && for f in $(git ls-tree --name-only origin/main supabase/functions/send-session-report/); do git show origin/main:$f > $B/$(basename $f); done
//   deno run --allow-read --allow-write --allow-env scripts/rp1-check.ts $B <out-dir>
// exit 1 on any failure.
const BEFORE = Deno.args[0], OUT = Deno.args[1]
if (!BEFORE || !OUT) { console.error('usage: rp1-check.ts <report-before dir> <out dir>'); Deno.exit(2) }
const abs = (p: string) => p.startsWith('/') ? p : Deno.cwd() + '/' + p
const here = new URL('../supabase/functions/send-session-report/', import.meta.url).href
const before = { game: await import('file://' + abs(BEFORE) + '/template_game.ts'), helpers: await import('file://' + abs(BEFORE) + '/helpers.ts') }
const after = { game: await import(here + 'template_game.ts'), helpers: await import(here + 'helpers.ts'), diamond: await import(here + 'diamond.ts') }
await Deno.mkdir(OUT, { recursive: true })
let fails = 0, checks = 0
const ok = (name: string, cond: boolean, why = '') => { checks++; if (!cond) { fails++; console.log(`FAIL ${name}${why ? ': ' + why : ''}`) } }

// ---------- the sentence rules, one play at a time ----------
const P = (o: Record<string, unknown>) => ({ result: 'in_play', inPlayOutcome: 'out', hitType: null, fielder: null, bbType: null, sprayBox: null, sprayField: null, ...o })
const say = (o: Record<string, unknown>) => after.diamond.playSentence(P(o))
const CASES: [string, Record<string, unknown>, string][] = [
  ["Joel's example", { bbType: 'fly', sprayBox: 10, sprayField: 'OF', fielder: 'RF' }, 'Flyball out in the Right-field corner'],
  ['17 infield', { bbType: 'ground', sprayBox: 17, sprayField: 'IF', fielder: '3B' }, 'Groundball out at Third base (3B)'],
  ['17 outfield', { bbType: 'line', sprayBox: 17, sprayField: 'OF', fielder: 'LF' }, 'Line drive out down the shallow Left-field line'],
  ['18 infield', { bbType: 'ground', sprayBox: 18, sprayField: 'IF', fielder: 'SS' }, 'Groundball out at Shortstop (SS)'],
  ['18 outfield', { bbType: 'line', sprayBox: 18, sprayField: 'OF', fielder: 'LF', inPlayOutcome: 'hit', hitType: '1B' }, 'Line drive single in shallow Left field'],
  ['22 infield', { bbType: 'ground', sprayBox: 22, sprayField: 'IF', fielder: '2B' }, 'Groundball out at Second base (2B)'],
  ['22 outfield', { bbType: 'fly', sprayBox: 22, sprayField: 'OF', fielder: 'RF' }, 'Flyball out in shallow Right field'],
  ['23 infield', { bbType: 'ground', sprayBox: 23, sprayField: 'IF', fielder: '1B', inPlayOutcome: 'error' }, 'Groundball error at First base (1B)'],
  ['23 outfield', { bbType: 'line', sprayBox: 23, sprayField: 'OF', fielder: 'RF', inPlayOutcome: 'hit', hitType: '2B' }, 'Line drive double down the shallow Right-field line'],
  ['24 pitcher', { bbType: 'ground', sprayBox: 24, sprayField: 'IF', fielder: 'P' }, "Groundball out at the Pitcher's mound"],
  ['24 catcher', { bbType: 'bunt', sprayBox: 24, sprayField: 'IF', fielder: 'C' }, "Bunt out at the Pitcher's mound"],
  ['24 nobody', { bbType: 'ground', sprayBox: 24, sprayField: 'IF' }, "Groundball out at the Pitcher's mound"],
  ['24 shortstop', { bbType: 'ground', sprayBox: 24, sprayField: 'IF', fielder: 'SS' }, 'Shallow SS groundball out'],
  ['24 third', { bbType: 'line', sprayBox: 24, sprayField: 'IF', fielder: '3B', inPlayOutcome: 'fc' }, "Shallow 3B line drive fielder's choice"],
  ['25 infield (decision 1)', { bbType: 'ground', sprayBox: 25, sprayField: 'IF', fielder: '2B' }, 'Groundball out up the middle'],
  ['25 outfield (decision 1)', { bbType: 'line', sprayBox: 25, sprayField: 'OF', fielder: 'CF', inPlayOutcome: 'hit', hitType: '1B' }, 'Line drive single in shallow Center field'],
  ['IF answer wins over the fielder (decision 2)', { bbType: 'line', sprayBox: 22, sprayField: 'IF', fielder: 'RF' }, 'Line drive out at Second base (2B)'],
  ['OF answer wins over the fielder (decision 2)', { bbType: 'fly', sprayBox: 22, sprayField: 'OF', fielder: '2B' }, 'Flyball out in shallow Right field'],
  ['FOUL answer, box 17 (decision 2)', { bbType: 'fly', sprayBox: 17, fielder: '3B' }, 'Flyball out in foul ground down the third-base line'],
  ['FOUL answer, box 23 (decision 2)', { bbType: 'line', sprayBox: 23, fielder: '1B' }, 'Line drive out in foul ground down the first-base line'],
  ['FOUL answer, box 3 (decision 2)', { bbType: 'fly', sprayBox: 3, fielder: 'LF' }, 'Flyball out in foul ground down the Left-field line'],
  ['FOUL answer, box 11 (decision 2)', { bbType: 'fly', sprayBox: 11, fielder: 'RF' }, 'Flyball out in foul ground down the Right-field line'],
  ['FOUL answer, box 15 (decision 2)', { bbType: 'fly', sprayBox: 15, fielder: 'C' }, 'Flyball out in foul ground behind home'],
  ['no answer, no foul ground: infield', { bbType: 'ground', sprayBox: 18, fielder: 'LF', inPlayOutcome: 'hit', hitType: '1B' }, 'Groundball single at Shortstop (SS)'],
  ['old game, by fielder 2B (decision 4)', { bbType: 'ground', fielder: '2B' }, 'Groundball out at Second base (2B)'],
  ['old game, by fielder CF (decision 4)', { fielder: 'CF', inPlayOutcome: 'hit', hitType: '2B' }, 'Double in Center field'],
  ['home run over the fence (decision 5)', { bbType: 'fly', sprayBox: 6, fielder: null, inPlayOutcome: 'hit', hitType: 'HR' }, 'Flyball home run over the fence in Left field'],
  ['deep, not a home run (decision 5)', { bbType: 'fly', sprayBox: 9, sprayField: 'OF', fielder: 'RF' }, 'Flyball out deep down the Right-field line'],
  ['no contact stored (decision 6)', { sprayBox: 20, sprayField: 'OF', fielder: 'CF' }, 'Out in Center field'],
  ['a hit with no hit type', { bbType: 'line', sprayBox: 19, sprayField: 'OF', fielder: 'LF', inPlayOutcome: 'hit' }, 'Line drive hit in Left field'],
  ['foul ground', { bbType: 'fly', sprayBox: 14, sprayField: null, fielder: '1B' }, 'Flyball out in foul ground right of home'],
  ['home plate', { bbType: 'bunt', sprayBox: 15, sprayField: 'IF', fielder: 'C' }, 'Bunt out at Home plate'],
  ['triple', { bbType: 'line', sprayBox: 4, sprayField: 'OF', fielder: 'LF', inPlayOutcome: 'hit', hitType: '3B' }, 'Line drive triple in the Left-field corner']
]
for (const [name, o, want] of CASES) { const got = say(o); ok(`sentence: ${name}`, got === want, `got "${got}", want "${want}"`) }

// ---------- whole reports: both sports, every level ----------
const T0 = Date.UTC(2026, 10, 18, 20, 0)
const TYPES: Record<string, string[]> = { baseball: ['Four Seam Fastball', 'Curveball', 'Changeup', 'Slider'], softball: ['Fastball', 'Change-up', 'Drop ball', 'Rise ball'] }
function gamePitches(sport: string) {
  const ps: Record<string, unknown>[] = []
  let ab = 1, inning = 1, outs = 0, i = 0
  for (const [, o] of CASES) {
    for (const r of ['ball', 'strike_swinging']) ps.push(pitch(sport, i++, ab, inning, outs, { result: r, inPlayOutcome: null }))
    ps.push(pitch(sport, i++, ab, inning, outs, P(o)))
    if ((o.inPlayOutcome ?? 'out') === 'out') outs++
    ab++; if (outs >= 3) { inning++; outs = 0 }
  }
  return ps
}
function pitch(sport: string, i: number, ab: number, inning: number, outs: number, o: Record<string, unknown>) {
  const t = TYPES[sport]
  return { type: t[i % 4], velo: null, actualRow: i % 5, actualCol: (i * 3) % 5, targetRow: null, targetCol: null, batterSide: i % 2 ? 'L' : 'R', ts: T0 + i * 25000,
    hitType: null, fielder: null, delivery: sport === 'softball' ? null : 'windup', inning, outsBefore: outs, ballsBefore: o.result === 'in_play' ? 1 : 0, strikesBefore: o.result === 'in_play' ? 1 : 0,
    atBatIndex: ab, timeToPlate: null, runnersBefore: 0, sprayBox: null, sprayField: null, bbType: null, runnersAfter: 0, fielders: null, sacrifice: null, batterTo: null,
    runnerAdvances: null, runsScored: null, unearnedRuns: null, inheritedRuns: null, chargedPrev: false, ...o }
}
function payload(sport: string, level: string) {
  const pitches = gamePitches(sport)
  return { sport, raOn: false, sessionId: 'rp1e7d60-0000-4000-8000-00000000000' + (sport === 'softball' ? 's' : 'b'), pitcherId: 'p1', pitcherName: 'Demo Pitcher', uniformNumber: 21,
    teamName: 'Demo Team', date: T0, opponent: 'Visitors', chartingPerspective: 'behind_catcher', loggedByCoach: true, pitchTypes: TYPES[sport], gridSize: 5, pitches,
    comparison: { baselines: { level, windows: {} }, recent: [], throws: 'R', workload: { level, age_group: null, sport, seven_day: 60, parts: [] } },
    summary: { pitches: pitches.length, strikes: 40, strike_pct: 50, strike_pct_denominator: pitches.length, k: 0, bb: 0, h: 9, outs_in_play: 15, errors: 1, batters_faced: CASES.length,
      outs_recorded: 15, outs_source: 'counter', final_inning: 6, final_inning_source: 'counter', pitch_count: pitches.length, runs: 0, er: 0, provisional: false } }
}
const unesc = (h: string) => h.replace(/&#39;|&#x27;|&apos;/g, "'").replace(/&amp;/g, '&')
// "What led to it" and the at-bat endings are what RP1 changes; everything else must be byte-identical
const cut = (h: string) => h.replace(/<h2>What led to it<\/h2>[\s\S]*?<h3>Pitch type × result<\/h3>/g, '[WLI]').replace(/<span class="ab-ending">[^<]*<\/span>/g, '[END]')
  .replace(/on the field's 25 boxes \(foul ground included\)|on the field \(foul ground included\)/g, '[CAP]')
const LEVELS: Record<string, string[]> = { baseball: ['little_league', 'high_school', 'college'], softball: ['little_league', 'high_school_up'] }
for (const sport of ['baseball', 'softball']) {
  after.helpers.useSportPalette(sport); before.helpers.useSportPalette(sport)
  for (const level of LEVELS[sport]) {
    const name = `game-${sport}-${level}`
    const a = after.game.buildGameReportHtml(structuredClone(payload(sport, level)))
    const b = before.game.buildGameReportHtml(structuredClone(payload(sport, level)))
    Deno.writeTextFileSync(`${OUT}/${name}.html`, a); Deno.writeTextFileSync(`${OUT}/${name}-before.html`, b)
    const text = unesc(a.replace(/<svg[\s\S]*?<\/svg>/g, '').replace(/<[^>]+>/g, ' '))
    ok(`${name}: "The Play"`, a.includes('<h3>The Play</h3>'))
    ok(`${name}: no "By field box"`, !a.includes('By field box'))
    const boxy = text.match(/\b[Bb]ox(es)? ?\d+|\d+ boxes/g)
    ok(`${name}: no box number`, !boxy, String(boxy))
    ok(`${name}: the before build had box numbers (the check can see them)`, /Box \d+/.test(b) && /box \d+/.test(b))
    for (const [, , want] of CASES) ok(`${name}: row "${want}"`, unesc(a).includes(`<td>${want}</td>`))
    ok(`${name}: at-bat log names the place`, unesc(a).includes('· in the Right-field corner</span>') && unesc(a).includes("· at the Pitcher's mound</span>"))
    ok(`${name}: only RP1's parts changed`, cut(a) === cut(b))
    // the versions: The Play sits in the Location panel; which versions carry it is unchanged from before
    const panel = (h: string) => { const i = h.search(/<h3>(?:The Play|By field box)<\/h3>/); const o = h.lastIndexOf('<div class="kr-panel ', i); return i < 0 || o < 0 ? '' : (h.slice(o, h.indexOf('>', o)).match(/kr-p\d+|kr-pv-\w+/g) ?? []).join(' ') }
    ok(`${name}: same versions carry it (${panel(a)})`, panel(a) === panel(b) && panel(a).length > 0, `${panel(a)} vs ${panel(b)}`)
  }
}
console.log(`${checks - fails} of ${checks} checks passed`)
Deno.exit(fails ? 1 : 0)
