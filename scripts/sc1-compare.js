// SC1 acceptance 4: the app's own functions (lifted from bullpen-tracker.html, unchanged) vs the stored session_stats row.
// usage: node scripts/sc1-compare.js bullpen-tracker.html <rows.json>   (rows: supabase/tests/sc1_compare_rows.sql)
const fs = require('node:fs'), vm = require('node:vm');
const html = fs.readFileSync(process.argv[2], 'utf8');
const lift = name => {
  const i = html.indexOf('function ' + name + '(');
  if(i < 0) throw new Error('missing ' + name);
  let j = html.indexOf('{', i), d = 0;
  for(let k = j; k < html.length; k++){ if(html[k] === '{') d++; else if(html[k] === '}' && --d === 0) return html.slice(i, k + 1); }
};
const constLine = name => html.match(new RegExp('const ' + name + ' = [^\\n]*'))[0];
const src = [constLine('GRID_SIZE'), constLine('U6_CUTOFF_TS'), constLine('GAME_STRIKE_RESULTS'),
  ...['isStrikeCell', 'isAccurate', 'isRelativelyAccurate', 'isHit', 'isDefaultVeloReading', 'sessionStats', 'gameIsK', 'gameStats', 'trendsIsStrike'].map(lift)].join('\n');
const ctx = {}; vm.createContext(ctx); vm.runInContext(src + '\n;this.api={sessionStats,gameStats,isHit,isStrikeCell,isDefaultVeloReading,trendsIsStrike,GAME_STRIKE_RESULTS};', ctx);
const A = ctx.api;
const d = JSON.parse(fs.readFileSync(process.argv[3], 'utf8')); const rows = d.rows || d;
const diffs = [], expected = []; let checks = 0;
const eq = (s, what, app, db, known) => { checks++; if(JSON.stringify(app) !== JSON.stringify(db)) (known ? expected : diffs).push(`${s.id.slice(0, 8)} ${s.kind} ${what}: app=${JSON.stringify(app)} db=${JSON.stringify(db)}${known ? ' (' + known + ')' : ''}`); };
const avg = (sum, n) => n ? Math.round(sum / n) : null;
const cellsOf = (ps) => { const g = {}; ps.forEach(p => { const k = p.actualRow + '-' + p.actualCol; g[k] = (g[k] || 0) + 1; }); return g; };
const sortObj = o => o && Object.fromEntries(Object.keys(o).sort().map(k => [k, (o[k] && typeof o[k] === 'object') ? sortObj(o[k]) : o[k]]));
for(const s of rows){
  const st = s.stats; const ps = s.pitches.map(p => Object.assign({}, p, { timeToPlate: p.timeToPlate === null ? null : Number(p.timeToPlate) }));
  if(!st){ diffs.push(s.id + ' no row'); continue; }
  const game = s.kind === 'game';
  const pct = (a, b) => b ? Math.round((a / b) * 100) : 0;
  // Common: counts, the one accuracy number, velocity (Amendment 10), time to home, cells, sides, Trends' per-type points.
  const ss = A.sessionStats(ps);
  eq(s, 'pitches', ss.total, st.pitches);
  eq(s, 'accuracy % (isHit)', ss.accuracyPct, pct(st.hits, st.pitches));
  eq(s, 'exact / ra', [ss.exactHits, ss.raHits], [st.exact_hits, st.ra_hits]);
  eq(s, 'zone acc', [ss.zoneTotal, ss.zoneAccuracyPct], [st.zone_total, st.zone_total ? Math.round((st.zone_hits / st.zone_total) * 100) : null]);
  eq(s, 'velo avg/min/max', [ss.avgVelo, ss.minVelo, ss.maxVelo], [avg(st.velo_sum, st.velo_n), st.velo_min, st.velo_max]);
  const ttp = ps.map(p => p.timeToPlate).filter(v => typeof v === 'number');
  eq(s, 'time to home', ttp.length ? (ttp.reduce((a, b) => a + b, 0) / ttp.length).toFixed(2) : null, st.ttp_n ? (Number(st.ttp_sum) / st.ttp_n).toFixed(2) : null);
  eq(s, 'cells', sortObj(cellsOf(ps)), sortObj(st.cells));
  const sides = {}; ps.forEach(p => { const k = p.batterSide || 'none', o = sides[k] || (sides[k] = { n: 0, strikes: 0, hits: 0 }); o.n++; if(A.trendsIsStrike(s, p)) o.strikes++; if(A.isHit(p)) o.hits++; });
  eq(s, 'by_side', sortObj(sides), sortObj(st.by_side));
  const types = [...new Set(ps.map(p => p.type))];
  eq(s, 'types', types.slice().sort(), Object.keys(st.by_type).sort());
  for(const t of types){
    const tp = ps.filter(p => p.type === t), b = st.by_type[t] || {};
    const vs = tp.filter(p => p.velo !== null && p.velo !== undefined && !A.isDefaultVeloReading(p)).map(p => p.velo);
    // Trends: strike % per type per session and peak velo per type per session; History breakdown / game type table
    eq(s, `${t} trends strike%`, Math.round(100 * tp.filter(p => A.trendsIsStrike(s, p)).length / tp.length), Math.round(100 * b.strikes / b.n));
    eq(s, `${t} peak velo`, vs.length ? Math.max(...vs) : null, b.velo_max ?? null);
    eq(s, `${t} avg/min velo`, [vs.length ? Math.round(vs.reduce((a, c) => a + c, 0) / vs.length) : null, vs.length ? Math.min(...vs) : null], [avg(b.velo_sum, b.velo_n), b.velo_min ?? null]);
    eq(s, `${t} cells`, sortObj(cellsOf(tp)), sortObj(b.cells));
    const by = (key) => { const o = {}; tp.forEach(p => { const k = p[key] || 'none'; (o[k] = o[k] || []).push(p); }); return sortObj(Object.fromEntries(Object.entries(o).map(([k, v]) => [k, cellsOf(v)]))); };
    eq(s, `${t} side cells`, by('batterSide'), sortObj(b.side_cells));
    eq(s, `${t} delivery cells`, by('delivery'), sortObj(b.delivery_cells));
    if(!game){
      const bt = ss.byType[t];
      eq(s, `${t} pen strike%/acc%/zone`, [bt.strikePct, bt.accuracyPct, bt.zoneAccuracyPct], [pct(b.strikes, b.n), pct(b.hits, b.n), b.zone_total ? Math.round((b.zone_hits / b.zone_total) * 100) : null]);
    }
  }
  if(!game){
    eq(s, 'pen strike %', ss.strikePct, pct(st.strikes, st.pitches));
    eq(s, 'pen pitch_count', ss.total, st.pitch_count);
    continue;
  }
  // Games: History's game card (gameStats + R3 exit_*) vs compute_game_summary's numbers (Joel: its rules everywhere)
  const g = A.gameStats(ps, s.pitch_count_adjust, s.events), G = st.game;
  const charted = ps.length, interf = ps.filter(p => p.result === 'interference' || p.result === 'other').length;
  eq(s, 'pitch count', g.total, st.pitch_count);
  eq(s, 'K / BB / H', [g.k, g.bb + (s.exit_bb || 0), g.h], [G.k, G.bb, G.h]);
  eq(s, 'strike %', g.strikePct, G.strike_pct, interf ? `${interf} interference/other pitch(es): the summary leaves them out of the denominator` : null);
  const r = g.r + (s.exit_runs || 0), er = g.er === null ? null : g.er + (s.exit_er || 0);
  const runsTracked = ps.some(p => p.runsScored) || s.events.some(e => e.runsScored) || G.runs !== null;
  eq(s, 'R', runsTracked ? r : null, G.runs, (G.runs === null && r === 0) ? 'no runs recorded: the card shows 0, the summary null' : null);
  eq(s, 'ER', er, G.er, (er !== null && G.er !== null && er === Math.max(0, G.er)) ? 'the card floors ER at 0' : null);
  // the report's pitching line (template_game.ts)
  const evs = s.events, soft = s.sport === 'softball';
  const wp = new Set(evs.filter(e => e.eventType === 'wild_pitch').map(e => `${e.inningBefore}|${e.atBatIndex}|${e.ballsBefore}|${e.strikesBefore}`)).size;
  const bk = evs.filter(e => soft ? (e.eventType === 'illegal_pitch' || e.eventType === 'balk') : e.eventType === 'balk').length;
  const hits = ps.filter(x => x.result === 'in_play' && x.inPlayOutcome === 'hit');
  eq(s, 'WP / BK / SF / SAC', [wp, bk, ps.filter(x => x.sacrifice === 'SF').length, ps.filter(x => x.sacrifice === 'SAC').length], [G.wp, G.bk, G.sf, G.sac]);
  eq(s, '1B/2B/3B/HR', ['1B', '2B', '3B', 'HR'].map(h => hits.filter(x => x.hitType === h).length), [G.h_1b, G.h_2b, G.h_3b, G.h_hr]);
  eq(s, 'provisional', !s.final_at, st.provisional);
}
console.log(JSON.stringify({ sessions: rows.length, checks, differences: diffs.length, explained: expected.length }, null, 1));
diffs.forEach(x => console.log('DIFF', x)); expected.forEach(x => console.log('KNOWN', x));
