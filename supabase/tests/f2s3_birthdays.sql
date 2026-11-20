-- F2 Stage 3 acceptance, database part (staging; everything rolled back -- the block ends by raising its results).
-- Fixture logins (example.invalid; made-up dates relative to today, never a real person's): PA a pitcher attested
-- adult, PM a pitcher attested 13-17, PAR a parent with two created players (K1, K2), G a linked guardian of K1, C a
-- coach with a coach-added player (CK) and a pitcher PA on their team, plus a facility manager M. Checks numbered after
-- the packet's "Done when" 17-23.
do $$
declare
  PA uuid := 'aaaaaaaa-0000-4000-8000-0000000f3a01'; PM uuid := 'aaaaaaaa-0000-4000-8000-0000000f3a02';
  PAR uuid := 'aaaaaaaa-0000-4000-8000-0000000f3a03'; G uuid := 'aaaaaaaa-0000-4000-8000-0000000f3a04';
  C uuid := 'aaaaaaaa-0000-4000-8000-0000000f3a05'; M uuid := 'aaaaaaaa-0000-4000-8000-0000000f3a06';
  K1 uuid; K2 uuid; CK uuid; team uuid; org uuid; tok text; FB uuid;
  today date := (now() at time zone 'America/New_York')::date;
  r jsonb; n int; v text; out text := ''; fails int := 0; pol0 int; pol1 int; s_before text; s_after text; lv text;
begin
  select count(*) into pol0 from pg_policies where schemaname in ('public', 'storage');
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', e || '@example.invalid',
         jsonb_build_object('full_name', nm, 'intended_role', ro, 'intended_sport', 'baseball'), now(), now()
    from (values (PA, 'f2s3-pa', 'Adult Pitcher', 'pitcher'), (PM, 'f2s3-pm', 'Teen Pitcher', 'pitcher'), (PAR, 'f2s3-par', 'Pat Parent', 'parent'),
                 (G, 'f2s3-g', 'Second Parent', 'parent'), (C, 'f2s3-c', 'Coach Cole', 'coach'), (M, 'f2s3-m', 'Morgan Manager', 'coach')) x(u, e, nm, ro);
  insert into public.profiles (id, role, full_name, sport) select x.u, x.ro, x.nm, x.sp from (values (PA, 'pitcher', 'Adult Pitcher', 'baseball'), (PM, 'pitcher', 'Teen Pitcher', 'baseball'),
    (PAR, 'parent', 'Pat Parent', null), (G, 'parent', 'Second Parent', null)) x(u, ro, nm, sp) where not exists (select 1 from public.profiles where id = x.u);
  update public.profiles set email_verified_at = now(), age_attestation = 'adult', attested_at = now(), attested_via = 'signup', terms_version = '2026-10-14'
   where id in (PA, PAR, G, C, M);
  update public.profiles set age_attestation = 'minor_13_17', attested_at = now(), attested_via = 'signup', terms_version = '2026-10-14', guardian_consented_at = now() where id = PM;
  update public.profiles set level = 'little_league' where id in (PA, PM);
  perform set_config('request.jwt.claims', json_build_object('sub', PAR, 'role', 'authenticated')::text, true); set local role authenticated;
  K1 := (public.add_player('Kid One', 'baseball', 'R', true) ->> 'id')::uuid; K2 := (public.add_player('Kid Two', 'baseball', 'L', true) ->> 'id')::uuid;
  reset role;
  insert into public.player_links (player_id, login, role) values (K1, G, 'guardian');
  perform set_config('request.jwt.claims', json_build_object('sub', C, 'role', 'authenticated')::text, true); set local role authenticated;
  team := public.create_team('F2S3 Team', C);
  CK := (public.add_player('Coach Kid', 'baseball', 'R', true) ->> 'id')::uuid;
  reset role;
  insert into public.pitcher_teams (pitcher_id, team_id) values (PA, team), (PM, team), (K1, team), (CK, team);
  insert into public.facility_invites (facility_name, manager_email, baseball_level, softball_level)
    values ('F2S3 Facility', 'f2s3-m@example.invalid', 'high_school', 'high_school_up') returning token into tok;
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.create_facility(tok); org := (r ->> 'org_id')::uuid;
  reset role;
  select id into FB from public.teams where org_id = org and sport = 'baseball';
  insert into public.pitcher_teams (pitcher_id, team_id) values (PA, FB), (K2, FB);

  -- ---------- 17. a new pitcher's birthday, driven by the date; contradictions are not saved ----------
  perform set_config('request.jwt.claims', json_build_object('sub', PA, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.set_birthday(PA, (today - interval '16 years')::date, false);
  out := out || ' 17a said 18+, date 16: ' || coalesce(r ->> 'error', 'saved!'); if r ->> 'error' is distinct from 'contradiction' then fails := fails + 1; end if;
  r := public.set_birthday(PA, (today - interval '19 years')::date + 3, false);
  out := out || ' | said 18+, date 18: ' || coalesce(r ->> 'error', 'saved'); if r ->> 'ok' is distinct from 'true' then fails := fails + 1; end if;
  r := public.set_birthday(PA, today + 1, false);
  out := out || ' | a future date: ' || (r ->> 'error');
  r := public.set_birthday(PA, null, true);
  out := out || ' | "I don''t know" on his own: ' || (r ->> 'error'); if r ->> 'error' is distinct from 'date_required' then fails := fails + 1; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', PM, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.set_birthday(PM, (today - interval '11 years')::date, false);
  out := out || ' | said 13-17, date 11: ' || coalesce(r ->> 'error', 'saved!'); if r ->> 'error' is distinct from 'contradiction' then fails := fails + 1; end if;
  r := public.set_birthday(PM, (today - interval '14 years')::date - 20, false);
  out := out || ', date 14: ' || coalesce(r ->> 'error', 'saved');
  reset role;
  select count(*) into n from public.birthday_contradictions where profile_id in (PA, PM);
  out := out || ' | operator list: ' || n || ' (' || (select string_agg(attested || '->' || by_date, ', ' order by at) from public.birthday_contradictions where profile_id in (PA, PM)) || ')';

  -- ---------- 18. a parent's players need a date; a coach-added player may be "I don't know" ----------
  perform set_config('request.jwt.claims', json_build_object('sub', PAR, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.set_birthday(K1, null, true);
  out := out || ' | 18a parent says I don''t know: ' || (r ->> 'error'); if r ->> 'error' is distinct from 'date_required' then fails := fails + 1; end if;
  r := public.set_birthday(K1, (today - interval '12 years')::date, false); out := out || ', K1 age 12: ' || coalesce(r ->> 'error', 'saved');
  r := public.my_birthdays();
  out := out || ' | parent''s list: ' || jsonb_array_length(r) || ' (' || (select string_agg((e ->> 'name') || ':' || (e ->> 'access') || ':' || case when (e ->> 'answered')::boolean then 'answered' else 'asked' end, ', ') from jsonb_array_elements(r) e) || ')';
  if jsonb_array_length(r) <> 2 then fails := fails + 1; end if;
  r := public.set_birthday(K2, (today - interval '9 years')::date, false);
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', C, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.set_birthday(CK, null, true); out := out || ' | 18b coach-added player, I don''t know: ' || coalesce(r ->> 'error', 'saved');
  if r ->> 'ok' is distinct from 'true' then fails := fails + 1; end if;
  r := public.set_birthday(CK, (today - interval '15 years')::date, false); out := out || ', then a date: ' || coalesce(r ->> 'error', 'saved');
  r := public.my_birthdays();
  out := out || ', coach''s list shows it as ' || (r -> 0 ->> 'access') || ' with date ' || coalesce(r -> 0 ->> 'birth_date', 'hidden');
  if r -> 0 ->> 'birth_date' is not null then fails := fails + 1; end if;
  reset role;

  -- ---------- 19. asked once: answered stays answered ----------
  perform set_config('request.jwt.claims', json_build_object('sub', PAR, 'role', 'authenticated')::text, true); set local role authenticated;
  out := out || ' | 19 still to ask: parent ' || (select count(*) from jsonb_array_elements(public.my_birthdays()) e where not (e ->> 'answered')::boolean);
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', PA, 'role', 'authenticated')::text, true); set local role authenticated;
  out := out || ', pitcher ' || (select count(*) from jsonb_array_elements(public.my_birthdays()) e where not (e ->> 'answered')::boolean);
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', G, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.my_birthdays();
  out := out || ' | linked guardian reads K1: ' || coalesce((select e ->> 'birth_date' from jsonb_array_elements(r) e where (e ->> 'profile_id')::uuid = K1), 'nothing');
  reset role;

  -- ---------- 20. coaches and managers get nothing ----------
  out := out || ' | 20 reads that could return a birthday:';
  for v in select unnest(array['C', 'M']) loop
    perform set_config('request.jwt.claims', json_build_object('sub', case v when 'C' then C else M end, 'role', 'authenticated')::text, true); set local role authenticated;
    begin select count(*) into n from public.profile_birthdays; out := out || ' ' || v || ' table:' || n || '!'; fails := fails + 1;
    exception when insufficient_privilege then out := out || ' ' || v || ' table:denied'; end;
    r := public.my_birthdays();
    out := out || ', my_birthdays dates:' || (select count(*) from jsonb_array_elements(r) e where e ->> 'birth_date' is not null);
    if (select count(*) from jsonb_array_elements(r) e where e ->> 'birth_date' is not null) <> 0 then fails := fails + 1; end if;
    r := public.set_birthday(PA, (today - interval '30 years')::date, false); out := out || ', set PA:' || (r ->> 'error');
    if r ->> 'error' is distinct from 'not_allowed' then fails := fails + 1; end if;
    select count(*) into n from information_schema.columns where table_name = 'profiles' and column_name ilike '%birth%';
    out := out || ', profiles birth columns:' || n;
    reset role;
  end loop;

  -- ---------- 21. September 1: up, never down, a hand-set higher level kept, nothing else touched ----------
  update public.profiles set level = 'college' where id = K2;   -- hand-set: a 9-year-old "in college" stays
  insert into public.profile_birthdays (profile_id, birth_date) values (CK, make_date(extract(year from today)::int - 19, 3, 1))
    on conflict (profile_id) do update set birth_date = excluded.birth_date, unknown = false;   -- 19 on Sept 1
  update public.profile_birthdays set birth_date = make_date(extract(year from today)::int - 14, 3, 1) where profile_id = PM;   -- 14 on Sept 1
  select string_agg(id::text || coalesce(sealed_at::text, '') || coalesce(report_path, ''), ',') into s_before from public.sessions where pitcher_id in (PA, PM, K1, K2, CK);
  n := public.f2_level_switch(make_date(extract(year from today)::int, 9, 1));
  select string_agg(id::text || coalesce(sealed_at::text, '') || coalesce(report_path, ''), ',') into s_after from public.sessions where pitcher_id in (PA, PM, K1, K2, CK);
  select string_agg(p.full_name || ':' || coalesce(p.level, '-'), ', ' order by p.full_name) into lv from public.profiles p where p.id in (PA, PM, K1, K2, CK);
  out := out || ' | 21 Sept 1 run moved ' || n || ': ' || lv || ' | log: '
    || (select string_agg(from_level || '->' || to_level, ', ' order by to_level) from public.level_switch_log where profile_id in (PA, PM, K1, K2, CK))
    || ' | sessions unchanged: ' || (s_before is not distinct from s_after);
  if (select level from public.profiles where id = PM) <> 'high_school' or (select level from public.profiles where id = CK) <> 'college'
     or (select level from public.profiles where id = K2) <> 'college' or (select level from public.profiles where id = K1) is distinct from null and (select level from public.profiles where id = K1) <> 'little_league' then
    fails := fails + 1;
  end if;
  n := public.f2_level_switch(make_date(extract(year from today)::int, 9, 1));
  out := out || ', a second run moves ' || n;
  -- Joel's table at its edges (age on Sept 1): 12 LL, 13 HS, 17 HS, 18 College; softball 12 LL, 13 and 18 HS & up.
  v := public.f2_level_for('baseball', 12) || ',' || public.f2_level_for('baseball', 13) || ',' || public.f2_level_for('baseball', 17) || ','
    || public.f2_level_for('baseball', 18) || ',' || public.f2_level_for('softball', 12) || ',' || public.f2_level_for('softball', 13) || ','
    || public.f2_level_for('softball', 18);
  out := out || ' | table edges: ' || v;
  if v <> 'little_league,high_school,high_school,college,little_league,high_school_up,high_school_up' then fails := fails + 1; end if; if n <> 0 then fails := fails + 1; end if;
  out := out || ' | job: ' || (select schedule || ' ' || command from cron.job where jobname = 'f2-level-switch');

  -- ---------- 23. delete removes it ----------
  delete from public.pitcher_teams where pitcher_id = K2; delete from public.pitcher_team_departures where pitcher_id = K2;   -- as a1_purge_profile does, memberships first
  delete from public.profiles where id = K2;
  select count(*) into n from public.profile_birthdays where profile_id = K2;
  out := out || ' | 23 profile deleted -> birthday rows ' || n; if n <> 0 then fails := fails + 1; end if;

  select count(*) into pol1 from pg_policies where schemaname in ('public', 'storage');
  out := out || ' | policies ' || pol0 || '->' || pol1 || ', client grants on the three tables: '
    || (select count(*) from information_schema.role_table_grants where table_name in ('profile_birthdays', 'birthday_contradictions', 'level_switch_log') and grantee in ('anon', 'authenticated'));
  if pol0 <> pol1 then fails := fails + 1; end if;
  raise exception 'F2S3 RESULT fails=% |%', fails, out;
end $$;
