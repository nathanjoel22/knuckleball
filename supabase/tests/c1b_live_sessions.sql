-- C1 Stage B acceptance, database part (staging; everything rolled back -- the block ends by raising its results).
-- Fixture logins (example.invalid): H head of team T, H2 an assistant of T, P a pitcher on T (own login), O the head of
-- another team T2 that P is also on (an R4 reader), PAR a parent with a created player K on T, FAM view-only family
-- linked to K, Z nobody; a facility: M its manager, CA a coach with a one-session assignment for P2. Checks are numbered
-- after the packet's "Done when" 9-14.
do $$
declare
  H uuid := 'aaaaaaaa-0000-4000-8000-0000000c1b01'; H2 uuid := 'aaaaaaaa-0000-4000-8000-0000000c1b02';
  P uuid := 'aaaaaaaa-0000-4000-8000-0000000c1b03'; O uuid := 'aaaaaaaa-0000-4000-8000-0000000c1b04';
  PAR uuid := 'aaaaaaaa-0000-4000-8000-0000000c1b05'; FAM uuid := 'aaaaaaaa-0000-4000-8000-0000000c1b06';
  Z uuid := 'aaaaaaaa-0000-4000-8000-0000000c1b07'; M uuid := 'aaaaaaaa-0000-4000-8000-0000000c1b08';
  CA uuid := 'aaaaaaaa-0000-4000-8000-0000000c1b09'; P2 uuid := 'aaaaaaaa-0000-4000-8000-0000000c1b0a';
  T uuid; T2 uuid; K uuid; FB uuid; org uuid; tok text; mBB uuid; L uuid; L2 uuid; L3 uuid;
  r jsonb; v jsonb; n int; s1 int; s2 int; s3 int; s4 int; t0 timestamptz; out text := ''; fails int := 0;
  pol0 int; pol1 int; who record; seen text;
begin
  select count(*) into pol0 from pg_policies where schemaname in ('public', 'storage');
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', e || '@example.invalid',
         jsonb_build_object('full_name', nm, 'intended_role', ro, 'intended_sport', 'baseball'), now(), now()
    from (values (H, 'c1b-h', 'Head H', 'coach'), (H2, 'c1b-h2', 'Assistant H2', 'coach'), (O, 'c1b-o', 'Other Head', 'coach'),
                 (PAR, 'c1b-par', 'Pat Parent', 'parent'), (FAM, 'c1b-fam', 'Fam Family', 'parent'), (Z, 'c1b-z', 'Zoe Nobody', 'pitcher'),
                 (M, 'c1b-m', 'Mo Manager', 'coach'), (CA, 'c1b-ca', 'Coach A', 'coach'),
                 (P, 'c1b-p', 'Pia Pitcher', 'pitcher'), (P2, 'c1b-p2', 'Pax Pitcher', 'pitcher')) x(u, e, nm, ro);
  insert into public.profiles (id, role, full_name, sport) select x.u, x.ro, x.nm, x.sp
    from (values (P, 'pitcher', 'Pia Pitcher', 'baseball'), (P2, 'pitcher', 'Pax Pitcher', 'baseball'), (Z, 'pitcher', 'Zoe Nobody', 'baseball'),
                 (PAR, 'parent', 'Pat Parent', null), (FAM, 'parent', 'Fam Family', null)) x(u, ro, nm, sp)
   where not exists (select 1 from public.profiles where id = x.u);
  update public.profiles set email_verified_at = now(), age_attestation = 'adult', attested_at = now(), attested_via = 'signup', terms_version = '2026-11-20'
   where id in (H, H2, P, O, PAR, FAM, Z, M, CA, P2);
  T := public._create_team_with_head(H, 'C1B Team'); T2 := public._create_team_with_head(O, 'C1B Other');
  insert into public.team_coaches (team_id, coach_id, role, invited_by) values (T, H2, 'assistant', H);
  insert into public.pitcher_teams (pitcher_id, team_id) values (P, T), (P, T2);
  perform set_config('request.jwt.claims', json_build_object('sub', PAR, 'role', 'authenticated')::text, true); set local role authenticated;
  K := (public.add_player('Kid K', 'baseball', 'R', true) ->> 'id')::uuid;
  reset role;
  insert into public.pitcher_teams (pitcher_id, team_id) values (K, T);
  insert into public.player_links (player_id, login, role) values (K, FAM, 'family');
  -- a facility with a one-session assignment
  insert into public.facility_invites (facility_name, manager_email, baseball_level, softball_level)
    values ('C1B Facility', 'c1b-m@example.invalid', 'high_school', 'high_school_up') returning token into tok;
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.create_facility(tok); org := (r ->> 'org_id')::uuid;
  reset role;
  select id, coach_id into FB, mBB from public.teams where org_id = org and sport = 'baseball';
  insert into public.team_coaches (team_id, coach_id, role, invited_by) values (FB, CA, 'assistant', mBB);
  insert into public.pitcher_teams (pitcher_id, team_id) values (P2, FB);
  insert into public.session_assignments (team_id, pitcher_id, coach_id, assigned_by) values (FB, P2, CA, mBB);
  insert into public.sessions (id, pitcher_id, team_id, logged_by, started_at, kind) values (gen_random_uuid(), P2, FB, mBB, now(), 'bullpen');   -- P2's history

  -- ---------- 9. a coach starts with Outcome only; who sees it, who can take Intent ----------
  perform set_config('request.jwt.claims', json_build_object('sub', H, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.live_start(P, T, 'bullpen', 'outcome', H); L := (r ->> 'live_id')::uuid;
  out := out || '9 start: ' || coalesce(r ->> 'error', 'ok');
  if L is null then fails := fails + 1; end if;
  r := public.live_start(P, T, 'bullpen', 'outcome', H);
  out := out || ', a second start: ' || coalesce(r ->> 'error', 'ok!'); if r ->> 'error' is distinct from 'live_exists' then fails := fails + 1; end if;
  reset role;
  seen := '';
  for who in select * from (values ('H', H), ('H2', H2), ('P', P), ('O', O), ('PAR', PAR), ('FAM', FAM), ('Z', Z), ('CA', CA)) t(nm, id) loop
    perform set_config('request.jwt.claims', json_build_object('sub', who.id, 'role', 'authenticated')::text, true); set local role authenticated;
    v := public.live_summary();
    seen := seen || who.nm || ':' || (select count(*) from jsonb_array_elements(v) e where (e ->> 'live_id')::uuid = L) || ' ';
    reset role;
  end loop;
  out := out || ' | marks for L: ' || seen;
  if seen <> 'H:0 H2:1 P:1 O:0 PAR:0 FAM:0 Z:0 CA:0 ' then fails := fails + 1; end if;
  -- join: Z refused; P takes Intent; H2 then finds it taken
  perform set_config('request.jwt.claims', json_build_object('sub', Z, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.live_join(L, 'intent', Z); out := out || ' | Z joins: ' || coalesce(r ->> 'error', 'ok!'); if r ->> 'error' is distinct from 'not_entitled' then fails := fails + 1; end if;
  r := public.live_poll(L, 0); out := out || ', Z polls: ' || coalesce(r ->> 'error', 'ok!'); if r ->> 'error' is distinct from 'not_holding' then fails := fails + 1; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.live_join(L, 'intent', P); out := out || ' | P takes Intent: ' || coalesce(r ->> 'error', 'ok') || ' from ' || (r ->> 'from_seq');
  if r ->> 'ok' is distinct from 'true' then fails := fails + 1; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', H2, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.live_join(L, 'intent', H2); out := out || ', H2 then: ' || coalesce(r ->> 'error', 'ok!'); if r ->> 'error' is distinct from 'taken' then fails := fails + 1; end if;
  v := public.live_summary(); out := out || ', H2 marks now: ' || jsonb_array_length(v);
  reset role;

  -- ---------- 10-12. in step: Outcome waits for the call; Back locks; No pitch; Chart without it ----------
  perform set_config('request.jwt.claims', json_build_object('sub', H, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.live_put_outcome(L, null, '{"actual_row": 2, "actual_col": 2}');
  out := out || ' | 10 outcome before any call: ' || coalesce(r ->> 'error', 'ok!'); if r ->> 'error' is distinct from 'wait_for_intent' then fails := fails + 1; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.live_put_intent(L, 'Slider', 1, 3, 'R'); s1 := (r ->> 'seq')::int;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', H, 'role', 'authenticated')::text, true); set local role authenticated;
  v := public.live_poll(L, 0);
  out := out || ', H sees seq ' || (v -> 'pitches' -> 0 ->> 'seq') || ' type ' || (v -> 'pitches' -> 0 ->> 'type');
  if v -> 'pitches' -> 0 ->> 'type' is distinct from 'Slider' then fails := fails + 1; end if;
  r := public.live_put_outcome(L, s1, '{"actual_row": 1, "actual_col": 3}'); out := out || ', outcome on it: ' || coalesce(r ->> 'error', 'ok');
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.live_unconfirm(L, s1); out := out || ' | 12 Back after the outcome: ' || coalesce(r ->> 'error', 'ok!'); if r ->> 'error' is distinct from 'locked' then fails := fails + 1; end if;
  r := public.live_put_intent(L, 'Curveball', 3, 2, 'R'); s2 := (r ->> 'seq')::int;
  r := public.live_unconfirm(L, s2); out := out || ', Back before it: ' || coalesce(r ->> 'error', 'ok'); if r ->> 'ok' is distinct from 'true' then fails := fails + 1; end if;
  r := public.live_put_intent(L, 'Curveball', 3, 2, 'R'); s2 := (r ->> 'seq')::int;
  r := public.live_put_intent(L, 'Changeup', 3, 1, 'R'); s3 := (r ->> 'seq')::int;
  r := public.live_unconfirm(L, s2); out := out || ', Back after a later call: ' || coalesce(r ->> 'error', 'ok!'); if r ->> 'error' is distinct from 'locked' then fails := fails + 1; end if;
  r := public.live_no_pitch(L, s3); out := out || ' | 11 No pitch: ' || coalesce(r ->> 'error', 'ok');
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', H, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.live_put_outcome(L, s3, '{"actual_row": 2, "actual_col": 2}'); out := out || ', outcome on the no-pitch: ' || coalesce(r ->> 'error', 'ok!');
  if r ->> 'error' is distinct from 'not_open' then fails := fails + 1; end if;
  r := public.live_put_outcome(L, s2, '{"actual_row": 3, "actual_col": 2}');
  r := public.live_put_outcome(L, null, '{"actual_row": 2, "actual_col": 1}', true); s4 := (r ->> 'seq')::int;
  reset role;
  out := out || ', Chart without it: seq ' || s4 || ' skipped ' || (select skipped_intent from public.live_pitches where live_id = L and seq = s4);

  -- ---------- 13. offline, matched by time ----------
  -- P leaves (Intent opens), H charts on alone, P rejoins and sends what it charted offline: one call lines up, one doesn't
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.live_leave(L);
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', H, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.live_put_outcome(L, null, '{"actual_row": 1, "actual_col": 1}');
  out := out || ' | 15 alone after P left: seq ' || coalesce(r ->> 'seq', r ->> 'error');
  reset role;
  select outcome_at into t0 from public.live_pitches where live_id = L and seq = (r ->> 'seq')::int;
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.live_join(L, 'intent', P);
  r := public.live_put_offline(L, jsonb_build_array(
         jsonb_build_object('key', 'a', 'at', t0 - interval '120 seconds', 'type', 'Slider', 'row', 2, 'col', 2, 'side', 'R'),
         jsonb_build_object('key', 'b', 'at', t0 - interval '6 seconds', 'type', 'Slider', 'row', 1, 'col', 1, 'side', 'R')));
  out := out || ' | 13 offline calls: kept ' || (r ->> 'kept') || ', dropped ' || (r ->> 'dropped');
  if (r ->> 'kept')::int <> 1 or (r ->> 'dropped')::int <> 1 then fails := fails + 1; end if;
  r := public.live_put_intent(L, 'Slider', 2, 3, 'L'); s1 := (r ->> 'seq')::int;
  reset role;
  select intent_at into t0 from public.live_pitches where live_id = L and seq = s1;
  perform set_config('request.jwt.claims', json_build_object('sub', H, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.live_put_offline(L, jsonb_build_array(jsonb_build_object('key', 'x', 'at', t0 + interval '7 seconds', 'outcome', '{"actual_row": 2, "actual_col": 3}'::jsonb),
                                                    jsonb_build_object('key', 'y', 'at', t0 + interval '9 seconds', 'outcome', '{"actual_row": 0, "actual_col": 0}'::jsonb)));
  out := out || ', offline outcomes: kept ' || (r ->> 'kept') || ', dropped ' || (r ->> 'dropped');
  if (r ->> 'kept')::int <> 1 or (r ->> 'dropped')::int <> 1 then fails := fails + 1; end if;
  reset role;

  -- ---------- 19 (report). a pitching change: the next pitcher's live session points back ----------
  perform set_config('request.jwt.claims', json_build_object('sub', H, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.live_start(P, T, 'game', 'outcome', H); L3 := (r ->> 'live_id')::uuid;
  r := public.live_start(K, T, 'game', 'outcome', H, L3);
  reset role;
  out := out || ' | pitching change: successor set ' || ((select successor_id from public.live_sessions where id = L3) = (r ->> 'live_id')::uuid);
  if (select successor_id from public.live_sessions where id = L3) is distinct from (r ->> 'live_id')::uuid then fails := fails + 1; end if;

  -- ---------- 14. a one-session-assignment coach joins and still can't read the history ----------
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.live_start(P2, FB, 'game', 'outcome', mBB); L2 := (r ->> 'live_id')::uuid;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', CA, 'role', 'authenticated')::text, true); set local role authenticated;
  v := public.live_summary();
  out := out || ' | 14 CA sees ' || (select count(*) from jsonb_array_elements(v) e where (e ->> 'live_id')::uuid = L2) || ' mark';
  r := public.live_join(L2, 'intent', CA); out := out || ', joins: ' || coalesce(r ->> 'error', 'ok');
  if r ->> 'ok' is distinct from 'true' then fails := fails + 1; end if;
  select count(*) into n from public.sessions where pitcher_id = P2;
  out := out || ', reads P2 sessions: ' || n; if n <> 0 then fails := fails + 1; end if;
  begin
    select count(*) into n from public.live_sessions; out := out || ', reads live tables directly: ' || n || '!'; fails := fails + 1;
  exception when insufficient_privilege then out := out || ', a direct read of the live tables: refused';
  end;
  reset role;
  -- the access the joiner had: none of the tables are granted; policies unchanged
  select count(*) into n from information_schema.role_table_grants where table_name in ('live_sessions', 'live_parts', 'live_pitches') and grantee in ('anon', 'authenticated');
  out := out || ' | grants on the live tables: ' || n; if n <> 0 then fails := fails + 1; end if;
  select count(*) into pol1 from pg_policies where schemaname in ('public', 'storage');
  out := out || ', policies ' || pol0 || '->' || pol1; if pol0 <> pol1 then fails := fails + 1; end if;
  raise exception 'C1B RESULT fails=% | %', fails, out;
end $$;
