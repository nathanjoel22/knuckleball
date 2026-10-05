-- Teams hotfix acceptance (E1 + E2). Rolled back. Run on staging with the migration prepended,
-- or alone once it's applied.
do $$
declare
  T  uuid := '18fa6885-c85e-4c2a-88e9-e301c6f93723';   -- Staging Knights (baseball, has sessions)
  H  uuid := '84c1d3f1-0509-49b2-8b3f-30aae98dcbf3';   -- its head coach
  A  uuid := 'aaaaaaaa-0000-4000-8000-0000000000f1';   -- assistant
  P  uuid := 'aaaaaaaa-0000-4000-8000-0000000000f2';   -- rostered pitcher
  E  uuid;                                              -- an empty team
  r jsonb; c int; v text; out text := ''; n_sess int; lvl text; nm text;
begin
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at) values
    (A, '00000000-0000-0000-0000-000000000000','authenticated','authenticated','hf-a@example.invalid','{}', now(), now()),
    (P, '00000000-0000-0000-0000-000000000000','authenticated','authenticated','hf-p@example.invalid','{}', now(), now());
  insert into public.profiles (id, role, full_name, sport) values (A,'coach','Asst HF','baseball'), (P,'pitcher','Pat HF','baseball');
  insert into public.team_coaches (team_id, coach_id, role, invited_by) values (T, A, 'assistant', H);
  insert into public.pitcher_teams (pitcher_id, team_id) values (P, T);
  select count(*) into n_sess from public.sessions where team_id = T;
  select level, name into lvl, nm from public.teams where id = T;
  out := 'Staging Knights has ' || n_sess || ' sessions';

  -- E2: the head coach can't write teams directly
  perform set_config('request.jwt.claims', json_build_object('sub', H, 'role','authenticated')::text, true); execute 'set local role authenticated';
  begin delete from public.teams where id = T; get diagnostics c = row_count; out := out || ' | head coach direct DELETE team: ' || c || ' rows (BAD if >0)';
  exception when others then out := out || ' | head coach direct DELETE team: ' || sqlerrm; end;
  begin update public.teams set name = 'x' where id = T; get diagnostics c = row_count; out := out || ', direct rename to 1 char: ' || c || ' rows (BAD)';
  exception when others then out := out || ', direct rename: ' || sqlerrm; end;
  begin update public.teams set coach_id = A where id = T; out := out || ', direct coach_id change: ALLOWED (BAD)';
  exception when others then out := out || ', direct coach_id change: ' || sqlerrm; end;
  begin update public.teams set invite_token = 'abc' where id = T; out := out || ', direct invite_token change: ALLOWED (BAD)';
  exception when others then out := out || ', direct invite_token change: ' || sqlerrm; end;
  begin insert into public.teams (coach_id, name) values (H, 'Sneaky'); out := out || ', direct INSERT team: ALLOWED (BAD)';
  exception when others then out := out || ', direct INSERT team: ' || sqlerrm; end;
  select count(*) into c from public.teams where id = T; out := out || ' | head still reads own team: ' || c || ' row';
  -- Level of play through the new function
  perform public.set_team_level(T, case when lvl = 'college' then 'high_school' else 'college' end);
  out := out || ' | set_team_level as head: ' || (select level from public.teams where id = T);
  begin perform public.set_team_level(T, 'high_school_up'); out := out || ', softball level on a baseball team: ALLOWED (BAD)';
  exception when others then out := out || ', softball level on a baseball team: ' || replace(sqlerrm, '"', ''); end;
  perform public.rename_team(T, nm || ' 2'); out := out || ' | rename_team still works: ' || (select name from public.teams where id = T);
  perform public.rename_team(T, nm);
  perform public.set_team_level(T, lvl);
  execute 'reset role';

  perform set_config('request.jwt.claims', json_build_object('sub', A, 'role','authenticated')::text, true); execute 'set local role authenticated';
  begin perform public.set_team_level(T, 'college'); out := out || ' | set_team_level as assistant: ALLOWED (BAD)';
  exception when others then out := out || ' | set_team_level as assistant: ' || sqlerrm; end;
  select count(*) into c from public.teams where id = T; out := out || ', assistant reads team: ' || c;
  begin delete from public.teams where id = T; get diagnostics c = row_count; out := out || ', assistant direct DELETE: ' || c || ' rows';
  exception when others then out := out || ', assistant direct DELETE: ' || sqlerrm; end;
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role','authenticated')::text, true); execute 'set local role authenticated';
  begin perform public.set_team_level(T, 'college'); out := out || ' | set_team_level as pitcher: ALLOWED (BAD)';
  exception when others then out := out || ' | set_team_level as pitcher: ' || sqlerrm; end;
  select count(*) into c from public.teams where id = T; out := out || ', pitcher reads team: ' || c;
  execute 'reset role';
  execute 'set local role anon';
  begin perform public.set_team_level(T, 'college'); out := out || ', anon: ALLOWED (BAD)'; exception when others then out := out || ', anon set_team_level: refused'; end;
  execute 'reset role';

  -- E1: the database refuses to delete a team that has sessions -- even as the table owner
  begin delete from public.teams where id = T; out := out || ' | owner deletes team with sessions: ALLOWED (BAD)';
  exception when others then out := out || ' | owner deletes team with ' || n_sess || ' sessions: ' || replace(sqlerrm, '"', ''); end;
  out := out || ', sessions still there: ' || (select count(*) from public.sessions where team_id = T);
  -- a team with no sessions still deletes (memberships cascade)
  E := public._create_team_with_head(H, 'Empty HF Team');
  delete from public.teams where id = E; get diagnostics c = row_count;
  out := out || ' | empty team (no sessions, no roster) deleted: ' || c || ' row, coach rows left: ' || (select count(*) from public.team_coaches where team_id = E);
  -- (A team with a rostered pitcher can't be deleted at all today: the G3 departure trigger
  --  logs a departure that references the team being deleted. P1-09's delete_team handles it.)
  -- create_team still works for a coach (SECURITY DEFINER)
  perform set_config('request.jwt.claims', json_build_object('sub', H, 'role','authenticated')::text, true); execute 'set local role authenticated';
  begin E := public.create_team('New HF Team', H); out := out || ' | create_team as coach: ok';
  exception when others then out := out || ' | create_team as coach: ' || sqlerrm; end;
  execute 'reset role';

  out := out || ' | FK now: ' || (select pg_get_constraintdef(oid) from pg_constraint where conname = 'sessions_team_id_fkey')
             || ' | policies: ' || (select count(*) from pg_policies where schemaname = 'public');
  raise exception 'RESULTS(rolled back):%', out;
end $$;
