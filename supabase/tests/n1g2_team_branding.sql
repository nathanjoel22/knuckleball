-- N1 Stage G2 acceptance: team branding (set_team_branding, my_brandings, is_team_reader, the team-logos rules).
-- Staging; everything rolled back (the block ends by raising its results). Fixture logins at example.invalid.
do $$
declare
  HT uuid := 'dddddddd-0000-4000-8000-00000000f101'; AS1 uuid := 'dddddddd-0000-4000-8000-00000000f102';
  HT2 uuid := 'dddddddd-0000-4000-8000-00000000f103'; X uuid := 'dddddddd-0000-4000-8000-00000000f104';
  L  uuid := 'dddddddd-0000-4000-8000-00000000f105'; M  uuid := 'dddddddd-0000-4000-8000-00000000f106';
  P1 uuid := 'dddddddd-0000-4000-8000-00000000f111';
  T uuid; T2 uuid; orgA uuid; FB uuid; tok text; r jsonb; n int; ok boolean; out text := ''; fails int := 0;
begin
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', e || '@example.invalid',
         jsonb_build_object('full_name', nm, 'intended_role', ro, 'intended_sport', 'baseball'), now(), now()
    from (values (HT, 'g2-ht', 'Head', 'coach'), (AS1, 'g2-as', 'Assistant', 'coach'), (HT2, 'g2-ht2', 'Other Head', 'coach'),
                 (X, 'g2-x', 'Outsider', 'coach'), (L, 'g2-l', 'Linked Parent', 'parent'), (M, 'g2-m', 'Fac Mgr', 'coach')) x(u, e, nm, ro);
  update public.profiles set email_verified_at = now(), age_attestation = 'adult', attested_at = now(), attested_via = 'signup',
         terms_version = '2026-10-17' where id in (HT, AS1, HT2, X, L, M);
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
    values (P1, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'g2-p1@example.invalid', '{}', now(), now());
  insert into public.profiles (id, role, full_name, sport, email_verified_at, age_attestation, attested_at, attested_via, terms_version)
    values (P1, 'pitcher', 'Pitcher One', 'baseball', now(), 'adult', now(), 'signup', '2026-10-17');
  -- team T (head HT, assistant AS1, pitcher P1 with linked parent L); team T2 (head HT2); a facility (manager M)
  T := public._create_team_with_head(HT, 'G2 Team');
  T2 := public._create_team_with_head(HT2, 'G2 Other Team');
  insert into public.team_coaches (team_id, coach_id, role) values (T, AS1, 'assistant');
  insert into public.pitcher_teams (pitcher_id, team_id, joined_at) values (P1, T, now() - interval '30 days');
  insert into public.player_links (player_id, login, role) values (P1, L, 'guardian');
  tok := encode(gen_random_bytes(32), 'hex');
  insert into public.facility_invites (token, facility_name, manager_email, baseball_level, softball_level, expires_at)
    values (tok, 'G2 Facility', 'g2-m@example.invalid', 'high_school', 'high_school_up', now() + interval '1 day');
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated', 'email', 'g2-m@example.invalid')::text, true);
  set local role authenticated; r := public.create_facility(tok); reset role;
  orgA := (r ->> 'org_id')::uuid;
  select id into FB from public.teams where org_id = orgA and sport = 'baseball';

  -- (1) the head sets; (3) bad hex / another team's path
  perform set_config('request.jwt.claims', json_build_object('sub', HT, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.set_team_branding(T, '#7A1F2B', '#E8B04A', T::text || '/logo.png'); out := out || '(1) head sets: ' || coalesce(r ->> 'error', 'ok');
  if r ->> 'ok' <> 'true' then fails := fails + 1; end if;
  r := public.set_team_branding(T, 'maroon', '#E8B04A', null); out := out || ' | (3) bad hex: ' || coalesce(r ->> 'error', 'ok');
  if coalesce(r ->> 'error', '') <> 'bad_color' then fails := fails + 1; end if;
  r := public.set_team_branding(T, '#7A1F2B', '#E8B04A', T2::text || '/logo.png'); out := out || ', other team''s path: ' || coalesce(r ->> 'error', 'ok');
  if coalesce(r ->> 'error', '') <> 'bad_logo_path' then fails := fails + 1; end if;
  r := public.set_team_branding(T, '#7A1F2B', null, null); out := out || ', one color: ' || coalesce(r ->> 'error', 'ok');
  if coalesce(r ->> 'error', '') <> 'both_colors' then fails := fails + 1; end if;
  reset role;
  -- (2) not the head
  out := out || ' | (2)';
  for r in select * from jsonb_array_elements(jsonb_build_array(
      jsonb_build_object('k', 'assistant', 'who', AS1), jsonb_build_object('k', 'pitcher', 'who', P1),
      jsonb_build_object('k', 'other head', 'who', HT2), jsonb_build_object('k', 'outsider', 'who', X))) loop
    perform set_config('request.jwt.claims', json_build_object('sub', r ->> 'who', 'role', 'authenticated')::text, true); set local role authenticated;
    r := jsonb_build_object('k', r ->> 'k', 'res', public.set_team_branding(T, '#000000', '#FFFFFF', null));
    reset role;
    out := out || ' ' || (r ->> 'k') || '=' || coalesce(r -> 'res' ->> 'error', 'ok');
    if coalesce(r -> 'res' ->> 'error', '') <> 'not_allowed' then fails := fails + 1; end if;
  end loop;
  -- (4) a facility side; an archived team
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.set_team_branding(FB, '#000000', '#FFFFFF', null); reset role;
  out := out || ' | (4) facility side: ' || coalesce(r ->> 'error', 'ok');
  if coalesce(r ->> 'error', '') <> 'use_facility_look' then fails := fails + 1; end if;
  update public.teams set archived_at = now() where id = T2;
  perform set_config('request.jwt.claims', json_build_object('sub', HT2, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.set_team_branding(T2, '#000000', '#FFFFFF', null); reset role;
  out := out || ', archived: ' || coalesce(r ->> 'error', 'ok');
  if coalesce(r ->> 'error', '') <> 'team_archived' then fails := fails + 1; end if;
  update public.teams set archived_at = null where id = T2;

  -- (5) reads, and facility rows identical to my_facility_brandings()
  out := out || ' | (5) reads:';
  for r in select * from jsonb_array_elements(jsonb_build_array(
      jsonb_build_object('k', 'head', 'who', HT, 'want', true), jsonb_build_object('k', 'assistant', 'who', AS1, 'want', true),
      jsonb_build_object('k', 'pitcher', 'who', P1, 'want', true), jsonb_build_object('k', 'linked parent', 'who', L, 'want', true),
      jsonb_build_object('k', 'other head', 'who', HT2, 'want', false), jsonb_build_object('k', 'outsider', 'who', X, 'want', false),
      jsonb_build_object('k', 'facility mgr', 'who', M, 'want', false))) loop
    perform set_config('request.jwt.claims', json_build_object('sub', r ->> 'who', 'role', 'authenticated')::text, true); set local role authenticated;
    select count(*) into n from public.my_brandings() b where b.team_id = T and b.brand_color = '#7A1F2B' and b.org_id is null;
    reset role;
    out := out || ' ' || (r ->> 'k') || '=' || n;
    if (n > 0) <> (r ->> 'want')::boolean then fails := fails + 1; end if;
  end loop;
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  select count(*) into n from (
    (select team_id, org_id, name, brand_color, accent_color, logo_path, updated_at from public.my_brandings() where org_id is not null
     except select * from public.my_facility_brandings())
    union all
    (select * from public.my_facility_brandings()
     except select team_id, org_id, name, brand_color, accent_color, logo_path, updated_at from public.my_brandings() where org_id is not null)) d;
  reset role;
  out := out || ', facility rows differ: ' || n;
  if n <> 0 then fails := fails + 1; end if;

  -- (6) storage rules
  out := out || ' | (6) storage:';
  for r in select * from jsonb_array_elements(jsonb_build_array(
      jsonb_build_object('k', 'head upload', 'who', HT, 'want', true), jsonb_build_object('k', 'assistant upload', 'who', AS1, 'want', false),
      jsonb_build_object('k', 'outsider upload', 'who', X, 'want', false))) loop
    perform set_config('request.jwt.claims', json_build_object('sub', r ->> 'who', 'role', 'authenticated')::text, true); set local role authenticated;
    begin
      insert into storage.objects (bucket_id, name, owner) values ('team-logos', T::text || '/logo.png', (r ->> 'who')::uuid);
      ok := true;
    exception when others then ok := false; end;
    reset role;
    out := out || ' ' || (r ->> 'k') || '=' || case when ok then 'allowed' else 'refused' end;
    if ok <> (r ->> 'want')::boolean then fails := fails + 1; end if;
  end loop;
  for r in select * from jsonb_array_elements(jsonb_build_array(
      jsonb_build_object('k', 'pitcher reads', 'who', P1, 'want', true), jsonb_build_object('k', 'outsider reads', 'who', X, 'want', false))) loop
    perform set_config('request.jwt.claims', json_build_object('sub', r ->> 'who', 'role', 'authenticated')::text, true); set local role authenticated;
    select count(*) into n from storage.objects where bucket_id = 'team-logos' and name = T::text || '/logo.png';
    reset role;
    out := out || ' ' || (r ->> 'k') || '=' || n;
    if (n > 0) <> (r ->> 'want')::boolean then fails := fails + 1; end if;
  end loop;

  -- archived team: no row
  update public.teams set archived_at = now() where id = T;
  perform set_config('request.jwt.claims', json_build_object('sub', P1, 'role', 'authenticated')::text, true); set local role authenticated;
  select count(*) into n from public.my_brandings() where team_id = T;
  reset role;
  out := out || ' | archived team rows ' || n;
  if n <> 0 then fails := fails + 1; end if;

  out := out || ' | (7) public policies ' || (select count(*) from pg_policies where schemaname = 'public')
             || ', storage policies ' || (select count(*) from pg_policies where schemaname = 'storage');
  if (select count(*) from pg_policies where schemaname = 'public') <> 32 then fails := fails + 1; end if;
  if (select count(*) from pg_policies where schemaname = 'storage') <> 12 then fails := fails + 1; end if;
  out := out || ' | fails ' || fails;
  raise exception 'N1G2(rolled back):%', out;
end $$;
