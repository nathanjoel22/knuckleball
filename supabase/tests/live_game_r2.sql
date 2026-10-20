-- Live Game Release 2 (Oct 20 2026) -- staging; everything rolled back (the block ends by raising its results).
-- A reliever's game: 2 inherited runners (1 scores), a walk charged to the previous pitcher, an unearned run, fielders
-- and a sacrifice fly. compute_game_summary: runs charged to him, ER, IR / IRS, BB without the charged walk.
do $$
declare
  T uuid := '18fa6885-c85e-4c2a-88e9-e301c6f93723';   -- Staging Knights
  P uuid := '14345e15-dca3-4bc7-8126-2639b6504aad';   -- Staging Pitcher
  G uuid := gen_random_uuid(); O uuid := gen_random_uuid();
  sm jsonb; out text := '';
  base jsonb := jsonb_build_object('type', 'Slider', 'kind', 'game', 'actual_row', 2, 'actual_col', 2, 'inning', 4, 'outs_before', 1);
begin
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role', 'authenticated')::text, true);
  set local role authenticated;
  perform public.sync_session(
    jsonb_build_object('id', G, 'pitcher_id', P, 'team_id', T, 'logged_by', P, 'started_at', now() - interval '30 minutes',
                       'ended_at', now() - interval '20 minutes', 'kind', 'game', 'inherited_runners', 2, 'game_outs_recorded', 2),
    jsonb_build_array(
      -- ball four on the 3-1 count he inherited: the previous pitcher's walk
      base || jsonb_build_object('id', gen_random_uuid(), 'ts', now() - interval '29 minutes', 'result', 'ball', 'balls_before', 3, 'strikes_before', 1, 'at_bat_index', 1, 'batter_to', 1, 'charged_prev', true, 'runs_scored', 0, 'unearned_runs', 0, 'inherited_runs', 0),
      -- sac fly 8: an inherited runner scores
      base || jsonb_build_object('id', gen_random_uuid(), 'ts', now() - interval '28 minutes', 'result', 'in_play', 'in_play_outcome', 'out', 'bb_type', 'fly', 'balls_before', 0, 'strikes_before', 0, 'at_bat_index', 2,
        'fielder', 'CF', 'sacrifice', 'SF', 'batter_to', 0, 'runner_advances', '[{"from":3,"to":4,"how":"tagged_up"}]'::jsonb, 'runs_scored', 1, 'unearned_runs', 0, 'inherited_runs', 1, 'outs_on_play', 1),
      -- error 6 (E6): his own unearned run scores
      base || jsonb_build_object('id', gen_random_uuid(), 'ts', now() - interval '27 minutes', 'result', 'in_play', 'in_play_outcome', 'error', 'bb_type', 'ground', 'balls_before', 0, 'strikes_before', 0, 'at_bat_index', 3,
        'fielder', 'SS', 'fielders', '3', 'batter_to', 1, 'runs_scored', 1, 'unearned_runs', 1, 'inherited_runs', 0),
      -- a 6-3 ground out
      base || jsonb_build_object('id', gen_random_uuid(), 'ts', now() - interval '26 minutes', 'result', 'in_play', 'in_play_outcome', 'out', 'bb_type', 'ground', 'balls_before', 0, 'strikes_before', 0, 'at_bat_index', 4,
        'fielder', 'SS', 'fielders', '1B', 'batter_to', 0, 'runs_scored', 0, 'unearned_runs', 0, 'inherited_runs', 0, 'outs_on_play', 1)),
    -- a wild pitch scores a run (earned) between pitches
    jsonb_build_array(jsonb_build_object('id', gen_random_uuid(), 'event_type', 'wild_pitch', 'at_bat_index', 4, 'runners_before', 4, 'runs_scored', 1, 'unearned_runs', 0, 'inherited_runs', 0,
      'runner_advances', '[{"from":3,"to":4}]'::jsonb, 'seq', 9, 'inning_before', 4, 'balls_before', 0, 'strikes_before', 0, 'outs_before', 1)));
  sm := public.compute_game_summary(G);
  out := out || format('reliever: runs=%s er=%s ir=%s irs=%s bb=%s bb_charged_prev=%s', sm ->> 'runs', sm ->> 'er', sm ->> 'ir', sm ->> 'irs', sm ->> 'bb', sm ->> 'bb_charged_prev');
  out := out || format(' | stored: inherited_runners=%s sf=%s fielders=%s', (select inherited_runners from public.sessions where id = G),
    (select count(*) from public.pitches where session_id = G and sacrifice = 'SF'), (select string_agg(fielder || coalesce('-' || fielders, ''), ',' order by ts) from public.pitches where session_id = G and fielder is not null));
  begin
    update public.sessions set inherited_runners = 0 where id = G;
    out := out || ' | change IR=SAVED?';
  exception when others then out := out || ' | change IR=refused'; end;
  -- a game from before Release 2 (no unearned / inherited data): er / ir / irs null, runs unchanged
  perform public.sync_session(
    jsonb_build_object('id', O, 'pitcher_id', P, 'team_id', T, 'logged_by', P, 'started_at', now() - interval '19 minutes',
                       'ended_at', now() - interval '18 minutes', 'kind', 'game'),
    jsonb_build_array(base || jsonb_build_object('id', gen_random_uuid(), 'ts', now() - interval '19 minutes', 'result', 'in_play', 'in_play_outcome', 'hit', 'balls_before', 0, 'strikes_before', 0, 'at_bat_index', 1, 'runs_scored', 2)),
    '[]'::jsonb);
  sm := public.compute_game_summary(O);
  out := out || format(' | old game: runs=%s er=%s ir=%s irs=%s', sm ->> 'runs', coalesce(sm ->> 'er', 'null'), coalesce(sm ->> 'ir', 'null'), coalesce(sm ->> 'irs', 'null'));
  raise exception 'RESULT %', out;
end $$;
