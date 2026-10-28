-- SC1 session_stats (Oct 28 2026) -- staging; rolled back (the block ends by raising its results).
-- Save -> row in the same call; who reads it; no client writes; delete -> row gone, tombstone stays; a game row with the
-- report's WP; R3 recompute when a game's line closes; save anyway when the stats fail.
do $$
declare
  T uuid := '18fa6885-c85e-4c2a-88e9-e301c6f93723';   -- Staging Knights
  P uuid := '14345e15-dca3-4bc7-8126-2639b6504aad';   -- Staging Pitcher (primary profile = login)
  C uuid; O uuid;                                      -- the head coach's login; another pitcher's login
  S1 uuid := gen_random_uuid(); S2 uuid := gen_random_uuid(); S3 uuid := gen_random_uuid();
  r jsonb; n int; out text := '';
  claims text;
begin
  select pr.account_id into C from public.team_coaches tc join public.profiles pr on pr.id = tc.coach_id
   where tc.team_id = T and tc.role = 'head';
  select pr.account_id into O from public.profiles pr
   where pr.role = 'pitcher' and pr.account_id <> P
     and not exists (select 1 from public.profiles q join public.team_coaches tc on tc.coach_id = q.id where q.account_id = pr.account_id)
   limit 1;

  -- 1. A pen saved by the pitcher: the row is there when sync_session returns (3 pitches: 2 strikes, 1 exact hit,
  --    velocities 80 / 84 / null).
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role', 'authenticated')::text, true);
  set local role authenticated;
  r := public.sync_session(
    jsonb_build_object('id', S1, 'pitcher_id', P, 'team_id', T, 'logged_by', P, 'started_at', now() - interval '9 minutes', 'ended_at', now() - interval '8 minutes', 'kind', 'bullpen'),
    jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'type', 'Slider', 'velo', 80, 'ts', now() - interval '9 minutes', 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2, 'batter_side', 'R'),
      jsonb_build_object('id', gen_random_uuid(), 'type', 'Slider', 'velo', 84, 'ts', now() - interval '9 minutes', 'target_row', 1, 'target_col', 1, 'actual_row', 3, 'actual_col', 3, 'batter_side', 'L'),
      jsonb_build_object('id', gen_random_uuid(), 'type', '4-Seam', 'ts', now() - interval '9 minutes', 'target_row', 2, 'target_col', 2, 'actual_row', 0, 'actual_col', 4)),
    '[]'::jsonb);
  select count(*) into n from public.session_stats where session_id = S1;
  out := format('1 save=%s row_seen_by_pitcher=%s', r ->> 'status', n);
  select format(' pitches=%s strikes=%s hits=%s velo=%s/%s max=%s slider_cells=%s', pitches, strikes, hits, velo_n, velo_sum, velo_max, by_type -> 'Slider' -> 'cells')
    into claims from public.session_stats where session_id = S1;
  out := out || claims;

  -- 2. No client writes, and the stats functions can't be called.
  begin insert into public.session_stats (session_id, sport, kind, started_at, pitches, pitch_count, strikes, hits, exact_hits, ra_hits, zone_total, zone_hits, velo_n, velo_sum, ttp_n, ttp_sum, by_type, by_side, cells, stats_version)
        values (gen_random_uuid(), 'baseball', 'bullpen', now(), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '{}', '{}', '{}', 1);
        out := out || ' | 2 insert=ALLOWED?'; exception when others then out := out || ' | 2 insert=refused'; end;
  begin update public.session_stats set hits = 99 where session_id = S1; get diagnostics n = row_count;
        out := out || format(' update=%s', case when n = 0 then 'refused' else 'ALLOWED?' end); exception when others then out := out || ' update=refused'; end;
  begin delete from public.session_stats where session_id = S1; get diagnostics n = row_count;
        out := out || format(' delete=%s', case when n = 0 then 'refused' else 'ALLOWED?' end); exception when others then out := out || ' delete=refused'; end;
  begin perform public.finalize_session_stats(S1); out := out || ' finalize()=ALLOWED?'; exception when others then out := out || ' finalize()=refused'; end;
  begin perform public.sc1_try_finalize(S1); out := out || ' try_finalize()=ALLOWED?'; exception when others then out := out || ' try_finalize()=refused'; end;
  begin select count(*) into n from public.session_stats_failures; out := out || ' failures_table=READABLE?'; exception when others then out := out || ' failures_table=refused'; end;

  -- 3. Who reads it: the team's head coach yes, another pitcher no.
  perform set_config('request.jwt.claims', json_build_object('sub', C, 'role', 'authenticated')::text, true);
  select count(*) into n from public.session_stats where session_id = S1;
  out := out || format(' | 3 coach_sees=%s', n);
  perform set_config('request.jwt.claims', json_build_object('sub', O, 'role', 'authenticated')::text, true);
  select count(*) into n from public.session_stats where session_id = S1;
  out := out || format(' other_pitcher_sees=%s', n);

  -- 4. A game with one wild pitch moving two runners (one WP) and a strikeout; then the pitcher deletes the pen.
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role', 'authenticated')::text, true);
  r := public.sync_session(
    jsonb_build_object('id', S2, 'pitcher_id', P, 'team_id', T, 'logged_by', P, 'started_at', now() - interval '7 minutes', 'ended_at', now() - interval '6 minutes', 'kind', 'game',
                       'left_owners', jsonb_build_object('1', S2::text)),   -- he left his own runner on: line stays open
    jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'type', 'Slider', 'ts', now() - interval '7 minutes', 'actual_row', 2, 'actual_col', 2, 'result', 'strike_swinging', 'balls_before', 0, 'strikes_before', 2, 'inning', 1, 'at_bat_index', 1, 'outs_before', 0)),
    jsonb_build_array(
      jsonb_build_object('id', gen_random_uuid(), 'event_type', 'wild_pitch', 'at_bat_index', 2, 'inning_before', 1, 'balls_before', 1, 'strikes_before', 0, 'seq', 1),
      jsonb_build_object('id', gen_random_uuid(), 'event_type', 'wild_pitch', 'at_bat_index', 2, 'inning_before', 1, 'balls_before', 1, 'strikes_before', 0, 'seq', 2)));
  select format(' | 4 game=%s kind=%s k=%s wp=%s provisional=%s', r ->> 'status', kind, game ->> 'k', game ->> 'wp', provisional)
    into claims from public.session_stats where session_id = S2;
  out := out || coalesce(claims, ' | 4 game row MISSING');
  r := public.delete_session(S1);
  select count(*) into n from public.session_stats where session_id = S1;
  out := out || format(' delete_session=%s row_after=%s tombstone=%s', coalesce(r ->> 'error', 'ok'), n,
                       (select deleted_at is not null from public.sessions where id = S1));

  -- 5. R3: the server closes the game's line with a run charged after he left -> the row is recomputed.
  reset role;
  update public.sessions set exit_runs = 1, exit_er = 1, final_at = now() where id = S2;
  select format(' | 5 after close: runs=%s provisional=%s', game ->> 'runs', provisional) into claims from public.session_stats where session_id = S2;
  out := out || claims;

  -- 6. Save anyway: break the stats function, save a pen -> saved and sealed, no row, the failure logged.
  execute $f$create or replace function public.finalize_session_stats(p_session uuid) returns void language plpgsql
             security definer set search_path = '' as $b$ begin raise exception 'sc1 test: stats broken'; end $b$ $f$;
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role', 'authenticated')::text, true);
  set local role authenticated;
  r := public.sync_session(
    jsonb_build_object('id', S3, 'pitcher_id', P, 'team_id', T, 'logged_by', P, 'started_at', now() - interval '5 minutes', 'ended_at', now() - interval '4 minutes', 'kind', 'bullpen'),
    jsonb_build_array(jsonb_build_object('id', gen_random_uuid(), 'type', 'Slider', 'ts', now() - interval '5 minutes', 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2)),
    '[]'::jsonb);
  reset role;
  out := out || format(' | 6 broken stats: save=%s sealed=%s pitches=%s row=%s logged=%s', r ->> 'status',
    (select sealed_at is not null from public.sessions where id = S3),
    (select count(*) from public.pitches where session_id = S3),
    (select count(*) from public.session_stats where session_id = S3),
    (select string_agg(error, ';') from public.session_stats_failures where session_id = S3));
  raise exception 'RESULT %', out;
end $$;
