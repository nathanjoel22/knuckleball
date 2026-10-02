-- S4 Stage A acceptance 2, 6, 7 (database side). Rolled back.
do $$
declare
  T  uuid := '18fa6885-c85e-4c2a-88e9-e301c6f93723';   -- baseball team (Staging Knights)
  H  uuid := '84c1d3f1-0509-49b2-8b3f-30aae98dcbf3';   -- its head coach (verified login)
  P  uuid := '14345e15-dca3-4bc7-8126-2639b6504aad';   -- pitcher on it (verified login)
  S  uuid := '0822329a-2f3c-4133-aec1-aa81b8d9eb06';   -- P's pen on T
  X  uuid := 'aaaaaaaa-0000-4000-8000-00000000000b';   -- stranger (fixture)
  U  uuid := 'aaaaaaaa-0000-4000-8000-00000000000c';   -- unverified pitcher login (fixture)
  hs uuid; ps uuid; sbteam uuid; sbtok text; r jsonb; out text := ''; c int; v text;
  procedure_noop int;
begin
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at) values
    (X, '00000000-0000-0000-0000-000000000000','authenticated','authenticated','mp-x@example.invalid','{}', now(), now()),
    (U, '00000000-0000-0000-0000-000000000000','authenticated','authenticated','mp-u@example.invalid','{}', now(), now());
  insert into public.profiles (id, role, full_name, sport) values (X, 'coach', 'MP Stranger', 'baseball'), (U, 'pitcher', 'MP Unverified', 'softball');

  -- 2. Add a sport (head coach adds softball)
  perform set_config('request.jwt.claims', json_build_object('sub', H, 'role','authenticated')::text, true); execute 'set local role authenticated';
  hs := public.add_sport_profile('softball');
  select count(*), string_agg(sport || '/' || role || (case when is_primary then '*' else '' end), ', ' order by sport) into c, v from public.profiles where account_id = H;
  out := out || ' | Add softball: login owns ' || c || ' profiles (' || v || ')';
  begin perform public.add_sport_profile('softball'); out := out || ' | add again: ALLOWED (BAD)'; exception when others then out := out || ' | add again: refused (' || sqlerrm || ')'; end;
  begin perform public.create_team('No profile given'); out := out || ' | create_team w/o profile: ALLOWED (BAD)'; exception when others then out := out || ' | create_team w/o profile: refused (' || sqlerrm || ')'; end;
  sbteam := public.create_team('MP Softball Team', hs);
  out := out || ' | softball team sport=' || (select sport from public.teams where id = sbteam) || ' head=softball profile:' || ((select coach_id from public.teams where id = sbteam) = hs);
  begin insert into public.team_coaches (team_id, coach_id, role) values (T, hs, 'assistant'); out := out || ' | softball profile onto baseball team: ALLOWED (BAD)';
  exception when others then out := out || ' | softball profile onto baseball team: refused (' || sqlerrm || ')'; end;
  out := out || ' | still coach of both: ' || public.is_team_coach(T) || '/' || public.is_team_coach(sbteam);
  sbtok := (select invite_token from public.teams where id = sbteam);
  execute 'reset role';

  -- 6. report gate: a second-sport profile of a verified login
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role','authenticated')::text, true); execute 'set local role authenticated';
  ps := public.add_sport_profile('softball');
  r := public.join_team_via_invite(sbtok);   -- no profile given: picks the login's softball pitcher profile
  out := out || ' | P joins softball team -> profile used is the softball one: ' || ((r->>'profile_id')::uuid = ps);
  execute 'reset role';
  out := out || ' | report eligible: second-sport profile of verified login=' || public.is_pitcher_report_eligible(ps);
  insert into public.pitcher_teams (pitcher_id, team_id) values (U, sbteam);
  out := out || ', unverified login=' || public.is_pitcher_report_eligible(U);

  -- 7. crafted requests with another login's profile id (stranger X)
  perform set_config('request.jwt.claims', json_build_object('sub', X, 'role','authenticated')::text, true); execute 'set local role authenticated';
  begin insert into public.pitches (session_id, type, target_row, target_col, actual_row, actual_col, ts) values (S, 'fb', 2, 2, 2, 2, now()); out := out || ' | X inserts pitch in P''s pen: ALLOWED (BAD)';
  exception when others then out := out || ' | X inserts pitch in P''s pen: refused'; end;
  begin insert into public.sessions (id, pitcher_id, team_id, logged_by, started_at, ended_at) values (gen_random_uuid(), ps, sbteam, ps, now(), now()); out := out || ' | X saves a session as P''s softball profile: ALLOWED (BAD)';
  exception when others then out := out || ' | X saves a session as P''s softball profile: refused'; end;
  r := public.join_team_via_invite(sbtok, ps);
  out := out || ' | X joins a team as P''s profile: ' || coalesce(r->>'error', 'ALLOWED (BAD)');
  begin insert into public.session_notes (session_id, author_id, body) values (S, H, 'forged'); out := out || ' | X writes a note as H: ALLOWED (BAD)';
  exception when others then out := out || ' | X writes a note as H: refused'; end;
  r := public.delete_session(S);
  out := out || ' | X deletes P''s session: ' || coalesce(r->>'error', 'ALLOWED (BAD)');
  begin perform public.create_team('Forged', hs); out := out || ' | X creates a team as H''s profile: ALLOWED (BAD)';
  exception when others then out := out || ' | X creates a team as H''s profile: refused (' || sqlerrm || ')'; end;
  select count(*) into c from public.profiles where id in (hs, ps); out := out || ' | X can see H''s/P''s new profiles: ' || c;
  execute 'reset role';

  -- profiles cap
  perform set_config('request.jwt.claims', json_build_object('sub', X, 'role','authenticated')::text, true);
  raise exception 'RESULTS(rolled back):%', out;
end $$;
