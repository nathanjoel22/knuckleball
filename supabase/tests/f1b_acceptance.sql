-- F1-B QR join acceptance (staging; everything rolled back -- the block ends by raising its results).
-- Fixture logins (example.invalid): M a facility manager, CA and CB its coaches, X an outside coach, PAR a parent with a
-- player KID, ADL an adult pitcher, TEEN a 13-17 pitcher with their own login, NEW a login that hasn't answered the age
-- question. A softball parent player SB checks the sport refusal.
--   supabase db query --linked --project-ref wpsscxwawgiwmifpjpec -f supabase/tests/f1b_acceptance.sql
do $$
declare
  M uuid := 'aaaaaaaa-0000-4000-8000-00000000e101'; CA uuid := 'aaaaaaaa-0000-4000-8000-00000000e102';
  CB uuid := 'aaaaaaaa-0000-4000-8000-00000000e103'; X uuid := 'aaaaaaaa-0000-4000-8000-00000000e104';
  PAR uuid := 'aaaaaaaa-0000-4000-8000-00000000e105'; ADL uuid := 'aaaaaaaa-0000-4000-8000-00000000e106';
  TEEN uuid := 'aaaaaaaa-0000-4000-8000-00000000e107'; NEW uuid := 'aaaaaaaa-0000-4000-8000-00000000e108';
  KID uuid; SB uuid; tok text; org uuid; FB uuid; mBB uuid; gA uuid; gB uuid; tA text; tB text; tOld text;
  r jsonb; n int; out text := ''; fails int := 0; who record;
begin
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', e || '@example.invalid', md, now(), now()
    from (values (M, 'b-m', '{"full_name":"Mona Manager","intended_role":"coach","intended_sport":"baseball"}'::jsonb),
                 (CA, 'b-ca', '{}'::jsonb), (CB, 'b-cb', '{}'::jsonb), (X, 'b-x', '{}'::jsonb), (PAR, 'b-par', '{}'::jsonb),
                 (ADL, 'b-adl', '{}'::jsonb), (TEEN, 'b-teen', '{}'::jsonb), (NEW, 'b-new', '{}'::jsonb)) x(u, e, md);
  insert into public.profiles (id, role, full_name, sport) values (CA, 'coach', 'Coach A', 'baseball'), (CB, 'coach', 'Coach B', 'baseball'),
    (X, 'coach', 'Outside Coach', 'baseball'), (PAR, 'parent', 'Pat Parent', null), (ADL, 'pitcher', 'Ada Adult', 'baseball'),
    (TEEN, 'pitcher', 'Tia Teen', 'baseball'), (NEW, 'pitcher', 'Ned New', 'baseball');
  update public.profiles set email_verified_at = now(), age_attestation = 'adult', attested_at = now(), attested_via = 'signup', terms_version = '2026-10-17'
   where id in (M, CA, CB, X, PAR, ADL);
  update public.profiles set age_attestation = 'minor_13_17', attested_at = now(), attested_via = 'signup', terms_version = '2026-10-17',
         guardian_email = 'g@example.invalid', guardian_consented_at = now() where id = TEEN;
  perform set_config('request.jwt.claims', json_build_object('sub', PAR, 'role', 'authenticated')::text, true); set local role authenticated;
  KID := (public.add_player('Kit Kid', 'baseball', 'R', true) ->> 'id')::uuid;
  SB := (public.add_player('Sky Softball', 'softball', 'R', true) ->> 'id')::uuid;
  reset role;
  insert into public.facility_invites (facility_name, manager_email, baseball_level, softball_level)
    values ('B Test Facility', 'b-m@example.invalid', 'high_school', 'high_school_up') returning token into tok;
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  org := (public.create_facility(tok) ->> 'org_id')::uuid;
  reset role;
  update public.profiles set email_verified_at = now(), age_attestation = 'adult', attested_at = now(), attested_via = 'signup', terms_version = '2026-10-17' where account_id = M;
  select id, coach_id into FB, mBB from public.teams where org_id = org and sport = 'baseball';
  insert into public.team_coaches (team_id, coach_id, role, invited_by) values (FB, CA, 'assistant', mBB), (FB, CB, 'assistant', mBB);
  select id, join_token into gA, tA from public.coach_groups where team_id = FB and coach_id = CA;
  select id, join_token into gB, tB from public.coach_groups where team_id = FB and coach_id = CB;

  -- 1. what a code says before signing in
  set local role anon;
  r := public.group_join_info(tA);
  out := '1 info(anon): ' || (r ->> 'status') || ' / ' || (r ->> 'coach_name') || ' at ' || (r ->> 'facility_name') || ' / ' || (r ->> 'sport')
      || '; bad code ' || (public.group_join_info('nope') ->> 'status');
  reset role;

  -- 2. who sees which codes
  out := out || ' | 2 my codes:';
  for who in select * from (values ('M', M), ('CA', CA), ('CB', CB), ('X', X), ('PAR', PAR)) t(nm, id) loop
    perform set_config('request.jwt.claims', json_build_object('sub', who.id, 'role', 'authenticated')::text, true); set local role authenticated;
    r := public.my_group_codes();
    out := out || ' ' || who.nm || '=[' || coalesce((select string_agg((e ->> 'coach_name') || case when (e ->> 'mine')::boolean then '*' else '' end, ',') from jsonb_array_elements(r) e), '') || ']';
    reset role;
  end loop;

  -- 3. joining by code
  out := out || ' | 3 join:';
  for who in select * from (values ('PAR as KID', PAR, KID, tA), ('PAR as KID again', PAR, KID, tA), ('PAR as KID via B', PAR, KID, tB),
                                    ('ADL self', ADL, null::uuid, tA), ('TEEN self', TEEN, null::uuid, tA), ('NEW (no age)', NEW, null::uuid, tA),
                                    ('CA (coach)', CA, null::uuid, tB), ('PAR as softball SB', PAR, SB, tA), ('PAR bad code', PAR, KID, 'nope'),
                                    ('PAR other''s player', PAR, ADL, tA)) t(nm, id, prof, tk) loop
    perform set_config('request.jwt.claims', json_build_object('sub', who.id, 'role', 'authenticated')::text, true); set local role authenticated;
    begin
      r := public.join_group_via_token(who.tk, who.prof);
      out := out || ' ' || who.nm || '=' || coalesce(r ->> 'error', case when (r ->> 'already')::boolean then 'already' else 'ok' end);
      if (who.nm in ('PAR as KID', 'PAR as KID again', 'PAR as KID via B', 'ADL self')) <> (r ->> 'ok' = 'true') then fails := fails + 1; out := out || '(FAIL)'; end if;
    exception when others then
      out := out || ' ' || who.nm || '=' || sqlerrm; set local role authenticated;
      if who.nm <> 'PAR as softball SB' then fails := fails + 1; out := out || '(FAIL)'; end if;
    end;
    reset role;
  end loop;
  out := out || '; KID on side ' || exists (select 1 from public.pitcher_teams where pitcher_id = KID and team_id = FB)
             || ', groups ' || (select string_agg(cp.full_name || case when m.flagged_new then '(New)' else '' end, ',' order by cp.full_name)
                                  from public.coach_group_members m join public.coach_groups g on g.id = m.group_id join public.profiles cp on cp.id = g.coach_id where m.pitcher_id = KID)
             || '; TEEN on side ' || exists (select 1 from public.pitcher_teams where pitcher_id = TEEN and team_id = FB);

  -- 4. regenerate: who may; the old code stops; joined pitchers stay
  out := out || ' | 4 regenerate:';
  for who in select * from (values ('X', X, gA), ('CB on A', CB, gA), ('PAR', PAR, gA), ('CA own', CA, gA), ('M on B', M, gB)) t(nm, id, g) loop
    perform set_config('request.jwt.claims', json_build_object('sub', who.id, 'role', 'authenticated')::text, true); set local role authenticated;
    r := public.rotate_group_code(who.g);
    out := out || ' ' || who.nm || '=' || coalesce(r ->> 'error', 'ok');
    if (who.nm in ('CA own', 'M on B')) <> (r ->> 'ok' = 'true') then fails := fails + 1; out := out || '(FAIL)'; end if;
    reset role;
  end loop;
  select join_token into tOld from public.coach_groups where id = gA;   -- (tOld = the new code here)
  set local role anon;
  out := out || '; old A code ' || (public.group_join_info(tA) ->> 'status') || ', new A code ' || (public.group_join_info(tOld) ->> 'status');
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', ADL, 'role', 'authenticated')::text, true); set local role authenticated;
  out := out || ', join with old A code=' || coalesce(public.join_group_via_token(tA, null) ->> 'error', 'ok');
  reset role;
  out := out || ', KID still in A ' || exists (select 1 from public.coach_group_members where group_id = gA and pitcher_id = KID);

  -- 5. the token stays unreadable directly
  perform set_config('request.jwt.claims', json_build_object('sub', CA, 'role', 'authenticated')::text, true); set local role authenticated;
  begin
    select count(*) into n from (select join_token from public.coach_groups) x;
    out := out || ' | 5 direct token read=' || n || '(FAIL)'; fails := fails + 1;
  exception when insufficient_privilege then out := out || ' | 5 direct token read=denied'; set local role authenticated;
  end;
  reset role;

  -- 6. archived side: codes stop
  update public.teams set archived_at = now() where id = FB;
  select join_token into tB from public.coach_groups where id = gB;
  set local role anon;
  out := out || ' | 6 archived: info ' || (public.group_join_info(tB) ->> 'status');
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', PAR, 'role', 'authenticated')::text, true); set local role authenticated;
  out := out || ', join ' || coalesce(public.join_group_via_token(tB, KID) ->> 'error', 'ok');
  reset role;

  out := out || ' | policies ' || (select count(*) from pg_policies where schemaname = 'public') || ' | hard fails ' || fails;
  raise exception 'B(rolled back):%', out;
end $$;
