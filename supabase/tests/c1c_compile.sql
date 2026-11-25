-- C1 Stage C acceptance, database part (staging; everything rolled back -- the block ends by raising its results).
-- H (head of team T) charts Outcome, P (a pitcher on T) charts Intent, through the live functions; each saves a piece
-- through sync_session; the combined session appears when the last piece is in. Then the three-hour rule, a part nobody
-- took, and that pieces never have numbers. Checks are numbered after the packet's "Done when" 15-18.
do $$
declare
  H uuid := 'aaaaaaaa-0000-4000-8000-0000000c1c01'; P uuid := 'aaaaaaaa-0000-4000-8000-0000000c1c02';
  T uuid; L uuid; L2 uuid; L3 uuid; s1 int; s2 int; s3 int; s4 int; pieceP uuid := gen_random_uuid(); pieceH uuid := gen_random_uuid();
  pieceH2 uuid := gen_random_uuid(); C uuid; r jsonb; n int; v text; t0 timestamptz := now() - interval '1 hour'; out text := ''; fails int := 0;
  pol0 int; pol1 int; h0 text; h1 text;
begin
  select count(*) into pol0 from pg_policies where schemaname in ('public', 'storage');
  select md5(string_agg((to_jsonb(x) - 'computed_at')::text, '|' order by session_id)) into h0 from public.session_stats x;
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', e || '@example.invalid',
         jsonb_build_object('full_name', nm, 'intended_role', ro, 'intended_sport', 'baseball'), now(), now()
    from (values (H, 'c1c-h', 'Head H', 'coach'), (P, 'c1c-p', 'Pia Pitcher', 'pitcher')) x(u, e, nm, ro);
  insert into public.profiles (id, role, full_name, sport) select P, 'pitcher', 'Pia Pitcher', 'baseball' where not exists (select 1 from public.profiles where id = P);
  update public.profiles set email_verified_at = now(), age_attestation = 'adult', attested_at = now(), attested_via = 'signup', terms_version = '2026-11-20' where id in (H, P);
  T := public._create_team_with_head(H, 'C1C Team');
  insert into public.pitcher_teams (pitcher_id, team_id, joined_at) values (P, T, now() - interval '30 days');

  -- the live session: H Outcome, P Intent; calls 1-3, outcomes on 1-2, a skipped one (4)
  perform set_config('request.jwt.claims', json_build_object('sub', H, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.live_start(P, T, 'bullpen', 'outcome', H); L := (r ->> 'live_id')::uuid;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.live_join(L, 'intent', P);
  s1 := (public.live_put_intent(L, 'Slider', 2, 2, 'R') ->> 'seq')::int;
  s2 := (public.live_put_intent(L, 'Curveball', 3, 1, 'R') ->> 'seq')::int;
  s3 := (public.live_put_intent(L, 'Changeup', 3, 3, 'R') ->> 'seq')::int;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', H, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.live_put_outcome(L, s1, '{"actual_row": 2, "actual_col": 2}');
  r := public.live_put_outcome(L, s2, '{"actual_row": 3, "actual_col": 2}');
  s4 := (public.live_put_outcome(L, null, '{"actual_row": 1, "actual_col": 1}', true) ->> 'seq')::int;
  reset role;

  -- 15. each charter saves their piece (leave, then sync, as the app does); nothing is put together until the last
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.live_leave(L, pieceP);
  r := public.sync_session(jsonb_build_object('id', pieceP, 'pitcher_id', P, 'logged_by', P, 'team_id', T, 'kind', 'bullpen',
         'charted_intent', true, 'charted_outcome', false, 'live_session_id', L, 'live_part', 'intent', 'purpose', 'command',
         'started_at', t0, 'ended_at', t0 + interval '20 minutes'),
       jsonb_build_array(
         jsonb_build_object('id', gen_random_uuid(), 'type', 'Slider', 'target_row', 2, 'target_col', 2, 'batter_side', 'R', 'live_seq', s1, 'ts', t0 + interval '1 minute'),
         jsonb_build_object('id', gen_random_uuid(), 'type', 'Curveball', 'target_row', 3, 'target_col', 1, 'batter_side', 'R', 'live_seq', s2, 'ts', t0 + interval '2 minutes'),
         jsonb_build_object('id', gen_random_uuid(), 'type', 'Changeup', 'target_row', 3, 'target_col', 3, 'batter_side', 'R', 'live_seq', s3, 'ts', t0 + interval '3 minutes'),
         jsonb_build_object('id', gen_random_uuid(), 'type', 'Slider', 'target_row', 1, 'target_col', 1, 'ts', t0 + interval '9 minutes')), '[]'::jsonb);   -- an unmatched call
  out := out || '15 P piece: ' || (r ->> 'status');
  reset role;
  select count(*) into n from public.sessions where compiled_from = L;
  out := out || ', combined after the first piece: ' || n; if n <> 0 then fails := fails + 1; end if;
  perform set_config('request.jwt.claims', json_build_object('sub', H, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.live_leave(L, pieceH);
  r := public.sync_session(jsonb_build_object('id', pieceH, 'pitcher_id', P, 'logged_by', H, 'team_id', T, 'kind', 'bullpen',
         'charted_intent', false, 'charted_outcome', true, 'live_session_id', L, 'live_part', 'outcome',
         'started_at', t0 + interval '30 seconds', 'ended_at', t0 + interval '21 minutes'),
       jsonb_build_array(
         jsonb_build_object('id', gen_random_uuid(), 'type', 'Slider', 'actual_row', 2, 'actual_col', 2, 'velo', 82, 'live_seq', s1, 'ts', t0 + interval '70 seconds'),
         jsonb_build_object('id', gen_random_uuid(), 'type', 'Curveball', 'actual_row', 3, 'actual_col', 2, 'live_seq', s2, 'ts', t0 + interval '130 seconds'),
         jsonb_build_object('id', gen_random_uuid(), 'type', 'Fastball', 'actual_row', 1, 'actual_col', 1, 'live_seq', s4, 'ts', t0 + interval '5 minutes'),
         jsonb_build_object('id', gen_random_uuid(), 'type', 'Fastball', 'actual_row', 0, 'actual_col', 4, 'ts', t0 + interval '8 minutes')), '[]'::jsonb);   -- unmatched outcome
  out := out || ', H piece: ' || (r ->> 'status');
  reset role;
  select id into C from public.sessions where compiled_from = L;
  out := out || ', combined after the last: ' || (C is not null);
  if C is null then fails := fails + 1; end if;
  select string_agg(coalesce(live_seq::text, '-') || ':' || case when target_row is not null then 'I' else '' end || case when actual_row is not null then 'O' else '' end
                    || coalesce('(' || accuracy_hit_kind || ')', ''), ' ' order by ts) into v from public.pitches where session_id = C;
  out := out || ' | pitches ' || v;
  if v is distinct from '1:IO(exact) 2:IO(miss) 3:I 4:O -:O' then fails := fails + 1; end if;
  select type into v from public.pitches where session_id = C and live_seq = s2;
  out := out || ', type from the call: ' || v; if v <> 'Curveball' then fails := fails + 1; end if;
  select (charted_intent and charted_outcome)::text || ' purpose ' || coalesce(purpose, '-') || ' logged_by H ' || (logged_by = H) into v from public.sessions where id = C;
  out := out || ', ' || v;
  -- the pieces: unchanged, no numbers; the combined session: a stats row
  select count(*) into n from public.session_stats where session_id in (pieceP, pieceH);
  out := out || ' | pieces with stats rows: ' || n; if n <> 0 then fails := fails + 1; end if;
  select count(*) into n from public.pitches where session_id in (pieceP, pieceH);
  out := out || ', piece pitches kept: ' || n; if n <> 8 then fails := fails + 1; end if;
  select pitches || '/' || scored || '/' || hits into v from public.session_stats where session_id = C;
  out := out || ', combined stats pitches/scored/hits ' || v; if v is distinct from '5/2/1' then fails := fails + 1; end if;
  begin
    update public.sessions set compiled_from = null where id = C; v := 'changed';
  exception when others then v := sqlerrm; end;
  out := out || ', unlink: ' || left(v, 22); if v = 'changed' then fails := fails + 1; end if;

  -- 16. three hours: P still holding Intent after H saved; the job closes it and fills P's part from what reached the server
  perform set_config('request.jwt.claims', json_build_object('sub', H, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.live_start(P, T, 'bullpen', 'outcome', H); L2 := (r ->> 'live_id')::uuid;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.live_join(L2, 'intent', P);
  s1 := (public.live_put_intent(L2, 'Slider', 1, 1, 'L') ->> 'seq')::int;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', H, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.live_put_outcome(L2, s1, '{"actual_row": 1, "actual_col": 2}');
  r := public.live_leave(L2, pieceH2);
  r := public.sync_session(jsonb_build_object('id', pieceH2, 'pitcher_id', P, 'logged_by', H, 'team_id', T, 'kind', 'bullpen',
         'charted_intent', false, 'charted_outcome', true, 'live_session_id', L2, 'live_part', 'outcome',
         'started_at', now() - interval '5 hours', 'ended_at', now() - interval '4 hours'),
       jsonb_build_array(jsonb_build_object('id', gen_random_uuid(), 'type', 'Slider', 'actual_row', 1, 'actual_col', 2, 'live_seq', s1, 'ts', now() - interval '290 minutes')), '[]'::jsonb);
  reset role;
  select count(*) into n from public.sessions where compiled_from = L2;
  out := out || ' | 16 before the job: ' || n;
  update public.sessions set sealed_at = now() - interval '4 hours' where id = pieceH2 and false;   -- (sealed_at is locked; age the live row instead)
  update public.live_sessions set last_activity_at = now() - interval '4 hours' where id = L2;
  n := public.c1_compile_stale();
  select id into C from public.sessions where compiled_from = L2;
  select string_agg(coalesce(live_seq::text, '-') || ':' || case when target_row is not null then 'I' else '' end || case when actual_row is not null then 'O' else '' end || coalesce(':' || type, ''), ' ') into v
    from public.pitches where session_id = C;
  out := out || ', after the job: ' || coalesce(v, 'none') || ' (P part filled from the server)';
  if v is distinct from '1:IO:Slider' then fails := fails + 1; end if;
  select count(*) into n from public.live_parts where live_id = L2 and left_at is null;
  out := out || ', open parts left: ' || n; if n <> 0 then fails := fails + 1; end if;

  -- 17. a part nobody took: Outcome alone, saved; the combined session has no call anywhere
  perform set_config('request.jwt.claims', json_build_object('sub', H, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.live_start(P, T, 'game', 'outcome', H); L3 := (r ->> 'live_id')::uuid;
  pieceH := gen_random_uuid();
  r := public.live_put_outcome(L3, null, '{"actual_row": 2, "actual_col": 2, "result": "strike_looking"}');
  r := public.live_leave(L3, pieceH);
  r := public.sync_session(jsonb_build_object('id', pieceH, 'pitcher_id', P, 'logged_by', H, 'team_id', T, 'kind', 'game',
         'charted_intent', false, 'charted_outcome', true, 'live_session_id', L3, 'live_part', 'outcome', 'game_final_inning', 1, 'game_outs_recorded', 0,
         'started_at', t0, 'ended_at', t0 + interval '10 minutes'),
       jsonb_build_array(jsonb_build_object('id', gen_random_uuid(), 'kind', 'game', 'type', 'Slider', 'actual_row', 2, 'actual_col', 2, 'result', 'strike_looking',
                          'inning', 1, 'outs_before', 0, 'balls_before', 0, 'strikes_before', 0, 'at_bat_index', 1, 'batter_side', 'R', 'live_seq', 1, 'ts', t0)), '[]'::jsonb);
  reset role;
  select (charted_intent)::text || '/' || charted_outcome::text into v from public.sessions where compiled_from = L3;
  out := out || ' | 17 nobody on Intent: charted ' || coalesce(v, 'none'); if v is distinct from 'false/true' then fails := fails + 1; end if;

  -- 18. nothing else changed: every stats row that existed before is the same
  select md5(string_agg((to_jsonb(x) - 'computed_at')::text, '|' order by session_id)) into h1 from public.session_stats x
   where x.session_id not in (select id from public.sessions where pitcher_id = P);
  out := out || ' | 18 other stats rows unchanged: ' || (h0 = h1); if h0 is distinct from h1 then fails := fails + 1; end if;
  select count(*) into pol1 from pg_policies where schemaname in ('public', 'storage');
  out := out || ', policies ' || pol0 || '->' || pol1; if pol0 <> pol1 then fails := fails + 1; end if;
  raise exception 'C1C RESULT fails=% | %', fails, out;
end $$;
