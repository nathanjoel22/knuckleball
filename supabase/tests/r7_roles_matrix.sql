-- R7 Stage C, Done-when 13 (staging; rolled back -- the block ends by raising its results): a login with two roles reads
-- exactly the union of what each role reads alone, never more (decision 6, "the union, never more"). Method: build the
-- two-role login the real way (the link functions), read every table with a read rule as that login, then move one role
-- to a twin login (same rows, same memberships, only the owner changes), read as each, and compare row for row.
-- Pairs: (1) a team's head coach who joins another team as a pitcher, (2) a facility manager who joins a team's
-- coaching staff (Joel's case), (3) a team's head coach who becomes a guardian of a parent's player.
do $$
declare
  L uuid := 'aaaaaaaa-0000-4000-8000-0000000007d1'; HB uuid := 'aaaaaaaa-0000-4000-8000-0000000007d2';
  HX uuid := 'aaaaaaaa-0000-4000-8000-0000000007d3'; F uuid := 'aaaaaaaa-0000-4000-8000-0000000007d4';
  PAR uuid := 'aaaaaaaa-0000-4000-8000-0000000007d5'; PA uuid := 'aaaaaaaa-0000-4000-8000-0000000007d6';
  PB uuid := 'aaaaaaaa-0000-4000-8000-0000000007d7'; PX uuid := 'aaaaaaaa-0000-4000-8000-0000000007d8';
  PF uuid := 'aaaaaaaa-0000-4000-8000-0000000007d9'; T1 uuid := 'aaaaaaaa-0000-4000-8000-0000000007da';
  T2 uuid := 'aaaaaaaa-0000-4000-8000-0000000007db'; T3 uuid := 'aaaaaaaa-0000-4000-8000-0000000007dc';
  A uuid; B uuid; X uuid; KID uuid; org uuid; FBB uuid; FBside uuid; pL uuid; code text; tok text; r jsonb;
  bTeam text; xStaff text; pj jsonb; out text := ''; fails int := 0; pol0 int;
  snap_sql text := $q$select jsonb_build_object(
      'sessions',      (select coalesce(jsonb_agg(id::text order by id), '[]') from public.sessions),
      'pitches',       (select coalesce(jsonb_agg(id::text order by id), '[]') from public.pitches),
      'game_events',   (select coalesce(jsonb_agg(id::text order by id), '[]') from public.game_events),
      'session_stats', (select coalesce(jsonb_agg(session_id::text order by session_id), '[]') from public.session_stats),
      'session_notes', (select coalesce(jsonb_agg(id::text order by id), '[]') from public.session_notes),
      'pitcher_teams', (select coalesce(jsonb_agg(pitcher_id::text || '/' || team_id::text order by pitcher_id, team_id), '[]') from public.pitcher_teams),
      'team_coaches',  (select coalesce(jsonb_agg(team_id::text || '/' || coach_id::text order by team_id, coach_id), '[]') from public.team_coaches),
      'teams',         (select coalesce(jsonb_agg(id::text order by id), '[]') from public.teams),
      'profiles',      (select coalesce(jsonb_agg(id::text order by id), '[]') from public.profiles))$q$;
  sBoth jsonb; s1 jsonb; s2 jsonb; k text; u jsonb; pair text;
begin
  select count(*) into pol0 from pg_policies where schemaname = 'public';
  -- ---------- fixture ----------
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select x.u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', x.e || '@example.invalid',
         jsonb_build_object('full_name', x.nm, 'intended_role', x.ro, 'intended_sport', 'baseball'), now(), now()
    from (values (L, 'r7m-l', 'Lee TwoRoles', 'coach'), (HB, 'r7m-hb', 'Bo B', 'coach'), (HX, 'r7m-hx', 'Xan X', 'coach'),
                 (F, 'r7m-f', 'Fay Facility', 'coach'), (PAR, 'r7m-par', 'Pam Parent', 'parent'), (PA, 'r7m-pa', 'Al A', 'pitcher'),
                 (PB, 'r7m-pb', 'Ben B', 'pitcher'), (PX, 'r7m-px', 'Xia X', 'pitcher'), (PF, 'r7m-pf', 'Fin F', 'pitcher'),
                 (T1, 'r7m-t1', 'Twin One', 'pitcher'), (T2, 'r7m-t2', 'Twin Two', 'coach'), (T3, 'r7m-t3', 'Twin Three', 'parent')) x(u, e, nm, ro);
  insert into public.profiles (id, role, full_name, sport) select x.u, x.ro, x.nm, x.sp
    from (values (PA, 'pitcher', 'Al A', 'baseball'), (PB, 'pitcher', 'Ben B', 'baseball'), (PX, 'pitcher', 'Xia X', 'baseball'),
                 (PF, 'pitcher', 'Fin F', 'baseball'), (PAR, 'parent', 'Pam Parent', null),
                 (T3, 'parent', 'Twin Three', null)) x(u, ro, nm, sp)   -- T1 has no profile: the moved pitcher profile becomes its only one
   where not exists (select 1 from public.profiles where id = x.u);
  update public.profiles set age_attestation = 'adult', attested_at = now(), attested_via = 'signup', terms_version = '2026-10-17', email_verified_at = now()
   where id in (L, HB, HX, F, PAR, PA, PB, PX, PF, T1, T2, T3);
  A := public._create_team_with_head(L, 'R7M Team A');
  B := public._create_team_with_head(HB, 'R7M Team B');
  X := public._create_team_with_head(HX, 'R7M Team X');
  select invite_token into bTeam from public.teams where id = B;
  select coach_invite_token into xStaff from public.teams where id = X;
  insert into public.pitcher_teams (pitcher_id, team_id) values (PA, A), (PB, B), (PX, X);
  perform set_config('request.jwt.claims', json_build_object('sub', F, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.create_facility_self('R7M Facility'); org := (r ->> 'org_id')::uuid;
  reset role;
  select id into FBside from public.teams where org_id = org and sport = 'baseball';
  select id into FBB from public.profiles where account_id = F and role = 'coach' and sport = 'baseball';
  select g.join_token into code from public.coach_groups g where g.team_id = FBside and g.coach_id = FBB;
  perform set_config('request.jwt.claims', json_build_object('sub', PF, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.join_group_via_token(code, null);
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', PAR, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.add_player('Kim Kid', 'baseball', 'R', true); KID := (r ->> 'id')::uuid;
  reset role;
  -- one saved pen per place, each charted by the people who chart it in real life
  select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'fb', 'velo', 80, 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2)) into pj from generate_series(1, 3);
  perform set_config('request.jwt.claims', json_build_object('sub', L, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.sync_session(jsonb_build_object('id', gen_random_uuid(), 'pitcher_id', PA, 'team_id', A, 'logged_by', L,
         'started_at', now() - interval '2 hours', 'ended_at', now() - interval '1 hour'), pj, '[]');
  out := out || 'pens: A ' || coalesce(r ->> 'status', r ->> 'error');
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', HB, 'role', 'authenticated')::text, true); set local role authenticated;
  select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'fb', 'velo', 80, 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2)) into pj from generate_series(1, 3);
  r := public.sync_session(jsonb_build_object('id', gen_random_uuid(), 'pitcher_id', PB, 'team_id', B, 'logged_by', HB,
         'started_at', now() - interval '2 hours', 'ended_at', now() - interval '1 hour'), pj, '[]');
  out := out || ', B ' || coalesce(r ->> 'status', r ->> 'error');
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', HX, 'role', 'authenticated')::text, true); set local role authenticated;
  select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'fb', 'velo', 80, 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2)) into pj from generate_series(1, 3);
  r := public.sync_session(jsonb_build_object('id', gen_random_uuid(), 'pitcher_id', PX, 'team_id', X, 'logged_by', HX,
         'started_at', now() - interval '2 hours', 'ended_at', now() - interval '1 hour'), pj, '[]');
  out := out || ', X ' || coalesce(r ->> 'status', r ->> 'error');
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', F, 'role', 'authenticated')::text, true); set local role authenticated;
  select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'fb', 'velo', 80, 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2)) into pj from generate_series(1, 3);
  r := public.sync_session(jsonb_build_object('id', gen_random_uuid(), 'pitcher_id', PF, 'team_id', FBside, 'logged_by', FBB,
         'started_at', now() - interval '2 hours', 'ended_at', now() - interval '1 hour'), pj, '[]');
  out := out || ', facility ' || coalesce(r ->> 'status', r ->> 'error');
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', PAR, 'role', 'authenticated')::text, true); set local role authenticated;
  select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'fb', 'velo', 70, 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2)) into pj from generate_series(1, 3);
  r := public.sync_session(jsonb_build_object('id', gen_random_uuid(), 'pitcher_id', KID, 'team_id', null, 'logged_by', KID,
         'started_at', now() - interval '2 hours', 'ended_at', now() - interval '1 hour'), pj, '[]');
  out := out || ', kid ' || coalesce(r ->> 'status', r ->> 'error');
  reset role;

  -- ---------- the three two-role logins, made by the link functions ----------
  perform set_config('request.jwt.claims', json_build_object('sub', L, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.join_team_via_invite(bTeam, null, true); pL := (r ->> 'profile_id')::uuid;
  out := out || ' | L joins B as pitcher ' || coalesce(r ->> 'error', 'ok');
  select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'fb', 'velo', 75, 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2)) into pj from generate_series(1, 2);
  r := public.sync_session(jsonb_build_object('id', gen_random_uuid(), 'pitcher_id', pL, 'team_id', B, 'logged_by', pL,
         'started_at', now() - interval '50 minutes', 'ended_at', now() - interval '40 minutes'), pj, '[]');
  out := out || ', L''s own pen on B ' || coalesce(r ->> 'status', r ->> 'error');
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', F, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.join_team_as_coach(xStaff, null); out := out || ', F joins X staff ' || coalesce(r ->> 'error', 'ok');
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', PAR, 'role', 'authenticated')::text, true); set local role authenticated;
  tok := public.create_player_link(KID, 'guardian') ->> 'token';
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', HB, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.accept_player_link(tok, '2026-10-17'); out := out || ', HB guardian of the kid ' || coalesce(r ->> 'error', 'ok');
  reset role;
  insert into public.profiles (id, role, full_name, sport) select T2, 'coach', 'Twin Two', 'baseball' where not exists (select 1 from public.profiles where id = T2);

  -- ---------- read, split, read, compare ----------
  for pair in select unnest(array['coach + pitcher', 'facility + assistant', 'coach + guardian']) loop
    -- both roles on one login
    perform set_config('request.jwt.claims', json_build_object('sub', case pair when 'coach + pitcher' then L when 'facility + assistant' then F else HB end, 'role', 'authenticated')::text, true);
    set local role authenticated; execute snap_sql into sBoth; reset role;
    -- split one role off to a twin
    if pair = 'coach + pitcher' then update public.profiles set account_id = T1 where id = pL;
    elsif pair = 'facility + assistant' then update public.team_coaches set coach_id = T2 where team_id = X and coach_id = FBB;
    else update public.player_links set login = T3 where login = HB and player_id = KID; end if;
    perform set_config('request.jwt.claims', json_build_object('sub', case pair when 'coach + pitcher' then L when 'facility + assistant' then F else HB end, 'role', 'authenticated')::text, true);
    set local role authenticated; execute snap_sql into s1; reset role;
    perform set_config('request.jwt.claims', json_build_object('sub', case pair when 'coach + pitcher' then T1 when 'facility + assistant' then T2 else T3 end, 'role', 'authenticated')::text, true);
    set local role authenticated; execute snap_sql into s2; reset role;
    -- the twin's own identity (its own profile row, and in pair 2 the staff row under its id) stands for the original's
    if pair = 'facility + assistant' then s2 := replace(s2::text, T2::text, FBB::text)::jsonb;
    elsif pair = 'coach + guardian' then s2 := replace(s2::text, T3::text, HB::text)::jsonb; end if;
    -- put it back
    if pair = 'coach + pitcher' then update public.profiles set account_id = L where id = pL;
    elsif pair = 'facility + assistant' then update public.team_coaches set coach_id = FBB where team_id = X and coach_id = T2;
    else update public.player_links set login = HB where login = T3 and player_id = KID; end if;
    out := out || ' | ' || pair || ':';
    for k in select jsonb_object_keys(sBoth) loop
      select coalesce(jsonb_agg(v order by v), '[]') into u from (select distinct v from jsonb_array_elements_text((s1 -> k) || (s2 -> k)) v) d;
      if u = (select coalesce(jsonb_agg(v order by v), '[]') from jsonb_array_elements_text(sBoth -> k) v) then
        out := out || ' ' || k || ' ' || jsonb_array_length(sBoth -> k) || '=' || jsonb_array_length(s1 -> k) || '+' || jsonb_array_length(s2 -> k);
      else
        fails := fails + 1;
        out := out || ' ' || k || ' DIFFERS (both ' || jsonb_array_length(sBoth -> k) || ', union ' || jsonb_array_length(u) || ')';
      end if;
    end loop;
  end loop;
  out := out || ' | policies ' || pol0 || '->' || (select count(*) from pg_policies where schemaname = 'public') || ' | hard fails ' || fails;
  raise exception 'R7MATRIX(rolled back):%', out;
end $$;
