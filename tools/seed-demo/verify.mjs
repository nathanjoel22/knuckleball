// DS1 acceptance: signs in as each demo account (anon key, RLS as the app sees it) and checks the packet's list.
//   node verify.mjs --env staging
// Prints PASS / FAIL per check and exits 1 on any FAIL. Writes nothing to the database except one deliberate refusal
// test (the manager trying to post in a coach's private thread, which must be refused).
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { buildPlan } from './generate.mjs';
import { loadConfig, args, projectFor, account, call, writeOut, REPO, zonedDay } from './lib.mjs';

const A = args(), cfg = loadConfig(), project = projectFor(A.env), plan = buildPlan(cfg);
const results = [];
const check = (n, name, ok, detail) => { results.push({ n, name, ok }); console.log(`${ok ? 'PASS' : 'FAIL'}  ${n}. ${name}${detail ? '  -- ' + detail : ''}`); };
const eqSet = (a, b) => a.size === b.size && [...a].every(x => b.has(x));

async function all(q){   // PostgREST pages at 1000 rows
  const out = [];
  for(let from = 0; ; from += 1000){
    const { data, error } = await q().range(from, from + 999);
    if(error) throw new Error(error.message);
    out.push(...data); if(data.length < 1000) return out;
  }
}
const chunks = (arr, n) => Array.from({ length: Math.ceil(arr.length / n) }, (_, i) => arr.slice(i * n, i * n + n));

console.log(`DS1 verify on ${project.env} (${project.url})\n`);

// 1. every account signs in with the shared password
const acc = {};
let signed = 0;
for(const [key, p] of [['manager', cfg.manager], ...cfg.coaches.map((c, i) => ['coach' + (i + 1), c]), ...cfg.pitchers.map((c, i) => ['pitcher' + (i + 1), c])]){
  try { acc[key] = await account(project, p.email, cfg.password, null, { allowCreate: false }); signed++; }
  catch(e){ console.log('   ' + e.message); }
}
check(1, `all ${2 + 1 + cfg.pitchers.length} accounts sign in (web; the TestFlight check is Joel's)`, signed === 13, `${signed} of 13`);
if(signed < 13) process.exit(1);

const mgr = acc.manager, fac = await call(mgr.db, 'my_facility');
const team = fac.teams.find(t => t.sport === 'baseball');
const pitcherIds = cfg.pitchers.map((_, i) => acc['pitcher' + (i + 1)].uid);
const expected = new Map(plan.pitchers.flatMap((x, i) => x.sessions.map(s => [s.session.id, { s, i }])));
const sessCols = 'id, pitcher_id, team_id, logged_by, kind, sport, started_at, ended_at, final_at, deleted_at, pitch_count_adjust, exit_runs, exit_er, exit_bb, game_outs_recorded, report_path';
const seen = async db => all(() => db.from('sessions').select(sessCols).eq('team_id', team.id).order('started_at'));

// 2. the manager sees everyone and everything
const ms = await seen(mgr.db);
const groups = (await call(mgr.db, 'my_group_codes')).filter(g => g.team_id === team.id);
const mThreads = await call(mgr.db, 'chat_my_threads');
const facThread = (mThreads || []).find(t => t.kind === 'facility');
const privThread = (mThreads || []).find(t => t.kind === 'private');   // the seed's Coach 1 <-> Pitcher 2 thread
const privId = privThread && privThread.thread_id;
const privCoach = cfg.chat && cfg.chat.private ? cfg.chat.private.coach : null, privPitcher = cfg.chat && cfg.chat.private ? cfg.chat.private.pitcher : null;
check(2, 'manager: all sessions, all ten pitchers, both coaches\' groups, the facility chat',
  ms.length === expected.size && eqSet(new Set(ms.map(s => s.pitcher_id)), new Set(pitcherIds))
  && cfg.coaches.every(c => groups.some(g => g.coach_name === c.name)) && !!facThread,
  `${ms.length}/${expected.size} sessions, ${new Set(ms.map(s => s.pitcher_id)).size} pitchers, groups: ${groups.map(g => g.coach_name).join(', ')}, facility thread: ${!!facThread}`);
if(privThread){
  const r = await mgr.db.rpc('chat_post', { p_thread: privId, p_body: 'DS1 verify: this post must be refused' });
  check('2b', 'manager cannot post in a coach\'s private thread', !!(r.error || (r.data && r.data.ok === false)), r.error ? r.error.message : JSON.stringify(r.data));
} else check('2b', 'manager cannot post in a coach\'s private thread', false, 'the manager sees no private thread to try (expected one: the seed\'s Coach 1 thread)');

// 3. each coach sees only their own group's pitchers
for(const [ci] of cfg.coaches.entries()){
  const c = acc['coach' + (ci + 1)], want = new Set(cfg.pitchers.map((p, i) => p.coach === ci + 1 ? pitcherIds[i] : null).filter(Boolean));
  const got = new Set((await seen(c.db)).map(s => s.pitcher_id));
  const roster = new Set((await all(() => c.db.from('pitcher_teams').select('pitcher_id').eq('team_id', team.id))).map(r => r.pitcher_id));
  const threads = (await call(c.db, 'chat_my_threads')) || [];
  const others = threads.filter(t => t.kind === 'private' && t.thread_id === privId && privCoach !== ci + 1);
  check(3, `coach ${ci + 1} (${cfg.coaches[ci].name}) sees pitchers ${[...want].map(id => pitcherIds.indexOf(id) + 1).join(', ')} only (History / Trends / Charts read sessions; chat)`,
    eqSet(got, want) && [...roster].every(id => want.has(id)) && !others.length,
    `sessions of ${got.size} pitchers, roster ${roster.size}, other coaches' threads ${others.length}`);
}

// 4. each pitcher sees only their own sessions and their own coach's thread
let p4 = 0;
for(const [i] of cfg.pitchers.entries()){
  const p = acc['pitcher' + (i + 1)];
  const own = await all(() => p.db.from('sessions').select('id, pitcher_id'));
  const threads = (await call(p.db, 'chat_my_threads')) || [];
  const ok = own.length === plan.pitchers[i].sessions.length && own.every(s => s.pitcher_id === p.uid) && threads.every(t => t.kind === 'facility' || (t.thread_id === privId && privPitcher === i + 1));
  if(ok) p4++; else console.log(`   pitcher ${i + 1}: ${own.length} sessions, threads ${JSON.stringify(threads.map(t => t.kind))}`);
}
check(4, 'each pitcher sees only their own sessions (and only their own private thread)', p4 === 10, `${p4} of 10`);

// 5. counts, kinds, dates, one per day
const byP = pitcherIds.map(id => ms.filter(s => s.pitcher_id === id));
const fails5 = [];
byP.forEach((list, i) => {
  const pens = list.filter(s => s.kind === 'bullpen').length, games = list.length - pens;
  const days = list.map(s => zonedDay(s.started_at, cfg.timezone));
  if(list.length < 10 || list.length > 15) fails5.push(`p${i + 1} count ${list.length}`);
  if(pens !== Math.ceil(list.length / 2) || games !== Math.floor(list.length / 2)) fails5.push(`p${i + 1} split ${pens}/${games}`);
  if(days.some(d => d < cfg.startDate || d > cfg.endDate)) fails5.push(`p${i + 1} date outside the window`);
  if(new Set(days).size !== days.length) fails5.push(`p${i + 1} two on one day`);
});
check(5, `${ms.length} sessions (100-150), 10-15 each, half pens / half games, ${cfg.startDate} to ${cfg.endDate}, one a day`, ms.length >= 100 && ms.length <= 150 && !fails5.length, fails5.join('; '));

// 6. reports can be made: every pitcher and both coaches verified, the report gate open
const block = [];
for(const [k, a] of Object.entries(acc)){
  const v = await call(a.db, 'my_verification_status');
  if(!(Array.isArray(v) && v[0] && v[0].email_confirmed === true)) block.push(k + ' unverified');
}
for(const [i, id] of pitcherIds.entries()){
  const r = await mgr.db.rpc('pitcher_report_block', { p_pitcher_id: id });
  if(r.error) { block.push('pitcher_report_block: ' + r.error.message); break; }
  if(r.data) block.push(`p${i + 1}: ${r.data}`);
}
const games = ms.filter(s => s.kind === 'game'), open = games.filter(s => !s.final_at);
check(6, 'reports can be made (all 13 verified, the gate open for every pitcher, no game line open); opening one per pitcher is Joel\'s check',
  !block.length && !open.length, [...block, open.length ? `${open.length} games still provisional` : ''].filter(Boolean).join('; '));

// stats rows for every session (8 and 7 read them)
const ids = ms.map(s => s.id), stats = new Map();
for(const c of chunks(ids, 100)) (await all(() => mgr.db.from('session_stats').select('*').in('session_id', c))).forEach(r => stats.set(r.session_id, r));

// 7. Trends: the four improvers' strike % rises across the window (and the two who slip fall)
const tr = [];
byP.forEach((list, i) => {
  const traj = plan.pitchers[i].profile.trajectory, h = Math.floor(list.length / 2);
  const pct = l => { let n = 0, k = 0; l.forEach(s => { const st = stats.get(s.id); if(st){ n += st.pitches; k += st.strikes; } }); return n ? Math.round(100 * k / n) : 0; };
  const a = pct(list.slice(0, h)), b = pct(list.slice(-h));
  tr.push({ i, traj, a, b, ok: traj === 'improve' ? b - a >= 5 : traj === 'slip' ? a - b >= 5 : Math.abs(b - a) <= 6 });
});
check(7, 'Trends: improvers rise, slips fall, holds stay level (strike %, first half vs second half)', tr.every(x => x.ok),
  tr.map(x => `p${x.i + 1} ${x.traj} ${x.a}>${x.b}`).join(', '));

// 8. session_stats: a row for every session, and 20 of them equal a fresh recomputation with the app's own functions
const sample = ids.filter((_, k) => k % Math.max(1, Math.floor(ids.length / 20)) === 0).slice(0, 20);
const rows = [];
for(const sid of sample){
  const s = ms.find(x => x.id === sid);
  const ps = await all(() => mgr.db.from('pitches').select('id, type, velo, ts, target_row, target_col, actual_row, actual_col, accuracy_mode, in_accuracy_zone, accuracy_hit_kind, batter_side, delivery, time_to_plate, result, in_play_outcome, hit_type, strikes_before, balls_before, bb_type, runs_scored, unearned_runs, inherited_runs, charged_prev, inning, sacrifice').eq('session_id', sid));
  ps.sort((a, b) => Date.parse(a.ts) - Date.parse(b.ts) || (a.id < b.id ? -1 : 1));
  const ev = await all(() => mgr.db.from('game_events').select('event_type, balls_before, strikes_before, inning_before, at_bat_index, runs_scored, unearned_runs, inherited_runs, charged_prev').eq('session_id', sid));
  rows.push({ id: s.id, kind: s.kind, sport: s.sport, pitch_count_adjust: s.pitch_count_adjust, exit_runs: s.exit_runs, exit_er: s.exit_er, exit_bb: s.exit_bb, final_at: s.final_at, game_outs_recorded: s.game_outs_recorded,
    pitches: ps.map(p => ({ type: p.type, velo: p.velo, ts: Date.parse(p.ts), targetRow: p.target_row, targetCol: p.target_col, actualRow: p.actual_row, actualCol: p.actual_col, accuracyMode: p.accuracy_mode, inAccuracyZone: p.in_accuracy_zone, accuracyHitKind: p.accuracy_hit_kind, batterSide: p.batter_side, delivery: p.delivery, timeToPlate: p.time_to_plate, result: p.result, inPlayOutcome: p.in_play_outcome, hitType: p.hit_type, strikesBefore: p.strikes_before, ballsBefore: p.balls_before, bbType: p.bb_type, runsScored: p.runs_scored || 0, unearnedRuns: p.unearned_runs, inheritedRuns: p.inherited_runs || 0, chargedPrev: p.charged_prev === true, inning: p.inning, sacrifice: p.sacrifice })),
    events: ev.map(e => ({ eventType: e.event_type, ballsBefore: e.balls_before, strikesBefore: e.strikes_before, inningBefore: e.inning_before, atBatIndex: e.at_bat_index, runsScored: e.runs_scored || 0, unearnedRuns: e.unearned_runs, inheritedRuns: e.inherited_runs || 0, chargedPrev: e.charged_prev === true })),
    stats: stats.get(sid) || null });
}
const rowsFile = writeOut(`stats-sample-${project.env}.json`, JSON.stringify(rows));
// the compare scripts print their totals as JSON, then one DIFF line per difference
const compare = script => {
  const out = execFileSync('node', [path.join(REPO, 'scripts', script), path.join(REPO, 'bullpen-tracker.html'), rowsFile], { encoding: 'utf8' });
  out.split('\n').filter(l => l.startsWith('DIFF')).slice(0, 5).forEach(l => console.log('   ' + script + ' ' + l));
  return JSON.parse(out.slice(0, out.indexOf('\n}') + 2));
};
const c1 = compare('sc1-compare.js'), c2 = compare('sc1b-compare.js');
const v2 = [...stats.values()].filter(r => r.stats_version === 2).length;
check(8, `session_stats: a version-2 row for every session; 20 recomputed with the app's own functions (sc1-compare, sc1b-compare)`,
  stats.size === ids.length && v2 === ids.length && c1.differences === 0 && c2.differences === 0,
  `${stats.size}/${ids.length} rows, ${v2} v2; sc1: ${c1.checks} checks ${c1.differences} differences; sc1b: ${c2.checks} checks ${c2.differences} differences`);

// 8b. every game's box line (compute_game_summary) equals the generator's
const boxDiffs = [];
for(const g of games){
  const e = expected.get(g.id); if(!e){ boxDiffs.push('unknown game ' + g.id); continue; }
  const sm = await call(mgr.db, 'compute_game_summary', { p_session_id: g.id }), b = e.s.box;
  const want = { pitch_count: b.pitches, strikes: b.strikes, outs_recorded: b.outs, h: b.h, runs: b.r, er: b.er, k: b.k, bb: b.bb, hbp: b.hbp };
  const got = Object.fromEntries(Object.keys(want).map(k => [k, sm[k]]));
  if(JSON.stringify(want) !== JSON.stringify(got)) boxDiffs.push(`${e.s.date} p${e.i + 1}: want ${JSON.stringify(want)} got ${JSON.stringify(got)}`);
}
check('8b', `every game's line (IP, H, R, ER, K, BB, HBP, pitches, strikes) matches its pitches (${games.length} games)`, !boxDiffs.length, boxDiffs.slice(0, 3).join(' | '));

// 9. no leaderboard and no notes on the facility team
const lb = await mgr.db.rpc('get_team_leaderboard', { p_team_id: team.id, p_window: 'season' });
const lbOff = !!(lb.error ? /facility_team/.test(lb.error.message) : (lb.data && (lb.data.error === 'facility_team' || lb.data.disabled)));
let notes = 0;
for(const c of chunks(ids, 100)) notes += (await all(() => mgr.db.from('session_notes').select('id').in('session_id', c))).length;
check(9, 'no leaderboard and no notes on the facility team (other accounts\' isolation: the F1-A RLS matrix)', lbOff && notes === 0,
  `leaderboard: ${lb.error ? lb.error.message : JSON.stringify(lb.data).slice(0, 80)}; notes ${notes}`);

// 10. email: the seed calls no Edge Function; the count is a read-only query (README step 7)
console.log(`\n10. Email: seed.mjs calls no Edge Function, so it can't send. To prove it, compare before and after the run:\n    supabase db query --linked --project-ref ${project.ref} "select count(*) from public.rate_limit_events where created_at > now() - interval '1 day'"`);

const failed = results.filter(r => !r.ok);
console.log(`\n${results.length - failed.length} passed, ${failed.length} failed`);
process.exit(failed.length ? 1 : 0);
