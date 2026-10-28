// SC1-B acceptance 2: every number History, Trends and the reports now read from a session's stats row, against the
// same number computed from its pitches -- both through the app's own functions, lifted unchanged from
// bullpen-tracker.html. Rows from supabase/tests/sc1_compare_rows.sql (read-only).
// usage: node scripts/sc1b-compare.js bullpen-tracker.html <rows.json>
// "KNOWN" lines are Joel's decisions, not bugs: a game card's line follows compute_game_summary (decision 4), and a
// pen charted in a pre-U7 accuracy mode loses its old relative accuracy (decision 3). Plots from cells are compared box by box (same dots in each box;
// the order inside a box isn't stored -- Joel approved, Oct 28).
const fs = require('fs'), vm = require('vm');
const html = fs.readFileSync(process.argv[2], 'utf8');
const lift = name => {
  const i = html.indexOf('function ' + name + '(');
  if(i < 0) throw new Error('missing ' + name);
  for(let k = html.indexOf('{', i), d = 0; k < html.length; k++){ if(html[k] === '{') d++; else if(html[k] === '}' && --d === 0) return html.slice(i, k + 1); }
};
const constLine = name => html.match(new RegExp('const ' + name + ' = [^\\n]*'))[0];
const src = [...['GRID_SIZE', 'U6_CUTOFF_TS', 'GAME_STRIKE_RESULTS', 'STATS_VERSION', 'REPORT_VIEW', 'REPORT_PERSPECTIVE', 'REPORT_VIEW_NAME'].map(constLine),
  ...['isStrikeCell', 'isAccurate', 'isRelativelyAccurate', 'isHit', 'isDefaultVeloReading', 'sessionStats', 'gameIsK', 'gameStats',
    'trendsIsStrike', 'statsRowOf', 'statsPct', 'rowHasStats', 'sessionPitchTotal', 'sessionTtp', 'avgTimeToPlateMeta', 'penStatsFromRow',
    'penCardStats', 'gameCardStats', 'sessionAvgVelo', 'sessionTypeAgg', 'orderPitchTypes', 'pitchesFromCells', 'plotSessionOf',
    'gameHistoryTypeTable', 'mirrorCol', 'perspectiveCol', 'escHtml', 'renderHistoryPlot', 'renderPerspectivePlate'].map(lift),
  // stand-ins for the page's pitcher lookups (colors and labels don't change any number)
  'function pitchTypesFor(p){ return p.mix; }', 'function colorForType(p, t){ return "#" + (p.mix.indexOf(t) + 10); }',
  'function pitchLabel(n){ return String(n).toUpperCase(); }'].join('\n');
const ctx = {}; vm.createContext(ctx); vm.runInContext(src + '\n;this.A = { statsRowOf, penCardStats, gameCardStats, sessionAvgVelo, sessionTypeAgg, avgTimeToPlateMeta, gameHistoryTypeTable, renderHistoryPlot, plotSessionOf, pitchesFromCells, sessionPitchTotal };', ctx);
const A = ctx.A;
const d = JSON.parse(fs.readFileSync(process.argv[3], 'utf8'));
let rows = d.rows || d; if(rows.length && rows[0].rows) rows = rows[0].rows;
const diffs = [], known = []; let checks = 0, noRow = 0;
const sortObj = o => (o && typeof o === 'object' && !Array.isArray(o)) ? Object.fromEntries(Object.keys(o).sort().map(k => [k, sortObj(o[k])])) : o;
const eq = (s, what, fromPitches, fromRow, why) => {
  checks++;
  if(JSON.stringify(sortObj(fromPitches)) !== JSON.stringify(sortObj(fromRow)))
    (why ? known : diffs).push(`${s.id.slice(0, 8)} ${s.kind} ${what}: pitches=${JSON.stringify(fromPitches)} row=${JSON.stringify(fromRow)}${why ? ' (' + why + ')' : ''}`);
};
const dots = svg => (svg.match(/<circle cx="[^"]+" cy="[^"]+" r="\d+" fill="[^"]+" stroke/g) || []).map(c => c.replace(/ stroke$/, '')).sort();
const boxes = pts => { const o = {}; pts.forEach(p => { const k = p.actualRow + '-' + p.actualCol + ' ' + p.type; o[k] = (o[k] || 0) + 1; }); return o; };
for(const r of rows){
  const stats = A.statsRowOf(r.stats);
  if(!stats){ noRow++; diffs.push(`${r.id.slice(0, 8)} no version-${ctx.STATS_VERSION || 2} stats row`); continue; }
  const base = { id: r.id, kind: r.kind, pitchCountAdjust: r.pitch_count_adjust || 0, exitRuns: r.exit_runs || 0, exitEr: r.exit_er || 0, exitBb: r.exit_bb || 0 };
  const P = Object.assign({}, base, { stats: null, pitches: r.pitches.map(p => Object.assign({}, p, { timeToPlate: p.timeToPlate === null ? null : Number(p.timeToPlate) })), events: r.events });
  const R = Object.assign({}, base, { stats, pitches: null, events: null });
  const mix = []; P.pitches.forEach(p => { if(!mix.includes(p.type)) mix.push(p.type); });
  const pitcher = { mix };
  eq(r, 'pitch total', A.sessionPitchTotal(P), A.sessionPitchTotal(R));
  eq(r, 'time to home', A.avgTimeToPlateMeta(P), A.avgTimeToPlateMeta(R));
  eq(r, 'avg velo (report game trend)', A.sessionAvgVelo(P), A.sessionAvgVelo(R));
  eq(r, 'per-type counts, strikes, velo, cells, splits (Trends, game table)', A.sessionTypeAgg(P), A.sessionTypeAgg(R));
  // History's expanded plot: the same dots in every box
  eq(r, 'History plot boxes', boxes(A.plotSessionOf(P, pitcher).pitches), boxes(A.plotSessionOf(R, pitcher).pitches));
  // Trends' per-type plot: identical drawing (one colour, so the order inside a box can't show)
  const agg = A.sessionTypeAgg(P);
  Object.keys(agg).forEach(t => eq(r, `${t} Trends plot`, dots(A.renderHistoryPlot({ kind: 'bullpen', pitches: P.pitches.filter(p => p.type === t) }, pitcher, { small: true, hotRing: true, legend: false, caption: '' })),
    dots(A.renderHistoryPlot({ kind: 'bullpen', pitches: A.pitchesFromCells(t, stats.by_type[t].cells) }, pitcher, { small: true, hotRing: true, legend: false, caption: '' }))));
  if(r.kind === 'game'){
    const g = A.gameCardStats(P), G = A.gameCardStats(R);
    eq(r, 'game card pitches / K / BB / H / innings', [g.total, g.k, g.bb, g.h, g.innings], [G.total, G.k, G.bb, G.h, G.innings]);
    const interf = P.pitches.filter(p => p.result === 'interference' || p.result === 'other').length;
    eq(r, 'game card strike %', g.strikePct, G.strikePct, interf ? `decision 4: ${interf} interference / other pitch(es) out of the summary's denominator` : null);
    eq(r, 'game card R / ER', [g.r, g.er], [G.r, G.er]);
    eq(r, 'game type table', A.gameHistoryTypeTable(pitcher, P), A.gameHistoryTypeTable(pitcher, R));
  } else {
    const a = A.penCardStats(P), b = A.penCardStats(R);
    const pick = x => ({ total: x.total, strikePct: x.strikePct, accuracyPct: x.accuracyPct, exactHits: x.exactHits, raHits: x.raHits, hasZone: x.hasZone,
      zoneTotal: x.zoneTotal, zoneAccuracyPct: x.zoneAccuracyPct, hasVelo: x.hasVelo, avgVelo: x.avgVelo, minVelo: x.minVelo, maxVelo: x.maxVelo });
    eq(r, 'pen card + report pen history', pick(a), pick(b));
    Object.keys(a.byType).forEach(t => {
      const x = Object.assign({}, a.byType[t]), y = Object.assign({}, b.byType[t] || {});
      delete x.velos; delete x.strikes; delete x.accurate; delete x.relativeAccurate; delete x.zoneHits;
      const legacy = P.pitches.some(p => p.type === t && p.accuracyMode);
      eq(r, `${t} pen type row`, x, y, legacy ? 'decision 3: a pre-U7 accuracy mode pen; its old relative accuracy is dropped' : null);
    });
  }
}
console.log(JSON.stringify({ sessions: rows.length, checks, differences: diffs.length, known: known.length, without_row: noRow }, null, 1));
diffs.forEach(x => console.log('DIFF', x)); known.forEach(x => console.log('KNOWN', x));
