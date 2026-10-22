-- P2-01 Stage 1 edges (staging; rolled back -- the block ends by raising its results).
-- A coach can't file an independent pen; the relief link refuses a missing team (it used to fail open); the G3 check
-- still refuses a team the pitcher isn't on and an archived team; independent sessions stay off the leaderboard;
-- profiles.level takes only its sport's values.
do $$
declare
  P uuid := 'aaaaaaaa-0000-4000-8000-000000000f01'; H uuid := 'aaaaaaaa-0000-4000-8000-000000000f11';
  O uuid := 'aaaaaaaa-0000-4000-8000-000000000f12';
  TA uuid; TO_ uuid; TX uuid; G uuid := gen_random_uuid(); RG uuid := gen_random_uuid();
  r jsonb; out text := ''; lb1 jsonb; lb2 jsonb;
  pj jsonb := '[{"type":"fb","actual_row":2,"actual_col":2,"target_row":2,"target_col":2}]';
begin
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000','authenticated','authenticated', 'p2s1-' || n || '@example.invalid', '{}', now(), now()
    from (values (P,'p'),(H,'h'),(O,'o')) x(u, n);
  insert into public.profiles (id, role, full_name, sport, email_verified_at, age_attestation, attested_at, attested_via, terms_version)
  select u, rl, nm, 'baseball', now(), 'adult', now(), 'signup', '2026-10-17'
    from (values (P,'pitcher','Pat S1'),(H,'coach','H'),(O,'coach','O')) x(u, rl, nm);
  TA := public._create_team_with_head(H, 'S1 Team'); TO_ := public._create_team_with_head(O, 'S1 Other'); TX := public._create_team_with_head(O, 'S1 Archived');
  insert into public.pitcher_teams (pitcher_id, team_id, joined_at) values (P, TA, now() - interval '30 days'), (P, TX, now() - interval '30 days');
  update public.teams set archived_at = now(), archived_by = O where id = TX;

  -- 1. the coach charting P can't file it Independent
  perform set_config('request.jwt.claims', json_build_object('sub', H, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.sync_session(jsonb_build_object('id', gen_random_uuid(), 'pitcher_id', P, 'team_id', null, 'logged_by', H,
         'started_at', now() - interval '2 hours', 'ended_at', now() - interval '1 hour'), pj, '[]');
  out := 'coach files Independent: ' || coalesce(r ->> 'error', r ->> 'status');
  -- 2. the coach's own team still works
  r := public.sync_session(jsonb_build_object('id', G, 'pitcher_id', P, 'team_id', TA, 'logged_by', H, 'kind', 'game',
         'started_at', now() - interval '3 hours', 'ended_at', now() - interval '150 minutes', 'runners_left', 1,
         'left_owners', jsonb_build_object('1', G)), pj || '[{"kind":"game","result":"ball","inning":1,"outs_before":0,"balls_before":0,"strikes_before":0,"at_bat_index":1}]'::jsonb, '[]');
  out := out || ' | coach files on his team: ' || coalesce(r ->> 'error', r ->> 'status');
  execute 'reset role';

  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role','authenticated')::text, true); execute 'set local role authenticated';
  -- 3. a relief game with no team naming a team game: refused (fail closed), saved unlinked
  r := public.sync_session(jsonb_build_object('id', RG, 'pitcher_id', P, 'team_id', null, 'logged_by', P, 'kind', 'game',
         'started_at', now() - interval '140 minutes', 'ended_at', now() - interval '2 hours', 'relieved_session_id', G), '[]', '[]');
  out := out || ' | independent relief of a team game: ' || coalesce(r ->> 'error', r ->> 'status') || ' relief=' || coalesce(r ->> 'relief', '-')
             || ' linked=' || (select (relieved_session_id is not null)::text from public.sessions where id = RG);
  -- 4. G3 for a team: one he isn't on, and an archived one he is on
  begin
    r := public.sync_session(jsonb_build_object('id', gen_random_uuid(), 'pitcher_id', P, 'team_id', TO_, 'logged_by', P,
           'started_at', now() - interval '1 hour', 'ended_at', now() - interval '30 minutes'), pj, '[]');
    out := out || ' | pen on a team he is not on: ' || coalesce(r ->> 'error', r ->> 'status');
  exception when others then out := out || ' | pen on a team he is not on: refused (' || sqlerrm || ')';
  end;
  begin
    r := public.sync_session(jsonb_build_object('id', gen_random_uuid(), 'pitcher_id', P, 'team_id', TX, 'logged_by', P,
           'started_at', now() - interval '1 hour', 'ended_at', now() - interval '30 minutes'), pj, '[]');
    out := out || ' | pen on his archived team: ' || coalesce(r ->> 'error', r ->> 'status');
  exception when others then out := out || ' | pen on his archived team: refused (' || sqlerrm || ')';
  end;
  -- 5. his own independent pen; the team leaderboard doesn't move
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', H, 'role','authenticated')::text, true); execute 'set local role authenticated';
  lb1 := public.get_team_leaderboard(TA, 'all');
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.sync_session(jsonb_build_object('id', gen_random_uuid(), 'pitcher_id', P, 'team_id', null, 'logged_by', P,
         'started_at', now() - interval '50 minutes', 'ended_at', now() - interval '20 minutes'), pj, '[]');
  out := out || ' | his independent pen: ' || coalesce(r ->> 'error', r ->> 'status');
  -- 6. level: his own profile, valid and invalid
  update public.profiles set level = 'high_school' where id = P;
  out := out || ' | level set: ' || (select level from public.profiles where id = P);
  begin
    update public.profiles set level = 'high_school_up' where id = P;
    out := out || ' | softball level on baseball: SAVED?';
  exception when check_violation then out := out || ' | softball level on baseball: refused';
  end;
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', H, 'role','authenticated')::text, true); execute 'set local role authenticated';
  lb2 := public.get_team_leaderboard(TA, 'all');
  execute 'reset role';
  out := out || ' | leaderboard unchanged: ' || (lb1 = lb2)::text;
  begin
    update public.profiles set level = 'college' where id = H;
    out := out || ' | level on a coach: SAVED?';
  exception when check_violation then out := out || ' | level on a coach: refused';
  end;
  out := out || ' | policies: ' || (select count(*) from pg_policies where schemaname = 'public');
  raise exception 'RESULT %', out;
end $$;
