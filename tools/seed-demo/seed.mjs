// DS1: seed the demo facility through the app's own calls, signed in as each account with the public anon key.
//   node seed.mjs --env staging --dry-run     everything generated, out/preview.json + the summary; no network
//   node seed.mjs --env staging               the real run (accounts, facility, groups, sessions, chat)
//   node seed.mjs --env staging --teardown    writes out/teardown-staging.sql for Joel to run (nothing is deleted here)
//   node seed.mjs --env staging --reset       writes the teardown, waits for you to run it, then seeds
// Every run also writes out/verify-<env>.sql (marks the 13 sign-ins verified: DS1 decision D1) once the accounts exist.
// Idempotent: existing accounts are signed into, existing memberships kept, and sessions have fixed ids from the seed,
// so a saved one returns already_saved and is never written twice. No Edge Function is called, so no email is sent.
import readline from 'node:readline/promises';
import { buildPlan, sessionStrikePct, PITCH_NAMES } from './generate.mjs';
import { loadConfig, args, projectFor, termsVersion, account, call, writeOut, allPeople, sqlList, STAGING_MARKER_TEAM } from './lib.mjs';

const A = args();
const cfg = loadConfig();
if(!A.env) throw new Error('--env staging|prod is required');
const plan = buildPlan(cfg);

// ---------------------------------------------------------------------------------------------------- summary
function summary(){
  const rows = plan.pitchers.map(({ profile: p, sessions }) => {
    const pens = sessions.filter(s => s.session.kind === 'bullpen'), games = sessions.filter(s => s.session.kind === 'game');
    const third = Math.max(1, Math.floor(sessions.length / 3));
    const avg = a => a.length ? Math.round(a.reduce((x, y) => x + y, 0) / a.length) : null;
    const early = avg(sessions.slice(0, third).map(sessionStrikePct)), late = avg(sessions.slice(-third).map(sessionStrikePct));
    return {
      pitcher: `${p.index + 1}. ${p.name}`, coach: p.coach, throws: p.throws, arsenal: p.arsenal.join('/'), fb: p.fbAvg,
      trend: p.trajectory, pens: pens.length, games: games.length, intent: games.filter(g => g.intent).length,
      pitches: sessions.reduce((n, s) => n + s.pitches.length, 0),
      first: sessions[0].date, last: sessions[sessions.length - 1].date,
      'strike% first>last third': `${early} > ${late}`
    };
  });
  console.table(rows);
  const all = plan.pitchers.flatMap(x => x.sessions);
  const days = all.map(s => s.date).sort();
  console.log(`sessions ${all.length} (bullpens ${all.filter(s => s.session.kind === 'bullpen').length}, games ${all.filter(s => s.session.kind === 'game').length}), ` +
    `pitches ${all.reduce((n, s) => n + s.pitches.length, 0)}, dates ${days[0]} to ${days[days.length - 1]}`);
  const gl = plan.pitchers.flatMap(x => x.sessions.filter(s => s.box).map(s => s.box));
  const sum = k => gl.reduce((n, b) => n + b[k], 0);
  console.log(`games: ${gl.length}, IP ${sum('outs') / 3}, H ${sum('h')}, R ${sum('r')}, ER ${sum('er')}, K ${sum('k')}, BB ${sum('bb')}, HBP ${sum('hbp')}`);
}

// ---------------------------------------------------------------------------------------------------- SQL files
function guardSql(env){
  return env === 'staging'
    ? `  if not exists (select 1 from public.teams where id = '${STAGING_MARKER_TEAM}') then raise exception 'refused: this is not the staging project'; end if;`
    : `  if exists (select 1 from public.teams where id = '${STAGING_MARKER_TEAM}') then raise exception 'refused: this is the staging project, not production'; end if;`;
}
function verifySql(env){
  const emails = allPeople(cfg).map(p => p.email);
  return `-- DS1 decision D1 (Joel, Nov 11 2026): mark the ${emails.length} demo sign-ins' email verified, without the emailed link.
-- ${env.toUpperCase()} only. Touches public.profiles.email_verified_at on each login's primary profile and nothing else
-- (auth.users is only read). Refuses unless all ${emails.length} logins exist.
--   supabase db query --linked --project-ref ${projectFor(env).ref} -f tools/seed-demo/out/verify-${env}.sql
do $$
declare n_logins int; n_set int;
begin
${guardSql(env)}
  select count(*) into n_logins from auth.users where lower(email) in (
    ${sqlList(emails)});
  if n_logins <> ${emails.length} then raise exception 'refused: % of the ${emails.length} demo logins exist (run seed.mjs first)', n_logins; end if;
  update public.profiles p set email_verified_at = now()
    from auth.users u
   where p.id = u.id and p.email_verified_at is null and lower(u.email) in (
    ${sqlList(emails)});
  get diagnostics n_set = row_count;
  raise notice 'DS1 verify: % profiles marked verified (% were already)', n_set, n_logins - n_set;
end $$;
`;
}
function teardownSql(env){
  const emails = allPeople(cfg).map(p => p.email), name = cfg.facilityName.replace(/'/g, "''");
  return `-- DS1 teardown, ${env.toUpperCase()}: remove everything seed.mjs made. DRY RUN by default: it does the whole cleanup,
-- reports the counts and rolls back. Set dry_run to false to really remove it.
--   supabase db query --linked --project-ref ${projectFor(env).ref} -f tools/seed-demo/out/teardown-${env}.sql
-- Removes: the "${name}" facility (its sessions -- pitches, events, stats and notes go with them -- chat, roster, staff,
-- coach groups, both teams, the organization and its signup link) and the ${emails.length} demo sign-ins with their profiles.
-- Refuses if the facility has a pitcher or coach who is not one of the demo sign-ins (someone real joined it).
-- Report files made from these sessions are listed, and removed if this project lets SQL delete Storage objects.
do $$
declare
  dry_run constant boolean := true;
  v_logins uuid[]; v_org uuid; v_teams uuid[]; v_paths text[]; n_s int; n_pt int; n_prof int; n_users int; n_files int := 0;
begin
${guardSql(env)}
  select array_agg(id) into v_logins from auth.users where lower(email) in (
    ${sqlList(emails)});
  select id into v_org from public.organizations where name = '${name}' and manager_login = any(coalesce(v_logins, '{}'));
  select coalesce(array_agg(id), '{}') into v_teams from public.teams where org_id = v_org;
  if exists (select 1 from public.pitcher_teams pt join public.profiles pr on pr.id = pt.pitcher_id
              where pt.team_id = any(v_teams) and not pr.account_id = any(v_logins))
     or exists (select 1 from public.team_coaches tc join public.profiles pr on pr.id = tc.coach_id
              where tc.team_id = any(v_teams) and not pr.account_id = any(v_logins)) then
    raise exception 'refused: someone who is not a demo sign-in is on this facility; remove them in the app first';
  end if;
  select coalesce(array_agg(report_path), '{}') into v_paths from public.sessions s
   where s.report_path is not null and (s.team_id = any(v_teams)
      or s.pitcher_id in (select id from public.profiles where account_id = any(v_logins)));
  delete from public.sessions s where s.team_id = any(v_teams)
      or s.pitcher_id in (select id from public.profiles where account_id = any(v_logins));   get diagnostics n_s = row_count;
  delete from public.pitcher_teams where team_id = any(v_teams);                             get diagnostics n_pt = row_count;
  delete from public.team_coaches where team_id = any(v_teams);                              -- their groups go with them (trigger)
  delete from public.chat_threads where org_id = v_org;                                      -- messages, reads and reports cascade
  delete from public.teams where id = any(v_teams);                                          -- departures cascade
  delete from public.facility_invites where org_id = v_org or (facility_name = '${name}' and lower(manager_email) in (
    ${sqlList([cfg.manager.email])}));
  delete from public.organizations where id = v_org;
  delete from public.profiles where account_id = any(v_logins) and managed_by is not null;
  delete from public.profiles where account_id = any(v_logins);                              get diagnostics n_prof = row_count;
  delete from auth.users where id = any(v_logins);                                           get diagnostics n_users = row_count;
  if array_length(v_paths, 1) > 0 then
    begin
      delete from storage.objects where bucket_id = 'reports' and name = any(v_paths);       get diagnostics n_files = row_count;
    exception when others then
      raise notice 'Report files to delete by hand (Storage -> reports): %', array_to_string(v_paths, ', ');
    end;
  end if;
  if dry_run then
    raise exception 'DS1 TEARDOWN DRY RUN (rolled back): % sessions, % roster rows, % profiles, % logins, % report files (% listed); facility gone: %',
      n_s, n_pt, n_prof, n_users, n_files, coalesce(array_length(v_paths, 1), 0), not exists (select 1 from public.organizations where id = v_org);
  end if;
  raise notice 'DS1 teardown done: % sessions, % roster rows, % profiles, % logins, % report files', n_s, n_pt, n_prof, n_users, n_files;
end $$;
`;
}

// ---------------------------------------------------------------------------------------------------- the run
const log = (...a) => console.log(...a);
const tally = { accounts: { created: 0, found: 0 }, sessions: { saved: 0, already: 0 }, chat: { posted: 0, found: 0 } };

async function setupAccount(project, person, role){
  const meta = { full_name: person.name, intended_role: role, intended_sport: 'baseball' };
  const a = await account(project, person.email, cfg.password, meta);
  tally.accounts[a.created ? 'created' : 'found']++;
  await call(a.db, 'ensure_account_setup');
  const att = await call(a.db, 'record_attestation', { p_status: 'adult', p_terms_version: termsVersion(), p_guardian_email: null, p_via: 'signup' });
  if(!att || !att.ok) throw new Error(`record_attestation for ${person.name}: ${JSON.stringify(att)}`);
  log(`  ${a.created ? 'made ' : 'found'} ${role.padEnd(7)} ${person.name}`);
  return a;
}

async function run(project){
  log(`\n== ${project.env} (${project.url})`);
  // the manager and the facility (facility-signup.html)
  const mgr = await setupAccount(project, cfg.manager, 'coach');
  let fac = await call(mgr.db, 'my_facility');
  if(!fac){
    const token = (cfg.invites || {})[project.env];
    if(!token) throw new Error(`no facility yet and no invite token: make one on operator.html (${project.env}) for ${cfg.manager.email} and paste it into config.local.json invites.${project.env}`);
    const info = await call(mgr.db, 'facility_invite_info', { p_token: token });
    if(!info || (info.status !== 'ok' && info.status !== 'done')) throw new Error('facility invite: ' + JSON.stringify(info && info.status));
    const made = await call(mgr.db, 'create_facility', { p_token: token });
    if(!made || !made.ok) throw new Error('create_facility: ' + JSON.stringify(made));
    fac = await call(mgr.db, 'my_facility');
    log(`  made the facility "${fac.name}"`);
  } else log(`  found the facility "${fac.name}"`);
  if(fac.name !== cfg.facilityName) throw new Error(`this manager's facility is "${fac.name}", not "${cfg.facilityName}"`);
  const team = fac.teams.find(t => t.sport === 'baseball');
  const links = await call(mgr.db, 'get_team_invite_links', { p_team_id: team.id });
  const coachToken = (Array.isArray(links) ? links[0] : links).coach_invite_token;
  if(!coachToken) throw new Error('get_team_invite_links gave no coach link: ' + JSON.stringify(links));

  // coaches (join-coach.html)
  const coaches = [];
  for(const c of cfg.coaches){
    const a = await setupAccount(project, c, 'coach');
    let mine = (await call(a.db, 'my_group_codes')).find(g => g.mine && g.team_id === team.id);
    if(!mine){
      const j = await call(a.db, 'join_team_as_coach', { p_token: coachToken });
      if(!j || j.error) throw new Error(`join_team_as_coach for ${c.name}: ${JSON.stringify(j)}`);
      mine = (await call(a.db, 'my_group_codes')).find(g => g.mine && g.team_id === team.id);
    }
    if(!mine) throw new Error(`${c.name} has no coach group after joining`);
    a.group = mine; a.profileId = await myCoachProfile(a.db, a.uid); coaches.push(a);
  }

  // pitchers (join.html?c=, "I'm 18 or older and pitch for myself"), their hand and their pitches
  const pitchers = [];
  for(const p of cfg.pitchers){
    const a = await setupAccount(project, p, 'pitcher');
    const coach = coaches[p.coach - 1];
    const onTeam = await a.db.from('pitcher_teams').select('team_id').eq('pitcher_id', a.uid).eq('team_id', team.id);
    if(onTeam.error) throw new Error('pitcher_teams read: ' + onTeam.error.message);
    if(!onTeam.data.length){
      const j = await call(a.db, 'join_group_via_token', { p_token: coach.group.token });
      if(!j || j.error) throw new Error(`join_group_via_token for ${p.name}: ${JSON.stringify(j)}`);
    }
    const t = await a.db.from('profiles').update({ throws: p.throws }).eq('id', a.uid);
    if(t.error) throw new Error('throws: ' + t.error.message);
    await call(a.db, 'set_pitch_arsenal', { p_pitcher: a.uid, p_types: p.arsenal.map(x => PITCH_NAMES[x]) });
    pitchers.push(a);
  }
  log(`  verify SQL: ${writeOut(`verify-${project.env}.sql`, verifySql(project.env))}`);

  // sessions: one sync_session each, as the outbox sends it, by the coach (most) or the pitcher
  for(const [i, x] of plan.pitchers.entries()){
    const pa = pitchers[i], coach = coaches[cfg.pitchers[i].coach - 1];
    let saved = 0, already = 0;
    for(const s of x.sessions){
      const by = s.chartedBy === 'coach' ? coach : pa;
      const sessionRow = Object.assign({}, s.session, { pitcher_id: pa.uid, team_id: team.id, logged_by: by === coach ? coach.profileId : pa.uid });
      const pitchRows = s.pitches.map(p => Object.assign({}, p, { session_id: s.session.id }));
      const r = await call(by.db, 'sync_session', { p_session: sessionRow, p_pitches: pitchRows, p_events: s.events });
      if(!r || !r.ok) throw new Error(`sync_session ${s.date} ${s.session.kind} for ${x.profile.name}: ${JSON.stringify(r)}`);
      if(r.status === 'already_saved') already++; else saved++;
    }
    tally.sessions.saved += saved; tally.sessions.already += already;
    log(`  ${x.profile.name.padEnd(16)} sessions: ${saved} saved, ${already} already there`);
  }

  // chat, dated today (chat_post has no date): the facility thread and one private thread
  if(cfg.chat){
    const ft = await call(mgr.db, 'chat_open', { p_kind: 'facility', p_org: fac.org_id, p_group: null, p_pitcher: null });
    await postAll(mgr.db, ft.thread_id, cfg.chat.facility.map(t => [mgr, t]));
    const pc = cfg.chat.private;
    if(pc){
      const coach = coaches[pc.coach - 1], pitcher = pitchers[pc.pitcher - 1];
      const pt = await call(coach.db, 'chat_open', { p_kind: 'private', p_org: null, p_group: coach.group.group_id, p_pitcher: pitcher.uid });
      if(!pt.ok) throw new Error('chat_open private: ' + JSON.stringify(pt));
      await postAll(coach.db, pt.thread_id, pc.messages.map(([who, t]) => [who === 'coach' ? coach : pitcher, t]));
    }
  }
  log(`\ncreated vs found: ${JSON.stringify(tally)}`);
  log(`next: the verify SQL above (README step 6), then node verify.mjs --env ${project.env}`);
}

// The login's baseball coach profile: the one sync_session's logged_by names when the coach charts.
async function myCoachProfile(db, uid){
  const r = await db.from('profiles').select('id').eq('account_id', uid).eq('role', 'coach').eq('sport', 'baseball');
  if(r.error || !r.data.length) throw new Error('no baseball coach profile for this login' + (r.error ? ': ' + r.error.message : ''));
  return r.data[0].id;
}

async function postAll(db, threadId, posts){
  const th = await call(db, 'chat_thread', { p_thread: threadId });
  const have = (th && th.messages) ? th.messages.length : 0;
  if(have){ tally.chat.found += have; log(`  chat thread already has ${have} messages: left as is`); return; }
  for(const [who, text] of posts){
    const r = await call(who.db, 'chat_post', { p_thread: threadId, p_body: text });
    if(!r || !r.ok) throw new Error('chat_post: ' + JSON.stringify(r));
    tally.chat.posted++;
  }
  log(`  chat: ${posts.length} messages posted`);
}

// ---------------------------------------------------------------------------------------------------- main
const env = A.env;
if(A.flags.has('dry-run')){
  const f = writeOut('preview.json', JSON.stringify({ env, facility: cfg.facilityName, profiles: plan.pitchers.map(x => x.profile), sessions: plan.pitchers.map(x => x.sessions) }, null, 1));
  summary();
  log(`\npreview: ${f}\n(dry run: nothing was sent anywhere)`);
} else if(A.flags.has('teardown') || A.flags.has('reset')){
  projectFor(env);
  const f = writeOut(`teardown-${env}.sql`, teardownSql(env));
  log(`teardown SQL written: ${f}\nIt is a dry run until you change dry_run to false (README, "Removing the facility").`);
  if(A.flags.has('reset')){
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    const ok = await rl.question('Run that SQL (with dry_run false) now. Type SEED when it has finished to seed again: ');
    rl.close();
    if(ok.trim() !== 'SEED'){ log('stopped: nothing seeded'); process.exit(0); }
    summary(); await run(projectFor(env));
  }
} else {
  summary();
  await run(projectFor(env));
}
