-- F2 Stage 4 acceptance, database part (staging; everything rolled back -- the block ends by raising its results).
-- Fixture (example.invalid): M the manager (create_facility), coaches CA / CB / CC with one or two pitchers each, CX the
-- camp's coach (no pitchers of their own), X the head of an ordinary team. Checks are numbered after the packet's
-- "Done when" 13-16. Days are Eastern; "today" is f2_today_et().
do $$
declare
  M  uuid := 'aaaaaaaa-0000-4000-8000-0000000f4a01'; CA uuid := 'aaaaaaaa-0000-4000-8000-0000000f4a02';
  CB uuid := 'aaaaaaaa-0000-4000-8000-0000000f4a03'; CC uuid := 'aaaaaaaa-0000-4000-8000-0000000f4a04';
  CX uuid := 'aaaaaaaa-0000-4000-8000-0000000f4a05'; X  uuid := 'aaaaaaaa-0000-4000-8000-0000000f4a06';
  P uuid[]; FB uuid; T uuid; org uuid; tok text; gA uuid; gB uuid; gC uuid; mBB uuid; camp uuid; d0 date;
  s1 uuid := gen_random_uuid(); s2 uuid := gen_random_uuid(); s3 uuid := gen_random_uuid(); s4 uuid := gen_random_uuid();
  r jsonb; pj jsonb; n int; n2 int; v text; out text := ''; fails int := 0; pol0 int; pol1 int; groups0 text; groups1 text; err text;
begin
  select count(*) into pol0 from pg_policies where schemaname in ('public', 'storage');
  d0 := public.f2_today_et();
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', e || '@example.invalid',
         jsonb_build_object('full_name', nm, 'intended_role', 'coach', 'intended_sport', 'baseball'), now(), now()
    from (values (M, 'f2s4-m', 'Morgan Manager'), (CA, 'f2s4-ca', 'Coach A'), (CB, 'f2s4-cb', 'Coach B'), (CC, 'f2s4-cc', 'Coach C'),
                 (CX, 'f2s4-cx', 'Camp Coach'), (X, 'f2s4-x', 'Other Head')) x(u, e, nm);
  update public.profiles set email_verified_at = now(), age_attestation = 'adult', attested_at = now(), attested_via = 'signup', terms_version = '2026-10-14'
   where id in (M, CA, CB, CC, CX, X);
  select array_agg(gen_random_uuid()) into P from generate_series(1, 5);
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select P[i], '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'f2s4-p' || i || '@example.invalid', '{}', now(), now() from generate_series(1, 5) i;
  insert into public.profiles (id, role, full_name, sport, email_verified_at, age_attestation, attested_at, attested_via, terms_version, pitch_types)
  select P[i], 'pitcher', 'Camp Kid ' || i, 'baseball', now(), 'adult', now(), 'signup', '2026-10-14', array['Four Seam Fastball'] from generate_series(1, 5) i;
  T := public._create_team_with_head(X, 'F2S4 Ordinary Team');
  insert into public.facility_invites (facility_name, manager_email, baseball_level, softball_level)
    values ('F2S4 Facility', 'f2s4-m@example.invalid', 'high_school', 'high_school_up') returning token into tok;
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.create_facility(tok); org := (r ->> 'org_id')::uuid;
  reset role;
  select id, coach_id into FB, mBB from public.teams where org_id = org and sport = 'baseball';
  insert into public.team_coaches (team_id, coach_id, role, invited_by) values (FB, CA, 'assistant', mBB), (FB, CB, 'assistant', mBB), (FB, CC, 'assistant', mBB), (FB, CX, 'assistant', mBB);
  select id into gA from public.coach_groups where team_id = FB and coach_id = CA;
  select id into gB from public.coach_groups where team_id = FB and coach_id = CB;
  select id into gC from public.coach_groups where team_id = FB and coach_id = CC;
  insert into public.pitcher_teams (pitcher_id, team_id, joined_at) select P[i], FB, now() - interval '30 days' from generate_series(1, 5) i;
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.add_to_group(gA, P[1]); r := public.add_to_group(gA, P[2]); r := public.add_to_group(gB, P[3]); r := public.add_to_group(gC, P[4]);
  reset role;
  select string_agg(group_id::text || pitcher_id::text, ',' order by group_id, pitcher_id) into groups0 from public.coach_group_members where pitcher_id = any(P);

  -- ---------- 13. a manager makes a camp: name, coach, four pitchers from three coaches, three days ----------
  perform set_config('request.jwt.claims', json_build_object('sub', CA, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.create_camp(FB, 'Winter Camp', CX, array[P[1], P[3]], d0, d0 + 2);
  out := out || ' 13a a coach creates: ' || (r ->> 'error'); if r ->> 'error' is distinct from 'not_allowed' then fails := fails + 1; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.create_camp(FB, 'Winter Camp', CX, array[P[1], P[3], gen_random_uuid()], d0, d0 + 2);
  out := out || ' | 13b a pitcher not on the side: ' || (r ->> 'error'); if r ->> 'error' is distinct from 'not_on_side' then fails := fails + 1; end if;
  r := public.create_camp(FB, 'Winter Camp', CX, array[P[1], P[2], P[3], P[4]], d0, d0 + 2);
  camp := (r ->> 'id')::uuid;
  out := out || ' | 13c camp (4 pitchers from A, A, B, C; ' || d0 || '..' || (d0 + 2) || '): ' || coalesce(r ->> 'error', 'made');
  r := public.facility_camps(FB);
  out := out || ' | manager list: ' || jsonb_array_length(r -> 'camps') || ' camp, ' || jsonb_array_length(r -> 'camps' -> 0 -> 'pitchers') || ' pitchers, coach '
    || (r -> 'camps' -> 0 ->> 'coach_name');
  if jsonb_array_length(r -> 'camps') <> 1 then fails := fails + 1; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', CX, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.my_camps();
  out := out || ' | camp coach''s list: ' || jsonb_array_length(r) || ' (' || (r -> 0 ->> 'name') || ', ' || jsonb_array_length(r -> 0 -> 'pitchers') || ' pitchers, keys '
    || (select string_agg(k, ',' order by k) from jsonb_object_keys(r -> 0 -> 'pitchers' -> 0) k) || ')';
  if jsonb_array_length(r) <> 1 or (r -> 0 -> 'pitchers' -> 0) ? 'contact_emails' then fails := fails + 1; end if;
  r := public.facility_camps(FB);
  out := out || ' | camp coach asks the manager list: ' || (r ->> 'error');
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', CB, 'role', 'authenticated')::text, true); set local role authenticated;
  out := out || ' | another coach''s camps: ' || jsonb_array_length(public.my_camps());
  reset role;

  -- ---------- 14. on a camp day the coach charts a camp pitcher; the name rides on the session; nothing else readable ----------
  perform set_config('request.jwt.claims', json_build_object('sub', CX, 'role', 'authenticated')::text, true); set local role authenticated;
  select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'Four Seam Fastball', 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2)) into pj from generate_series(1, 4);
  r := public.sync_session(jsonb_build_object('id', s1, 'pitcher_id', P[3], 'team_id', FB, 'logged_by', CX, 'camp_id', camp, 'started_at', now(), 'ended_at', now() + interval '20 minutes'), pj, '[]');
  out := out || ' | 14a camp day, camp pitcher: ' || coalesce(r ->> 'status', r ->> 'error'); if r ->> 'status' is distinct from 'saved' then fails := fails + 1; end if;
  r := public.sync_session(jsonb_build_object('id', s2, 'pitcher_id', P[1], 'team_id', FB, 'logged_by', CX, 'camp_id', camp, 'started_at', now() + interval '1 hour', 'ended_at', now() + interval '80 minutes'), pj, '[]');
  out := out || ', a second camp session: ' || coalesce(r ->> 'status', r ->> 'error'); if r ->> 'status' is distinct from 'saved' then fails := fails + 1; end if;
  r := public.sync_session(jsonb_build_object('id', s3, 'pitcher_id', P[5], 'team_id', FB, 'logged_by', CX, 'camp_id', camp, 'started_at', now(), 'ended_at', now() + interval '20 minutes'), pj, '[]');
  out := out || ', a pitcher not in the camp: ' || coalesce(r ->> 'error', 'saved!'); if r ->> 'error' is distinct from 'not_entitled' then fails := fails + 1; end if;
  r := public.sync_session(jsonb_build_object('id', s3, 'pitcher_id', P[3], 'team_id', FB, 'logged_by', CX, 'camp_id', camp, 'started_at', now() + interval '4 days', 'ended_at', now() + interval '4 days 20 minutes'), pj, '[]');
  out := out || ', after the last day: ' || coalesce(r ->> 'error', 'saved!'); if r ->> 'error' is distinct from 'not_entitled' then fails := fails + 1; end if;
  r := public.sync_session(jsonb_build_object('id', s3, 'pitcher_id', P[3], 'team_id', FB, 'logged_by', CX, 'started_at', now(), 'ended_at', now() + interval '20 minutes'), pj, '[]');
  out := out || ', without the camp: ' || coalesce(r ->> 'error', 'saved!'); if r ->> 'error' is distinct from 'not_entitled' then fails := fails + 1; end if;
  select count(*) into n from public.sessions where id in (s1, s2);
  select count(*) into n2 from public.profiles where id = any(P);
  out := out || ' | 14b camp coach reads: his camp sessions ' || n || ', camp pitchers'' profiles ' || n2 || ', roster rows '
    || (select count(*) from public.pitcher_teams where pitcher_id = any(P)) || ', sees ' || public.coach_sees_pitcher(FB, P[3]);
  if n + n2 <> 0 then fails := fails + 1; end if;
  r := public.sync_session(jsonb_build_object('id', s1, 'pitcher_id', P[3], 'team_id', FB, 'logged_by', CX, 'camp_id', camp, 'started_at', now(), 'ended_at', now() + interval '20 minutes'), pj, '[]');
  out := out || ', retry: ' || (r ->> 'status');
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', CB, 'role', 'authenticated')::text, true); set local role authenticated;
  select camp_name into v from public.sessions where id = s1;
  out := out || ' | 14c P3''s own coach reads it, labelled: ' || coalesce(v, 'none'); if v is distinct from 'Winter Camp' then fails := fails + 1; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', P[3], 'role', 'authenticated')::text, true); set local role authenticated;
  select camp_name into v from public.sessions where id = s1;
  out := out || ', the pitcher too: ' || coalesce(v, 'none');
  reset role;
  -- the lock: a saved session's camp can't change, even as the table owner
  begin update public.sessions set camp_name = 'Renamed' where id = s1; err := 'changed!'; exception when others then err := sqlerrm; end;
  out := out || ' | locked: ' || err; if err <> 'session_saved_locked' then fails := fails + 1; end if;

  -- ---------- 16. edit (name, coach, pitchers, dates) and end early: no saved session changes ----------
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.update_camp(camp, 'Spring Camp', CC, array[P[1], P[3], P[5]], d0 - 1, d0 + 5);
  reset role;
  out := out || ' | 16a edit: ' || coalesce(r ->> 'error', 'saved') || ' -> ' || (select name || ' · ' || first_day || '..' || last_day || ' · ' || (select count(*) from public.camp_roster_pitchers where camp_id = camp) || ' pitchers' from public.camp_rosters where id = camp);
  select camp_name into v from public.sessions where id = s1;
  out := out || ', saved session still: ' || v; if v <> 'Winter Camp' then fails := fails + 1; end if;
  perform set_config('request.jwt.claims', json_build_object('sub', CX, 'role', 'authenticated')::text, true); set local role authenticated;
  out := out || ', old coach''s list ' || jsonb_array_length(public.my_camps());
  if jsonb_array_length(public.my_camps()) <> 0 then fails := fails + 1; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', CC, 'role', 'authenticated')::text, true); set local role authenticated;
  out := out || ', new coach''s list ' || jsonb_array_length(public.my_camps());
  r := public.sync_session(jsonb_build_object('id', s4, 'pitcher_id', P[5], 'team_id', FB, 'logged_by', CC, 'camp_id', camp, 'started_at', now(), 'ended_at', now() + interval '20 minutes'), pj, '[]');
  out := out || ', new coach charts the added pitcher: ' || coalesce(r ->> 'status', r ->> 'error') || ' as ' || coalesce((select camp_name from public.sessions where id = s4), 'none (unreadable)');
  reset role;
  select camp_name into v from public.sessions where id = s4;
  out := out || ' [' || coalesce(v, 'none') || ']'; if v is distinct from 'Spring Camp' then fails := fails + 1; end if;
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.end_camp(camp);
  out := out || ' | 16b end early: ' || (r ->> 'ok') || ', manager list ' || jsonb_array_length(public.facility_camps(FB) -> 'camps');
  if jsonb_array_length(public.facility_camps(FB) -> 'camps') <> 0 then fails := fails + 1; end if;
  r := public.update_camp(camp, 'Again', CC, array[P[1]], d0, d0);
  out := out || ', edit after the end: ' || (r ->> 'error');
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', CC, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.sync_session(jsonb_build_object('id', gen_random_uuid(), 'pitcher_id', P[5], 'team_id', FB, 'logged_by', CC, 'camp_id', camp, 'started_at', now() + interval '1 minute', 'ended_at', now() + interval '20 minutes'), pj, '[]');
  out := out || ', charting after the end: ' || coalesce(r ->> 'error', 'saved!'); if r ->> 'error' is distinct from 'not_entitled' then fails := fails + 1; end if;
  reset role;
  select count(*) into n from public.sessions where id in (s1, s2, s4) and camp_name is not null;
  out := out || ', camp sessions kept with their names: ' || n; if n <> 3 then fails := fails + 1; end if;

  -- ---------- 15. the day after the last day: gone from both lists; sessions and permanent coaches unchanged ----------
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.create_camp(FB, 'Short Camp', CX, array[P[2]], d0 - 3, d0 - 1);
  out := out || ' | 15a a camp that ended yesterday: manager list ' || jsonb_array_length(public.facility_camps(FB) -> 'camps');
  if jsonb_array_length(public.facility_camps(FB) -> 'camps') <> 0 then fails := fails + 1; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', CX, 'role', 'authenticated')::text, true); set local role authenticated;
  out := out || ', coach list ' || jsonb_array_length(public.my_camps());
  if jsonb_array_length(public.my_camps()) <> 0 then fails := fails + 1; end if;
  reset role;
  select string_agg(group_id::text || pitcher_id::text, ',' order by group_id, pitcher_id) into groups1 from public.coach_group_members where pitcher_id = any(P);
  out := out || ' | 15b permanent coaches unchanged: ' || (groups0 = groups1);
  if groups0 <> groups1 then fails := fails + 1; end if;

  select count(*) into pol1 from pg_policies where schemaname in ('public', 'storage');
  out := out || ' | policies ' || pol0 || '->' || pol1 || ', client grants on the camp tables: '
    || (select count(*) from information_schema.role_table_grants where table_name in ('camp_rosters', 'camp_roster_pitchers') and grantee in ('anon', 'authenticated'));
  if pol0 <> pol1 then fails := fails + 1; end if;
  raise exception 'F2S4 RESULT fails=% |%', fails, out;
end $$;
