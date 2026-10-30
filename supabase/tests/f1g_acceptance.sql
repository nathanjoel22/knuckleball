-- F1-G linked sign-ins acceptance (staging; everything rolled back -- the block ends by raising its results).
-- Fixture logins (example.invalid): PAR a parent who creates the player KID; G2 a second parent; FAM and FAM2 parents
-- used as friends and family; X another parent; CH a brand-new login (the child's own sign-in); PIT a pitcher with
-- their own login; M a facility manager and CA their coach (KID in CA's group); HT head of an ordinary team KID is
-- also on (for notes and the leaderboard).
--   supabase db query --linked --project-ref wpsscxwawgiwmifpjpec -f supabase/tests/f1g_acceptance.sql
do $$
declare
  PAR uuid := 'aaaaaaaa-0000-4000-8000-00000000d101'; G2 uuid := 'aaaaaaaa-0000-4000-8000-00000000d102';
  FAM uuid := 'aaaaaaaa-0000-4000-8000-00000000d103'; FAM2 uuid := 'aaaaaaaa-0000-4000-8000-00000000d104';
  X uuid := 'aaaaaaaa-0000-4000-8000-00000000d105'; CH uuid := 'aaaaaaaa-0000-4000-8000-00000000d106';
  PIT uuid := 'aaaaaaaa-0000-4000-8000-00000000d107'; M uuid := 'aaaaaaaa-0000-4000-8000-00000000d108';
  CA uuid := 'aaaaaaaa-0000-4000-8000-00000000d109'; HT uuid := 'aaaaaaaa-0000-4000-8000-00000000d110';
  KID uuid; tok text; tG text; tF text; tC text; org uuid; FB uuid; mBB uuid; gA uuid; T uuid; s1 uuid := gen_random_uuid();
  s2 uuid; th uuid; pj jsonb; r jsonb; n int; n2 int; n3 int; out text := ''; fails int := 0; v text; who record;
begin
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', e || '@example.invalid', md, now(), now()
    from (values (PAR, 'g-par', '{}'::jsonb), (G2, 'g-g2', '{}'::jsonb), (FAM, 'g-fam', '{}'::jsonb), (FAM2, 'g-fam2', '{}'::jsonb),
                 (X, 'g-x', '{}'::jsonb), (CH, 'g-ch', '{"full_name":"Kit Kid"}'::jsonb), (PIT, 'g-pit', '{}'::jsonb),
                 (M, 'g-m', '{"full_name":"Mona Manager","intended_role":"coach","intended_sport":"baseball"}'::jsonb),
                 (CA, 'g-ca', '{"full_name":"Coach A","intended_role":"coach","intended_sport":"baseball"}'::jsonb),
                 (HT, 'g-ht', '{"full_name":"Team Head","intended_role":"coach","intended_sport":"baseball"}'::jsonb)) x(u, e, md);
  insert into public.profiles (id, role, full_name, sport) values (PAR, 'parent', 'Pat Parent', null), (G2, 'parent', 'Gale Second', null),
    (FAM, 'parent', 'Fay Family', null), (FAM2, 'parent', 'Finn Family', null), (X, 'parent', 'Xan Extra', null),
    (PIT, 'pitcher', 'Pia Pitcher', 'baseball');
  update public.profiles set email_verified_at = now(), age_attestation = 'adult', attested_at = now(), attested_via = 'signup', terms_version = '2026-10-17'
   where id in (PAR, G2, FAM, FAM2, X, PIT, M, CA, HT);
  perform set_config('request.jwt.claims', json_build_object('sub', PAR, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.add_player('Kit Kid', 'baseball', 'R', true); KID := (r ->> 'id')::uuid;
  reset role;
  insert into public.facility_invites (facility_name, manager_email, baseball_level, softball_level)
    values ('G Test Facility', 'g-m@example.invalid', 'high_school', 'high_school_up') returning token into tok;
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.create_facility(tok); org := (r ->> 'org_id')::uuid;
  reset role;
  insert into public.profiles (id, role, full_name, sport) values (CA, 'coach', 'Coach A', 'baseball'), (HT, 'coach', 'Team Head', 'baseball') on conflict do nothing;
  update public.profiles set email_verified_at = now(), age_attestation = 'adult', attested_at = now(), attested_via = 'signup', terms_version = '2026-10-17' where id in (M, CA, HT);
  select id, coach_id into FB, mBB from public.teams where org_id = org and sport = 'baseball';
  insert into public.team_coaches (team_id, coach_id, role, invited_by) values (FB, CA, 'assistant', mBB);
  select id into gA from public.coach_groups where team_id = FB and coach_id = CA;
  T := public._create_team_with_head(HT, 'G Ordinary Team');
  insert into public.pitcher_teams (pitcher_id, team_id) values (KID, FB), (KID, T);
  insert into public.coach_group_members (group_id, pitcher_id, flagged_new) values (gA, KID, false);
  -- one pen on the ordinary team (by HT) with a note, before anyone is linked
  perform set_config('request.jwt.claims', json_build_object('sub', HT, 'role', 'authenticated')::text, true); set local role authenticated;
  select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'fb', 'velo', 80, 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2)) into pj from generate_series(1, 4);
  r := public.sync_session(jsonb_build_object('id', s1, 'pitcher_id', KID, 'team_id', T, 'logged_by', HT,
         'started_at', now() - interval '3 days', 'ended_at', now() - interval '3 days' + interval '20 minutes'), pj, '[]');
  reset role;
  insert into public.session_notes (session_id, author_id, author_name, body) values (s1, HT, 'Team Head', 'Nice pen.');
  out := 'setup: pen ' || coalesce(r ->> 'status', r ->> 'error');

  -- ---------- 1. who can make links ----------
  out := out || ' | 1 make links:';
  for who in select * from (values ('PAR', PAR), ('G2', G2), ('CA', CA), ('M', M)) t(nm, id) loop
    perform set_config('request.jwt.claims', json_build_object('sub', who.id, 'role', 'authenticated')::text, true); set local role authenticated;
    r := public.create_player_link(KID, 'guardian');
    out := out || ' ' || who.nm || '=' || coalesce(r ->> 'error', 'ok');
    if who.nm = 'PAR' then tG := r ->> 'token'; end if;
    if (who.nm = 'PAR') <> coalesce((r ->> 'ok')::boolean, false) then fails := fails + 1; out := out || '(FAIL)'; end if;
    reset role;
  end loop;
  perform set_config('request.jwt.claims', json_build_object('sub', PAR, 'role', 'authenticated')::text, true); set local role authenticated;
  tF := public.create_player_link(KID, 'family') ->> 'token';
  tC := public.create_player_link(KID, 'child') ->> 'token';
  reset role;

  -- ---------- 2. what the link says before signing in (anon) ----------
  set local role anon;
  r := public.player_link_info(tG);
  out := out || ' | 2 info(anon): ' || (r ->> 'status') || ' ' || (r ->> 'role') || ' for ' || (r ->> 'player_name') || ' from ' || (r ->> 'from_name')
             || '; bad token ' || (public.player_link_info('nope') ->> 'status');
  reset role;

  -- ---------- 3. accepting ----------
  out := out || ' | 3 accept:';
  for who in select * from (values ('PIT as guardian', PIT, tG), ('CA as guardian', CA, tG), ('PAR own player', PAR, tG),
                                    ('G2 as guardian', G2, tG), ('X same link again', X, tG), ('G2 again', G2, tG),
                                    ('FAM as family', FAM, tF), ('PIT as child', PIT, tC), ('CH as child', CH, tC)) t(nm, id, tk) loop
    perform set_config('request.jwt.claims', json_build_object('sub', who.id, 'role', 'authenticated')::text, true); set local role authenticated;
    r := public.accept_player_link(who.tk, '2026-10-17');
    out := out || ' ' || who.nm || '=' || coalesce(r ->> 'error', coalesce(r ->> 'status', 'ok'));
    if (who.nm in ('G2 as guardian', 'G2 again', 'FAM as family', 'CH as child')) <> coalesce((r ->> 'ok')::boolean, false) then fails := fails + 1; out := out || '(FAIL)'; end if;
    reset role;
  end loop;
  out := out || '; CH profile ' || (select role || '/' || full_name || '/' || age_attestation || '/' || consent_via || '/' || (guardian_consented_at is not null) from public.profiles where id = CH);

  -- ---------- 4. limits: two parents in all, at most 5 friends and family, one child ----------
  perform set_config('request.jwt.claims', json_build_object('sub', PAR, 'role', 'authenticated')::text, true); set local role authenticated;
  out := out || ' | 4 limits: 3rd parent link ' || coalesce(public.create_player_link(KID, 'guardian') ->> 'error', 'ok')
             || ', 2nd child link ' || coalesce(public.create_player_link(KID, 'child') ->> 'error', 'ok');
  reset role;
  insert into public.player_links (player_id, login, role) select KID, u, 'family' from unnest(array[FAM2, X, PIT, M]) u;   -- now 5 family
  perform set_config('request.jwt.claims', json_build_object('sub', PAR, 'role', 'authenticated')::text, true); set local role authenticated;
  out := out || ', 6th family link ' || coalesce(public.create_player_link(KID, 'family') ->> 'error', 'ok');
  reset role;
  delete from public.player_links where player_id = KID and login in (FAM2, X, PIT, M);

  -- ---------- 5. expired link ----------
  perform set_config('request.jwt.claims', json_build_object('sub', PAR, 'role', 'authenticated')::text, true); set local role authenticated;
  tF := public.create_player_link(KID, 'family') ->> 'token';
  reset role;
  update public.player_link_invites set expires_at = now() - interval '1 minute' where token = tF;
  perform set_config('request.jwt.claims', json_build_object('sub', FAM2, 'role', 'authenticated')::text, true); set local role authenticated;
  out := out || ' | 5 expired link: ' || coalesce(public.accept_player_link(tF, '2026-10-17') ->> 'error', 'ok');
  reset role;

  -- ---------- 6. reads: sessions / pitches / stats / notes / player row / team row / leaderboard ----------
  out := out || ' | 6 reads (sess/pitches/stats/notes/profile/teams):';
  for who in select * from (values ('PAR', PAR), ('G2', G2), ('CH', CH), ('FAM', FAM), ('X', X)) t(nm, id) loop
    perform set_config('request.jwt.claims', json_build_object('sub', who.id, 'role', 'authenticated')::text, true); set local role authenticated;
    select count(*) into n from public.sessions where id = s1;
    select count(*) into n2 from public.pitches where session_id = s1;
    select count(*) into n3 from public.session_stats where session_id = s1;
    out := out || ' ' || who.nm || '=' || n || '/' || n2 || '/' || n3 || '/' || (select count(*) from public.session_notes where session_id = s1)
               || '/' || (select count(*) from public.profiles where id = KID) || '/' || (select count(*) from public.teams where id in (T, FB));
    if who.nm in ('PAR', 'G2', 'CH') and not (n = 1 and n2 = 4 and n3 = 1) then fails := fails + 1; out := out || '(FAIL)'; end if;
    if who.nm = 'FAM' and not (n = 1 and n2 = 4 and n3 = 1 and (select count(*) from public.session_notes where session_id = s1) = 1
                               and (select count(*) from public.profiles where id = KID) = 0) then fails := fails + 1; out := out || '(FAIL)'; end if;
    if who.nm = 'X' and n + n2 + n3 > 0 then fails := fails + 1; out := out || '(FAIL)'; end if;
    reset role;
  end loop;
  out := out || '; my_linked_players:';
  for who in select * from (values ('G2', G2), ('CH', CH), ('FAM', FAM), ('X', X)) t(nm, id) loop
    perform set_config('request.jwt.claims', json_build_object('sub', who.id, 'role', 'authenticated')::text, true); set local role authenticated;
    r := public.my_linked_players();
    out := out || ' ' || who.nm || '=' || coalesce((select string_agg((je ->> 'full_name') || '/' || (je ->> 'linked_role') || '/contacts:' || (je -> 'contact_emails' is not null and jsonb_typeof(je -> 'contact_emails') <> 'null'), ',') from jsonb_array_elements(r) je), 'none');
    reset role;
  end loop;
  out := out || '; leaderboard T:';
  for who in select * from (values ('G2', G2), ('CH', CH), ('FAM', FAM)) t(nm, id) loop
    perform set_config('request.jwt.claims', json_build_object('sub', who.id, 'role', 'authenticated')::text, true); set local role authenticated;
    begin
      r := public.get_team_leaderboard(T, 'all');
      out := out || ' ' || who.nm || '=' || case when r ? 'error' then r ->> 'error' else 'ok' end;
    exception when others then out := out || ' ' || who.nm || '=refused'; set local role authenticated;
    end;
    reset role;
  end loop;

  -- ---------- 7. charting: the second parent and the child chart; family can't ----------
  out := out || ' | 7 chart a pen:';
  for who in select * from (values ('G2', G2), ('CH', CH), ('FAM', FAM), ('X', X)) t(nm, id) loop
    perform set_config('request.jwt.claims', json_build_object('sub', who.id, 'role', 'authenticated')::text, true); set local role authenticated;
    select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'fb', 'velo', 70, 'target_row', 1, 'target_col', 1, 'actual_row', 1, 'actual_col', 2)) into pj from generate_series(1, 3);
    s2 := gen_random_uuid();
    r := public.sync_session(jsonb_build_object('id', s2, 'pitcher_id', KID, 'team_id', null, 'logged_by', KID,
           'started_at', now() - interval '1 hour', 'ended_at', now() - interval '40 minutes'), pj, '[]');
    out := out || ' ' || who.nm || '=' || coalesce(r ->> 'status', r ->> 'error');
    if (who.nm in ('G2', 'CH')) <> (r ->> 'ok' = 'true') then fails := fails + 1; out := out || '(FAIL)'; end if;
    reset role;
  end loop;
  perform set_config('request.jwt.claims', json_build_object('sub', G2, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.sync_session(jsonb_build_object('id', gen_random_uuid(), 'pitcher_id', KID, 'team_id', null, 'logged_by', HT,
         'started_at', now() - interval '2 hours', 'ended_at', now() - interval '100 minutes'), pj, '[]');
  out := out || '; G2 as someone else=' || coalesce(r ->> 'status', r ->> 'error');
  if r ->> 'ok' = 'true' then fails := fails + 1; out := out || '(FAIL)'; end if;
  reset role;
  out := out || '; G2''s pen logged as the player ' || exists (select 1 from public.sessions where pitcher_id = KID and logged_by = KID);

  -- ---------- 8. what stays with the creator ----------
  perform set_config('request.jwt.claims', json_build_object('sub', G2, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.delete_session(s1);
  out := out || ' | 8 G2: delete a pen=' || coalesce(r ->> 'error', 'ok');
  update public.profiles set full_name = 'Renamed' where id = KID;
  get diagnostics n = row_count;
  out := out || ', rename player rows=' || n || ', link for others=' || coalesce(public.create_player_link(KID, 'family') ->> 'error', 'ok')
             || ', remove FAM=' || coalesce(public.remove_player_link(KID, FAM) ->> 'error', 'ok')
             || ', see access list=' || coalesce(public.player_access(KID) ->> 'error', 'ok');
  reset role;
  select invite_token into v from public.teams where id = T;
  perform set_config('request.jwt.claims', json_build_object('sub', CH, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.join_team_via_invite(v, null);
  out := out || '; CH: join a team=' || coalesce(r ->> 'error', 'ok') || ', add a player=';
  begin
    r := public.add_player('Other', 'baseball', 'R', true);
    out := out || coalesce(r ->> 'error', 'ok');
  exception when others then out := out || 'refused'; set local role authenticated;
  end;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', PAR, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.player_access(KID);
  out := out || '; PAR access list: ' || (select string_agg((je ->> 'name') || '/' || (je ->> 'role'), ', ') from jsonb_array_elements(r -> 'links') je);
  reset role;

  -- ---------- 9. direct table access ----------
  out := out || ' | 9 direct reads:';
  for who in select * from (values ('PAR', PAR), ('G2', G2)) t(nm, id) loop
    perform set_config('request.jwt.claims', json_build_object('sub', who.id, 'role', 'authenticated')::text, true); set local role authenticated;
    begin
      select count(*) into n from public.player_links;
      out := out || ' ' || who.nm || ' links=' || n || '(FAIL)'; fails := fails + 1;
    exception when insufficient_privilege then out := out || ' ' || who.nm || ' links=denied'; set local role authenticated;
    end;
    begin
      select count(*) into n from public.player_link_invites;
      out := out || ' invites=' || n || '(FAIL)'; fails := fails + 1;
    exception when insufficient_privilege then out := out || ' invites=denied'; set local role authenticated;
    end;
    reset role;
  end loop;

  -- ---------- 10. chat: the second parent and the child chat with the coach; family doesn't ----------
  out := out || ' | 10 chat compose:';
  for who in select * from (values ('PAR', PAR), ('G2', G2), ('CH', CH), ('FAM', FAM)) t(nm, id) loop
    perform set_config('request.jwt.claims', json_build_object('sub', who.id, 'role', 'authenticated')::text, true); set local role authenticated;
    out := out || ' ' || who.nm || '=[' || coalesce((select string_agg(je ->> 'label', ', ') from jsonb_array_elements(public.chat_compose_targets()) je), '')
               || ']' || (public.chat_summary() ->> 'enabled');
    reset role;
  end loop;
  perform set_config('request.jwt.claims', json_build_object('sub', G2, 'role', 'authenticated')::text, true); set local role authenticated;
  th := (public.chat_open('private', null, gA, KID) ->> 'thread_id')::uuid;
  out := out || '; G2 post=' || coalesce(public.chat_post(th, 'Hi coach, this is Kit''s other parent.') ->> 'error', 'ok');
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', CH, 'role', 'authenticated')::text, true); set local role authenticated;
  out := out || ', CH post=' || coalesce(public.chat_post(th, 'Hi coach, it''s Kit.') ->> 'error', 'ok');
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', FAM, 'role', 'authenticated')::text, true); set local role authenticated;
  out := out || ', FAM access=' || coalesce(public.chat_access(th), 'none') || ', FAM post=' || coalesce(public.chat_post(th, 'hello') ->> 'error', 'ok');
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', CA, 'role', 'authenticated')::text, true); set local role authenticated;
  out := out || '; coach sees: ' || (select string_agg((je ->> 'author') || '(' || (je ->> 'role') || ')', ', ') from jsonb_array_elements(public.chat_thread(th) -> 'messages') je)
             || '; coach''s list title for Kit=' || coalesce((select title from public.chat_my_threads() where thread_id = th), '-');
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', G2, 'role', 'authenticated')::text, true); set local role authenticated;
  out := out || '; G2''s list title=' || coalesce((select title || ' / ' || subtitle from public.chat_my_threads() where thread_id = th), '-');
  reset role;

  -- ---------- 11. removing and leaving ----------
  perform set_config('request.jwt.claims', json_build_object('sub', FAM, 'role', 'authenticated')::text, true); set local role authenticated;
  out := out || ' | 11 FAM leaves=' || coalesce(public.leave_player(KID) ->> 'error', 'ok');
  out := out || ', then reads ' || (select count(*) from public.sessions where pitcher_id = KID);
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', PAR, 'role', 'authenticated')::text, true); set local role authenticated;
  out := out || '; PAR removes G2=' || coalesce(public.remove_player_link(KID, G2) ->> 'error', 'ok');
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', G2, 'role', 'authenticated')::text, true); set local role authenticated;
  out := out || ', then G2 reads ' || (select count(*) from public.sessions where pitcher_id = KID) || ' sessions, chat ' || coalesce(public.chat_access(th), 'none');
  reset role;

  -- ---------- 12. account deletion ----------
  r := public.a1_purge_profile(CH);
  out := out || ' | 12 purge CH: their message ' || coalesce((select author_name || '/' || coalesce(nullif(body, ''), '(blank)') from public.chat_messages
                                                               where thread_id = th and author_deleted), 'not blanked')
             || ', the player''s pens kept ' || (select count(*) from public.sessions where pitcher_id = KID and deleted_at is null);
  delete from auth.users where id = CH;
  out := out || ', CH link gone ' || not exists (select 1 from public.player_links where login = CH);
  r := public.a1_purge_profile(KID);
  out := out || '; purge KID: links ' || (select count(*) from public.player_links where player_id = KID)
             || ', invites ' || (select count(*) from public.player_link_invites where player_id = KID);

  out := out || ' | policies ' || (select count(*) from pg_policies where schemaname = 'public') || ' | hard fails ' || fails;
  raise exception 'G(rolled back):%', out;
end $$;
