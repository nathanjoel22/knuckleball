-- R7 Stage C acceptance (staging; everything rolled back -- the block ends by raising its results). Checks are numbered
-- after the packet's Done-when 10, 11, 12, 14 and 15. Fixture logins (example.invalid): F a facility manager
-- (create_facility_self), HX head of an ordinary team X, HB head of team B, CO a coach, PI an adult pitcher, PAR a parent
-- with player KID, TEEN a 13-17 pitcher, CH a child sign-in linked to KID.
do $$
declare
  F uuid := 'aaaaaaaa-0000-4000-8000-0000000007c1'; HX uuid := 'aaaaaaaa-0000-4000-8000-0000000007c2';
  HB uuid := 'aaaaaaaa-0000-4000-8000-0000000007c3'; CO uuid := 'aaaaaaaa-0000-4000-8000-0000000007c4';
  PI uuid := 'aaaaaaaa-0000-4000-8000-0000000007c5'; PAR uuid := 'aaaaaaaa-0000-4000-8000-0000000007c6';
  TEEN uuid := 'aaaaaaaa-0000-4000-8000-0000000007c7'; CH uuid := 'aaaaaaaa-0000-4000-8000-0000000007c8';
  X uuid; B uuid; KID uuid; org uuid; tok text; r jsonb; n int; n2 int; err text; out text := ''; fails int := 0;
  p uuid; roles text; pol0 int; xStaff text; xTeam text; bStaff text; bTeam text;
begin
  select count(*) into pol0 from pg_policies where schemaname = 'public';
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select x.u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', x.e || '@example.invalid',
         jsonb_build_object('full_name', x.nm, 'intended_role', x.ro, 'intended_sport', 'baseball'), now(), now()
    from (values (F, 'r7c-f', 'Fran Facility', 'coach'), (HX, 'r7c-hx', 'Hal X', 'coach'), (HB, 'r7c-hb', 'Bea B', 'coach'),
                 (CO, 'r7c-co', 'Cole Coach', 'coach'), (PI, 'r7c-pi', 'Pia Pitcher', 'pitcher'), (PAR, 'r7c-par', 'Pat Parent', 'parent'),
                 (TEEN, 'r7c-teen', 'Tia Teen', 'pitcher'), (CH, 'r7c-ch', 'Kid Signin', 'child')) x(u, e, nm, ro);
  -- profiles the signup trigger doesn't make (landmine 3): the pitchers', the parent's
  insert into public.profiles (id, role, full_name, sport) select x.u, x.ro, x.nm, x.sp
    from (values (PI, 'pitcher', 'Pia Pitcher', 'baseball'), (TEEN, 'pitcher', 'Tia Teen', 'baseball'), (PAR, 'parent', 'Pat Parent', null)) x(u, ro, nm, sp)
   where not exists (select 1 from public.profiles where id = x.u);
  update public.profiles set age_attestation = 'adult', attested_at = now(), attested_via = 'signup', terms_version = '2026-10-17', email_verified_at = now()
   where id in (F, HX, HB, CO, PI, PAR);
  update public.profiles set age_attestation = 'minor_13_17', attested_at = now(), attested_via = 'signup', terms_version = '2026-10-17',
         guardian_consented_at = now(), consent_via = 'guardian_email', email_verified_at = now() where id = TEEN;
  X := public._create_team_with_head(HX, 'R7C Team X');
  B := public._create_team_with_head(HB, 'R7C Team B');
  select coach_invite_token, invite_token into xStaff, xTeam from public.teams where id = X;
  select coach_invite_token, invite_token into bStaff, bTeam from public.teams where id = B;
  perform set_config('request.jwt.claims', json_build_object('sub', F, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.create_facility_self('R7C Facility'); org := (r ->> 'org_id')::uuid;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', PAR, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.add_player('Kit Kid', 'baseball', 'R', true); KID := (r ->> 'id')::uuid;
  reset role;

  -- ---------- 10. Joel's case: a facility manager accepts a coaching-staff link ----------
  perform set_config('request.jwt.claims', json_build_object('sub', F, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.join_team_as_coach(xStaff, null);
  reset role;
  select count(*) into n from public.team_coaches tc join public.profiles pr on pr.id = tc.coach_id where tc.team_id = X and pr.account_id = F and tc.role = 'assistant';
  select count(*) into n2 from public.team_coaches tc join public.teams t on t.id = tc.team_id join public.profiles pr on pr.id = tc.coach_id
   where t.org_id = org and pr.account_id = F and tc.role = 'head';
  out := out || ' 10 staff link:' || coalesce(r ->> 'error', 'ok') || ' assistant on X ' || n || ', still head of both sides ' || n2;
  if n <> 1 or n2 <> 2 then fails := fails + 1; end if;
  perform set_config('request.jwt.claims', json_build_object('sub', F, 'role', 'authenticated')::text, true); set local role authenticated;
  select string_agg(kind || ':' || coalesce(label, '-'), ', ' order by kind, label) into roles from public.my_roles();
  reset role;
  out := out || ' roles ' || roles;
  if roles not like '%coach:R7C Team X%' or roles not like '%facility:R7C Facility%' then fails := fails + 1; end if;

  -- ---------- 11. each gains the role and loses nothing ----------
  -- a coach accepts a team link as a pitcher: without asking, refused as before; asking, gains Pitcher
  perform set_config('request.jwt.claims', json_build_object('sub', HB, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.join_team_via_invite(xTeam, null);
  out := out || ' | 11a coach, team link, not asked:' || coalesce(r ->> 'error', 'joined');
  if r ->> 'error' is distinct from 'coach_cannot_join' then fails := fails + 1; end if;
  r := public.join_team_via_invite(xTeam, null, true);
  reset role;
  p := (r ->> 'profile_id')::uuid;
  select count(*) into n from public.pitcher_teams where pitcher_id = p and team_id = X;
  select count(*) into n2 from public.team_coaches tc join public.profiles pr on pr.id = tc.coach_id where pr.account_id = HB and tc.team_id = B and tc.role = 'head';
  out := out || ' asked:' || coalesce(r ->> 'error', 'joined') || ' pitcher on X ' || n || ' (' || (select role || '/' || sport || '/' || coalesce(created_via, '-') from public.profiles where id = p)
    || '), still head of B ' || n2;
  if n <> 1 or n2 <> 1 then fails := fails + 1; end if;
  -- an adult pitcher accepts a staff link: gains Coach (assistant)
  perform set_config('request.jwt.claims', json_build_object('sub', PI, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.join_team_as_coach(xStaff, null);
  out := out || ' | 11b pitcher, staff link, not asked:' || coalesce(r ->> 'error', 'joined');
  if r ->> 'error' is distinct from 'pitcher_cannot_join' then fails := fails + 1; end if;
  r := public.join_team_as_coach(xStaff, null, true);
  reset role;
  p := (r ->> 'profile_id')::uuid;
  out := out || ' asked:' || coalesce(r ->> 'error', 'joined') || ' (' || coalesce((select role || '/' || sport || '/' || created_via from public.profiles where id = p), '-')
    || ') assistant on X ' || (select count(*) from public.team_coaches where team_id = X and coach_id = p and role = 'assistant')
    || ', primary still pitcher ' || ((select role from public.profiles where id = PI) = 'pitcher');
  if (select count(*) from public.team_coaches where team_id = X and coach_id = p and role = 'assistant') <> 1 then fails := fails + 1; end if;
  -- a coach accepts a player link as guardian: gains Parent of that player
  perform set_config('request.jwt.claims', json_build_object('sub', PAR, 'role', 'authenticated')::text, true); set local role authenticated;
  tok := public.create_player_link(KID, 'guardian') ->> 'token';
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', CO, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.accept_player_link(tok, '2026-10-17');
  select string_agg(kind || ':' || coalesce(label, '-'), ', ' order by kind) into roles from public.my_roles();
  reset role;
  out := out || ' | 11c coach, guardian link:' || coalesce(r ->> 'error', r ->> 'role') || ' roles ' || coalesce(roles, '-')
    || ', primary still coach ' || ((select role from public.profiles where id = CO) = 'coach');
  if r ->> 'role' is distinct from 'guardian' or coalesce(roles, '') not like '%parent:Kit Kid%' then fails := fails + 1; end if;
  -- a coach starts a facility (no longer "fresh coach logins only")
  perform set_config('request.jwt.claims', json_build_object('sub', HX, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.create_facility_self('R7C Second Facility');
  reset role;
  out := out || ' | 11d team head starts a facility:' || coalesce(r ->> 'status', r ->> 'error') || ', still head of X '
    || (select count(*) from public.team_coaches tc join public.profiles pr on pr.id = tc.coach_id where tc.team_id = X and pr.account_id = HX and tc.role = 'head');
  if r ->> 'status' is distinct from 'created' then fails := fails + 1; end if;
  out := out || ', operator-link check for that email:' || public.facility_email_status('r7c-pi@example.invalid');

  -- ---------- 12. a child sign-in and an under-18 pitcher are refused every adult role ----------
  perform set_config('request.jwt.claims', json_build_object('sub', PAR, 'role', 'authenticated')::text, true); set local role authenticated;
  tok := public.create_player_link(KID, 'child') ->> 'token';
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', CH, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.accept_player_link(tok, '2026-10-17');
  out := out || ' | 12 child sign-in made:' || coalesce(r ->> 'error', 'ok');
  r := public.join_team_as_coach(bStaff, null, true);
  out := out || '; child staff link:' || coalesce(r ->> 'error', 'JOINED');
  if r ->> 'error' is null then fails := fails + 1; end if;
  r := public.join_team_via_invite(bTeam, null, true);
  out := out || ', team link:' || coalesce(r ->> 'error', 'JOINED');
  if r ->> 'error' is null then fails := fails + 1; end if;
  r := public.create_facility_self('R7C Child Facility');
  out := out || ', facility:' || coalesce(r ->> 'error', 'CREATED');
  if r ->> 'error' is null then fails := fails + 1; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', PAR, 'role', 'authenticated')::text, true); set local role authenticated;
  tok := public.create_player_link(KID, 'family') ->> 'token';
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', TEEN, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.join_team_as_coach(bStaff, null, true);
  out := out || ' | 13-17 pitcher staff link:' || coalesce(r ->> 'error', 'JOINED');
  if r ->> 'error' is null then fails := fails + 1; end if;
  r := public.accept_player_link(tok, '2026-10-17');
  out := out || ', family link:' || coalesce(r ->> 'error', 'LINKED');
  if r ->> 'error' is null then fails := fails + 1; end if;
  r := public.create_facility_self('R7C Teen Facility');
  out := out || ', facility:' || coalesce(r ->> 'error', 'CREATED');
  if r ->> 'error' is null then fails := fails + 1; end if;
  reset role;
  out := out || ' (operator-link check for the teen: ' || public.facility_email_status('r7c-teen@example.invalid') || ')';

  -- ---------- 14. the opening role is stored on the account ----------
  perform set_config('request.jwt.claims', json_build_object('sub', F, 'role', 'authenticated')::text, true); set local role authenticated;
  p := (select pr.id from public.profiles pr where pr.account_id = F and pr.sport = 'baseball' and pr.role = 'coach');
  r := public.set_opening_role(p, X);
  select string_agg(kind || ':' || coalesce(label, '-'), ', ') into roles from public.my_roles() where opens;
  out := out || ' | 14 set to team X:' || coalesce(r ->> 'error', 'ok') || ' opens ' || coalesce(roles, '-');
  if coalesce(roles, '') <> 'coach:R7C Team X' then fails := fails + 1; end if;
  r := public.set_opening_role(KID, null);
  out := out || ', someone else''s player:' || coalesce(r ->> 'error', 'SET');
  if r ->> 'error' is distinct from 'not_your_role' then fails := fails + 1; end if;
  reset role;
  out := out || ', stored ' || ((select opens_profile from public.profiles where id = F) = p and (select opens_team from public.profiles where id = F) = X);

  -- ---------- 15. deletion covers every role; a facility manager is held until a hand-off ----------
  perform set_config('request.jwt.claims', json_build_object('sub', F, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.request_account_deletion('DELETE');
  reset role;
  out := out || ' | 15 facility manager asks to delete:' || coalesce(r ->> 'error', 'scheduled');
  if r ->> 'error' is distinct from 'still_head' then fails := fails + 1; end if;
  -- PI (pitcher + coach on X): the purge as delete-account runs it, every profile on the login, the primary last
  for p in select id from public.profiles where account_id = PI order by (id = PI), id loop
    perform public.a1_purge_profile(p);
  end loop;
  select count(*) into n from public.profiles where account_id = PI;
  select count(*) into n2 from public.team_coaches tc where tc.team_id = X and tc.coach_id not in (select id from public.profiles);
  out := out || ' pitcher+coach login purged: profiles left ' || n || ', staff rows left behind ' || n2;
  if n <> 0 or n2 <> 0 then fails := fails + 1; end if;
  -- CO (coach + guardian): the guardian link goes with the login
  delete from auth.users where id = CO;
  out := out || ', coach+guardian login deleted: links left ' || (select count(*) from public.player_links where login = CO);
  if (select count(*) from public.player_links where login = CO) <> 0 then fails := fails + 1; end if;

  out := out || ' | policies ' || pol0 || '->' || (select count(*) from pg_policies where schemaname = 'public') || ' | hard fails ' || fails;
  raise exception 'R7C(rolled back):%', out;
end $$;
