-- N1 Stage G acceptance: facility branding (set_facility_branding, my_facility_brandings, the facility-logos rules).
-- Staging; everything rolled back (the block ends by raising its results). Fixture logins at example.invalid.
do $$
declare
  M  uuid := 'dddddddd-0000-4000-8000-00000000f001'; CA uuid := 'dddddddd-0000-4000-8000-00000000f002';
  M2 uuid := 'dddddddd-0000-4000-8000-00000000f003'; HT uuid := 'dddddddd-0000-4000-8000-00000000f004';
  X  uuid := 'dddddddd-0000-4000-8000-00000000f005'; L  uuid := 'dddddddd-0000-4000-8000-00000000f006';
  P1 uuid := 'dddddddd-0000-4000-8000-00000000f011';
  orgA uuid; orgB uuid; FB uuid; T uuid; tok text; r jsonb; n int; ok boolean; out text := ''; fails int := 0;
begin
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', e || '@example.invalid',
         jsonb_build_object('full_name', nm, 'intended_role', ro, 'intended_sport', 'baseball'), now(), now()
    from (values (M, 'n1g-m', 'Mgr A', 'coach'), (CA, 'n1g-ca', 'Coach A', 'coach'), (M2, 'n1g-m2', 'Mgr B', 'coach'),
                 (HT, 'n1g-ht', 'Team Head', 'coach'), (X, 'n1g-x', 'Outsider', 'coach'), (L, 'n1g-l', 'Linked Parent', 'parent')) x(u, e, nm, ro);
  update public.profiles set email_verified_at = now(), age_attestation = 'adult', attested_at = now(), attested_via = 'signup',
         terms_version = '2026-10-17' where id in (M, CA, M2, HT, X, L);
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
    values (P1, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'n1g-p1@example.invalid', '{}', now(), now());
  insert into public.profiles (id, role, full_name, sport, email_verified_at, age_attestation, attested_at, attested_via, terms_version)
    values (P1, 'pitcher', 'Pitcher One', 'baseball', now(), 'adult', now(), 'signup', '2026-10-17');
  -- facility A (manager M, coach CA, pitcher P1 with a linked parent L), facility B (manager M2), a normal team T
  tok := encode(gen_random_bytes(32), 'hex');
  insert into public.facility_invites (token, facility_name, manager_email, baseball_level, softball_level, expires_at)
    values (tok, 'N1G Facility A', 'n1g-m@example.invalid', 'high_school', 'high_school_up', now() + interval '1 day');
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated', 'email', 'n1g-m@example.invalid')::text, true);
  set local role authenticated; r := public.create_facility(tok); reset role;
  orgA := (r ->> 'org_id')::uuid;
  select id into FB from public.teams where org_id = orgA and sport = 'baseball';
  tok := encode(gen_random_bytes(32), 'hex');
  insert into public.facility_invites (token, facility_name, manager_email, baseball_level, softball_level, expires_at)
    values (tok, 'N1G Facility B', 'n1g-m2@example.invalid', 'high_school', 'high_school_up', now() + interval '1 day');
  perform set_config('request.jwt.claims', json_build_object('sub', M2, 'role', 'authenticated', 'email', 'n1g-m2@example.invalid')::text, true);
  set local role authenticated; r := public.create_facility(tok); reset role;
  orgB := (r ->> 'org_id')::uuid;
  insert into public.team_coaches (team_id, coach_id, role) values (FB, CA, 'assistant');
  insert into public.pitcher_teams (pitcher_id, team_id, joined_at) values (P1, FB, now() - interval '30 days');
  insert into public.player_links (player_id, login, role) values (P1, L, 'guardian');
  T := public._create_team_with_head(HT, 'N1G Ordinary Team');

  -- (1)-(4) writes
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.set_facility_branding(orgA, '#13294B', '#F26B3A', orgA::text || '/logo.png'); out := out || '(1) manager sets: ' || coalesce(r ->> 'error', 'ok');
  if r ->> 'ok' <> 'true' then fails := fails + 1; end if;
  r := public.set_facility_branding(orgA, 'navy', '#F26B3A', null); out := out || ' | (4) bad hex: ' || coalesce(r ->> 'error', 'ok');
  if r ->> 'ok' = 'true' then fails := fails + 1; end if;
  r := public.set_facility_branding(orgA, '#13294B', '#F26B3A', orgB::text || '/logo.png'); out := out || ', other facility''s logo path: ' || coalesce(r ->> 'error', 'ok');
  if r ->> 'ok' = 'true' then fails := fails + 1; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', CA, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.set_facility_branding(orgA, '#000000', '#FFFFFF', null); out := out || ' | (2) pitching coach: ' || coalesce(r ->> 'error', 'ok');
  if r ->> 'ok' = 'true' then fails := fails + 1; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', M2, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.set_facility_branding(orgA, '#000000', '#FFFFFF', null); out := out || ' | (3) other facility''s manager: ' || coalesce(r ->> 'error', 'ok');
  if r ->> 'ok' = 'true' then fails := fails + 1; end if;
  reset role;

  -- (5) reads: members get the row, others none
  out := out || ' | (5) reads:';
  for r in select * from jsonb_array_elements(jsonb_build_array(
      jsonb_build_object('k', 'manager', 'who', M, 'want', true), jsonb_build_object('k', 'coach', 'who', CA, 'want', true),
      jsonb_build_object('k', 'pitcher', 'who', P1, 'want', true), jsonb_build_object('k', 'linked parent', 'who', L, 'want', true),
      jsonb_build_object('k', 'other manager', 'who', M2, 'want', false), jsonb_build_object('k', 'normal head', 'who', HT, 'want', false),
      jsonb_build_object('k', 'outsider', 'who', X, 'want', false))) loop
    perform set_config('request.jwt.claims', json_build_object('sub', r ->> 'who', 'role', 'authenticated')::text, true); set local role authenticated;
    select count(*) into n from public.my_facility_brandings() b where b.org_id = orgA and b.brand_color = '#13294B';
    reset role;
    out := out || ' ' || (r ->> 'k') || '=' || n;
    if (n > 0) <> (r ->> 'want')::boolean then fails := fails + 1; end if;
  end loop;

  -- (6) storage rules
  out := out || ' | (6) storage:';
  for r in select * from jsonb_array_elements(jsonb_build_array(
      jsonb_build_object('k', 'manager upload', 'who', M, 'want', true), jsonb_build_object('k', 'coach upload', 'who', CA, 'want', false),
      jsonb_build_object('k', 'outsider upload', 'who', X, 'want', false))) loop
    perform set_config('request.jwt.claims', json_build_object('sub', r ->> 'who', 'role', 'authenticated')::text, true); set local role authenticated;
    begin
      insert into storage.objects (bucket_id, name, owner) values ('facility-logos', orgA::text || '/logo.png', (r ->> 'who')::uuid);
      ok := true;
    exception when others then ok := false; end;
    reset role;
    out := out || ' ' || (r ->> 'k') || '=' || case when ok then 'allowed' else 'refused' end;
    if ok <> (r ->> 'want')::boolean then fails := fails + 1; end if;
  end loop;
  for r in select * from jsonb_array_elements(jsonb_build_array(
      jsonb_build_object('k', 'pitcher reads', 'who', P1, 'want', true), jsonb_build_object('k', 'outsider reads', 'who', X, 'want', false))) loop
    perform set_config('request.jwt.claims', json_build_object('sub', r ->> 'who', 'role', 'authenticated')::text, true); set local role authenticated;
    select count(*) into n from storage.objects where bucket_id = 'facility-logos' and name = orgA::text || '/logo.png';
    reset role;
    out := out || ' ' || (r ->> 'k') || '=' || n;
    if (n > 0) <> (r ->> 'want')::boolean then fails := fails + 1; end if;
  end loop;

  -- (7) an archived side returns no row
  update public.teams set archived_at = now() where id = FB;
  perform set_config('request.jwt.claims', json_build_object('sub', P1, 'role', 'authenticated')::text, true); set local role authenticated;
  select count(*) into n from public.my_facility_brandings();
  reset role;
  out := out || ' | (7) archived side, pitcher rows ' || n;
  if n <> 0 then fails := fails + 1; end if;

  out := out || ' | (8) public policies ' || (select count(*) from pg_policies where schemaname = 'public')
             || ', storage policies ' || (select count(*) from pg_policies where schemaname = 'storage');
  if (select count(*) from pg_policies where schemaname = 'public') <> 32 then fails := fails + 1; end if;
  out := out || ' | fails ' || fails;
  raise exception 'N1G(rolled back):%', out;
end $$;
