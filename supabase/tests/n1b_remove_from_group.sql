-- N1 Stage B (J3, Joel, Nov 16-17 2026) acceptance: remove_from_group never takes a pitcher off a facility side.
-- Staging; everything rolled back (the block ends by raising its results). Fixture logins at example.invalid.
-- Checks: (1) removing the last group keeps the pitcher_teams row, writes no departure, returns left_side false;
-- (2) the manager still sees the pitcher, the old coach no longer does; (3) removing one of two groups leaves the
-- other; (4) "Remove from facility" (the manager's delete of the pitcher_teams row) still ends the membership and logs
-- the departure; (5) callers outside the group are refused as before; (6) policies still 32.
do $$
declare
  M  uuid := 'bbbbbbbb-0000-4000-8000-00000000b001'; CA uuid := 'bbbbbbbb-0000-4000-8000-00000000b002';
  CB uuid := 'bbbbbbbb-0000-4000-8000-00000000b003'; P1 uuid := 'bbbbbbbb-0000-4000-8000-00000000b011';
  P2 uuid := 'bbbbbbbb-0000-4000-8000-00000000b012';
  FB uuid; org uuid; tok text; gA uuid; gB uuid; r jsonb; n int; n2 int; out text := ''; fails int := 0;
begin
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', e || '@example.invalid',
         jsonb_build_object('full_name', nm, 'intended_role', ro, 'intended_sport', 'baseball'), now(), now()
    from (values (M, 'n1b-m', 'Mgr', 'coach'), (CA, 'n1b-ca', 'Coach A', 'coach'), (CB, 'n1b-cb', 'Coach B', 'coach')) x(u, e, nm, ro);
  update public.profiles set email_verified_at = now(), age_attestation = 'adult', attested_at = now(), attested_via = 'signup',
         terms_version = '2026-10-17' where id in (M, CA, CB);
  -- pitchers as the F1-A test makes them: a bare login, then a baseball pitcher profile
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', e || '@example.invalid', '{}', now(), now()
    from (values (P1, 'n1b-p1'), (P2, 'n1b-p2')) x(u, e);
  insert into public.profiles (id, role, full_name, sport, email_verified_at, age_attestation, attested_at, attested_via, terms_version)
    values (P1, 'pitcher', 'Pitcher One', 'baseball', now(), 'adult', now(), 'signup', '2026-10-17'),
           (P2, 'pitcher', 'Pitcher Two', 'baseball', now(), 'adult', now(), 'signup', '2026-10-17');
  -- the facility, made the way facility-signup does it
  tok := encode(gen_random_bytes(32), 'hex');
  insert into public.facility_invites (token, facility_name, manager_email, baseball_level, softball_level, expires_at)
    values (tok, 'N1B Test Facility', 'n1b-m@example.invalid', 'high_school', 'high_school_up', now() + interval '1 day');
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated', 'email', 'n1b-m@example.invalid')::text, true);
  set local role authenticated;
  r := public.create_facility(tok);
  reset role;
  if not coalesce((r ->> 'ok')::boolean, false) then raise exception 'N1B fixture: create_facility %', r; end if;
  org := (r ->> 'org_id')::uuid;
  select id into FB from public.teams where org_id = org and sport = 'baseball';
  -- two coaches on the baseball side, each gets a group by trigger
  insert into public.team_coaches (team_id, coach_id, role) values (FB, CA, 'assistant'), (FB, CB, 'assistant');
  select id into gA from public.coach_groups where team_id = FB and coach_id = CA;
  select id into gB from public.coach_groups where team_id = FB and coach_id = CB;
  -- P1 in coach A's group only; P2 in both groups
  insert into public.pitcher_teams (pitcher_id, team_id) values (P1, FB), (P2, FB);
  insert into public.coach_group_members (group_id, pitcher_id, flagged_new) values (gA, P1, true), (gA, P2, false), (gB, P2, false);

  -- (1) + (5): coach B can't touch coach A's group; coach A removes P1 from their (only) group
  perform set_config('request.jwt.claims', json_build_object('sub', CB, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.remove_from_group(gA, P1);  out := out || ' (5) CB removes from A:' || coalesce(r ->> 'error', 'ok');
  if coalesce(r ->> 'error', '') <> 'not_allowed' then fails := fails + 1; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', CA, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.remove_from_group(gA, P1);  out := out || ' | (1) CA removes P1 last group:' || coalesce(r ->> 'error', 'ok') || ' left_side ' || (r ->> 'left_side');
  if r ->> 'left_side' <> 'false' then fails := fails + 1; end if;
  select count(*) into n from public.pitcher_teams where pitcher_id = P1 and team_id = FB;   -- as CA (RLS)
  reset role;
  select count(*) into n2 from public.pitcher_teams where pitcher_id = P1 and team_id = FB;
  out := out || ' on side ' || n2 || ' departures ' || (select count(*) from public.pitcher_team_departures where pitcher_id = P1 and team_id = FB);
  if n2 <> 1 or exists (select 1 from public.pitcher_team_departures where pitcher_id = P1 and team_id = FB) then fails := fails + 1; end if;
  -- (2) visibility after
  out := out || ' | (2) old coach A sees P1 rows ' || n;
  if n <> 0 then fails := fails + 1; end if;
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  select count(*) into n from public.pitcher_teams where pitcher_id = P1 and team_id = FB;
  reset role;
  out := out || ', manager sees ' || n;
  if n <> 1 then fails := fails + 1; end if;
  -- (3) one of two groups
  perform set_config('request.jwt.claims', json_build_object('sub', CB, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.remove_from_group(gB, P2);  out := out || ' | (3) CB removes P2 (2 groups):' || coalesce(r ->> 'error', 'ok');
  reset role;
  select count(*) into n from public.coach_group_members where pitcher_id = P2;
  out := out || ' groups left ' || n || ', on side ' || (select count(*) from public.pitcher_teams where pitcher_id = P2 and team_id = FB);
  if n <> 1 then fails := fails + 1; end if;
  -- (4) Remove from facility: the manager deletes the membership (the app's confirmRemoveRosterPitcher path)
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  delete from public.pitcher_teams where pitcher_id = P1 and team_id = FB;
  get diagnostics n = row_count;
  reset role;
  out := out || ' | (4) manager removes P1 from facility: rows ' || n || ', departure logged ' || (select count(*) from public.pitcher_team_departures where pitcher_id = P1 and team_id = FB);
  if n <> 1 or not exists (select 1 from public.pitcher_team_departures where pitcher_id = P1 and team_id = FB) then fails := fails + 1; end if;
  out := out || ' | (6) policies ' || (select count(*) from pg_policies where schemaname = 'public');
  if (select count(*) from pg_policies where schemaname = 'public') <> 32 then fails := fails + 1; end if;
  out := out || ' | fails ' || fails;
  raise exception 'N1B(rolled back):%', out;
end $$;
