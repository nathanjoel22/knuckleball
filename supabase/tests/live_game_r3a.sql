-- Live Game R3 Stage A (Oct 21 2026) -- staging; everything rolled back (the block ends by raising its results).
-- Checks: a negative pitch_count_adjust is refused by the CHECK; sync_session saves an old app's negative adjustment
-- as 0 and a +2 as 2; an old-shaped payload that still carries hbp_swing saves, and the column stays NULL.
do $$
declare
  T uuid := '18fa6885-c85e-4c2a-88e9-e301c6f93723';   -- Staging Knights
  P uuid := '14345e15-dca3-4bc7-8126-2639b6504aad';   -- Staging Pitcher
  G uuid := gen_random_uuid(); G2 uuid := gen_random_uuid(); D uuid := gen_random_uuid(); X uuid := gen_random_uuid();
  r jsonb; out text := '';
begin
  -- 1. the CHECK, straight on the table (as the owner, so only the constraint can refuse it)
  begin
    insert into public.sessions (id, pitcher_id, team_id, logged_by, started_at, kind, pitch_count_adjust)
    values (D, P, T, P, now() - interval '50 minutes', 'game', -10);
    out := out || 'negative insert=SAVED?';
  exception when check_violation then out := out || 'negative insert=refused'; end;

  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role', 'authenticated')::text, true);
  set local role authenticated;
  -- 2. an old app's queued game with -3 (its -K / -B), and a pitch that still carries hbp_swing
  r := public.sync_session(
    jsonb_build_object('id', G, 'pitcher_id', P, 'team_id', T, 'logged_by', P, 'started_at', now() - interval '40 minutes',
                       'ended_at', now() - interval '35 minutes', 'kind', 'game', 'pitch_count_adjust', -3),
    jsonb_build_array(jsonb_build_object('id', X, 'type', 'Slider', 'kind', 'game', 'ts', now() - interval '39 minutes',
      'actual_row', 2, 'actual_col', 2, 'result', 'strike_swinging', 'inning', 1, 'outs_before', 0, 'balls_before', 0,
      'strikes_before', 0, 'at_bat_index', 1, 'hbp_swing', true)),
    '[]'::jsonb);
  out := out || format(' | old app -3: %s, saved adjust=%s, pitches=%s, hbp_swing=%s', r ->> 'status',
    (select pitch_count_adjust from public.sessions where id = G), r ->> 'pitches',
    coalesce((select hbp_swing::text from public.pitches where id = X), 'NULL'));
  -- 3. +K / +B still count
  r := public.sync_session(
    jsonb_build_object('id', G2, 'pitcher_id', P, 'team_id', T, 'logged_by', P, 'started_at', now() - interval '30 minutes',
                       'ended_at', now() - interval '25 minutes', 'kind', 'game', 'pitch_count_adjust', 2),
    '[]'::jsonb, '[]'::jsonb);
  out := out || format(' | +2: %s, saved adjust=%s', r ->> 'status', (select pitch_count_adjust from public.sessions where id = G2));
  raise exception 'RESULT %', out;
end $$;
