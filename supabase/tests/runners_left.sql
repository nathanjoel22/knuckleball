-- Runners left on base (Oct 21 2026) -- staging; everything rolled back (the block ends by raising its results).
do $$
declare
  T uuid := '18fa6885-c85e-4c2a-88e9-e301c6f93723';   -- Staging Knights
  P uuid := '14345e15-dca3-4bc7-8126-2639b6504aad';   -- Staging Pitcher
  G uuid := gen_random_uuid(); B uuid := gen_random_uuid(); sm jsonb; out text := '';
begin
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role', 'authenticated')::text, true);
  set local role authenticated;
  perform public.sync_session(
    jsonb_build_object('id', G, 'pitcher_id', P, 'team_id', T, 'logged_by', P, 'started_at', now() - interval '30 minutes',
                       'ended_at', now() - interval '20 minutes', 'kind', 'game', 'runners_left', 2, 'inherited_runners', 2),
    jsonb_build_array(jsonb_build_object('id', gen_random_uuid(), 'type', 'Slider', 'kind', 'game', 'ts', now() - interval '29 minutes', 'actual_row', 2, 'actual_col', 2,
      'result', 'in_play', 'in_play_outcome', 'hit', 'hit_type', '1B', 'inning', 5, 'outs_before', 0, 'balls_before', 0, 'strikes_before', 0, 'at_bat_index', 1,
      'runs_scored', 1, 'inherited_runs', 1, 'unearned_runs', 0)), '[]'::jsonb);
  sm := public.compute_game_summary(G);
  out := format('game: runners_left=%s runs=%s ir=%s irs=%s', sm ->> 'runners_left', sm ->> 'runs', sm ->> 'ir', sm ->> 'irs');
  begin update public.sessions set runners_left = 0 where id = G; out := out || ' | change=SAVED?';
  exception when others then out := out || ' | change=refused'; end;
  perform public.sync_session(
    jsonb_build_object('id', B, 'pitcher_id', P, 'team_id', T, 'logged_by', P, 'started_at', now() - interval '19 minutes',
                       'ended_at', now() - interval '18 minutes', 'kind', 'bullpen', 'runners_left', 2),
    jsonb_build_array(jsonb_build_object('id', gen_random_uuid(), 'type', 'Slider', 'ts', now() - interval '19 minutes', 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2)), '[]'::jsonb);
  out := out || format(' | bullpen stores=%s', coalesce((select runners_left::text from public.sessions where id = B), 'null'));
  raise exception 'RESULT %', out;
end $$;
