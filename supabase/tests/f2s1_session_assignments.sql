-- F2 Stage 1 acceptance, database part (staging; everything rolled back -- the block ends by raising its results).
-- Fixture logins (example.invalid): M the manager (create_facility), CA coach A (P01-P03 in A's group), CB coach B
-- (P04 in B's group), CX a facility coach with no pitchers, X the head of an ordinary team (another "facility" can't
-- see in), plus Q, a pitcher on X's team only. Checks are numbered after the packet's "Done when" 6-12.
do $$
declare
  M  uuid := 'aaaaaaaa-0000-4000-8000-0000000f2a01'; CA uuid := 'aaaaaaaa-0000-4000-8000-0000000f2a02';
  CB uuid := 'aaaaaaaa-0000-4000-8000-0000000f2a03'; CX uuid := 'aaaaaaaa-0000-4000-8000-0000000f2a04';
  X  uuid := 'aaaaaaaa-0000-4000-8000-0000000f2a05';
  P uuid[]; Q uuid := gen_random_uuid(); FB uuid; T uuid; org uuid; tok text; gA uuid; gB uuid; mBB uuid;
  a1 uuid; a2 uuid; a3 uuid; s1 uuid := gen_random_uuid(); s2 uuid := gen_random_uuid(); s3 uuid := gen_random_uuid(); s4 uuid := gen_random_uuid();
  r jsonb; pj jsonb; n int; n2 int; ok boolean; out text := ''; fails int := 0; pol0 int; pol1 int; spol0 int; spol1 int;
  before_m text; after_m text; who record;
begin
  select count(*) into pol0 from pg_policies where schemaname = 'public';
  select count(*) into spol0 from pg_policies where schemaname = 'storage';
  -- ---------- fixture ----------
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', e || '@example.invalid',
         jsonb_build_object('full_name', nm, 'intended_role', 'coach', 'intended_sport', 'baseball'), now(), now()
    from (values (M, 'f2s1-m', 'Morgan Manager'), (CA, 'f2s1-ca', 'Coach A'), (CB, 'f2s1-cb', 'Coach B'),
                 (CX, 'f2s1-cx', 'Coach X'), (X, 'f2s1-x', 'Other Head')) x(u, e, nm);
  update public.profiles set email_verified_at = now(), age_attestation = 'adult', attested_at = now(), attested_via = 'signup', terms_version = '2026-10-14'
   where id in (M, CA, CB, CX, X);
  select array_agg(gen_random_uuid()) into P from generate_series(1, 4);
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'f2s1-p' || i || '@example.invalid', '{}', now(), now()
    from (select P[i] u, i from generate_series(1, 4) i union all select Q, 9) z;
  insert into public.profiles (id, role, full_name, sport, email_verified_at, age_attestation, attested_at, attested_via, terms_version, pitch_types, contact_emails)
  select u, 'pitcher', nm, 'baseball', now(), 'adult', now(), 'signup', '2026-10-14', array['Four Seam Fastball','Curveball'], '{"coach":"c@example.invalid"}'
    from (values (P[1], 'Zed Alpha'), (P[2], 'Zed Bravo'), (P[3], 'Zed Bravo'), (P[4], 'Yan Charlie'), (Q, 'Zed Outsider')) v(u, nm);
  insert into public.accuracy_zones (pitcher_id, pitch_type, batter_side, cells) values (P[1], 'Four Seam Fastball', 'R', array['1-1','1-2']);
  T := public._create_team_with_head(X, 'F2S1 Ordinary Team');
  insert into public.pitcher_teams (pitcher_id, team_id) values (Q, T);
  insert into public.facility_invites (facility_name, manager_email, baseball_level, softball_level)
    values ('F2S1 Facility', 'f2s1-m@example.invalid', 'high_school', 'high_school_up') returning token into tok;
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.create_facility(tok); org := (r ->> 'org_id')::uuid;
  reset role;
  select id, coach_id into FB, mBB from public.teams where org_id = org and sport = 'baseball';
  insert into public.team_coaches (team_id, coach_id, role, invited_by) values (FB, CA, 'assistant', mBB), (FB, CB, 'assistant', mBB), (FB, CX, 'assistant', mBB);
  select id into gA from public.coach_groups where team_id = FB and coach_id = CA;
  select id into gB from public.coach_groups where team_id = FB and coach_id = CB;
  insert into public.pitcher_teams (pitcher_id, team_id, joined_at) select P[i], FB, now() - interval '30 days' from generate_series(1, 4) i;
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.add_to_group(gA, P[1]); r := public.add_to_group(gA, P[2]); r := public.add_to_group(gA, P[3]); r := public.add_to_group(gB, P[4]);
  reset role;
  -- who sees whom, before any assignment (the F1-A matrix's question, every coach x every pitcher)
  before_m := '';
  for who in select * from (values ('CA', CA), ('CB', CB), ('CX', CX), ('M', M), ('X', X)) t(nm, id) loop
    perform set_config('request.jwt.claims', json_build_object('sub', who.id, 'role', 'authenticated')::text, true); set local role authenticated;
    before_m := before_m || who.nm || ':' || (select string_agg(case when public.coach_sees_pitcher(FB, pp) then '1' else '0' end, '' order by pp) from unnest(P || Q) pp)
                || '/' || (select count(*) from public.profiles where id = any(P || Q)) || ' ';
    reset role;
  end loop;

  -- ---------- 6. search ----------
  perform set_config('request.jwt.claims', json_build_object('sub', CB, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.facility_pitcher_search(FB, 'ze');
  out := out || ' 6a CB "ze": ' || (select string_agg((e ->> 'name') || case when (e ->> 'mine')::boolean then '(mine)' else '' end
                                       || coalesce('[' || (e ->> 'coach') || ']', ''), ', ') from jsonb_array_elements(r -> 'results') e);
  if jsonb_array_length(r -> 'results') <> 3 or (r -> 'results')::text like '%Outsider%' then fails := fails + 1; end if;
  if (select count(*) from jsonb_array_elements(r -> 'results') e where e ->> 'coach' is not null) <> 2 then fails := fails + 1; end if;   -- the two Zed Bravos say whose
  r := public.facility_pitcher_search(FB, 'y');
  out := out || ' | 1 letter:' || jsonb_array_length(r -> 'results'); if jsonb_array_length(r -> 'results') <> 0 then fails := fails + 1; end if;
  r := public.facility_pitcher_search(FB, 'ya');
  out := out || ' | own pitcher "ya": mine=' || (r -> 'results' -> 0 ->> 'mine');
  r := public.facility_pitcher_search(FB, '%');
  out := out || ' | "%" literal:' || jsonb_array_length(r -> 'results');
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', X, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.facility_pitcher_search(FB, 'ze');
  out := out || ' | another team''s head: ' || coalesce(r ->> 'error', 'results!'); if r ->> 'error' is distinct from 'not_allowed' then fails := fails + 1; end if;
  r := public.assign_session(FB, P[1], X);
  out := out || ' assign:' || coalesce(r ->> 'error', 'ok!'); if r ->> 'error' is distinct from 'not_allowed' then fails := fails + 1; end if;
  reset role;

  -- ---------- 7 / 9. assign to self, the narrow read, chart, release ----------
  perform set_config('request.jwt.claims', json_build_object('sub', CB, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.assign_session(FB, P[1], CB); a1 := (r ->> 'id')::uuid;
  out := out || ' | 7a CB assigns P1 to self:' || (r ->> 'status');
  r := public.my_assignments();
  out := out || ' | 9a device holds: ' || jsonb_array_length(r) || ' assignment, pitcher keys '
    || (select string_agg(k, ',' order by k) from jsonb_object_keys(r -> 0 -> 'pitcher') k) || ', zones ' || jsonb_array_length(r -> 0 -> 'zones');
  if (r -> 0 -> 'pitcher') ? 'contact_emails' or (r -> 0 -> 'pitcher') ? 'level' or jsonb_array_length(r -> 0 -> 'zones') <> 1 then fails := fails + 1; end if;
  select count(*) into n from public.profiles where id = P[1];
  select count(*) into n2 from public.pitcher_teams where pitcher_id = P[1];
  out := out || ' | 9b direct reads during: profile ' || n || ', roster row ' || n2
    || ', zones ' || (select count(*) from public.accuracy_zones where pitcher_id = P[1])
    || ', sees ' || public.coach_sees_pitcher(FB, P[1])
    || ', chat targets ' || coalesce((select count(*) from jsonb_array_elements(coalesce(public.chat_compose_targets() -> 'targets', '[]')) e where e::text like '%' || P[1] || '%'), 0);
  if n + n2 <> 0 or public.coach_sees_pitcher(FB, P[1]) then fails := fails + 1; end if;
  -- without naming the assignment: refused
  select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'Four Seam Fastball', 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2)) into pj from generate_series(1, 4);
  r := public.sync_session(jsonb_build_object('id', s1, 'pitcher_id', P[1], 'team_id', FB, 'logged_by', CB, 'started_at', now(), 'ended_at', now() + interval '20 minutes'), pj, '[]');
  out := out || ' | 7b save without the assignment: ' || coalesce(r ->> 'error', 'saved!'); if r ->> 'error' is distinct from 'not_entitled' then fails := fails + 1; end if;
  r := public.sync_session(jsonb_build_object('id', s1, 'pitcher_id', P[1], 'team_id', FB, 'logged_by', CB, 'assignment_id', a1, 'started_at', now(), 'ended_at', now() + interval '20 minutes'), pj, '[]');
  out := out || ' | 7c save with it: ' || coalesce(r ->> 'status', r ->> 'error'); if r ->> 'status' is distinct from 'saved' then fails := fails + 1; end if;
  select count(*) into n from public.sessions where id = s1;
  select count(*) into n2 from public.pitches where session_id = s1;
  out := out || ' | 7d after: CB reads session ' || n || ', pitches ' || n2 || ', profile ' || (select count(*) from public.profiles where id = P[1])
    || ', my_assignments ' || jsonb_array_length(public.my_assignments());
  if n + n2 <> 0 or jsonb_array_length(public.my_assignments()) <> 0 then fails := fails + 1; end if;
  r := public.sync_session(jsonb_build_object('id', s1, 'pitcher_id', P[1], 'team_id', FB, 'logged_by', CB, 'assignment_id', a1, 'started_at', now(), 'ended_at', now() + interval '20 minutes'), pj, '[]');
  out := out || ' | 7e retry (lost response): ' || coalesce(r ->> 'status', r ->> 'error'); if r ->> 'status' is distinct from 'already_saved' then fails := fails + 1; end if;
  r := public.sync_session(jsonb_build_object('id', s2, 'pitcher_id', P[1], 'team_id', FB, 'logged_by', CB, 'assignment_id', a1, 'started_at', now(), 'ended_at', now() + interval '20 minutes'), pj, '[]');
  out := out || ' | 7f a second session on it: ' || coalesce(r ->> 'error', 'saved!'); if r ->> 'error' is distinct from 'not_entitled' then fails := fails + 1; end if;
  reset role;
  select released_at is not null and session_id = s1 into ok from public.session_assignments where id = a1;
  out := out || ' | 7g released with the session: ' || ok; if not ok then fails := fails + 1; end if;

  -- ---------- 10. who sees the session: the pitcher, his own coach, the manager -- not CB ----------
  out := out || ' | 10 reads s1:';
  for who in select * from (values ('pitcher', P[1]), ('CA', CA), ('M', M), ('CB', CB), ('CX', CX)) t(nm, id) loop
    perform set_config('request.jwt.claims', json_build_object('sub', who.id, 'role', 'authenticated')::text, true); set local role authenticated;
    select count(*) into n from public.sessions where id = s1;
    out := out || ' ' || who.nm || '=' || n;
    if (who.nm in ('pitcher', 'CA', 'M') and n <> 1) or (who.nm in ('CB', 'CX') and n <> 0) then fails := fails + 1; end if;
    reset role;
  end loop;

  -- ---------- 8. assign to another coach ----------
  perform set_config('request.jwt.claims', json_build_object('sub', CA, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.assign_session(FB, P[4], CX); a2 := (r ->> 'id')::uuid;
  out := out || ' | 8a CA assigns P4 (B''s) to CX: ' || (r ->> 'status') || ', CA''s own list ' || jsonb_array_length(public.my_assignments());
  r := public.assign_session(FB, P[2], CA);
  out := out || ' | already their coach: ' || (r ->> 'status'); if r ->> 'status' is distinct from 'already_coach' then fails := fails + 1; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', CX, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.my_assignments();
  out := out || ' | CX list: ' || jsonb_array_length(r) || ' (' || (r -> 0 -> 'pitcher' ->> 'full_name') || ')';
  if jsonb_array_length(r) <> 1 then fails := fails + 1; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', CB, 'role', 'authenticated')::text, true); set local role authenticated;
  out := out || ', CB list ' || jsonb_array_length(public.my_assignments());
  reset role;

  -- ---------- 11. 24 hours; offline saves later; cancel ----------
  update public.session_assignments set created_at = now() - interval '30 hours', window_ends_at = now() - interval '6 hours' where id = a2;
  perform set_config('request.jwt.claims', json_build_object('sub', CX, 'role', 'authenticated')::text, true); set local role authenticated;
  out := out || ' | 11a after 24 h, CX list ' || jsonb_array_length(public.my_assignments());
  if jsonb_array_length(public.my_assignments()) <> 0 then fails := fails + 1; end if;
  r := public.sync_session(jsonb_build_object('id', s3, 'pitcher_id', P[4], 'team_id', FB, 'logged_by', CX, 'assignment_id', a2,
         'started_at', now() - interval '20 hours', 'ended_at', now() - interval '19 hours'), pj, '[]');
  out := out || ' | 11b charted inside the window, synced now: ' || coalesce(r ->> 'status', r ->> 'error');
  if r ->> 'status' is distinct from 'saved' then fails := fails + 1; end if;
  reset role;
  select released_at is not null into ok from public.session_assignments where id = a2;
  out := out || ' released:' || ok;
  perform set_config('request.jwt.claims', json_build_object('sub', CB, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.assign_session(FB, P[2], CB); a3 := (r ->> 'id')::uuid;
  r := public.sync_session(jsonb_build_object('id', s4, 'pitcher_id', P[2], 'team_id', FB, 'logged_by', CB, 'assignment_id', a3,
         'started_at', now() + interval '25 hours', 'ended_at', now() + interval '26 hours'), pj, '[]');
  out := out || ' | 11c started after the window: ' || coalesce(r ->> 'error', 'saved!'); if r ->> 'error' is distinct from 'not_entitled' then fails := fails + 1; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.cancel_assignment(a3); out := out || ' | 11d manager cancels: ' || (r ->> 'status');
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', CB, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.sync_session(jsonb_build_object('id', s4, 'pitcher_id', P[2], 'team_id', FB, 'logged_by', CB, 'assignment_id', a3,
         'started_at', now() + interval '1 minute', 'ended_at', now() + interval '20 minutes'), pj, '[]');
  out := out || ' started after the cancel: ' || coalesce(r ->> 'error', 'saved!'); if r ->> 'error' is distinct from 'not_entitled' then fails := fails + 1; end if;
  r := public.cancel_assignment(a2); out := out || ' | CB cancels CX''s: ' || coalesce(r ->> 'status', r ->> 'error');
  if r ->> 'error' is distinct from 'not_allowed' then fails := fails + 1; end if;
  reset role;

  -- ---------- 12. nothing widened ----------
  -- an open assignment in place while comparing (CB holds one for P3)
  perform set_config('request.jwt.claims', json_build_object('sub', CB, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.assign_session(FB, P[3], CB);
  reset role;
  after_m := '';
  for who in select * from (values ('CA', CA), ('CB', CB), ('CX', CX), ('M', M), ('X', X)) t(nm, id) loop
    perform set_config('request.jwt.claims', json_build_object('sub', who.id, 'role', 'authenticated')::text, true); set local role authenticated;
    after_m := after_m || who.nm || ':' || (select string_agg(case when public.coach_sees_pitcher(FB, pp) then '1' else '0' end, '' order by pp) from unnest(P || Q) pp)
               || '/' || (select count(*) from public.profiles where id = any(P || Q)) || ' ';
    reset role;
  end loop;
  select count(*) into pol1 from pg_policies where schemaname = 'public';
  select count(*) into spol1 from pg_policies where schemaname = 'storage';
  out := out || ' | 12 sees-pitcher bits / profiles read, before: ' || before_m || '; with an open assignment: ' || after_m || (case when before_m = after_m then '(same)' else '(DIFFERENT)' end) || ' | policies public ' || pol0 || '->' || pol1 || ', storage ' || spol0 || '->' || spol1
    || ' | client grants on session_assignments: ' || (select count(*) from information_schema.role_table_grants where table_name = 'session_assignments' and grantee in ('anon', 'authenticated'));
  if pol0 <> pol1 or spol0 <> spol1 or before_m <> after_m then fails := fails + 1; end if;

  raise exception 'F2S1 RESULT fails=% |%', fails, out;
end $$;
