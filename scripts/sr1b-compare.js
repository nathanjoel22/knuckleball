// SR1 Stage B acceptance 7: session_baselines() against sessions summed by hand from their pitches.
// usage: node scripts/sr1b-compare.js <project-ref> <pitcher-profile-id> [<pitcher-profile-id> ...]
// For each pitcher it reads, signed in as that pitcher's own login (read-only, rolled back): every saved session with
// its pitches, the team / profile level, and session_baselines() for every session. It then recomputes every window
// from the pitches -- not from session_stats -- with the app's own helpers (lifted from bullpen-tracker.html, as
// scripts/sc1-compare.js does) and prints every difference. Exit code 1 when there is one.
const fs = require('node:fs'), vm = require('node:vm'), os = require('node:os'), path = require('node:path');
const { execFileSync } = require('node:child_process');
const [ref, ...pitchers] = process.argv.slice(2);
if(!ref || !pitchers.length){ console.error('usage: node scripts/sr1b-compare.js <project-ref> <pitcher-id>...'); process.exit(2); }

const html = fs.readFileSync(path.join(__dirname, '..', 'bullpen-tracker.html'), 'utf8');
const lift = name => {
  const i = html.indexOf('function ' + name + '(');
  if(i < 0) throw new Error('missing ' + name);
  let j = html.indexOf('{', i), d = 0;
  for(let k = j; k < html.length; k++){ if(html[k] === '{') d++; else if(html[k] === '}' && --d === 0) return html.slice(i, k + 1); }
};
const constLine = name => html.match(new RegExp('const ' + name + ' = [^\\n]*'))[0];
const ctx = {}; vm.createContext(ctx);
vm.runInContext([constLine('U6_CUTOFF_TS'), constLine('GAME_STRIKE_RESULTS'), lift('isStrikeCell'), lift('isDefaultVeloReading')].join('\n')
  + '\n;this.api={isStrikeCell,isDefaultVeloReading,GAME_STRIKE_RESULTS};', ctx);
const A = ctx.api;

// The function's starting values (supabase/migrations/20261124000000_sr1b_baselines.sql)
const MIN_AVG = 3, MIN_RANGE = 5, MIN_PITCHES = 10, LO = 0.1, HI = 0.9, TZ = 'America/New_York';

function query(sql){
  const f = path.join(os.tmpdir(), 'sr1b-compare-' + process.pid + '.sql');
  fs.writeFileSync(f, sql);
  const out = execFileSync('supabase', ['db', 'query', '--linked', '--project-ref', ref, '-o', 'json', '-f', f], { encoding: 'utf8', maxBuffer: 1 << 28 });
  fs.unlinkSync(f);
  const o = JSON.parse(out.slice(out.indexOf('{')));
  return o.rows;
}
const rowsFor = pid => query(`begin;
select set_config('request.jwt.claims', json_build_object('sub', (select account_id from public.profiles where id = '${pid}'), 'role', 'authenticated')::text, true);
set local role authenticated;
select jsonb_build_object('id', s.id, 'kind', s.kind, 'purpose', s.purpose, 'started_at', s.started_at, 'adjust', s.pitch_count_adjust,
         'team_level', (select t.level from public.teams t where t.id = s.team_id), 'team_id', s.team_id, 'sport', s.sport,
         'profile_level', (select p.level from public.profiles p where p.id = s.pitcher_id),
         'pitches', coalesce((select jsonb_agg(jsonb_build_object('type', x.type, 'tr', x.target_row, 'tc', x.target_col, 'ar', x.actual_row,
                     'ac', x.actual_col, 'result', x.result, 'bb', x.balls_before, 'sb', x.strikes_before, 'velo', x.velo,
                     'ts', extract(epoch from x.ts) * 1000, 'hk', x.accuracy_hit_kind)) from public.pitches x where x.session_id = s.id), '[]'::jsonb),
         'baselines', public.session_baselines(s.id)) as r
  from public.sessions s
 where s.pitcher_id = '${pid}' and s.deleted_at is null and s.sealed_at is not null
 order by s.started_at;
rollback;`).map(x => typeof x.r === 'string' ? JSON.parse(x.r) : x.r);

// ---- by hand, from the pitches ----
function sessionParts(s){
  const game = s.kind === 'game', ps = s.pitches;
  const strike = p => game ? A.GAME_STRIKE_RESULTS.has(p.result) : A.isStrikeCell(p.ar, p.ac);
  const inPct = p => p.result != null && p.result !== 'interference' && p.result !== 'other';
  const hit = p => p.hk ? (p.hk === 'exact' || p.hk === 'ra') : (p.tr != null && p.tr === p.ar && p.tc === p.ac);
  const vok = p => p.velo != null && !A.isDefaultVeloReading({ velo: p.velo, ts: p.ts });
  const sum = (arr, f) => arr.reduce((a, p) => a + (f(p) ? 1 : 0), 0);
  const part = arr => ({
    pitches: arr.length, k_num: sum(arr, strike), k_den: game ? sum(arr, inPct) : arr.length, hits: sum(arr, hit),
    velo_n: sum(arr, vok), velo_sum: arr.filter(vok).reduce((a, p) => a + p.velo, 0) });
  const all = part(ps);
  const fp = ps.filter(p => p.bb === 0 && p.sb === 0);
  Object.assign(all, { pitch_count: Math.max(0, ps.length + (game ? (s.adjust || 0) : 0)),
    fp_num: game ? sum(fp, strike) : 0, fp_den: game ? fp.length : 0,
    z_num: game ? sum(ps, p => A.isStrikeCell(p.ar, p.ac)) : 0, z_den: game ? ps.length : 0 });
  const types = {};
  for(const t of [...new Set(ps.map(p => p.type || ''))].filter(Boolean)) types[t] = part(ps.filter(p => (p.type || '') === t));
  return { all, types };
}
// exact half-up rounding to 1 decimal of a / b * mul (non-negative integers)
const r1 = (a, b, mul = 1) => b ? Math.floor((20 * a * mul + b) / (2 * b)) / 10 : null;
const rd = x => x == null ? null : Math.round(x * 10 + 1e-9) / 10;
const pct = (arr, q) => { if(!arr.length) return null; const v = [...arr].sort((a, b) => a - b), pos = q * (v.length - 1), lo = Math.floor(pos);
  return lo + 1 < v.length ? v[lo] + (v[lo + 1] - v[lo]) * (pos - lo) : v[lo]; };
const pair = arr => arr.length ? [rd(pct(arr, LO)), rd(pct(arr, HI))] : undefined;
const subMonths = (ms, m) => { const d = new Date(ms); const y = d.getUTCFullYear(), mo = d.getUTCMonth() - m;
  const ty = y + Math.floor(mo / 12), tm = ((mo % 12) + 12) % 12, last = new Date(Date.UTC(ty, tm + 1, 0)).getUTCDate();
  return Date.UTC(ty, tm, Math.min(d.getUTCDate(), last), d.getUTCHours(), d.getUTCMinutes(), d.getUTCSeconds(), d.getUTCMilliseconds()); };
const eastern = ms => new Intl.DateTimeFormat('en-CA', { timeZone: TZ, year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date(ms));

function expected(anchor, sessions){
  const level = anchor.team_id ? (anchor.team_level || null) : (anchor.profile_level || null);
  const lv = level || (anchor.sport === 'softball' ? 'high_school_up' : 'college'), college = lv === 'college';
  const at = Date.parse(anchor.started_at), day = eastern(at), y = +day.slice(0, 4);
  const [smm, sdd] = college ? ['09', '01'] : ['11', '15'];
  const season = (day >= `${y}-${smm}-${sdd}` ? y : y - 1) + `-${smm}-${sdd}`;
  const wins = { '1m': [subMonths(at, 1), at], '3m': [subMonths(at, 3), at], '12m': [subMonths(at, 12), at], season: ['season', at] };
  if(!college) wins.year_ago = [subMonths(subMonths(at, 12), 3), subMonths(at, 12)];
  const out = { level: lv, season_start: season, windows: {} };
  for(const [k, [f, t]] of Object.entries(wins)){
    const pool = sessions.filter(x => x.id !== anchor.id && x.kind === anchor.kind && x.pitches.length >= MIN_PITCHES
      && (anchor.kind !== 'bullpen' || !anchor.purpose || x.purpose === anchor.purpose)
      && Date.parse(x.started_at) < t && (f === 'season' ? eastern(Date.parse(x.started_at)) >= season : Date.parse(x.started_at) >= f));
    const P = pool.map(x => x.parts.all), n = P.length, S = key => P.reduce((a, p) => a + p[key], 0), game = anchor.kind === 'game';
    const w = { n, avg: null, range: null, types: {} };
    if(n >= MIN_AVG) w.avg = clean({ strike_pct: r1(S('k_num'), S('k_den'), 100), spot_pct: game ? undefined : r1(S('hits'), S('pitches'), 100),
      velo: r1(S('velo_sum'), S('velo_n')), velo_n: S('velo_n'), pitches: r1(S('pitch_count'), n),
      fp_strike_pct: game ? r1(S('fp_num'), S('fp_den'), 100) : undefined, in_zone_pct: game ? r1(S('z_num'), S('z_den'), 100) : undefined });
    if(n >= MIN_RANGE) w.range = clean({
      strike_pct: pair(P.filter(p => p.k_den > 0).map(p => 100 * p.k_num / p.k_den)),
      spot_pct: game ? undefined : pair(P.filter(p => p.pitches > 0).map(p => 100 * p.hits / p.pitches)),
      velo: pair(P.filter(p => p.velo_n > 0).map(p => p.velo_sum / p.velo_n)),
      pitches: pair(P.map(p => p.pitch_count)),
      fp_strike_pct: game ? pair(P.filter(p => p.fp_den > 0).map(p => 100 * p.fp_num / p.fp_den)) : undefined,
      in_zone_pct: game ? pair(P.filter(p => p.z_den > 0).map(p => 100 * p.z_num / p.z_den)) : undefined });
    const types = {};
    pool.forEach(x => Object.entries(x.parts.types).forEach(([t, p]) => (types[t] ||= []).push(p)));
    for(const [t, T] of Object.entries(types)){
      const m = T.length, ST = key => T.reduce((a, p) => a + p[key], 0);
      w.types[t] = { n: m,
        avg: m >= MIN_AVG ? clean({ strike_pct: r1(ST('k_num'), ST('k_den'), 100), spot_pct: game ? undefined : r1(ST('hits'), ST('pitches'), 100),
          velo: r1(ST('velo_sum'), ST('velo_n')), velo_n: ST('velo_n'), pitches: r1(ST('pitches'), m) }) : null,
        range: m >= MIN_RANGE ? clean({ strike_pct: pair(T.filter(p => p.k_den > 0).map(p => 100 * p.k_num / p.k_den)),
          spot_pct: game ? undefined : pair(T.filter(p => p.pitches > 0).map(p => 100 * p.hits / p.pitches)),
          velo: pair(T.filter(p => p.velo_n > 0).map(p => p.velo_sum / p.velo_n)) }) : null };
    }
    out.windows[k] = w;
  }
  return out;
}
function clean(o){ for(const k of Object.keys(o)) if(o[k] === undefined || o[k] === null) delete o[k]; return o; }
const num = v => (typeof v === 'string' && v !== '' && !isNaN(v)) ? Number(v) : v;
function norm(v){ if(Array.isArray(v)) return v.map(norm); if(v && typeof v === 'object'){ const o = {}; Object.keys(v).sort().forEach(k => o[k] = norm(v[k])); return o; } return num(v); }

let checks = 0, diffs = [];
for(const pid of pitchers){
  const sessions = rowsFor(pid);
  sessions.forEach(s => { s.parts = sessionParts(s); });
  const counts = { bullpen: 0, game: 0 }, windows = { n: 0, avg: 0, range: 0 };
  for(const s of sessions){
    counts[s.kind]++;
    const got = s.baselines, want = expected(s, sessions);
    for(const key of ['level', 'season_start']){ checks++; if(String(got[key]) !== String(want[key])) diffs.push(`${pid.slice(0, 8)} ${s.id.slice(0, 8)} ${key}: fn=${got[key]} hand=${want[key]}`); }
    const keys = new Set([...Object.keys(got.windows || {}), ...Object.keys(want.windows)]);
    for(const k of keys){
      const g = (got.windows || {})[k], w = want.windows[k];
      if(!g || !w){ checks++; diffs.push(`${pid.slice(0, 8)} ${s.id.slice(0, 8)} ${k}: fn ${g ? 'has' : 'lacks'} it, hand ${w ? 'has' : 'lacks'} it`); continue; }
      for(const part of ['n', 'avg', 'range', 'types']){
        checks++;
        const a = JSON.stringify(norm(part === 'types' ? g.types : g[part])), b = JSON.stringify(norm(part === 'types' ? w.types : w[part]));
        if(a !== b) diffs.push(`${pid.slice(0, 8)} ${s.id.slice(0, 8)} ${s.kind} ${k}.${part}:\n    fn   ${a}\n    hand ${b}`);
      }
      windows.n++; if(w.avg) windows.avg++; if(w.range) windows.range++;
    }
  }
  console.log(`${pid.slice(0, 8)}: ${counts.bullpen} pens, ${counts.game} games; ${windows.n} windows (${windows.avg} with an average, ${windows.range} with a range)`);
}
console.log(`${checks} checks, ${diffs.length} differences`);
diffs.slice(0, 40).forEach(d => console.log('  ' + d));
process.exit(diffs.length ? 1 : 0);
