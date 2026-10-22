-- Live Game R3 Stage B (Oct 22 2026) -- staging; everything rolled back (the block ends by raising its results).
-- A pitcher's line stays open for the runners he left: the reliever's save charges him (server only), the full lock,
-- the chain, the caps, the linker rule, a missing starter, the 6-hour job, and the lock refusing crafted changes.
do $$
declare
  T  uuid := '18fa6885-c85e-4c2a-88e9-e301c6f93723';   -- Staging Knights
  P  uuid := '14345e15-dca3-4bc7-8126-2639b6504aad';   -- Staging Pitcher
  P2 uuid := '3d967481-6e9a-4003-87d9-5a121fcf75f6';   -- Staging Player
  C  uuid := '84c1d3f1-0509-49b2-8b3f-30aae98dcbf3';   -- Staging Coach (head)
  S1 uuid := gen_random_uuid(); R1 uuid := gen_random_uuid();
  S2 uuid := gen_random_uuid(); R2 uuid := gen_random_uuid();
  S3 uuid := gen_random_uuid(); R3 uuid := gen_random_uuid(); R3b uuid := gen_random_uuid();
  S4 uuid := gen_random_uuid(); R4 uuid := gen_random_uuid();
  S5 uuid := gen_random_uuid(); S6 uuid := gen_random_uuid(); R6 uuid := gen_random_uuid(); B uuid := gen_random_uuid();
  r jsonb; sm jsonb; out text := '';
  t0 timestamptz := now() - interval '3 hours';
  pitch jsonb := jsonb_build_object('type', 'Slider', 'kind', 'game', 'actual_row', 2, 'actual_col', 2, 'inning', 3,
                                    'outs_before', 1, 'balls_before', 0, 'strikes_before', 0, 'at_bat_index', 1);
  function_ok boolean;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', C, 'role', 'authenticated')::text, true);
  set local role authenticated;

  -- 1. starter leaves runners on 1B and 3B (his own): his line stays open
  r := public.sync_session(jsonb_build_object('id', S1, 'pitcher_id', P, 'team_id', T, 'logged_by', C, 'kind', 'game',
         'started_at', t0, 'ended_at', t0 + interval '30 minutes', 'runners_left', 2, 'left_owners', jsonb_build_object('1', S1, '3', S1)),
       jsonb_build_array(pitch || jsonb_build_object('id', gen_random_uuid(), 'ts', t0 + interval '1 minute', 'result', 'ball')), '[]'::jsonb);
  out := out || format('starter: %s final=%s', r ->> 'status', (select final_at is not null from public.sessions where id = S1));
  sm := public.compute_game_summary(S1);
  out := out || format(' provisional=%s', sm ->> 'provisional');
  -- 2. the reliever gives up a single, both score (one of them reached on an error: unearned); batter on 1B is his
  r := public.sync_session(jsonb_build_object('id', R1, 'pitcher_id', P2, 'team_id', T, 'logged_by', C, 'kind', 'game',
         'started_at', t0 + interval '31 minutes', 'ended_at', t0 + interval '50 minutes', 'relieved_session_id', S1,
         'inherited_runners', 2, 'runners_left', 1, 'left_owners', jsonb_build_object('1', R1)),
       jsonb_build_array(pitch || jsonb_build_object('id', gen_random_uuid(), 'ts', t0 + interval '32 minutes', 'result', 'in_play',
         'in_play_outcome', 'hit', 'hit_type', '1B', 'batter_to', 1, 'runs_scored', 2, 'inherited_runs', 2, 'unearned_runs', 0,
         'charged_runs', jsonb_build_array(jsonb_build_object('s', S1, 'u', false), jsonb_build_object('s', S1, 'u', true)))), '[]'::jsonb);
  out := out || format(' | reliever: %s relief=%s, own final=%s', r ->> 'status', r ->> 'relief', (select final_at is not null from public.sessions where id = R1));
  select jsonb_build_object('r', exit_runs, 'er', exit_er, 'final', final_at is not null) into sm from public.sessions where id = S1;
  out := out || format(' | starter after: exit_runs=%s exit_er=%s final=%s', sm ->> 'r', sm ->> 'er', sm ->> 'final');
  sm := public.compute_game_summary(S1);
  out := out || format(' summary runs=%s er=%s provisional=%s', sm ->> 'runs', sm ->> 'er', sm ->> 'provisional');
  sm := public.compute_game_summary(R1);
  out := out || format(' | reliever summary runs=%s irs=%s', sm ->> 'runs', sm ->> 'irs');

  -- 3. stranded: the reliever ends the inning, nobody scores -> the starter is final with exit_runs NULL
  perform public.sync_session(jsonb_build_object('id', S2, 'pitcher_id', P, 'team_id', T, 'logged_by', C, 'kind', 'game',
         'started_at', t0, 'ended_at', t0 + interval '20 minutes', 'runners_left', 1, 'left_owners', jsonb_build_object('2', S2)), '[]'::jsonb, '[]'::jsonb);
  perform public.sync_session(jsonb_build_object('id', R2, 'pitcher_id', P2, 'team_id', T, 'logged_by', C, 'kind', 'game',
         'started_at', t0 + interval '21 minutes', 'ended_at', t0 + interval '40 minutes', 'relieved_session_id', S2, 'runners_left', 0,
         'left_owners', '{}'::jsonb), '[]'::jsonb, '[]'::jsonb);
  out := out || format(' | stranded: final=%s exit_runs=%s', (select final_at is not null from public.sessions where id = S2),
    coalesce((select exit_runs::text from public.sessions where id = S2), 'NULL'));

  -- 4. the chain: reliever 1 leaves the starter's runner on, reliever 2 lets him score -> charged to the starter
  perform public.sync_session(jsonb_build_object('id', S3, 'pitcher_id', P, 'team_id', T, 'logged_by', C, 'kind', 'game',
         'started_at', t0, 'ended_at', t0 + interval '10 minutes', 'runners_left', 1, 'left_owners', jsonb_build_object('1', S3)), '[]'::jsonb, '[]'::jsonb);
  perform public.sync_session(jsonb_build_object('id', R3, 'pitcher_id', P2, 'team_id', T, 'logged_by', C, 'kind', 'game',
         'started_at', t0 + interval '11 minutes', 'ended_at', t0 + interval '15 minutes', 'relieved_session_id', S3, 'runners_left', 1,
         'left_owners', jsonb_build_object('2', S3)), '[]'::jsonb, '[]'::jsonb);
  out := out || format(' | chain: after reliever 1 starter final=%s, reliever 1 final=%s', (select final_at is not null from public.sessions where id = S3),
    (select final_at is not null from public.sessions where id = R3));
  perform public.sync_session(jsonb_build_object('id', R3b, 'pitcher_id', P, 'team_id', T, 'logged_by', C, 'kind', 'game',
         'started_at', t0 + interval '16 minutes', 'ended_at', t0 + interval '25 minutes', 'relieved_session_id', R3, 'runners_left', 0,
         'left_owners', '{}'::jsonb),
       jsonb_build_array(pitch || jsonb_build_object('id', gen_random_uuid(), 'ts', t0 + interval '17 minutes', 'result', 'in_play',
         'in_play_outcome', 'hit', 'hit_type', '2B', 'batter_to', 2, 'runs_scored', 1, 'inherited_runs', 1,
         'charged_runs', jsonb_build_array(jsonb_build_object('s', S3, 'u', false)))), '[]'::jsonb);
  out := out || format(' -> after reliever 2: starter exit_runs=%s final=%s, reliever 1 exit_runs=%s',
    (select exit_runs from public.sessions where id = S3), (select final_at is not null from public.sessions where id = S3),
    coalesce((select exit_runs::text from public.sessions where id = R3), 'NULL'));

  -- 5. the cap: a crafted relief claiming 5 runs for a starter who left 1 runner -> 1
  perform public.sync_session(jsonb_build_object('id', S6, 'pitcher_id', P, 'team_id', T, 'logged_by', C, 'kind', 'game',
         'started_at', t0, 'ended_at', t0 + interval '10 minutes', 'runners_left', 1, 'left_owners', jsonb_build_object('3', S6)), '[]'::jsonb, '[]'::jsonb);
  perform public.sync_session(jsonb_build_object('id', R6, 'pitcher_id', P2, 'team_id', T, 'logged_by', C, 'kind', 'game',
         'started_at', t0 + interval '11 minutes', 'ended_at', t0 + interval '20 minutes', 'relieved_session_id', S6, 'left_owners', '{}'::jsonb),
       jsonb_build_array(pitch || jsonb_build_object('id', gen_random_uuid(), 'ts', t0 + interval '12 minutes', 'result', 'in_play',
         'in_play_outcome', 'hit', 'hit_type', 'HR', 'batter_to', 4, 'runs_scored', 4, 'inherited_runs', 3,
         'charged_runs', (select jsonb_agg(jsonb_build_object('s', S6, 'u', false)) from generate_series(1, 5)))), '[]'::jsonb);
  out := out || format(' | cap: claimed 5, charged %s', (select exit_runs from public.sessions where id = S6));

  -- 6. a bullpen is final at save
  perform public.sync_session(jsonb_build_object('id', B, 'pitcher_id', P, 'team_id', T, 'logged_by', C, 'kind', 'bullpen',
         'started_at', t0, 'ended_at', t0 + interval '5 minutes'), '[]'::jsonb, '[]'::jsonb);
  out := out || format(' | bullpen final=%s', (select final_at is not null from public.sessions where id = B));

  -- 7. a missing starter: the relief waits in the outbox
  r := public.sync_session(jsonb_build_object('id', gen_random_uuid(), 'pitcher_id', P2, 'team_id', T, 'logged_by', C, 'kind', 'game',
         'started_at', now() - interval '20 minutes', 'ended_at', now() - interval '5 minutes', 'relieved_session_id', gen_random_uuid()), '[]'::jsonb, '[]'::jsonb);
  out := out || format(' | missing starter: %s', r ->> 'error');

  -- 8. a crafted write of another pitcher's line from the API: refused
  begin
    update public.sessions set exit_runs = 3 where id = S2;
    out := out || ' | API write exit_runs=SAVED?';
  exception when others then out := out || ' | API write exit_runs=refused';
  end;
  begin
    update public.sessions set relieved_session_id = null where id = R1;
    out := out || ' | API unlink=SAVED?';
  exception when others then out := out || ' | API unlink=refused';
  end;

  -- 9. a pitcher charting himself can't link to a teammate's game the coach charted
  perform public.sync_session(jsonb_build_object('id', S4, 'pitcher_id', P, 'team_id', T, 'logged_by', C, 'kind', 'game',
         'started_at', t0, 'ended_at', t0 + interval '10 minutes', 'runners_left', 1, 'left_owners', jsonb_build_object('1', S4)), '[]'::jsonb, '[]'::jsonb);
  perform set_config('request.jwt.claims', json_build_object('sub', P2, 'role', 'authenticated')::text, true);
  r := public.sync_session(jsonb_build_object('id', R4, 'pitcher_id', P2, 'team_id', T, 'logged_by', P2, 'kind', 'game',
         'started_at', t0 + interval '11 minutes', 'ended_at', t0 + interval '20 minutes', 'relieved_session_id', S4, 'left_owners', '{}'::jsonb),
       jsonb_build_array(pitch || jsonb_build_object('id', gen_random_uuid(), 'ts', t0 + interval '12 minutes', 'result', 'in_play',
         'in_play_outcome', 'hit', 'hit_type', '1B', 'batter_to', 1, 'runs_scored', 1, 'inherited_runs', 1,
         'charged_runs', jsonb_build_array(jsonb_build_object('s', S4, 'u', false)))), '[]'::jsonb);
  out := out || format(' | pitcher links teammate: %s relief=%s, linked=%s, teammate exit_runs=%s', r ->> 'status', r ->> 'relief',
    (select relieved_session_id is not null from public.sessions where id = R4), coalesce((select exit_runs::text from public.sessions where id = S4), 'NULL'));

  -- 10. the API can't call the charging function or the 6-hour job itself
  begin
    perform public.r3_apply_relief(R1);
    out := out || ' | API r3_apply_relief=RAN?';
  exception when insufficient_privilege then out := out || ' | API r3_apply_relief=refused';
  end;

  -- 11. as the owner: no change once final; then the 6-hour job
  reset role;
  begin
    update public.sessions set exit_runs = 5 where id = S1;
    out := out || ' | change after final=SAVED?';
  exception when others then out := out || ' | change after final=refused';
  end;
  perform set_config('request.jwt.claims', json_build_object('sub', C, 'role', 'authenticated')::text, true);
  set local role authenticated;
  perform public.sync_session(jsonb_build_object('id', S5, 'pitcher_id', P, 'team_id', T, 'logged_by', C, 'kind', 'game',
         'started_at', now() - interval '8 hours', 'ended_at', now() - interval '7 hours', 'runners_left', 1, 'left_owners', jsonb_build_object('1', S5)), '[]'::jsonb, '[]'::jsonb);
  reset role;
  out := out || format(' | 6h: open before=%s', (select final_at is null from public.sessions where id = S5));
  alter table public.sessions disable trigger sessions_h1_lock;
  update public.sessions set sealed_at = now() - interval '7 hours' where id = S5;   -- as if saved 7 hours ago
  alter table public.sessions enable trigger sessions_h1_lock;
  perform public.r3_finalize_stale();
  out := out || format(', after the job final=%s, S4 (saved now) still open=%s', (select final_at is not null from public.sessions where id = S5),
    (select final_at is null from public.sessions where id = S4));
  out := out || format(' | job scheduled=%s', (select count(*) from cron.job where jobname = 'r3-final-lock'));
  raise exception 'RESULT %', out;
end $$;
