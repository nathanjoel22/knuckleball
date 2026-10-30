-- F1-C1 Chat acceptance (staging; everything rolled back -- the block ends by raising its results).
-- Fixture logins (example.invalid): M manager, CA coach A, CB coach B, HT head of an ordinary team, PAR a parent with a
-- created player KID, ADL an adult pitcher with their own login, MIN a 15-year-old whose guardian hasn't approved yet.
-- KID and ADL start in coach A's group; MIN in coach B's.
do $$
declare
  M uuid := 'aaaaaaaa-0000-4000-8000-00000000c101'; CA uuid := 'aaaaaaaa-0000-4000-8000-00000000c102';
  CB uuid := 'aaaaaaaa-0000-4000-8000-00000000c103'; HT uuid := 'aaaaaaaa-0000-4000-8000-00000000c104';
  PAR uuid := 'aaaaaaaa-0000-4000-8000-00000000c105'; ADL uuid := 'aaaaaaaa-0000-4000-8000-00000000c106';
  MIN uuid := 'aaaaaaaa-0000-4000-8000-00000000c107';
  KID uuid; tok text; org uuid; FB uuid; mBB uuid; gA uuid; gB uuid; T uuid;
  thF uuid; thK uuid; thA uuid; thM uuid; msg uuid; msg2 uuid; r jsonb; n int; out text := ''; fails int := 0; v text; i int;
begin
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', e || '@example.invalid', md, now(), now()
    from (values (M, 'c1-m', '{"full_name":"Mona Manager","intended_role":"coach","intended_sport":"baseball"}'::jsonb),
                 (CA, 'c1-ca', '{"full_name":"Coach A","intended_role":"coach","intended_sport":"baseball"}'::jsonb),
                 (CB, 'c1-cb', '{"full_name":"Coach B","intended_role":"coach","intended_sport":"baseball"}'::jsonb),
                 (HT, 'c1-ht', '{"full_name":"Team Head","intended_role":"coach","intended_sport":"baseball"}'::jsonb),
                 (PAR, 'c1-par', '{}'::jsonb), (ADL, 'c1-adl', '{}'::jsonb), (MIN, 'c1-min', '{}'::jsonb)) x(u, e, md);
  insert into public.profiles (id, role, full_name, sport) values (PAR, 'parent', 'Pat Parent', null),
    (ADL, 'pitcher', 'Ada Adult', 'baseball'), (MIN, 'pitcher', 'Mo Minor', 'baseball');
  update public.profiles set email_verified_at = now(), age_attestation = 'adult', attested_at = now(), attested_via = 'signup', terms_version = '2026-10-17'
   where id in (M, CA, CB, HT, PAR, ADL);
  update public.profiles set email_verified_at = now(), age_attestation = 'minor_13_17', attested_at = now(), attested_via = 'signup',
         guardian_email = 'g@example.invalid', guardian_consented_at = null where id = MIN;
  perform set_config('request.jwt.claims', json_build_object('sub', PAR, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.add_player('Kit Kid', 'baseball', 'R', true); KID := (r ->> 'id')::uuid;
  reset role;
  insert into public.facility_invites (facility_name, manager_email, baseball_level, softball_level)
    values ('C1 Test Facility', 'c1-m@example.invalid', 'high_school', 'high_school_up') returning token into tok;
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.create_facility(tok); org := (r ->> 'org_id')::uuid;
  reset role;
  select id, coach_id into FB, mBB from public.teams where org_id = org and sport = 'baseball';
  insert into public.team_coaches (team_id, coach_id, role, invited_by) values (FB, CA, 'assistant', mBB), (FB, CB, 'assistant', mBB);
  select id into gA from public.coach_groups where team_id = FB and coach_id = CA;
  select id into gB from public.coach_groups where team_id = FB and coach_id = CB;
  insert into public.pitcher_teams (pitcher_id, team_id) values (KID, FB), (ADL, FB), (MIN, FB);
  insert into public.coach_group_members (group_id, pitcher_id, flagged_new) values (gA, KID, false), (gA, ADL, false), (gB, MIN, false);
  T := public._create_team_with_head(HT, 'C1 Ordinary Team');
  insert into public.pitcher_teams (pitcher_id, team_id) values (ADL, T);   -- ADL is also on an ordinary team

  -- ---------- compose targets per role ----------
  out := 'compose:';
  for v in select unnest(array['M','CA','CB','HT','PAR','ADL','MIN']) loop
    perform set_config('request.jwt.claims', json_build_object('sub', case v when 'M' then M when 'CA' then CA when 'CB' then CB when 'HT' then HT
      when 'PAR' then PAR when 'ADL' then ADL else MIN end, 'role', 'authenticated')::text, true); set local role authenticated;
    out := out || ' ' || v || '=[' || coalesce((select string_agg(x ->> 'label', ', ') from jsonb_array_elements(public.chat_compose_targets()) x), '') || ']'
               || (public.chat_summary() ->> 'enabled');
    reset role;
  end loop;

  -- ---------- the facility thread: only the manager posts; everyone on the facility reads ----------
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  thF := (public.chat_open('facility', org, null, null) ->> 'thread_id')::uuid;
  r := public.chat_post(thF, 'Welcome to the facility! Hours change next week.');
  out := out || ' | facility post by M:' || coalesce(r ->> 'error', 'ok');
  reset role;
  out := out || ' | facility access:';
  for v in select unnest(array['M','CA','PAR','ADL','MIN','HT']) loop
    perform set_config('request.jwt.claims', json_build_object('sub', case v when 'M' then M when 'CA' then CA when 'PAR' then PAR when 'ADL' then ADL
      when 'MIN' then MIN else HT end, 'role', 'authenticated')::text, true); set local role authenticated;
    out := out || ' ' || v || '=' || coalesce(public.chat_access(thF), 'none');
    if v <> 'M' then r := public.chat_post(thF, 'hi'); if r ->> 'ok' = 'true' then fails := fails + 1; out := out || '(POSTED!)'; end if; end if;
    reset role;
  end loop;

  -- ---------- private threads ----------
  perform set_config('request.jwt.claims', json_build_object('sub', PAR, 'role', 'authenticated')::text, true); set local role authenticated;
  thK := (public.chat_open('private', null, gA, KID) ->> 'thread_id')::uuid;
  r := public.chat_post(thK, 'Hi Coach A, Kit has a tournament Saturday -- see https://www.youtube.com/watch?v=dQw4w9WgXcQ <script>alert(1)</script>');
  msg := (r ->> 'id')::uuid; out := out || ' | PAR opens Kit+A and posts:' || coalesce(r ->> 'error', 'ok');
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', CA, 'role', 'authenticated')::text, true); set local role authenticated;
  out := out || ' CA unread before:' || (public.chat_summary() ->> 'unread');
  r := public.chat_mark_read(thK); out := out || ' after read:' || (public.chat_summary() ->> 'unread');
  r := public.chat_post(thK, 'Thanks! Work on the changeup grip from today.'); msg2 := (r ->> 'id')::uuid;
  r := public.chat_pin(msg2, true); out := out || ' CA pins:' || coalesce(r ->> 'error', 'ok');
  thA := (public.chat_open('private', null, gA, ADL) ->> 'thread_id')::uuid;
  r := public.chat_post(thA, 'Ada, see you Tuesday.');
  reset role;
  -- who reads / posts Kit's thread
  out := out || ' | Kit thread access:';
  for v in select unnest(array['M','CA','CB','PAR','ADL','HT']) loop
    perform set_config('request.jwt.claims', json_build_object('sub', case v when 'M' then M when 'CA' then CA when 'CB' then CB when 'PAR' then PAR
      when 'ADL' then ADL else HT end, 'role', 'authenticated')::text, true); set local role authenticated;
    out := out || ' ' || v || '=' || coalesce(public.chat_access(thK), 'none');
    reset role;
  end loop;
  -- the manager can't post in a family's thread (the database refuses), and nobody writes the tables directly
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.chat_post(thK, 'manager here'); out := out || ' | M posts in Kit thread:' || coalesce(r ->> 'error', 'POSTED');
  if r ->> 'ok' = 'true' then fails := fails + 1; end if;
  r := public.chat_pin(msg, true); out := out || ' M pins there:' || coalesce(r ->> 'error', 'PINNED');
  reset role;
  for v in select unnest(array['M','HT','PAR']) loop
    begin
      perform set_config('request.jwt.claims', json_build_object('sub', case v when 'M' then M when 'HT' then HT else PAR end, 'role', 'authenticated')::text, true);
      set local role authenticated;
      execute 'select count(*) from public.chat_messages' into n;
      out := out || ' ' || v || ' direct select:' || n; fails := fails + 1;
    exception when insufficient_privilege then out := out || ' ' || v || ' direct select:denied';
    end;
    begin
      perform set_config('request.jwt.claims', json_build_object('sub', case v when 'M' then M when 'HT' then HT else PAR end, 'role', 'authenticated')::text, true);
      set local role authenticated;   -- again: the failed select above undid the role change with its block
      insert into public.chat_messages (thread_id, author_name, author_role, body) values (thK, 'x', 'coach', 'x');
      out := out || ' insert:ALLOWED'; fails := fails + 1;
    exception when insufficient_privilege then out := out || ' insert:denied';
    end;
    reset role;
  end loop;
  -- the ordinary team's head: no chat at all
  perform set_config('request.jwt.claims', json_build_object('sub', HT, 'role', 'authenticated')::text, true); set local role authenticated;
  out := out || ' | HT threads:' || (select count(*) from public.chat_my_threads()) || ' summary enabled ' || (public.chat_summary() ->> 'enabled');
  reset role;
  -- the 15-year-old waits for the guardian; then can open their coach
  perform set_config('request.jwt.claims', json_build_object('sub', MIN, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.chat_open('private', null, gB, MIN); out := out || ' | MIN before approval:' || coalesce(r ->> 'error', 'opened');
  reset role;
  update public.profiles set guardian_consented_at = now() where id = MIN;
  perform set_config('request.jwt.claims', json_build_object('sub', MIN, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.chat_open('private', null, gB, MIN); thM := (r ->> 'thread_id')::uuid;
  r := public.chat_post(thM, 'Hi coach'); out := out || ' after:' || coalesce(r ->> 'error', 'posted');
  reset role;

  -- ---------- delete, report, pins cap ----------
  perform set_config('request.jwt.claims', json_build_object('sub', PAR, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.chat_delete_message(msg2); out := out || ' | PAR deletes coach msg:' || coalesce(r ->> 'error', 'DELETED');
  r := public.chat_delete_message(msg); out := out || ' PAR deletes own:' || coalesce(r ->> 'error', 'ok');
  r := public.chat_thread(thK);
  out := out || ' PAR sees body of deleted:' || coalesce((select x ->> 'body' from jsonb_array_elements(r -> 'messages') x where (x ->> 'id')::uuid = msg), 'null');
  r := public.chat_report(msg2); out := out || ' PAR reports:' || coalesce(r ->> 'error', 'ok');
  r := public.chat_pin(msg2, false); out := out || ' PAR unpins:' || coalesce(r ->> 'error', 'UNPINNED');
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.chat_thread(thK);
  out := out || ' | M sees deleted text:' || left(coalesce((select x ->> 'body' from jsonb_array_elements(r -> 'messages') x where (x ->> 'id')::uuid = msg), 'null'), 22)
    || ' M reports:' || (public.chat_summary() ->> 'reports') || ' list:' || jsonb_array_length(public.chat_open_reports());
  r := public.chat_resolve_report(((public.chat_open_reports() -> 0) ->> 'id')::uuid);
  out := out || ' resolved -> ' || (public.chat_summary() ->> 'reports');
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', CA, 'role', 'authenticated')::text, true); set local role authenticated;
  for i in 1..5 loop r := public.chat_post(thK, 'drill ' || i); r := public.chat_pin((r ->> 'id')::uuid, true); end loop;
  out := out || ' | 6th pin:' || coalesce(r ->> 'error', 'ok');   -- msg2 + 4 drills = 5, the 5th drill is the 6th
  reset role;

  -- ---------- moving coaches: the conversation follows; the old coach is out ----------
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.move_between_groups(KID, gA, gB);
  reset role;
  out := out || ' | after move A->B: thread now in group B ' || ((select group_id from public.chat_threads where id = thK) = gB);
  for v in select unnest(array['CA','CB','PAR']) loop
    perform set_config('request.jwt.claims', json_build_object('sub', case v when 'CA' then CA when 'CB' then CB else PAR end, 'role', 'authenticated')::text, true);
    set local role authenticated;
    out := out || ' ' || v || '=' || coalesce(public.chat_access(thK), 'none');
    if v = 'CB' then out := out || '(sees ' || jsonb_array_length(public.chat_thread(thK) -> 'messages') || ' msgs)'; end if;
    reset role;
  end loop;

  -- ---------- closing (coach "deletes"), departed family, the 90-day clear ----------
  perform set_config('request.jwt.claims', json_build_object('sub', CA, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.chat_close(thA); out := out || ' | CA closes Ada thread:' || coalesce(r ->> 'error', 'ok');
  out := out || ' CA still lists it:' || exists (select 1 from public.chat_my_threads() where thread_id = thA);
  reset role;
  for v in select unnest(array['M','ADL']) loop
    perform set_config('request.jwt.claims', json_build_object('sub', case v when 'M' then M else ADL end, 'role', 'authenticated')::text, true); set local role authenticated;
    out := out || ' ' || v || '=' || coalesce(public.chat_access(thA), 'none');
    r := public.chat_post(thA, 'still there?'); out := out || '(post ' || coalesce(r ->> 'error', 'POSTED') || ')';
    reset role;
  end loop;
  -- MIN leaves coach B's group (their only one): off the side, thread closed, family keeps reading
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.remove_from_group(gB, MIN);
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', MIN, 'role', 'authenticated')::text, true); set local role authenticated;
  out := out || ' | MIN removed: thread ' || coalesce(public.chat_access(thM), 'none') || ', lists it ' || exists (select 1 from public.chat_my_threads() where thread_id = thM);
  reset role;
  update public.chat_threads set clear_after = now() - interval '1 minute' where id = thA;   -- back-dated: 90 days passed
  n := public.chat_clear_archived();
  out := out || ' | clear job removed ' || n || ', Ada thread gone ' || not exists (select 1 from public.chat_threads where id = thA);

  -- ---------- account deletion (decision D) ----------
  r := public.a1_purge_profile(PAR);
  out := out || ' | purge PAR: their messages ' || (select string_agg(author_name || '/' || coalesce(nullif(body, ''), '(blank)') || '/' || author_deleted, ', ')
                                                      from public.chat_messages where thread_id = thK and author_role = 'parent')
    || '; Kit thread closed ' || ((select archived_at from public.chat_threads where id = thK) is not null);

  out := out || ' | policies ' || (select count(*) from pg_policies where schemaname = 'public') || ' | hard fails ' || fails;
  raise exception 'C1(rolled back):%', out;
end $$;
