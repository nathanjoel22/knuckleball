-- Live Game pitch count and runs (Oct 19 2026) -- staging; everything rolled back (the block ends by raising its results).
do $$
declare
  T uuid := '18fa6885-c85e-4c2a-88e9-e301c6f93723';   -- Staging Knights
  P uuid := '14345e15-dca3-4bc7-8126-2639b6504aad';   -- Staging Pitcher
  G uuid := gen_random_uuid(); G2 uuid := gen_random_uuid(); B uuid := gen_random_uuid();
  r jsonb; sm jsonb; out text := ''; n int; w_before int; w_after int;
  pitch jsonb := '{}'::jsonb;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select d7_game into w_before from public.pitcher_workload(array[P]);
  -- 1. a game: 3 pitches (a single scoring one, a homer scoring two, a ball), a balk scoring one, adjustment +2
  r := public.sync_session(
    jsonb_build_object('id', G, 'pitcher_id', P, 'team_id', T, 'logged_by', P, 'started_at', now() - interval '30 minutes',
                       'ended_at', now() - interval '20 minutes', 'kind', 'game', 'pitch_count_adjust', 2),
    jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'type', 'Slider', 'kind', 'game', 'ts', now() - interval '29 minutes', 'actual_row', 2, 'actual_col', 2, 'result', 'in_play', 'in_play_outcome', 'hit', 'inning', 1, 'outs_before', 0, 'balls_before', 0, 'strikes_before', 0, 'at_bat_index', 1, 'runs_scored', 1),
      jsonb_build_object('id', gen_random_uuid(), 'type', 'Slider', 'kind', 'game', 'ts', now() - interval '28 minutes', 'actual_row', 2, 'actual_col', 2, 'result', 'in_play', 'in_play_outcome', 'hit', 'hit_type', 'HR', 'inning', 1, 'outs_before', 0, 'balls_before', 0, 'strikes_before', 0, 'at_bat_index', 2, 'runs_scored', 2),
      jsonb_build_object('id', gen_random_uuid(), 'type', 'Slider', 'kind', 'game', 'ts', now() - interval '27 minutes', 'actual_row', 0, 'actual_col', 0, 'result', 'ball', 'inning', 1, 'outs_before', 0, 'balls_before', 0, 'strikes_before', 0, 'at_bat_index', 3, 'runs_scored', 0)),
    jsonb_build_array(jsonb_build_object('id', gen_random_uuid(), 'event_type', 'balk', 'at_bat_index', 3, 'runners_before', 4, 'runs_scored', 1, 'seq', 9, 'inning_before', 1, 'balls_before', 1, 'strikes_before', 0, 'outs_before', 0)));
  sm := public.compute_game_summary(G);
  out := out || format('game %s: adjust=%s pitches=%s pitch_count=%s runs=%s strike_pct=%s', r ->> 'status',
    (select pitch_count_adjust from public.sessions where id = G), sm ->> 'pitches', sm ->> 'pitch_count', sm ->> 'runs', sm ->> 'strike_pct');
  -- 2. workload counts the adjustment (3 pitches + 2)
  select d7_game into w_after from public.pitcher_workload(array[P]);
  out := out || format(' | workload d7 game %s -> %s', w_before, w_after);
  -- 3. locked once saved
  begin
    update public.sessions set pitch_count_adjust = 9 where id = G;
    out := out || format(' | change adjust=SAVED? now %s', (select pitch_count_adjust from public.sessions where id = G));
  exception when others then out := out || ' | change adjust=refused'; end;
  -- 4. a game saved before runs were tracked (runs_scored NULL everywhere): runs is null; a big minus floors at 0
  perform public.sync_session(
    jsonb_build_object('id', G2, 'pitcher_id', P, 'team_id', T, 'logged_by', P, 'started_at', now() - interval '19 minutes',
                       'ended_at', now() - interval '18 minutes', 'kind', 'game', 'pitch_count_adjust', -10),
    jsonb_build_array(jsonb_build_object('id', gen_random_uuid(), 'type', 'Slider', 'kind', 'game', 'ts', now() - interval '19 minutes', 'actual_row', 2, 'actual_col', 2, 'result', 'ball', 'inning', 1, 'outs_before', 0, 'balls_before', 0, 'strikes_before', 0, 'at_bat_index', 1)),
    '[]'::jsonb);
  sm := public.compute_game_summary(G2);
  out := out || format(' | old-style game: runs=%s pitch_count=%s', coalesce(sm ->> 'runs', 'null'), sm ->> 'pitch_count');
  -- 5. a bullpen never carries an adjustment (sync_session saves 0)
  perform public.sync_session(
    jsonb_build_object('id', B, 'pitcher_id', P, 'team_id', T, 'logged_by', P, 'started_at', now() - interval '17 minutes',
                       'ended_at', now() - interval '16 minutes', 'kind', 'bullpen', 'pitch_count_adjust', 5),
    jsonb_build_array(jsonb_build_object('id', gen_random_uuid(), 'type', 'Slider', 'ts', now() - interval '17 minutes', 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2)),
    '[]'::jsonb);
  out := out || format(' | bullpen adjust stored=%s', (select pitch_count_adjust from public.sessions where id = B));
  raise exception 'RESULT %', out;
end $$;
