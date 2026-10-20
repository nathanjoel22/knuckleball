-- Live Game Release 1 (Oct 20 2026) -- staging; everything rolled back (the block ends by raising its results).
-- Checks: hbp_swing is saved by sync_session; a two-strike foul bunt counts as a K (and a strikeout out); hit types,
-- FC, batter_to and runner_advances are saved as sent; hbp_swing is refused anywhere but a game's swinging strike.
do $$
declare
  T uuid := '18fa6885-c85e-4c2a-88e9-e301c6f93723';   -- Staging Knights
  P uuid := '14345e15-dca3-4bc7-8126-2639b6504aad';   -- Staging Pitcher
  G uuid := gen_random_uuid(); G2 uuid := gen_random_uuid(); B uuid := gen_random_uuid();
  r jsonb; sm jsonb; out text := '';
  base jsonb := jsonb_build_object('type', 'Slider', 'kind', 'game', 'actual_row', 2, 'actual_col', 2, 'inning', 1, 'outs_before', 0, 'balls_before', 0);
begin
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role', 'authenticated')::text, true);
  set local role authenticated;
  -- 1. a game: a swing that hit the batter (strike 1), a two-strike foul bunt (K), a double with a runner forced to 3B,
  --    an FC (runner on 1B out, batter to 1B)
  r := public.sync_session(
    jsonb_build_object('id', G, 'pitcher_id', P, 'team_id', T, 'logged_by', P, 'started_at', now() - interval '30 minutes',
                       'ended_at', now() - interval '20 minutes', 'kind', 'game', 'game_final_inning', 1, 'game_outs_recorded', 2),
    jsonb_build_array(
      base || jsonb_build_object('id', gen_random_uuid(), 'ts', now() - interval '29 minutes', 'result', 'strike_swinging', 'strikes_before', 0, 'at_bat_index', 1, 'hbp_swing', true),
      base || jsonb_build_object('id', gen_random_uuid(), 'ts', now() - interval '28 minutes', 'result', 'foul', 'bb_type', 'bunt', 'strikes_before', 2, 'at_bat_index', 1, 'batter_to', 0, 'outs_on_play', 1),
      base || jsonb_build_object('id', gen_random_uuid(), 'ts', now() - interval '27 minutes', 'result', 'in_play', 'in_play_outcome', 'hit', 'hit_type', '2B', 'bb_type', 'line', 'strikes_before', 0, 'at_bat_index', 2,
        'runners_before', 1, 'batter_to', 2, 'runner_advances', '[{"from":1,"to":3,"how":"forced"}]'::jsonb, 'runners_after', 6, 'spray_box', 20, 'spray_field', 'OF'),
      base || jsonb_build_object('id', gen_random_uuid(), 'ts', now() - interval '26 minutes', 'result', 'in_play', 'in_play_outcome', 'fc', 'bb_type', 'ground', 'strikes_before', 0, 'at_bat_index', 3,
        'runners_before', 1, 'batter_to', 1, 'runner_advances', '[{"from":1,"to":0,"how":"out"}]'::jsonb, 'outs_on_play', 1, 'runners_after', 1, 'spray_box', 18, 'spray_field', 'IF')),
    '[]'::jsonb);
  sm := public.compute_game_summary(G);
  out := out || format('game %s: k=%s h=%s xbh=%s outs_in_play=%s', r ->> 'status', sm ->> 'k', sm ->> 'h', sm ->> 'xbh', sm ->> 'outs_in_play');
  out := out || format(' | hbp_swing saved=%s', (select count(*) from public.pitches where session_id = G and hbp_swing));
  out := out || format(' | double: hit_type=%s batter_to=%s advances=%s', (select hit_type from public.pitches where session_id = G and in_play_outcome = 'hit'),
    (select batter_to from public.pitches where session_id = G and in_play_outcome = 'hit'), (select runner_advances::text from public.pitches where session_id = G and in_play_outcome = 'hit'));
  out := out || format(' | fc: outcome=%s batter_to=%s', (select in_play_outcome from public.pitches where session_id = G and in_play_outcome = 'fc'),
    (select batter_to from public.pitches where session_id = G and in_play_outcome = 'fc'));
  -- 2. with no outs counter, the strikeout outs include the foul bunt (derived: 1 K out + 0 in play)
  perform public.sync_session(
    jsonb_build_object('id', G2, 'pitcher_id', P, 'team_id', T, 'logged_by', P, 'started_at', now() - interval '19 minutes',
                       'ended_at', now() - interval '18 minutes', 'kind', 'game'),
    jsonb_build_array(base || jsonb_build_object('id', gen_random_uuid(), 'ts', now() - interval '19 minutes', 'result', 'foul', 'bb_type', 'bunt', 'strikes_before', 2, 'at_bat_index', 1)),
    '[]'::jsonb);
  sm := public.compute_game_summary(G2);
  out := out || format(' | no counter: k=%s outs_recorded=%s (%s)', sm ->> 'k', sm ->> 'outs_recorded', sm ->> 'outs_source');
  -- 3. hbp_swing anywhere else is refused (the whole save fails)
  begin
    perform public.sync_session(
      jsonb_build_object('id', B, 'pitcher_id', P, 'team_id', T, 'logged_by', P, 'started_at', now() - interval '17 minutes',
                         'ended_at', now() - interval '16 minutes', 'kind', 'game'),
      jsonb_build_array(base || jsonb_build_object('id', gen_random_uuid(), 'ts', now() - interval '17 minutes', 'result', 'ball', 'strikes_before', 0, 'at_bat_index', 1, 'hbp_swing', true)),
      '[]'::jsonb);
    out := out || format(' | hbp_swing on a ball=SAVED? %s', (select count(*) from public.pitches where session_id = B));
  exception when check_violation then out := out || ' | hbp_swing on a ball=refused'; end;
  raise exception 'RESULT %', out;
end $$;
