-- U14 database checks (staging; everything rolled back -- the block ends by raising its results).
do $$
declare
  T uuid := '18fa6885-c85e-4c2a-88e9-e301c6f93723';   -- Staging Knights
  H uuid := '84c1d3f1-0509-49b2-8b3f-30aae98dcbf3';   -- its head coach
  P uuid := '14345e15-dca3-4bc7-8126-2639b6504aad';   -- Staging Pitcher
  SID uuid := gen_random_uuid(); r jsonb; out text := ''; n int; b boolean; acc_before int; acc_after int;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role', 'authenticated')::text, true);
  set local role authenticated;
  -- 1. zone cap: 4 cells saved, 5 refused (as the pitcher, through RLS, as the painter writes)
  delete from public.accuracy_zones where pitcher_id = P;
  insert into public.accuracy_zones (pitcher_id, pitch_type, batter_side, cells) values (P, 'Slider', 'R', array['1-1','1-2','2-1','2-2']);
  out := out || '4 cells=saved';
  begin
    insert into public.accuracy_zones (pitcher_id, pitch_type, batter_side, cells) values (P, 'Slider', 'L', array['1-1','1-2','2-1','2-2','3-3']);
    out := out || ' | 5 cells=SAVED (wrong)';
  exception when check_violation then out := out || ' | 5 cells=refused'; end;
  begin
    update public.accuracy_zones set cells = array['0-0','0-1','0-2','0-3','0-4'] where pitcher_id = P and pitch_type = 'Slider' and batter_side = 'R';
    out := out || ' | update to 5=SAVED (wrong)';
  exception when check_violation then out := out || ' | update to 5=refused'; end;
  -- leaderboard before (as the head coach)
  perform set_config('request.jwt.claims', json_build_object('sub', H, 'role', 'authenticated')::text, true);
  select (x ->> 'value')::int into acc_before from jsonb_array_elements(public.get_team_leaderboard(T, 'all') -> 'accuracy') x where x ->> 'name' = 'Staging Pitcher';
  -- 2. a U14 pen through sync_session, as the pitcher: target 2-2 every time; exact / ra / miss / target-is-marked
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role', 'authenticated')::text, true);
  r := public.sync_session(
    jsonb_build_object('id', SID, 'pitcher_id', P, 'team_id', T, 'logged_by', P, 'started_at', now() - interval '20 minutes',
                       'ended_at', now() - interval '10 minutes', 'kind', 'bullpen', 'ra_on', true),
    jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'type', 'Slider', 'batter_side', 'R', 'ts', now() - interval '19 minutes', 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2, 'accuracy_hit_kind', 'exact', 'accuracy_zone_cells', array['1-1','1-2','2-1','2-2']),
      jsonb_build_object('id', gen_random_uuid(), 'type', 'Slider', 'batter_side', 'R', 'ts', now() - interval '18 minutes', 'target_row', 2, 'target_col', 2, 'actual_row', 1, 'actual_col', 1, 'accuracy_hit_kind', 'ra', 'accuracy_zone_cells', array['1-1','1-2','2-1','2-2']),
      jsonb_build_object('id', gen_random_uuid(), 'type', 'Slider', 'batter_side', 'R', 'ts', now() - interval '17 minutes', 'target_row', 2, 'target_col', 2, 'actual_row', 4, 'actual_col', 4, 'accuracy_hit_kind', 'miss', 'accuracy_zone_cells', array['1-1','1-2','2-1','2-2'])),
    '[]'::jsonb);
  select s.ra_on into b from public.sessions s where s.id = SID;
  select count(*) into n from public.pitches where session_id = SID and accuracy_hit_kind is not null;
  out := out || format(' | sync %s, ra_on=%s, hit kinds stored=%s', coalesce(r ->> 'status', r ->> 'error', r::text), b, n);
  out := out || format(' (%s)', (select string_agg(accuracy_hit_kind, '/' order by ts) from public.pitches where session_id = SID));
  -- 3. an 'ra' hit with no cells is refused; a kind outside the three is refused
  begin
    perform public.sync_session(jsonb_build_object('id', gen_random_uuid(), 'pitcher_id', P, 'team_id', T, 'logged_by', P, 'started_at', now() - interval '9 minutes', 'ended_at', now() - interval '8 minutes', 'kind', 'bullpen', 'ra_on', true),
      jsonb_build_array(jsonb_build_object('id', gen_random_uuid(), 'type', 'Slider', 'batter_side', 'R', 'target_row', 2, 'target_col', 2, 'actual_row', 1, 'actual_col', 1, 'accuracy_hit_kind', 'ra')), '[]'::jsonb);
    out := out || ' | ra without cells=SAVED (wrong)';
  exception when check_violation then out := out || ' | ra without cells=refused'; end;
  begin
    perform public.sync_session(jsonb_build_object('id', gen_random_uuid(), 'pitcher_id', P, 'team_id', T, 'logged_by', P, 'started_at', now() - interval '7 minutes', 'ended_at', now() - interval '6 minutes', 'kind', 'bullpen'),
      jsonb_build_array(jsonb_build_object('id', gen_random_uuid(), 'type', 'Slider', 'target_row', 2, 'target_col', 2, 'actual_row', 1, 'actual_col', 1, 'accuracy_hit_kind', 'close')), '[]'::jsonb);
    out := out || ' | kind close=SAVED (wrong)';
  exception when check_violation then out := out || ' | kind close=refused'; end;
  -- 4. ra_on is locked once saved
  begin
    update public.sessions set ra_on = false where id = SID;
    out := out || format(' | change ra_on=SAVED? now %s', (select ra_on from public.sessions where id = SID));
  exception when others then out := out || ' | change ra_on=refused (' || sqlerrm || ')'; end;
  -- 5. leaderboard: the U14 pen adds 3 pitches, 2 accurate (exact + ra)
  perform set_config('request.jwt.claims', json_build_object('sub', H, 'role', 'authenticated')::text, true);
  select (x ->> 'value')::int, (x ->> 'pitch_count')::int into acc_after, n from jsonb_array_elements(public.get_team_leaderboard(T, 'all') -> 'accuracy') x where x ->> 'name' = 'Staging Pitcher';
  out := out || format(' | leaderboard acc %s%% -> %s%% over %s pitches', acc_before, acc_after, n);
  raise exception 'RESULT %', out;
end $$;
