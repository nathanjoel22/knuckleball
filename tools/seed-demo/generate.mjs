// DS1: the demo facility's pitcher profiles and sessions, as the exact rows the app's own save call takes
// (sync_session's p_session / p_pitches). No network here: seed.mjs --dry-run runs all of this and writes the preview.
//
// Everything comes from one seeded RNG, split into named streams (one per pitcher, per session), so the same config
// gives the same facility on staging and production, and changing one pitcher doesn't move anyone else's numbers.
// Cells are the app's stored catcher frame: rows / cols 0-4, the strike zone rows / cols 1-3 (isStrikeCell).

// ---------------------------------------------------------------------------------------------------- the RNG
function xmur3(str){
  let h = 1779033703 ^ str.length;
  for(let i = 0; i < str.length; i++){ h = Math.imul(h ^ str.charCodeAt(i), 3432918353); h = (h << 13) | (h >>> 19); }
  return () => { h = Math.imul(h ^ (h >>> 16), 2246822507); h = Math.imul(h ^ (h >>> 13), 3266489909); return (h ^= h >>> 16) >>> 0; };
}
function mulberry32(a){
  return () => { a |= 0; a = (a + 0x6D2B79F5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}
export function stream(seed, label){
  const r = mulberry32(xmur3(seed + '|' + label)());
  const api = {
    next: r,
    range: (a, b) => a + r() * (b - a),
    int: (a, b) => a + Math.floor(r() * (b - a + 1)),          // inclusive
    chance: p => r() < p,
    pick: arr => arr[Math.floor(r() * arr.length)],
    weighted: pairs => { let t = 0; pairs.forEach(p => t += p[1]); let x = r() * t; for(const p of pairs){ if((x -= p[1]) < 0) return p[0]; } return pairs[pairs.length - 1][0]; },
    normal: () => { let u = 0, v = 0; while(!u) u = r(); while(!v) v = r(); return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v); },
    uuid: () => {
      const b = Array.from({ length: 16 }, () => Math.floor(r() * 256));
      b[6] = (b[6] & 0x0f) | 0x40; b[8] = (b[8] & 0x3f) | 0x80;
      const h = b.map(x => x.toString(16).padStart(2, '0')).join('');
      return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`;
    }
  };
  api.shuffle = arr => { const a = arr.slice(); for(let i = a.length - 1; i > 0; i--){ const j = Math.floor(r() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };
  return api;
}

// ---------------------------------------------------------------------------------------------------- pitches
// The app's catalog names (bullpen-tracker.html BASEBALL_PITCH_CATALOG); the config uses the short forms.
export const PITCH_NAMES = { FB: 'Four Seam Fastball', SL: 'Slider', CH: 'Changeup', CB: 'Curveball', CT: 'Cutter', SPL: 'Splitter' };
// mph below the fastball, roughly what a college arm shows
const VELO_OFFSET = { FB: 0, CT: -4, SL: -8, CH: -9, SPL: -8, CB: -12 };
const BREAKING = new Set(['SL', 'CB', 'CT']);

const isStrikeCell = (r, c) => r >= 1 && r <= 3 && c >= 1 && c <= 3;
const clampCell = v => Math.max(0, Math.min(4, v));

// The called spot, in the catcher frame. RHB inside = catcher-frame left (zoneNumberFor); a righty's glove side is the
// catcher's right. "No batter" pens aim as vs RHB, like the app speaks them.
function pickTarget(R, abbr, throws, side){
  const inside = side === 'L' ? 3 : 1, away = 4 - inside;
  const glove = throws === 'L' ? 1 : 3, arm = 4 - glove, gloveRing = glove === 3 ? 4 : 0;
  if(abbr === 'FB') return [R.weighted([[1, 0.4], [2, 0.2], [3, 0.4]]), R.weighted([[inside, 0.4], [2, 0.2], [away, 0.4]])];
  if(abbr === 'SL') return [R.weighted([[3, 0.6], [2, 0.3], [4, 0.1]]), R.weighted([[glove, 0.7], [2, 0.2], [gloveRing, 0.1]])];
  if(abbr === 'CB') return [R.weighted([[3, 0.6], [4, 0.25], [2, 0.15]]), R.weighted([[glove, 0.5], [2, 0.4], [arm, 0.1]])];
  if(abbr === 'CT') return [R.weighted([[1, 0.2], [2, 0.3], [3, 0.5]]), R.weighted([[glove, 0.6], [2, 0.3], [arm, 0.1]])];
  // CH / SPL: low and away
  return [R.weighted([[3, 0.65], [4, abbr === 'SPL' ? 0.25 : 0.15], [2, abbr === 'SPL' ? 0.1 : 0.2]]), R.weighted([[away, 0.7], [2, 0.25], [inside, 0.05]])];
}

// Where it went: the target, a neighbouring cell, or anywhere else on the grid (the outer ring included).
// zoneP: how often a miss that left the zone is still pulled back into it (the drifting "throws strikes" part).
function pickActual(R, target, exactP, nearP, zoneP){
  const [tr, tc] = target, x = R.next();
  if(x < exactP) return [tr, tc];
  const keep = cell => (!isStrikeCell(cell[0], cell[1]) && R.chance(zoneP || 0)) ? [Math.min(3, Math.max(1, cell[0])), Math.min(3, Math.max(1, cell[1]))] : cell;
  const near = [];
  for(let dr = -1; dr <= 1; dr++) for(let dc = -1; dc <= 1; dc++){
    if(!dr && !dc) continue;
    const r = tr + dr, c = tc + dc;
    if(r >= 0 && r <= 4 && c >= 0 && c <= 4) near.push([r, c]);
  }
  if(x < nearP) return keep(R.pick(near));
  const rest = [];
  for(let r = 0; r <= 4; r++) for(let c = 0; c <= 4; c++){
    if(Math.abs(r - tr) <= 1 && Math.abs(c - tc) <= 1) continue;
    rest.push([r, c]);
  }
  return keep(R.pick(rest));
}

// ---------------------------------------------------------------------------------------------------- profiles
const TRAJECTORIES = ['improve', 'improve', 'improve', 'improve', 'hold', 'hold', 'hold', 'hold', 'slip', 'slip'];

export function pitcherProfiles(cfg){
  const order = stream(cfg.seed, 'trajectories').shuffle(TRAJECTORIES);
  return cfg.pitchers.map((p, i) => {
    const R = stream(cfg.seed, 'profile|' + i);
    const arsenal = p.arsenal.slice();
    const secondaries = arsenal.filter(a => a !== 'FB');
    const best = secondaries.length ? R.pick(secondaries) : null;
    const worst = secondaries.length > 1 ? R.pick(secondaries.filter(a => a !== best)) : null;
    const exact = R.range(0.25, 0.45);
    const near = Math.max(exact + 0.25, R.range(0.60, 0.80));
    const typeMod = {};
    arsenal.forEach(a => { typeMod[a] = a === best ? 0.07 : a === worst ? -0.07 : 0; });
    // usage: the fastball about half, the best secondary a little more than the rest
    const usage = arsenal.map(a => [a, a === 'FB' ? (arsenal.length === 2 ? 0.6 : 0.5) : (a === best ? 1.4 : a === worst ? 0.7 : 1) * (0.5 / Math.max(1, secondaries.length))]);
    return {
      index: i, name: p.name, throws: p.throws, coach: p.coach, arsenal, best, worst,
      fbAvg: Math.round(R.range(79, 91) * 10) / 10, exact, near, typeMod, usage,
      trajectory: order[i]
    };
  });
}

// Command and velocity drift across the window (t = 0 on the first day, 1 on the last): slow, never a jump.
function drift(prof, t){
  if(prof.trajectory === 'improve') return { cmd: 0.72 + 0.56 * t, zone: 0.0 + 0.32 * t, velo: 1.5 * t };
  if(prof.trajectory === 'slip') return { cmd: 1.15 - 0.36 * t, zone: 0.3 - 0.3 * t, velo: -1.2 * t };
  return { cmd: 1, zone: 0.15, velo: 0 };
}
function command(prof, abbr, t, R){
  const d = drift(prof, t).cmd * (1 + R.normal() * 0.02);
  const mod = prof.typeMod[abbr] || 0;
  const exact = Math.min(0.62, Math.max(0.12, (prof.exact + mod) * d));
  const near = Math.min(0.93, Math.max(exact + 0.18, (prof.near + mod) * Math.min(1.2, d)));
  return { exact, near, zone: drift(prof, t).zone };
}
function velo(prof, abbr, t, R){
  const avg = prof.fbAvg + VELO_OFFSET[abbr] + drift(prof, t).velo;
  let v = Math.round(avg + Math.max(-2, Math.min(2, R.normal() * 1.0)));
  if(v === 65) v = 66;   // U6: a 65 from before Sep 21 is read as "no reading"
  return v;
}

// ---------------------------------------------------------------------------------------------------- dates
const DAY = 86400000;
function dayList(startISO, endISO){
  const out = [];
  for(let d = Date.parse(startISO + 'T12:00:00Z'); d <= Date.parse(endISO + 'T12:00:00Z'); d += DAY) out.push(new Date(d).toISOString().slice(0, 10));
  return out;
}
// A wall-clock time in the facility's timezone -> epoch ms (handles the Nov 1 change from EDT to EST).
export function zonedMs(dateISO, hour, minute, tz){
  const [y, m, d] = dateISO.split('-').map(Number);
  const guess = Date.UTC(y, m - 1, d, hour, minute);
  const off = new Intl.DateTimeFormat('en-US', { timeZone: tz, timeZoneName: 'shortOffset' }).formatToParts(new Date(guess)).find(p => p.type === 'timeZoneName').value;
  const mm = off.match(/GMT([+-])(\d+)(?::(\d+))?/);
  const offMin = mm ? (mm[1] === '-' ? -1 : 1) * (Number(mm[2]) * 60 + Number(mm[3] || 0)) : 0;
  return guess - offMin * 60000;
}
const weekday = iso => new Date(iso + 'T12:00:00Z').getUTCDay();   // 0 Sun .. 6 Sat

function sessionDates(R, cfg, nPens, nGames){
  const days = dayList(cfg.startDate, cfg.endDate), used = new Set();
  const draw = (weightOf) => {
    const pairs = days.filter(d => !used.has(d)).map(d => [d, weightOf(d)]).filter(p => p[1] > 0);
    const d = R.weighted(pairs); used.add(d); return d;
  };
  const games = [], pens = [];
  for(let i = 0; i < nGames; i++) games.push(draw(d => {
    const wd = weekday(d), mo = Number(d.slice(5, 7));
    return ([0, 4, 5, 6].includes(wd) ? 1 : 0.12) * ((mo === 9 || mo === 10) ? 1.6 : 1);
  }));
  for(let i = 0; i < nPens; i++) pens.push(draw(d => ([1, 2, 3, 4, 5].includes(weekday(d)) ? 1 : 0.25)));
  return { pens, games };
}

// ---------------------------------------------------------------------------------------------------- a bullpen
function pickType(R, prof, weights){ return R.weighted(weights || prof.usage); }

function buildPen(R, prof, cfg, dateISO, t, ids){
  const n = R.int(20, 40), warm = R.int(5, 8);
  const hasGun = R.chance(0.8);
  const batterMode = R.chance(0.35) ? 'none' : 'batters';
  let side = R.chance(0.7) ? 'R' : 'L', sideLeft = R.int(5, 8), delivery = 'windup', delLeft = warm;
  const hour = R.weighted([[15, 1], [16, 1.2], [17, 0.8], [18, 0.4]]);
  let ts = zonedMs(dateISO, hour, R.int(0, 50), cfg.timezone);
  const startedAt = ts - R.int(60, 180) * 1000;
  const pitches = [];
  for(let i = 0; i < n; i++){
    const abbr = i < warm ? 'FB' : pickType(R, prof);
    const s = batterMode === 'none' ? null : side;
    const target = pickTarget(R, abbr, prof.throws, s || 'R');
    const cmd = command(prof, abbr, t, R);
    const actual = pickActual(R, target, cmd.exact, cmd.near, cmd.zone);
    pitches.push({
      id: ids.uuid(), type: PITCH_NAMES[abbr], velo: hasGun && R.chance(0.92) ? velo(prof, abbr, t, R) : null,
      target_row: target[0], target_col: target[1], actual_row: actual[0], actual_col: actual[1],
      accuracy_mode: null, in_accuracy_zone: null, accuracy_zone_cells: null,
      accuracy_hit_kind: (target[0] === actual[0] && target[1] === actual[1]) ? 'exact' : 'miss',
      batter_side: s, delivery, time_to_plate: null, kind: 'bullpen', ts: new Date(ts).toISOString()
    });
    ts += R.int(22, 40) * 1000;
    if(batterMode === 'batters' && --sideLeft <= 0){ side = side === 'R' ? 'L' : 'R'; sideLeft = R.int(5, 8); }
    if(--delLeft <= 0){ delivery = (i >= warm && R.chance(0.4)) ? 'set' : 'windup'; delLeft = R.int(4, 7); }
  }
  return {
    session: {
      started_at: new Date(startedAt).toISOString(), ended_at: new Date(ts + R.int(30, 90) * 1000).toISOString(),
      kind: 'bullpen', charting_perspective: 'behind_pitcher',   // U15: a bullpen opens behind the pitcher
      opponent: null, game_final_inning: null, game_outs_recorded: null, ra_on: false, pitch_count_adjust: 0,
      inherited_runners: null, runners_left: null, relieved_session_id: null, left_owners: null
    },
    pitches, events: []
  };
}

// ---------------------------------------------------------------------------------------------------- a Live Game
const OPPONENTS = ['Lakeview', 'North County', 'Harbor City', 'Eastside', 'Pinecrest', 'Ridgeway', 'Westfield', 'Cedar Valley', 'Summit', 'Brookside'];
const IF_BOX = { P: 24, C: 15, '1B': 23, '2B': 22, SS: 18, '3B': 17 };
const OF_BOX = { LF: [19, 4, 5], CF: [20, 6, 7, 8], RF: [21, 9, 10] };

function pull(R, side, pairsR){   // a lefty pulls to the other side of the field
  if(side !== 'L') return R.weighted(pairsR);
  const mirror = { '3B': '1B', '1B': '3B', SS: '2B', '2B': 'SS', LF: 'RF', RF: 'LF' };
  return R.weighted(pairsR.map(([k, w]) => [mirror[k] || k, w]));
}
const bits = bases => (bases[1] ? 1 : 0) | (bases[2] ? 2 : 0) | (bases[3] ? 4 : 0);

// Push runners as far as forced (a walk or HBP): returns the advances and the runs.
function forceAdvance(bases){
  const adv = []; let runs = 0, unearned = 0;
  if(bases[1]){
    if(bases[2]){
      if(bases[3]){ adv.push({ from: 3, to: 4, how: 'forced' }); runs++; if(!bases[3].earned) unearned++; }
      adv.push({ from: 2, to: 3, how: 'forced' }); bases[3] = bases[2];
    }
    adv.push({ from: 1, to: 2, how: 'forced' }); bases[2] = bases[1];
  }
  return { adv, runs, unearned };
}

// One ball in play. bases[1..3] hold {earned} runners (mutated). Returns the play's stored fields.
function resolveInPlay(R, side, bases, outsBefore){
  const play = { in_play_outcome: null, hit_type: null, bb_type: null, fielder: null, fielders: null, spray_box: null, spray_field: null,
    batter_to: 0, runner_advances: [], outs_on_play: 0, runs_scored: 0, unearned_runs: 0, sacrifice: null };
  const score = (b, how) => { play.runner_advances.push({ from: b, to: 4, how }); play.runs_scored++; if(!bases[b].earned) play.unearned_runs++; bases[b] = null; };
  const move = (b, to, how) => { play.runner_advances.push({ from: b, to, how }); bases[to] = bases[b]; bases[b] = null; };
  const ofPick = () => { const f = pull(R, side, [['LF', 0.4], ['CF', 0.35], ['RF', 0.25]]); return [f, R.pick(OF_BOX[f])]; };
  const x = R.next();
  if(x < 0.29){   // a hit
    const h = R.weighted([['1B', 0.70], ['2B', 0.20], ['3B', 0.03], ['HR', 0.07]]);
    play.in_play_outcome = 'hit'; play.hit_type = h;
    if(h === 'HR'){
      play.bb_type = R.weighted([['fly', 0.7], ['line', 0.3]]); play.spray_box = R.pick([5, 6, 7, 8, 9]);
      [3, 2, 1].forEach(b => { if(bases[b]) score(b, 'hr'); });
      play.batter_to = 4; play.runs_scored++;   // the batter's own run (earned: he reached on a hit)
      return play;
    }
    if(h === '1B' && R.chance(0.08)){ play.bb_type = 'ground'; play.fielder = pull(R, side, [['SS', 0.6], ['3B', 0.4]]); play.spray_box = IF_BOX[play.fielder]; play.spray_field = 'IF'; }
    else {
      play.bb_type = h === '1B' ? R.weighted([['ground', 0.4], ['line', 0.45], ['fly', 0.15]]) : h === '2B' ? R.weighted([['line', 0.55], ['fly', 0.35], ['ground', 0.1]]) : R.weighted([['line', 0.6], ['fly', 0.4]]);
      const [f, box] = ofPick(); play.fielder = f; play.spray_field = 'OF';
      play.spray_box = h === '1B' ? OF_BOX[f][0] : box === OF_BOX[f][0] ? OF_BOX[f][1] : box;
    }
    if(h === '1B'){
      if(bases[3]) score(3, 'advanced');
      if(bases[2]){ if(R.chance(0.6)) score(2, 'advanced'); else move(2, 3, 'advanced'); }
      if(bases[1]){ if(!bases[3] && R.chance(0.3)) move(1, 3, 'advanced'); else move(1, 2, 'advanced'); }
      bases[1] = { earned: true }; play.batter_to = 1;
    } else if(h === '2B'){
      if(bases[3]) score(3, 'advanced');
      if(bases[2]) score(2, 'advanced');
      if(bases[1]){ if(R.chance(0.45)) score(1, 'advanced'); else move(1, 3, 'advanced'); }
      bases[2] = { earned: true }; play.batter_to = 2;
    } else {
      [3, 2, 1].forEach(b => { if(bases[b]) score(b, 'advanced'); });
      bases[3] = { earned: true }; play.batter_to = 3;
    }
    return play;
  }
  if(x < 0.325){   // reached on an error: he and every run on the play are unearned
    play.in_play_outcome = 'error'; play.bb_type = 'ground';
    play.fielder = pull(R, side, [['SS', 0.35], ['3B', 0.3], ['2B', 0.2], ['1B', 0.15]]); play.spray_box = IF_BOX[play.fielder]; play.spray_field = 'IF';
    if(bases[3]){ play.runner_advances.push({ from: 3, to: 4, how: 'on_error' }); play.runs_scored++; play.unearned_runs++; bases[3] = null; }
    if(bases[2]) move(2, 3, 'on_error');
    if(bases[1]) move(1, 2, 'on_error');
    bases[1] = { earned: false }; play.batter_to = 1;
    return play;
  }
  // an out
  play.in_play_outcome = 'out';
  const bb = R.weighted([['ground', 0.45], ['fly', 0.28], ['pop', 0.14], ['line', 0.13]]);
  play.bb_type = bb;
  if(bb === 'ground'){
    const f = pull(R, side, [['3B', 0.25], ['SS', 0.3], ['2B', 0.2], ['1B', 0.1], ['P', 0.15]]);
    play.fielder = f; play.spray_box = IF_BOX[f]; play.spray_field = 'IF';
    if(bases[1] && outsBefore < 2 && R.chance(0.4)){   // the double play: force at second, then the batter
      play.fielders = (f === '2B' || f === '1B') ? 'SS-1B' : '2B-1B'; play.outs_on_play = 2;
      play.runner_advances.push({ from: 1, to: 0, how: 'force_out' }); bases[1] = null;
      if(outsBefore === 0){ if(bases[3]) score(3, 'advanced'); if(bases[2]) move(2, 3, 'advanced'); }
      return play;
    }
    play.fielders = '1B'; play.outs_on_play = 1;   // the out at first (fielded by the first baseman: unassisted)
    if(outsBefore < 2){
      if(bases[3] && R.chance(0.45)) score(3, 'advanced');
      if(bases[2] && !bases[3] && R.chance(0.55)) move(2, 3, 'advanced');
      if(bases[1] && !bases[2] && R.chance(0.7)) move(1, 2, 'advanced');
    }
    return play;
  }
  if(bb === 'pop' || (bb === 'line' && R.chance(0.5))){
    const f = bb === 'pop' ? pull(R, side, [['C', 0.1], ['1B', 0.2], ['2B', 0.25], ['SS', 0.25], ['3B', 0.2]]) : pull(R, side, [['SS', 0.35], ['2B', 0.3], ['3B', 0.2], ['1B', 0.1], ['P', 0.05]]);
    play.fielder = f; play.spray_box = IF_BOX[f]; play.spray_field = 'IF'; play.outs_on_play = 1;
    return play;
  }
  const [f, box] = ofPick(); play.fielder = f; play.spray_box = box; play.spray_field = 'OF'; play.outs_on_play = 1;
  if(bb === 'fly' && bases[3] && outsBefore < 2 && R.chance(0.55)){ score(3, 'tagged_up'); play.sacrifice = 'SF'; }
  return play;
}

function simulateGame(R, prof, t, intent, startMs, ids){
  const innings = R.weighted([[1, 0.1], [2, 0.3], [3, 0.35], [4, 0.25]]);
  const lineup = R.shuffle(['R', 'R', 'R', 'R', 'R', 'R', 'L', 'L', 'L']);
  const hasGun = R.chance(0.75);
  const pitches = []; let ts = startMs, ab = 0, box = { h: 0, r: 0, er: 0, k: 0, bb: 0, hbp: 0, strikes: 0 };
  for(let inning = 1; inning <= innings; inning++){
    const bases = [null, null, null, null]; let outs = 0;
    if(inning > 1) ts += R.int(6, 12) * 60000;   // the other half-inning
    while(outs < 3){
      ab++; const side = lineup[(ab - 1) % 9]; let balls = 0, strikes = 0, done = false;
      while(!done){
        const behind = balls >= 2 && balls > strikes, twoK = strikes === 2 && balls < 3;
        const weights = twoK ? prof.usage.map(([a, w]) => [a, a === 'FB' ? w * 0.8 : w * 1.4]) : behind ? prof.usage.map(([a, w]) => [a, a === 'FB' ? w * 1.8 : w]) : null;
        const abbr = pickType(R, prof, weights);
        const target = pickTarget(R, abbr, prof.throws, side);
        const cmd = command(prof, abbr, t, R), cmdG = { exact: cmd.exact * 0.92, near: cmd.near * 0.95 };   // a little less sharp than in the pen
        const [ar, ac] = pickActual(R, target, cmdG.exact, cmdG.near, cmd.zone * 0.9);
        const inZone = isStrikeCell(ar, ac);
        const p = {
          id: ids.uuid(), type: PITCH_NAMES[abbr], velo: hasGun && R.chance(0.9) ? velo(prof, abbr, t, R) : null,
          target_row: intent ? target[0] : null, target_col: intent ? target[1] : null, actual_row: ar, actual_col: ac,
          accuracy_mode: null, in_accuracy_zone: null, accuracy_zone_cells: null,
          accuracy_hit_kind: intent ? ((target[0] === ar && target[1] === ac) ? 'exact' : 'miss') : null,
          batter_side: side, delivery: bits(bases) ? 'set' : 'windup', time_to_plate: null, kind: 'game', ts: new Date(ts).toISOString(),
          result: null, in_play_outcome: null, hit_type: null, fielder: null, fielders: null, bb_type: null,
          inning, outs_before: outs, balls_before: balls, strikes_before: strikes, at_bat_index: ab,
          runners_before: bits(bases), batter_to: null, runner_advances: null, outs_on_play: 0, runs_scored: 0,
          sacrifice: null, spray_box: null, spray_field: null, runners_after: null, unearned_runs: 0, inherited_runs: 0
        };
        ts += R.int(18, 32) * 1000;
        const swingP = (balls === 3 && strikes === 0) ? 0.15 : inZone ? (strikes === 2 ? 0.82 : 0.66) : (strikes === 2 ? 0.4 : 0.27);
        if(R.chance(swingP)){
          if(R.chance(inZone ? 0.86 : 0.62)){
            if(R.chance(inZone ? 0.42 : 0.6)){ p.result = 'foul'; if(strikes < 2) strikes++; }
            else {
              p.result = 'in_play';
              const play = resolveInPlay(R, side, bases, outs);
              Object.assign(p, play, { runner_advances: play.runner_advances.length ? play.runner_advances : null });
              outs += play.outs_on_play; box.r += play.runs_scored; box.er += play.runs_scored - play.unearned_runs;
              if(play.in_play_outcome === 'hit') box.h++;
              done = true;
            }
          } else if(strikes === 2){ p.result = 'strike_swinging'; p.batter_to = 0; p.outs_on_play = 1; outs++; box.k++; done = true; }
          else { p.result = 'strike_swinging'; strikes++; }
        } else if(inZone){
          if(strikes === 2){ p.result = 'strike_looking'; p.batter_to = 0; p.outs_on_play = 1; outs++; box.k++; done = true; }
          else { p.result = 'strike_looking'; strikes++; }
        } else if(R.chance(0.012)){
          p.result = 'hbp'; const f = forceAdvance(bases); bases[1] = { earned: true };
          Object.assign(p, { batter_to: 1, runner_advances: f.adv.length ? f.adv : null, runs_scored: f.runs, unearned_runs: f.unearned });
          box.r += f.runs; box.er += f.runs - f.unearned; box.hbp++; done = true;
        } else if(balls === 3){
          p.result = 'ball'; const f = forceAdvance(bases); bases[1] = { earned: true };
          Object.assign(p, { batter_to: 1, runner_advances: f.adv.length ? f.adv : null, runs_scored: f.runs, unearned_runs: f.unearned });
          box.r += f.runs; box.er += f.runs - f.unearned; box.bb++; done = true;
        } else { p.result = 'ball'; balls++; }
        if(p.result !== 'ball' && p.result !== 'hbp') box.strikes++;
        // like the app: the bases after a plate appearance, except after a strikeout or the inning's last out
        if(done && p.result !== 'strike_swinging' && p.result !== 'strike_looking' && outs < 3) p.runners_after = bits(bases);
        pitches.push(p);
      }
    }
  }
  return { pitches, innings, box: Object.assign(box, { ip: innings + '.0', outs: innings * 3, pitches: pitches.length }), endMs: ts };
}

function buildGame(R, prof, cfg, dateISO, t, ids){
  const intent = R.chance(0.6);
  const wd = weekday(dateISO);
  const hour = (wd === 0 || wd === 6) ? R.weighted([[12, 1], [13, 1], [15, 0.6]]) : R.weighted([[17, 0.6], [18, 1], [19, 0.6]]);
  const startMs = zonedMs(dateISO, hour, R.pick([0, 0, 30]), cfg.timezone) + R.int(0, 8) * 60000;
  let g = null;
  for(let tries = 0; tries < 200; tries++){   // the packet's range: 25-75 pitches
    const cand = simulateGame(R, prof, t, intent, startMs, ids);
    if(cand.pitches.length >= 25 && cand.pitches.length <= 75){ g = cand; break; }
  }
  if(!g) throw new Error(`no game in 25-75 pitches for ${prof.name} on ${dateISO}`);
  return {
    session: {
      started_at: new Date(startMs - 120000).toISOString(), ended_at: new Date(g.endMs + 60000).toISOString(),
      kind: 'game', charting_perspective: 'behind_catcher',   // U15: a Live Game opens behind the catcher
      opponent: R.pick(OPPONENTS), game_final_inning: g.innings, game_outs_recorded: g.innings * 3, ra_on: false,
      pitch_count_adjust: 0, inherited_runners: 0, runners_left: 0, relieved_session_id: null, left_owners: null
    },
    pitches: g.pitches, events: [], intent, box: g.box
  };
}

// ---------------------------------------------------------------------------------------------------- the plan
export function buildPlan(cfg){
  const profiles = pitcherProfiles(cfg);
  const span = Date.parse(cfg.endDate) - Date.parse(cfg.startDate);
  const pitchers = profiles.map(prof => {
    const R = stream(cfg.seed, 'sessions|' + prof.index);
    const n = R.int(10, 15), nPens = Math.ceil(n / 2), nGames = n - nPens;
    const dates = sessionDates(R, cfg, nPens, nGames);
    const list = [...dates.pens.map(d => ['bullpen', d]), ...dates.games.map(d => ['game', d])].sort((a, b) => a[1] < b[1] ? -1 : 1);
    const sessions = list.map(([kind, d], k) => {
      const SR = stream(cfg.seed, `session|${prof.index}|${k}`), ids = stream(cfg.seed, `ids|${prof.index}|${k}`);
      const t = span ? (Date.parse(d) - Date.parse(cfg.startDate)) / span : 0;
      const built = kind === 'bullpen' ? buildPen(SR, prof, cfg, d, t, ids) : buildGame(SR, prof, cfg, d, t, ids);
      built.session.id = ids.uuid();
      built.date = d;
      built.chartedBy = SR.chance(0.7) ? 'coach' : 'pitcher';   // most facility sessions are charted by the coach
      return built;
    });
    return { profile: prof, sessions };
  });
  return { pitchers };
}

// The numbers the dry run prints and verify.mjs checks against: strike % the way Trends counts it.
export function penStrikePct(s){ return Math.round(100 * s.pitches.filter(p => isStrikeCell(p.actual_row, p.actual_col)).length / s.pitches.length); }
const GAME_STRIKES = new Set(['strike_looking', 'strike_swinging', 'foul', 'foul_tip', 'in_play']);
export function sessionStrikePct(s){
  return s.session.kind === 'game' ? Math.round(100 * s.pitches.filter(p => GAME_STRIKES.has(p.result)).length / s.pitches.length) : penStrikePct(s);
}
