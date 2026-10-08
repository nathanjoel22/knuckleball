-- G5 migration acceptance (database side). Rolled back. Run on staging once
-- 20261007000000_g5_spray_box.sql is applied:
--   supabase db query --linked --project-ref <staging> -f supabase/tests/g5_migration_acceptance.sql
do $$
declare
  T  uuid := '18fa6885-c85e-4c2a-88e9-e301c6f93723';   -- Staging Knights (baseball)
  P  uuid := 'aaaaaaaa-0000-4000-8000-0000000000f5';
  S1 uuid := gen_random_uuid(); S2 uuid := gen_random_uuid();
  pj jsonb; r jsonb; out text := ''; sess jsonb;
begin
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at) values
    (P, '00000000-0000-0000-0000-000000000000','authenticated','authenticated','g5-p@example.invalid','{}', now(), now());
  insert into public.profiles (id, role, full_name, sport) values (P,'pitcher','Pat G5','baseball');
  insert into public.pitcher_teams (pitcher_id, team_id) values (P, T);

  -- a game: a ball, a single to box 22 with a runner left on 1st, a groundout double play in box 19
  pj := jsonb_build_array(
    jsonb_build_object('id', gen_random_uuid(), 'type','fb', 'kind','game', 'result','ball', 'actual_row',1, 'actual_col',1,
      'inning',1, 'at_bat_index',0, 'balls_before',0, 'strikes_before',0, 'outs_before',0, 'runners_before',0),
    jsonb_build_object('id', gen_random_uuid(), 'type','fb', 'kind','game', 'result','in_play', 'in_play_outcome','hit', 'bb_type','line',
      'actual_row',2, 'actual_col',2, 'inning',1, 'at_bat_index',0, 'balls_before',1, 'strikes_before',0, 'outs_before',0,
      'runners_before',0, 'spray_box',22, 'spray_field','OF', 'runners_after',1, 'outs_on_play',0),
    jsonb_build_object('id', gen_random_uuid(), 'type','cb', 'kind','game', 'result','in_play', 'in_play_outcome','out', 'bb_type','ground',
      'actual_row',3, 'actual_col',2, 'inning',1, 'at_bat_index',1, 'balls_before',0, 'strikes_before',0, 'outs_before',0,
      'runners_before',1, 'spray_box',25, 'spray_field','IF', 'runners_after',0, 'outs_on_play',2));
  sess := jsonb_build_object('id', S1, 'pitcher_id', P, 'team_id', T, 'logged_by', P, 'started_at', now() - interval '1 hour',
          'ended_at', now(), 'kind', 'game', 'opponent', 'Rivals', 'game_final_inning', 1, 'game_outs_recorded', 2);
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.sync_session(sess, pj, '[]'::jsonb);
  execute 'reset role';
  out := '1. game via sync_session: ' || r::text || ' -> stored (result, spray_box, spray_field, runners_after, outs_on_play): ' ||
    (select string_agg(concat_ws('/', result, coalesce(spray_box::text,'-'), coalesce(spray_field,'-'), coalesce(runners_after::text,'-'), coalesce(outs_on_play::text,'-')), ' ; ' order by ts, id)
       from (select * from public.pitches where session_id = S1) x);

  -- 2. a bullpen pitch with either column filled is refused
  begin
    insert into public.sessions (id, pitcher_id, team_id, logged_by, started_at, kind) values (S2, P, T, P, now(), 'bullpen');
    insert into public.pitches (id, session_id, type, kind, actual_row, actual_col, spray_box) values (gen_random_uuid(), S2, 'fb', 'bullpen', 2, 2, 5);
    out := out || ' | 2. bullpen with spray_box: ALLOWED (BAD)';
  exception when others then out := out || ' | 2. bullpen with spray_box: ' || sqlerrm; end;
  begin
    insert into public.pitches (id, session_id, type, kind, actual_row, actual_col, runners_after) values (gen_random_uuid(), S2, 'fb', 'bullpen', 2, 2, 1);
    out := out || ', with runners_after: ALLOWED (BAD)';
  exception when others then out := out || ', with runners_after: ' || sqlerrm; end;

  -- 3. out-of-range values are refused
  begin insert into public.pitches (id, session_id, type, kind, actual_row, actual_col, spray_box) values (gen_random_uuid(), S2, 'fb', 'game', 2, 2, 0);
    out := out || ' | 3. box 0: ALLOWED (BAD)';
  exception when others then out := out || ' | 3. box 0: ' || sqlerrm; end;
  begin insert into public.pitches (id, session_id, type, kind, actual_row, actual_col, spray_box) values (gen_random_uuid(), S2, 'fb', 'game', 2, 2, 26);
    out := out || ', box 26: ALLOWED (BAD)';
  exception when others then out := out || ', box 26: ' || sqlerrm; end;
  begin insert into public.pitches (id, session_id, type, kind, actual_row, actual_col, runners_after) values (gen_random_uuid(), S2, 'fb', 'game', 2, 2, 8);
    out := out || ', bases 8: ALLOWED (BAD)';
  exception when others then out := out || ', bases 8: ' || sqlerrm; end;

  -- 3b. spray_field: only IF / OF, and never on a bullpen pitch
  begin insert into public.pitches (id, session_id, type, kind, actual_row, actual_col, spray_field) values (gen_random_uuid(), S2, 'fb', 'game', 2, 2, 'XX');
    out := out || ' | 3b. field XX: ALLOWED (BAD)';
  exception when others then out := out || ' | 3b. field XX: ' || sqlerrm; end;
  begin insert into public.pitches (id, session_id, type, kind, actual_row, actual_col, spray_field) values (gen_random_uuid(), S2, 'fb', 'bullpen', 2, 2, 'IF');
    out := out || ', bullpen with IF: ALLOWED (BAD)';
  exception when others then out := out || ', bullpen with IF: ' || sqlerrm; end;
  -- 4. policies unchanged
  out := out || ' | 4. policies: ' || (select count(*) from pg_policies where schemaname = 'public');
  raise exception 'RESULTS(rolled back):%', out;
end $$;
