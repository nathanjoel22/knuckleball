-- R4 acceptance (database side). Rolled back. Run on staging with the migration prepended, or alone
-- once applied. Pitcher P on Team A (recording) and Team B; a softball profile on a softball team.
do $$
declare
  P uuid := 'aaaaaaaa-0000-4000-8000-000000000d01'; P2 uuid := 'aaaaaaaa-0000-4000-8000-000000000d02';
  HA uuid := 'aaaaaaaa-0000-4000-8000-000000000d11'; HB uuid := 'aaaaaaaa-0000-4000-8000-000000000d13';
  AB uuid := 'aaaaaaaa-0000-4000-8000-000000000d14'; HS uuid := 'aaaaaaaa-0000-4000-8000-000000000d17';
  TA uuid; TB uuid; TS uuid;
  OLD uuid := gen_random_uuid(); NEW1 uuid := gen_random_uuid(); NEW2 uuid := gen_random_uuid(); GAME uuid := gen_random_uuid();
  SOFT uuid := gen_random_uuid(); LATE uuid := gen_random_uuid();
  pj jsonb; r jsonb; out text := ''; c int; w record; v text;
begin
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000','authenticated','authenticated', 'r4a-' || n || '@example.invalid', '{}', now(), now()
    from (values (P,'p'),(HA,'ha'),(HB,'hb'),(AB,'ab'),(HS,'hs')) x(u, n);
  insert into public.profiles (id, role, full_name, sport, email_verified_at, age_attestation, attested_at, attested_via, terms_version)
  select u, rl, nm, sp, now(), 'adult', now(), 'signup', '2026-10-03b'
    from (values (P,'pitcher','Pat R4A','baseball'),(HA,'coach','HA','baseball'),(HB,'coach','HB','baseball'),(AB,'coach','AB','baseball'),(HS,'coach','HS','softball')) x(u, rl, nm, sp);
  insert into public.profiles (id, account_id, role, full_name, sport) values (P2, P, 'pitcher', 'Pat R4A (softball)', 'softball');
  TA := public._create_team_with_head(HA, 'R4A Cairn'); TB := public._create_team_with_head(HB, 'R4A Kings');
  TS := public._create_team_with_head(HS, 'R4A Softball');
  insert into public.team_coaches (team_id, coach_id, role, invited_by) values (TB, AB, 'assistant', HB);
  update public.team_coaches set joined_at = now() - interval '30 days' where team_id in (TA, TB);   -- coaches on staff before these pens (dots only show later sessions)
  -- P has been on A for 60 days, joined B 10 days ago
  insert into public.pitcher_teams (pitcher_id, team_id, joined_at) values (P, TA, now() - interval '60 days'), (P, TB, now() - interval '10 days'), (P2, TS, now() - interval '60 days');

  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role','authenticated')::text, true); execute 'set local role authenticated';
  -- A pens: 20 days ago (before he joined B), 5 days ago, 2 days ago; one A game 3 days ago; softball pen 1 day ago
  select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'fb', 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2)) into pj from generate_series(1, 30);
  r := public.sync_session(jsonb_build_object('id', OLD, 'pitcher_id', P, 'team_id', TA, 'logged_by', P, 'started_at', now() - interval '20 days', 'ended_at', now() - interval '20 days' + interval '1 hour'), pj, '[]');
  select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'fb', 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2)) into pj from generate_series(1, 40);
  r := public.sync_session(jsonb_build_object('id', NEW1, 'pitcher_id', P, 'team_id', TA, 'logged_by', P, 'started_at', now() - interval '5 days', 'ended_at', now() - interval '5 days' + interval '1 hour'), pj, '[]');
  select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'fb', 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2)) into pj from generate_series(1, 25);
  r := public.sync_session(jsonb_build_object('id', NEW2, 'pitcher_id', P, 'team_id', TA, 'logged_by', P, 'started_at', now() - interval '2 days', 'ended_at', now() - interval '2 days' + interval '1 hour'), pj, '[]');
  select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'fb', 'kind', 'game', 'actual_row', 2, 'actual_col', 2, 'result', 'ball')) into pj from generate_series(1, 60);
  r := public.sync_session(jsonb_build_object('id', GAME, 'pitcher_id', P, 'team_id', TA, 'logged_by', P, 'started_at', now() - interval '3 days', 'ended_at', now() - interval '3 days' + interval '2 hours', 'kind', 'game'), pj, '[]');
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role','authenticated')::text, true); execute 'set local role authenticated';
  select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'fb', 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2)) into pj from generate_series(1, 15);
  r := public.sync_session(jsonb_build_object('id', SOFT, 'pitcher_id', P2, 'team_id', TS, 'logged_by', P2, 'started_at', now() - interval '1 day', 'ended_at', now() - interval '1 day' + interval '1 hour'), pj, '[]');
  execute 'reset role';
  insert into public.session_notes (session_id, author_id, author_name, body) values (NEW2, HA, 'HA', 'from Cairn');

  -- 2. B's coaches: see A's pens since P joined B (NEW1, NEW2, GAME), not the one from before (OLD)
  perform set_config('request.jwt.claims', json_build_object('sub', HB, 'role','authenticated')::text, true); execute 'set local role authenticated';
  select string_agg(case id when OLD then 'OLD' when NEW1 then 'NEW1' when NEW2 then 'NEW2' when GAME then 'GAME' else '?' end, ',' order by started_at)
    into v from public.sessions where pitcher_id = P;
  out := '2. B head sees P''s sessions: ' || coalesce(v, 'none') || ' (OLD was before he joined B)';
  select count(*) into c from public.session_notes where session_id = NEW2; out := out || ', A''s note on NEW2: ' || c;
  select count(*) into c from public.sessions where pitcher_id = P2; out := out || ', his softball pen: ' || c;
  select string_agg(team_name, ',') into v from public.pitcher_session_teams(P); out := out || ' | chips: ' || v;
  -- 4. workload as B's coach (counts what B can see) vs as P (everything)
  select * into w from public.pitcher_workload(array[P]);
  out := out || ' | 4. workload (B head): last=' || w.last_kind || ' ' || w.last_pitches || ' 7d bullpen=' || w.d7_bullpen || ' game=' || w.d7_game || ' 30d bullpen=' || w.d30_bullpen || ' game=' || w.d30_game;
  -- 5. dots: B's roster gets a dot for P's newest A session
  select count(*) into c from public.get_roster_latest(TB) where pitcher_id = P; out := out || ' | 5. B roster dot source: ' || c;
  select count(*) into c from public.get_unopened_sessions(TB, HB) where pitcher_id = P; out := out || ', unopened for B head: ' || c;
  insert into public.session_opened (viewer_id, session_id) values (HB, NEW2);
  select count(*) into c from public.get_unopened_sessions(TB, HB) where session_id = NEW2; out := out || ', after opening NEW2: ' || c;
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role','authenticated')::text, true); execute 'set local role authenticated';
  select * into w from public.pitcher_workload(array[P]);
  out := out || ' | workload (P): 7d bullpen=' || w.d7_bullpen || ' game=' || w.d7_game || ' 30d bullpen=' || w.d30_bullpen || ' game=' || w.d30_game;
  execute 'reset role';
  out := out || ' | SQL check 30d bullpen all=' || (select count(*) from public.pitches pp join public.sessions s on s.id = pp.session_id where s.pitcher_id = P and s.kind = 'bullpen' and s.started_at > now() - interval '30 days')
             || ' since B join=' || (select count(*) from public.pitches pp join public.sessions s on s.id = pp.session_id where s.pitcher_id = P and s.kind = 'bullpen' and s.started_at > now() - interval '10 days');

  -- 3. archive B: B's coaches keep B's own sessions (none here) and lose P's sessions for A
  update public.teams set archived_at = now(), archived_by = HB where id = TB;
  perform set_config('request.jwt.claims', json_build_object('sub', HB, 'role','authenticated')::text, true); execute 'set local role authenticated';
  select count(*) into c from public.sessions where pitcher_id = P; out := out || ' | 3. B archived -> B head sees P''s A sessions: ' || c;
  select count(*) into c from public.get_roster_latest(TB); out := out || ', B roster dots: ' || c;
  execute 'reset role';
  update public.teams set archived_at = null, archived_by = null where id = TB;

  -- removed from B: visibility ends at once
  delete from public.pitcher_teams where pitcher_id = P and team_id = TB;
  perform set_config('request.jwt.claims', json_build_object('sub', AB, 'role','authenticated')::text, true); execute 'set local role authenticated';
  select count(*) into c from public.sessions where pitcher_id = P; out := out || ' | removed from B -> B assistant sees: ' || c;
  execute 'reset role';
  -- removed from A (the recording team): A keeps its own (G3)
  delete from public.pitcher_teams where pitcher_id = P and team_id = TA;
  perform set_config('request.jwt.claims', json_build_object('sub', HA, 'role','authenticated')::text, true); execute 'set local role authenticated';
  select count(*) into c from public.sessions where pitcher_id = P; out := out || ' | removed from A -> A head still sees: ' || c || ' (his own A sessions)';
  execute 'reset role';
  out := out || ' | policies: ' || (select count(*) from pg_policies where schemaname = 'public');
  raise exception 'RESULTS(rolled back):%', out;
end $$;
