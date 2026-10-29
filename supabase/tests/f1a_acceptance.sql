-- F1-A acceptance (staging; everything rolled back -- the block ends by raising its results).
-- Fixture logins (example.invalid): M the manager (made by create_facility), CA coach A (15 pitchers), CB coach B (5),
-- CX a facility coach with no pitchers, HT head of an ordinary team "T" (the Cairn case), X unrelated, plus 20 pitchers.
-- P01 is on T and on the facility (coach A's group). Checks are numbered after the packet's acceptance list.
do $$
declare
  M  uuid := 'aaaaaaaa-0000-4000-8000-00000000f001'; CA uuid := 'aaaaaaaa-0000-4000-8000-00000000f002';
  CB uuid := 'aaaaaaaa-0000-4000-8000-00000000f003'; CX uuid := 'aaaaaaaa-0000-4000-8000-00000000f004';
  HT uuid := 'aaaaaaaa-0000-4000-8000-00000000f005'; X  uuid := 'aaaaaaaa-0000-4000-8000-00000000f006';
  M2 uuid := 'aaaaaaaa-0000-4000-8000-00000000f007';   -- a second login that tries the same link
  P  uuid[]; FB uuid; FS uuid; T uuid; org uuid; tok text; tok2 text; gA uuid; gB uuid; gX uuid; gM uuid;
  mBB uuid; mSB uuid; caSB uuid; s_lesson uuid := gen_random_uuid(); s_team uuid := gen_random_uuid(); s_b uuid := gen_random_uuid();
  r jsonb; n int; n2 int; n3 int; ok boolean; out text := ''; fails int := 0; who record; pj jsonb;
begin
  -- ---------- fixture ----------
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', e || '@example.invalid',
         jsonb_build_object('full_name', nm, 'intended_role', 'coach', 'intended_sport', 'baseball'), now(), now()
    from (values (M, 'f1a-m', 'Morgan Manager'), (M2, 'f1a-m2', 'Other Login'), (CA, 'f1a-ca', 'Coach A'), (CB, 'f1a-cb', 'Coach B'),
                 (CX, 'f1a-cx', 'Coach X'), (HT, 'f1a-ht', 'Team Head'), (X, 'f1a-x', 'Unrelated')) x(u, e, nm);
  -- handle_new_user made the coach profiles (baseball); give coach A a softball profile too
  update public.profiles set email_verified_at = now(), age_attestation = 'adult', attested_at = now(), attested_via = 'signup', terms_version = '2026-10-14'
   where id in (M, M2, CA, CB, CX, HT, X);
  caSB := gen_random_uuid();
  insert into public.profiles (id, account_id, role, full_name, sport) values (caSB, CA, 'coach', 'Coach A', 'softball');
  select array_agg(gen_random_uuid()) into P from generate_series(1, 20);
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select P[i], '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'f1a-p' || i || '@example.invalid', '{}', now(), now()
    from generate_series(1, 20) i;
  insert into public.profiles (id, role, full_name, sport, email_verified_at, age_attestation, attested_at, attested_via, terms_version)
  select P[i], 'pitcher', 'F1A Pitcher ' || lpad(i::text, 2, '0'), 'baseball', now(), 'adult', now(), 'signup', '2026-10-14' from generate_series(1, 20) i;
  T := public._create_team_with_head(HT, 'F1A Ordinary Team');

  insert into public.facility_invites (facility_name, manager_email, baseball_level, softball_level)
    values ('F1A Test Facility', 'F1A-M@example.invalid', 'high_school', 'high_school_up') returning token into tok;
  insert into public.facility_invites (facility_name, manager_email, baseball_level, softball_level, expires_at)
    values ('Expired Facility', 'f1a-m2@example.invalid', 'high_school', 'high_school_up', now() - interval '1 day') returning token into tok2;

  -- ---------- 1. create_facility ----------
  perform set_config('request.jwt.claims', json_build_object('sub', M2, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.create_facility(tok);          out := out || ' 1a wrong email:' || coalesce(r ->> 'error', 'none');
  if r ->> 'error' is distinct from 'wrong_email' then fails := fails + 1; end if;
  r := public.create_facility(tok2);         out := out || ' 1b expired:' || coalesce(r ->> 'error', 'none');
  if r ->> 'error' is distinct from 'expired' then fails := fails + 1; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.facility_invite_info(tok);     out := out || ' 1c info:' || (r ->> 'status');
  r := public.create_facility(tok);          org := (r ->> 'org_id')::uuid; out := out || ' 1d create:' || (r ->> 'status');
  r := public.create_facility(tok);          out := out || ' 1e again same login:' || (r ->> 'status');
  if r ->> 'status' is distinct from 'already_created' then fails := fails + 1; end if;
  ok := public.is_facility_login();          out := out || ' 1f facility login:' || ok;
  if not ok then fails := fails + 1; end if;
  r := public.my_facility();                 out := out || ' 1g teams:' || jsonb_array_length(r -> 'teams');
  reset role;
  select count(*) into n from public.profiles where account_id = M and role = 'coach';
  select id into FB from public.teams where org_id = org and sport = 'baseball';
  select id into FS from public.teams where org_id = org and sport = 'softball';
  select coach_id into mBB from public.teams where id = FB; select coach_id into mSB from public.teams where id = FS;
  select count(*) into n2 from public.teams where org_id = org and kind = 'facility' and invite_token is not null and coach_invite_token is not null;
  out := out || ' 1h coach profiles:' || n || ' facility teams with both tokens:' || n2
    || ' levels:' || (select string_agg(level, '/' order by sport) from public.teams where org_id = org)
    || ' head rows:' || (select count(*) from public.team_coaches where team_id in (FB, FS) and role = 'head');
  if n <> 2 or n2 <> 2 then fails := fails + 1; end if;
  perform set_config('request.jwt.claims', json_build_object('sub', M2, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.facility_invite_info(tok);     out := out || ' 1i link for another login:' || (r ->> 'status');
  r := public.create_facility(tok);          out := out || ' 1j second use:' || coalesce(r ->> 'error', 'none');
  if r ->> 'error' is distinct from 'used' then fails := fails + 1; end if;
  ok := public.is_facility_login();          out := out || ' 1k other login facility:' || ok;
  reset role;

  -- ---------- 3. coaches join -> groups ----------
  insert into public.team_coaches (team_id, coach_id, role, invited_by) values (FB, CA, 'assistant', mBB), (FB, CB, 'assistant', mBB),
    (FB, CX, 'assistant', mBB), (FS, caSB, 'assistant', mSB);
  select id into gA from public.coach_groups where team_id = FB and coach_id = CA;
  select id into gB from public.coach_groups where team_id = FB and coach_id = CB;
  select id into gX from public.coach_groups where team_id = FB and coach_id = CX;
  select id into gM from public.coach_groups where team_id = FB and coach_id = mBB;
  select count(*) into n from public.coach_groups g join public.profiles pr on pr.id = g.coach_id where pr.account_id = CA;
  out := out || ' | 3 groups: baseball side ' || (select count(*) from public.coach_groups where team_id = FB) || ' (manager + 3), coach A on both sides ' || n;
  if n <> 2 or gM is null then fails := fails + 1; end if;
  select count(*) into n from public.coach_groups where team_id = T;
  out := out || ', ordinary team groups ' || n;

  -- roster: 20 pitchers on the facility, 15 in A, 5 in B; P01 also on T
  insert into public.pitcher_teams (pitcher_id, team_id, joined_at) select P[i], FB, now() - interval '30 days' from generate_series(1, 20) i;
  insert into public.pitcher_teams (pitcher_id, team_id, joined_at) values (P[1], T, now() - interval '30 days');
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  for i in 1..15 loop r := public.add_to_group(gA, P[i]); end loop;
  for i in 16..20 loop r := public.add_to_group(gB, P[i]); end loop;
  reset role;

  -- ---------- 5. who sees whom ----------
  out := out || ' | 5 roster rows (pitcher_teams on the side / profiles / group members / roster_verification):';
  for who in select * from (values ('M', M), ('CA', CA), ('CB', CB), ('CX', CX), ('HT', HT), ('X', X)) t(nm, id) loop
    perform set_config('request.jwt.claims', json_build_object('sub', who.id, 'role', 'authenticated')::text, true); set local role authenticated;
    select count(*) into n from public.pitcher_teams where team_id = FB;
    select count(*) into n2 from public.profiles where id = any(P);
    select count(*) into n3 from public.coach_group_members;
    out := out || ' ' || who.nm || '=' || n || '/' || n2 || '/' || n3 || '/' || (select count(*) from public.get_roster_verification(FB));
    if (who.nm = 'M' and n <> 20) or (who.nm = 'CA' and n <> 15) or (who.nm = 'CB' and n <> 5) or (who.nm in ('CX', 'HT', 'X') and n <> 0) then fails := fails + 1; end if;
    reset role;
  end loop;

  -- ---------- charting (decision D) and 6. cross-team reads ----------
  out := out || ' | D charting:';
  for who in select * from (values ('M', M, P[16]), ('CA', CA, P[16]), ('CA', CA, P[1]), ('CB', CB, P[16]), ('CX', CX, P[2])) t(nm, id, pit) loop
    perform set_config('request.jwt.claims', json_build_object('sub', who.id, 'role', 'authenticated')::text, true); set local role authenticated;
    select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'fb', 'velo', 80, 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2)) into pj from generate_series(1, 4);
    r := public.sync_session(jsonb_build_object('id', gen_random_uuid(), 'pitcher_id', who.pit, 'team_id', FB, 'logged_by', case when who.id = M then mBB else who.id end,
           'started_at', now() - interval '1 day', 'ended_at', now() - interval '1 day' + interval '20 minutes'), pj, '[]');
    out := out || ' ' || who.nm || '->P' || array_position(P, who.pit) || ':' || coalesce(r ->> 'status', r ->> 'error');
    reset role;
  end loop;
  -- the lesson pen (P01, by coach A on the facility) and P01's ordinary-team pen (by HT on T); P16's pen by coach B
  perform set_config('request.jwt.claims', json_build_object('sub', CA, 'role', 'authenticated')::text, true); set local role authenticated;
  select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'fb', 'velo', 80, 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2)) into pj from generate_series(1, 4);
  r := public.sync_session(jsonb_build_object('id', s_lesson, 'pitcher_id', P[1], 'team_id', FB, 'logged_by', CA,
         'started_at', now() - interval '2 days', 'ended_at', now() - interval '2 days' + interval '20 minutes'), pj, '[]');
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', HT, 'role', 'authenticated')::text, true); set local role authenticated;
  select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'fb', 'velo', 80, 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2)) into pj from generate_series(1, 4);
  r := public.sync_session(jsonb_build_object('id', s_team, 'pitcher_id', P[1], 'team_id', T, 'logged_by', HT,
         'started_at', now() - interval '3 days', 'ended_at', now() - interval '3 days' + interval '20 minutes'), pj, '[]');
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', CB, 'role', 'authenticated')::text, true); set local role authenticated;
  select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'fb', 'velo', 80, 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2)) into pj from generate_series(1, 4);
  r := public.sync_session(jsonb_build_object('id', s_b, 'pitcher_id', P[16], 'team_id', FB, 'logged_by', CB,
         'started_at', now() - interval '2 days', 'ended_at', now() - interval '2 days' + interval '20 minutes'), pj, '[]');
  reset role;
  out := out || ' | 6 reads sessions/pitches/stats (lesson P01, team pen P01, coach B pen P16):';
  for who in select * from (values ('P01', P[1]), ('M', M), ('CA', CA), ('CB', CB), ('CX', CX), ('HT', HT), ('X', X)) t(nm, id) loop
    perform set_config('request.jwt.claims', json_build_object('sub', who.id, 'role', 'authenticated')::text, true); set local role authenticated;
    out := out || ' ' || who.nm || '=';
    for i in 1..3 loop
      select count(*) into n from public.sessions where id = (array[s_lesson, s_team, s_b])[i];
      select count(*) into n2 from public.pitches where session_id = (array[s_lesson, s_team, s_b])[i];
      select count(*) into n3 from public.session_stats where session_id = (array[s_lesson, s_team, s_b])[i];
      out := out || n || '/' || n2 || '/' || n3 || case when i < 3 then ',' else '' end;
    end loop;
    reset role;
  end loop;
  -- expected: P01 sees 1,1,0 (own two); M all three; CA lesson + team pen (P01 is theirs), not P16's; CB only P16's;
  -- CX nothing; HT lesson + team pen (R4 stands), not P16's; X nothing.

  -- ---------- workload line (SECURITY INVOKER) ----------
  out := out || ' | workload rows (all 20):';
  for who in select * from (values ('M', M), ('CA', CA), ('CB', CB), ('CX', CX)) t(nm, id) loop
    perform set_config('request.jwt.claims', json_build_object('sub', who.id, 'role', 'authenticated')::text, true); set local role authenticated;
    select count(*) filter (where last_at is not null) into n from public.pitcher_workload(P);
    out := out || ' ' || who.nm || '=' || n;
    reset role;
  end loop;

  -- ---------- 9. notes, leaderboard ----------
  out := out || ' | 9 note insert lesson/team:';
  for who in select * from (values ('M', M, s_lesson), ('CA', CA, s_lesson), ('HT', HT, s_team)) t(nm, id, sid) loop
    begin
      perform set_config('request.jwt.claims', json_build_object('sub', who.id, 'role', 'authenticated')::text, true); set local role authenticated;
      insert into public.session_notes (session_id, author_id, author_name, body) values (who.sid, case when who.id = M then mBB else who.id end, who.nm, 'probe');
      raise exception 'F1AUNDO:yes';
    exception when others then out := out || ' ' || who.nm || ':' || case when sqlerrm = 'F1AUNDO:yes' then 'yes' else 'no' end;
    end;
    reset role;
  end loop;
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
    r := public.get_team_leaderboard(FB, 'all'); out := out || ' leaderboard facility:returned';
  exception when others then out := out || ' leaderboard facility:' || sqlerrm;
  end;
  reset role;

  -- ---------- group actions ----------
  out := out || ' | groups:';
  perform set_config('request.jwt.claims', json_build_object('sub', CA, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.add_to_group(gB, P[2]);                   out := out || ' CA add to B:' || coalesce(r ->> 'error', 'ok');
  r := public.move_between_groups(P[2], gA, gB);        out := out || ' CA move:' || coalesce(r ->> 'error', 'ok');
  r := public.clear_new_flag(gA, P[3]);                 out := out || ' CA clear own:' || coalesce(r ->> 'error', 'ok');
  r := public.remove_from_group(gA, P[3]);              out := out || ' CA remove own last group:' || coalesce(r ->> 'error', 'ok') || ' left side ' || (r ->> 'left_side');
  reset role;
  select count(*) into n from public.pitcher_teams where pitcher_id = P[3] and team_id = FB;
  select count(*) into n2 from public.pitcher_team_departures where pitcher_id = P[3] and team_id = FB;
  out := out || ' (P03 on side ' || n || ', departure logged ' || n2 || ')';
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.move_between_groups(P[2], gA, gB);        out := out || ' M move P02 A->B:' || coalesce(r ->> 'error', 'ok');
  r := public.add_to_group(gA, P[17]);                  out := out || ' M add P17 to A too:' || coalesce(r ->> 'error', 'ok');
  r := public.remove_from_group(gA, P[17]);             out := out || ' M remove P17 from A:' || coalesce(r ->> 'error', 'ok') || ' left side ' || (r ->> 'left_side');
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', CB, 'role', 'authenticated')::text, true); set local role authenticated;
  select count(*) into n from public.pitcher_teams where team_id = FB;
  out := out || ' CB now sees ' || n;
  reset role;
  -- coach leaves the side: group gone, pitchers stay on the side ungrouped
  delete from public.team_coaches where team_id = FB and coach_id = CB;
  select count(*) into n from public.coach_groups where id = gB;
  select count(*) into n2 from public.pitcher_teams where team_id = FB and pitcher_id = P[16];
  out := out || ' | coach B removed: group rows ' || n || ', P16 still on side ' || n2;

  -- ---------- handoff (decision C) ----------
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.handoff_facility(CX);                     out := out || ' | handoff to a one-side coach:' || coalesce(r ->> 'error', 'ok');
  r := public.handoff_facility(CA);                     out := out || ' handoff to coach A (both sides):' || coalesce(r ->> 'error', 'ok');
  ok := public.is_facility_login();                     out := out || ' old manager still facility:' || ok;
  reset role;
  out := out || ' heads now coach A:' || (select count(*) from public.teams t join public.profiles pr on pr.id = t.coach_id where t.org_id = org and pr.account_id = CA)
    || ' manager_login A:' || ((select manager_login from public.organizations where id = org) = CA)
    || ' old manager assistant rows:' || (select count(*) from public.team_coaches tc join public.profiles pr on pr.id = tc.coach_id where pr.account_id = M and tc.role = 'assistant');

  out := out || ' | policies ' || (select count(*) from pg_policies where schemaname = 'public') || ' | hard fails ' || fails;
  raise exception 'F1A(rolled back):%', out;
end $$;
