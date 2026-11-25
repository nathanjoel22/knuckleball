-- C1 Stage A acceptance, database part (staging; everything rolled back -- the block ends by raising its results).
-- One fixture pitcher (example.invalid) charting for themself, independent (no team): a full pen, an Intent-only pen,
-- an Outcome-only pen, an Intent-only game and an Outcome & Response-only game, through sync_session, then what's
-- stored, the stats row, the lock, More Plays flags and the baselines filter. Checks are numbered after the packet's
-- "Done when" 1-8.
do $$
declare
  P uuid := 'aaaaaaaa-0000-4000-8000-0000000c1a01';
  S_FULL uuid := gen_random_uuid(); S_INT uuid := gen_random_uuid(); S_OUT uuid := gen_random_uuid();
  G_INT uuid := gen_random_uuid(); G_OUT uuid := gen_random_uuid(); S_FULL2 uuid := gen_random_uuid();
  t0 timestamptz := now() - interval '2 hours';
  r jsonb; st record; n int; v text; out text := ''; fails int := 0; pol0 int; pol1 int; err text;
  sess jsonb;
begin
  select count(*) into pol0 from pg_policies where schemaname in ('public', 'storage');
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  values (P, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'c1a-p@example.invalid',
          jsonb_build_object('full_name', 'C1 Pitcher', 'intended_role', 'pitcher', 'intended_sport', 'baseball'), now(), now());
  insert into public.profiles (id, role, full_name, sport) select P, 'pitcher', 'C1 Pitcher', 'baseball'
   where not exists (select 1 from public.profiles where id = P);
  update public.profiles set email_verified_at = now(), age_attestation = 'adult', attested_at = now(), attested_via = 'signup',
         terms_version = '2026-11-20' where id = P;
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role', 'authenticated')::text, true); set local role authenticated;

  -- ---------- 1. both parts = today's rows (no flags sent, as an older app) ----------
  sess := jsonb_build_object('id', S_FULL, 'pitcher_id', P, 'logged_by', P, 'kind', 'bullpen',
            'started_at', t0, 'ended_at', t0 + interval '10 minutes', 'ra_on', false);
  r := public.sync_session(sess, jsonb_build_array(
         jsonb_build_object('id', gen_random_uuid(), 'type', '4SFB', 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2, 'accuracy_hit_kind', 'exact', 'ts', t0),
         jsonb_build_object('id', gen_random_uuid(), 'type', '4SFB', 'target_row', 1, 'target_col', 1, 'actual_row', 3, 'actual_col', 3, 'accuracy_hit_kind', 'miss', 'ts', t0 + interval '20 seconds')), '[]'::jsonb);
  out := out || '1 full pen: ' || (r ->> 'status');
  select charted_intent, charted_outcome into st from public.sessions where id = S_FULL;
  out := out || ' (parts ' || st.charted_intent || '/' || st.charted_outcome || ')';
  if not (st.charted_intent and st.charted_outcome) then fails := fails + 1; end if;

  -- ---------- Intent-only pen: target, no location (sent location ignored? no: none is sent) ----------
  sess := jsonb_build_object('id', S_INT, 'pitcher_id', P, 'logged_by', P, 'kind', 'bullpen', 'charted_intent', true, 'charted_outcome', false,
            'started_at', t0 + interval '15 minutes', 'ended_at', t0 + interval '25 minutes');
  r := public.sync_session(sess, jsonb_build_array(
         jsonb_build_object('id', gen_random_uuid(), 'type', '4SFB', 'target_row', 2, 'target_col', 3, 'batter_side', 'R', 'ts', t0 + interval '15 minutes'),
         jsonb_build_object('id', gen_random_uuid(), 'type', 'CH', 'target_row', 3, 'target_col', 1, 'ts', t0 + interval '16 minutes')), '[]'::jsonb);
  select count(*) filter (where actual_row is null and actual_col is null and target_row is not null) into n from public.pitches where session_id = S_INT;
  out := out || ' | Intent-only pen: ' || (r ->> 'status') || ', ' || n || ' of 2 with a target and no location';
  if n <> 2 then fails := fails + 1; end if;

  -- ---------- Outcome-only pen: location, no target (a target sent anyway is dropped) ----------
  sess := jsonb_build_object('id', S_OUT, 'pitcher_id', P, 'logged_by', P, 'kind', 'bullpen', 'charted_intent', false, 'charted_outcome', true,
            'started_at', t0 + interval '30 minutes', 'ended_at', t0 + interval '40 minutes');
  r := public.sync_session(sess, jsonb_build_array(
         jsonb_build_object('id', gen_random_uuid(), 'type', '4SFB', 'actual_row', 2, 'actual_col', 2, 'velo', 84, 'ts', t0 + interval '30 minutes'),
         jsonb_build_object('id', gen_random_uuid(), 'type', '4SFB', 'target_row', 1, 'target_col', 1, 'actual_row', 0, 'actual_col', 4, 'ts', t0 + interval '31 minutes')), '[]'::jsonb);
  select count(*) filter (where target_row is null and actual_row is not null) into n from public.pitches where session_id = S_OUT;
  out := out || ' | Outcome-only pen: ' || (r ->> 'status') || ', ' || n || ' of 2 with a location and no target';
  if n <> 2 then fails := fails + 1; end if;

  -- ---------- 6. Intent-only game: type + target (+ batter side), nothing else; no game line ----------
  sess := jsonb_build_object('id', G_INT, 'pitcher_id', P, 'logged_by', P, 'kind', 'game', 'charted_intent', true, 'charted_outcome', false,
            'started_at', t0 + interval '45 minutes', 'ended_at', t0 + interval '70 minutes');
  r := public.sync_session(sess, jsonb_build_array(
         jsonb_build_object('id', gen_random_uuid(), 'kind', 'game', 'type', '4SFB', 'target_row', 2, 'target_col', 1, 'batter_side', 'L', 'ts', t0 + interval '46 minutes'),
         jsonb_build_object('id', gen_random_uuid(), 'kind', 'game', 'type', 'SL', 'target_row', 3, 'target_col', 3, 'batter_side', 'L', 'ts', t0 + interval '47 minutes')), '[]'::jsonb);
  select count(*) filter (where actual_row is null and result is null and inning is null and at_bat_index is null and target_row is not null) into n
    from public.pitches where session_id = G_INT;
  out := out || ' | 6 Intent-only game: ' || (r ->> 'status') || ', ' || n || ' of 2 type+target only';
  if n <> 2 then fails := fails + 1; end if;

  -- ---------- 5. Outcome & Response only: the same rows as an Intent-off game ----------
  sess := jsonb_build_object('id', G_OUT, 'pitcher_id', P, 'logged_by', P, 'kind', 'game', 'charted_intent', false, 'charted_outcome', true,
            'started_at', t0 + interval '75 minutes', 'ended_at', t0 + interval '95 minutes', 'game_final_inning', 1, 'game_outs_recorded', 1);
  r := public.sync_session(sess, jsonb_build_array(
         jsonb_build_object('id', gen_random_uuid(), 'kind', 'game', 'type', '4SFB', 'actual_row', 2, 'actual_col', 2, 'result', 'strike_looking',
                            'inning', 1, 'outs_before', 0, 'balls_before', 0, 'strikes_before', 0, 'at_bat_index', 1, 'batter_side', 'R', 'ts', t0 + interval '76 minutes'),
         jsonb_build_object('id', gen_random_uuid(), 'kind', 'game', 'type', '4SFB', 'actual_row', 2, 'actual_col', 3, 'result', 'in_play', 'in_play_outcome', 'out',
                            'bb_type', 'fly', 'spray_box', 19, 'spray_field', 'IF', 'play_flags', jsonb_build_array('infield_fly'),
                            'inning', 1, 'outs_before', 0, 'balls_before', 0, 'strikes_before', 1, 'at_bat_index', 1, 'batter_side', 'R', 'outs_on_play', 1, 'ts', t0 + interval '77 minutes')), '[]'::jsonb);
  select count(*) filter (where target_row is null and actual_row is not null and result is not null) into n from public.pitches where session_id = G_OUT;
  out := out || ' | 5 O&R-only game: ' || (r ->> 'status') || ', ' || n || ' of 2 rows as Intent off';
  if n <> 2 then fails := fails + 1; end if;
  select array_to_string(play_flags, ',') into v from public.pitches where session_id = G_OUT and play_flags is not null;
  out := out || ', More Plays flag stored: ' || coalesce(v, 'none'); if v is distinct from 'infield_fly' then fails := fails + 1; end if;

  -- ---------- neither part: refused ----------
  r := public.sync_session(jsonb_build_object('id', gen_random_uuid(), 'pitcher_id', P, 'logged_by', P, 'kind', 'bullpen', 'charted_intent', false, 'charted_outcome', false,
            'started_at', t0, 'ended_at', t0 + interval '1 minute'), '[]'::jsonb, '[]'::jsonb);
  out := out || ' | no part: ' || coalesce(r ->> 'error', 'saved!'); if r ->> 'error' is distinct from 'invalid_session' then fails := fails + 1; end if;
  reset role;

  -- ---------- More Plays flags: games only, known values only ----------
  insert into public.sessions (id, pitcher_id, logged_by, started_at, kind) values (S_FULL2, P, P, now(), 'bullpen');   -- unsaved: no lock
  begin
    insert into public.pitches (id, session_id, type, target_row, target_col, actual_row, actual_col, kind, play_flags)
    values (gen_random_uuid(), S_FULL2, '4SFB', 2, 2, 2, 2, 'bullpen', array['ground_rule_double']);
    err := 'inserted';
  exception when others then err := sqlerrm; end;
  out := out || ' | flag on a pen: ' || left(err, 60); if err = 'inserted' then fails := fails + 1; end if;
  begin
    insert into public.pitches (id, session_id, type, actual_row, actual_col, kind) values (gen_random_uuid(), S_FULL2, '4SFB', 2, null, 'bullpen');
    err := 'inserted';
  exception when others then err := sqlerrm; end;
  out := out || ' | half a location: ' || left(err, 60); if err = 'inserted' then fails := fails + 1; end if;

  -- ---------- the parts are locked once saved ----------
  begin
    update public.sessions set charted_intent = false where id = S_FULL;
    err := 'updated';
  exception when others then err := sqlerrm; end;
  out := out || ' | change parts: ' || left(err, 30); if err = 'updated' then fails := fails + 1; end if;

  -- ---------- 8. stats: accuracy only from pitches with both; partial sessions out of baselines ----------
  select pitches, located, scored, hits, strikes, charted_intent, charted_outcome, stats_version into st from public.session_stats where session_id = S_INT;
  out := out || ' | stats Intent-only pen: n' || st.pitches || ' located ' || st.located || ' scored ' || st.scored || ' hits ' || st.hits || ' k ' || st.strikes || ' v' || st.stats_version;
  if st.scored <> 0 or st.hits <> 0 or st.located <> 0 or st.stats_version <> 3 then fails := fails + 1; end if;
  select pitches, located, scored, hits, strikes into st from public.session_stats where session_id = S_OUT;
  out := out || ' | Outcome-only pen: n' || st.pitches || ' located ' || st.located || ' scored ' || st.scored || ' hits ' || st.hits || ' k ' || st.strikes;
  if st.scored <> 0 or st.hits <> 0 or st.located <> 2 then fails := fails + 1; end if;
  select pitches, located, scored, hits into st from public.session_stats where session_id = S_FULL;
  out := out || ' | full pen: n' || st.pitches || ' scored ' || st.scored || ' hits ' || st.hits;
  if st.scored <> 2 or st.hits <> 1 then fails := fails + 1; end if;
  select (game is null) as nogame, pitch_count into st from public.session_stats where session_id = G_INT;
  out := out || ' | Intent-only game: no line ' || st.nogame || ', pitch count ' || st.pitch_count;
  if not st.nogame or st.pitch_count <> 2 then fails := fails + 1; end if;
  select (game ->> 'pitches')::int as gp into st from public.session_stats where session_id = G_OUT;
  out := out || ' | O&R game line pitches ' || coalesce(st.gp::text, 'none'); if st.gp is distinct from 2 then fails := fails + 1; end if;

  -- a later full pen: its baselines count S_FULL (12 pitches needed? c_min_pitches) -- check the filter directly
  select count(*) into n from public.session_stats x where x.pitcher_id = P and x.kind = 'bullpen' and x.charted_intent and x.charted_outcome;
  out := out || ' | pens a baseline may use: ' || n || ' of 3'; if n <> 1 then fails := fails + 1; end if;

  select count(*) into pol1 from pg_policies where schemaname in ('public', 'storage');
  out := out || ' | policies ' || pol0 || '->' || pol1; if pol0 <> pol1 then fails := fails + 1; end if;
  raise exception 'C1A RESULT fails=% | %', fails, out;
end $$;
