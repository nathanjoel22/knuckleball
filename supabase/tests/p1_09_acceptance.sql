-- P1-09 acceptance (database side), both sports. Rolled back. Run on staging with the migration
-- prepended, or alone once it's applied.
do $$
declare
  HB uuid := '84c1d3f1-0509-49b2-8b3f-30aae98dcbf3';   -- staging baseball head coach (Staging Knights)
  HS uuid := 'aaaaaaaa-0000-4000-8000-000000000a01';   -- softball head coach
  A  uuid := 'aaaaaaaa-0000-4000-8000-000000000a02';   -- assistant on the baseball team
  PB uuid := 'aaaaaaaa-0000-4000-8000-000000000a03';   -- baseball pitcher
  PS uuid := 'aaaaaaaa-0000-4000-8000-000000000a04';   -- softball pitcher
  NP uuid := 'aaaaaaaa-0000-4000-8000-000000000a05';   -- a new pitcher with the invite link
  NC uuid := 'aaaaaaaa-0000-4000-8000-000000000a06';   -- a new coach with the coach link
  TB uuid; TS uuid; TE uuid;
  S1 uuid := gen_random_uuid(); S2 uuid := gen_random_uuid(); S3 uuid := gen_random_uuid();
  tok text; ctok text; r jsonb; c int; out text := ''; v text;
  long61 text := repeat('x', 61);
begin
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000','authenticated','authenticated', 'p109-' || n || '@example.invalid', '{}', now(), now()
    from (values (HS,'hs'),(A,'a'),(PB,'pb'),(PS,'ps'),(NP,'np'),(NC,'nc')) x(u, n);
  insert into public.profiles (id, role, full_name, sport, email_verified_at, age_attestation, attested_at, attested_via, terms_version) values
    (HS,'coach','Sally Softball','softball', now(), 'adult', now(), 'signup', '2026-10-03b'),
    (A,'coach','Asst P109','baseball', now(), 'adult', now(), 'signup', '2026-10-03b'),
    (PB,'pitcher','Ben Baseball','baseball', now(), 'adult', now(), 'signup', '2026-10-03b'),
    (PS,'pitcher','Sue Softball','softball', now(), 'adult', now(), 'signup', '2026-10-03b'),
    (NP,'pitcher','New Pitcher','baseball', now(), 'adult', now(), 'signup', '2026-10-03b'),
    (NC,'coach','New Coach','baseball', now(), 'adult', now(), 'signup', '2026-10-03b');
  TB := public._create_team_with_head(HB, 'P109 Throwaway');
  TS := public._create_team_with_head(HS, 'P109 Softball');
  insert into public.team_coaches (team_id, coach_id, role, invited_by) values (TB, A, 'assistant', HB);
  insert into public.pitcher_teams (pitcher_id, team_id) values (PB, TB), (PS, TS);
  select invite_token, coach_invite_token into tok, ctok from public.teams where id = TB;

  -- a saved pen on each team
  perform set_config('request.jwt.claims', json_build_object('sub', PB, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.sync_session(jsonb_build_object('id', S1, 'pitcher_id', PB, 'team_id', TB, 'logged_by', PB, 'started_at', now() - interval '1 hour', 'ended_at', now()),
       jsonb_build_array(jsonb_build_object('id', gen_random_uuid(), 'type', 'fb', 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2)), '[]');
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', PS, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.sync_session(jsonb_build_object('id', S3, 'pitcher_id', PS, 'team_id', TS, 'logged_by', PS, 'started_at', now() - interval '1 hour', 'ended_at', now()),
       jsonb_build_array(jsonb_build_object('id', gen_random_uuid(), 'type', 'fb', 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2)), '[]');
  execute 'reset role';

  -- 1. rename
  perform set_config('request.jwt.claims', json_build_object('sub', HB, 'role','authenticated')::text, true); execute 'set local role authenticated';
  perform public.rename_team(TB, '  P109 Renamed  '); out := '1. head renames: "' || (select name from public.teams where id = TB) || '"';
  begin perform public.rename_team(TB, 'x'); out := out || ', 1 char: ALLOWED (BAD)'; exception when others then out := out || ', 1 char: ' || sqlerrm; end;
  begin perform public.rename_team(TB, long61); out := out || ', 61 chars: ALLOWED (BAD)'; exception when others then out := out || ', 61 chars: ' || sqlerrm; end;
  perform public.rename_team(TB, repeat('y', 60)); out := out || ', 60 chars: ok';
  perform public.rename_team(TB, 'P109 Renamed');
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', A, 'role','authenticated')::text, true); execute 'set local role authenticated';
  begin perform public.rename_team(TB, 'Assistant Name'); out := out || ', assistant: ALLOWED (BAD)'; exception when others then out := out || ', assistant: ' || sqlerrm; end;
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', PB, 'role','authenticated')::text, true); execute 'set local role authenticated';
  begin perform public.rename_team(TB, 'Pitcher Name'); out := out || ', pitcher: ALLOWED (BAD)'; exception when others then out := out || ', pitcher: ' || sqlerrm; end;
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', HS, 'role','authenticated')::text, true); execute 'set local role authenticated';
  perform public.rename_team(TS, 'P109 Softball Renamed'); out := out || ', softball head renames: "' || (select name from public.teams where id = TS) || '"';
  execute 'reset role';

  -- 4 (part). delete is refused for a team with sessions
  perform set_config('request.jwt.claims', json_build_object('sub', HB, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.delete_team(TB); out := out || ' | 4. delete team with a session: ' || (r->>'message');

  -- 2. archive
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', A, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.archive_team(TB); out := out || ' | 2. archive as assistant: ' || (r->>'error');
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', HB, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.archive_team(TB); out := out || ', as head: ' || (r->>'ok');
  begin perform public.rename_team(TB, 'While Archived'); out := out || ', rename archived: ALLOWED (BAD)'; exception when others then out := out || ', rename archived: ' || sqlerrm; end;
  begin perform public.set_team_level(TB, 'college'); out := out || ', level: ALLOWED (BAD)'; exception when others then out := out || ', level: ' || sqlerrm; end;
  begin perform public.rotate_team_invite(TB); out := out || ', new invite link: ALLOWED (BAD)'; exception when others then out := out || ', new invite link: ' || sqlerrm; end;
  begin r := public.get_team_invite_links(TB); out := out || ', show invite links: ALLOWED (BAD)'; exception when others then out := out || ', show invite links: ' || sqlerrm; end;
  r := public.delete_team(TB); out := out || ', delete archived: ' || (r->>'error');
  select count(*) into c from public.sessions where team_id = TB; out := out || ' | head still reads ' || c || ' session';
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', A, 'role','authenticated')::text, true); execute 'set local role authenticated';
  select count(*) into c from public.sessions where team_id = TB; out := out || ', assistant reads ' || c;
  select count(*) into c from public.teams where id = TB; out := out || ', assistant sees the team row: ' || c;
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', PB, 'role','authenticated')::text, true); execute 'set local role authenticated';
  select count(*) into c from public.sessions where id = S1; out := out || ', pitcher reads his pen: ' || c;
  select count(*) into c from public.pitches p where p.session_id = S1; out := out || ' (' || c || ' pitch)';
  out := out || ', report still eligible: ' || public.is_pitcher_report_eligible(PB);
  r := public.get_team_leaderboard(TB, 'week'); out := out || ', leaderboard: disabled=' || (r->>'disabled') || ' velocity=' || (r->'velocity')::text;
  begin r := public.sync_session(jsonb_build_object('id', S2, 'pitcher_id', PB, 'team_id', TB, 'logged_by', PB, 'started_at', now(), 'ended_at', now()), '[]', '[]');
    out := out || ' | new session via sync_session: ' || coalesce(r->>'error', 'ALLOWED (BAD)');
  exception when others then out := out || ' | new session via sync_session: ' || sqlerrm; end;
  begin insert into public.sessions (id, pitcher_id, team_id, logged_by, started_at, ended_at) values (S2, PB, TB, PB, now(), now());
    out := out || ', direct insert: ALLOWED (BAD)';
  exception when others then out := out || ', direct insert: ' || sqlerrm; end;
  execute 'reset role';
  execute 'set local role anon';
  select team_archived::text into v from public.resolve_team_invite(tok); out := out || ' | invite link resolves archived=' || v;
  select team_archived::text into v from public.resolve_coach_invite(ctok); out := out || ', coach link archived=' || v;
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', NP, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.join_team_via_invite(tok, NP); out := out || ', new pitcher joins: ' || coalesce(r->>'error', 'ALLOWED (BAD)');
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', NC, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.join_team_as_coach(ctok, NC); out := out || ', new coach joins: ' || coalesce(r->>'error', 'ALLOWED (BAD)');
  execute 'reset role';

  -- 3. restore
  perform set_config('request.jwt.claims', json_build_object('sub', A, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.restore_team(TB); out := out || ' | 3. restore as assistant: ' || (r->>'error');
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', HB, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.restore_team(TB); out := out || ', as head: ' || (r->>'ok');
  execute 'reset role';
  select team_archived::text into v from public.resolve_team_invite(tok); out := out || ', same invite link resolves archived=' || v;
  perform set_config('request.jwt.claims', json_build_object('sub', NP, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.join_team_via_invite(tok, NP); out := out || ', new pitcher joins: ' || coalesce(r->>'ok', r->>'error');
  r := public.sync_session(jsonb_build_object('id', S2, 'pitcher_id', NP, 'team_id', TB, 'logged_by', NP, 'started_at', now(), 'ended_at', now()), '[]', '[]');
  out := out || ', new session: ' || coalesce(r->>'status', r->>'error');
  execute 'reset role';

  -- softball archive/restore cycle
  perform set_config('request.jwt.claims', json_build_object('sub', HS, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.archive_team(TS); out := out || ' | softball archive: ' || (r->>'ok');
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', PS, 'role','authenticated')::text, true); execute 'set local role authenticated';
  out := out || ', softball pitcher reads her pen: ' || (select count(*) from public.sessions where id = S3) || ', eligible: ' || public.is_pitcher_report_eligible(PS);
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', HS, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.restore_team(TS); out := out || ', restore: ' || (r->>'ok');
  execute 'reset role';

  -- 4. delete a team with no sessions (with a roster and an assistant)
  TE := public._create_team_with_head(HS, 'P109 Empty');
  insert into public.pitcher_teams (pitcher_id, team_id) values (PS, TE);
  insert into public.team_coaches (team_id, coach_id, role, invited_by)
    select TE, p.id, 'assistant', HS from public.profiles p where p.id = 'aaaaaaaa-0000-4000-8000-000000000a01'::uuid and false;   -- (no second softball coach needed)
  out := out || ' | 4. empty team before: coaches=' || (select count(*) from public.team_coaches where team_id = TE) || ' roster=' || (select count(*) from public.pitcher_teams where team_id = TE);
  perform set_config('request.jwt.claims', json_build_object('sub', PS, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.delete_team(TE); out := out || ', delete as pitcher: ' || (r->>'error');
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', HS, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.delete_team(TE); out := out || ', delete as head: ' || coalesce(r->>'ok', r->>'error');
  execute 'reset role';
  out := out || ', after: team=' || (select count(*) from public.teams where id = TE) || ' coaches=' || (select count(*) from public.team_coaches where team_id = TE)
         || ' roster=' || (select count(*) from public.pitcher_teams where team_id = TE) || ' departures=' || (select count(*) from public.pitcher_team_departures where team_id = TE);
  perform set_config('request.jwt.claims', json_build_object('sub', A, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.delete_team(TB); out := out || ', assistant deletes the baseball team: ' || (r->>'error');
  execute 'reset role';

  out := out || ' | policies: ' || (select count(*) from pg_policies where schemaname = 'public');
  raise exception 'RESULTS(rolled back):%', out;
end $$;
