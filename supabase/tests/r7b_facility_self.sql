-- R7 Stage B acceptance (staging; everything rolled back -- the block ends by raising its results).
-- Fixture logins (example.invalid): S makes a facility from the New account form (create_facility_self), M from an
-- operator link (create_facility), C a coach and P an adult pitcher who try to join, UA a login with no 18+ answer.
-- Checks are numbered after the packet's Done-when 8 and 9.
do $$
declare
  S uuid := 'aaaaaaaa-0000-4000-8000-0000000007b1'; M uuid := 'aaaaaaaa-0000-4000-8000-0000000007b2';
  C uuid := 'aaaaaaaa-0000-4000-8000-0000000007b3'; P uuid := 'aaaaaaaa-0000-4000-8000-0000000007b4';
  UA uuid := 'aaaaaaaa-0000-4000-8000-0000000007b5';
  tok text; orgS uuid; orgM uuid; SB uuid; staffTok text; groupTok text; shapeS jsonb; shapeM jsonb;
  r jsonb; n int; ok boolean; err text; out text := ''; fails int := 0; pol0 int; pol1 int;
begin
  select count(*) into pol0 from pg_policies where schemaname = 'public';
  -- ---------- fixture ----------
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select x.u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', e || '@example.invalid',
         jsonb_build_object('full_name', nm, 'intended_role', ro, 'intended_sport', 'baseball'), now(), now()
    from (values (S, 'r7b-s', 'Sam Selfserve', 'coach'), (M, 'r7b-m', 'Morgan Operator', 'coach'), (C, 'r7b-c', 'Casey Coach', 'coach'),
                 (P, 'r7b-p', 'Pat Pitcher', 'pitcher'), (UA, 'r7b-u', 'Unanswered', 'coach')) x(u, e, nm, ro);
  -- the signup trigger makes a coach's profile; a pitcher's comes later (landmine 3), so make P's here
  insert into public.profiles (id, role, full_name, sport) select P, 'pitcher', 'Pat Pitcher', 'baseball'
   where not exists (select 1 from public.profiles where id = P);
  -- the 18+ answer, as login.html records it before creating the facility; nobody is verified yet except C and P
  update public.profiles set age_attestation = 'adult', attested_at = now(), attested_via = 'signup', terms_version = '2026-10-17'
   where id in (S, M, C, P);
  update public.profiles set email_verified_at = now() where id in (C, P);
  insert into public.facility_invites (facility_name, manager_email, baseball_level, softball_level)
    values ('R7B Operator Facility', 'r7b-m@example.invalid', 'college', 'high_school_up') returning token into tok;

  -- ---------- 8a. a new person picks Facility ----------
  perform set_config('request.jwt.claims', json_build_object('sub', UA, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.create_facility_self('R7B No Answer');   out := out || ' 8a1 no 18+ answer:' || coalesce(r ->> 'error', 'none');
  if r ->> 'error' is distinct from 'adult_required' then fails := fails + 1; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', S, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.create_facility_self('x');               out := out || ' 8a2 short name:' || coalesce(r ->> 'error', 'none');
  if r ->> 'error' is distinct from 'name_invalid' then fails := fails + 1; end if;
  r := public.create_facility_self('R7B Self Facility'); orgS := (r ->> 'org_id')::uuid; out := out || ' 8a3 create:' || coalesce(r ->> 'status', r ->> 'error');
  if r ->> 'status' is distinct from 'created' then fails := fails + 1; end if;
  ok := public.is_facility_login();                    out := out || ' 8a4 facility login:' || ok;
  if not ok then fails := fails + 1; end if;
  -- ---------- 8b. a second attempt on the same login ----------
  r := public.create_facility_self('R7B Second Facility'); out := out || ' 8b again:' || coalesce(r ->> 'error', 'none');
  if r ->> 'error' is distinct from 'already_manager' then fails := fails + 1; end if;
  ok := public.my_facility_needs_verify();             out := out || ' 8c needs verify:' || ok;
  if not ok then fails := fails + 1; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.create_facility(tok); orgM := (r ->> 'org_id')::uuid; out := out || ' 8a5 operator create:' || coalesce(r ->> 'status', r ->> 'error');
  ok := public.my_facility_needs_verify();             out := out || ' operator needs verify:' || ok;
  if ok then fails := fails + 1; end if;
  reset role;

  -- ---------- 8a. identical in the database (everything but names, ids, levels and created_via) ----------
  select jsonb_build_object(
      'orgs', (select count(*) from public.organizations where manager_login = x.l),
      'sides', (select jsonb_agg(t.sport || '/' || t.kind || '/' || (t.coach_id is not null) || '/' || (t.invite_token is not null) || '/' || (t.coach_invite_token is not null) order by t.sport)
                  from public.teams t join public.organizations o on o.id = t.org_id where o.manager_login = x.l),
      'heads', (select count(*) from public.team_coaches tc join public.profiles pr on pr.id = tc.coach_id where pr.account_id = x.l and tc.role = 'head'),
      'coach_profiles', (select jsonb_agg(pr.sport order by pr.sport) from public.profiles pr where pr.account_id = x.l and pr.role = 'coach'),
      'groups', (select count(*) from public.coach_groups g join public.profiles pr on pr.id = g.coach_id where pr.account_id = x.l),
      'primary', (select pr.sport || '/' || pr.role from public.profiles pr where pr.id = x.l))
    into shapeS from (select S l) x;
  select jsonb_build_object(
      'orgs', (select count(*) from public.organizations where manager_login = x.l),
      'sides', (select jsonb_agg(t.sport || '/' || t.kind || '/' || (t.coach_id is not null) || '/' || (t.invite_token is not null) || '/' || (t.coach_invite_token is not null) order by t.sport)
                  from public.teams t join public.organizations o on o.id = t.org_id where o.manager_login = x.l),
      'heads', (select count(*) from public.team_coaches tc join public.profiles pr on pr.id = tc.coach_id where pr.account_id = x.l and tc.role = 'head'),
      'coach_profiles', (select jsonb_agg(pr.sport order by pr.sport) from public.profiles pr where pr.account_id = x.l and pr.role = 'coach'),
      'groups', (select count(*) from public.coach_groups g join public.profiles pr on pr.id = g.coach_id where pr.account_id = x.l),
      'primary', (select pr.sport || '/' || pr.role from public.profiles pr where pr.id = x.l))
    into shapeM from (select M l) x;
  out := out || ' 8a6 same shape:' || (shapeS = shapeM) || ' ' || shapeS::text;
  if shapeS is distinct from shapeM then fails := fails + 1; out := out || ' operator=' || shapeM::text; end if;
  out := out || ' created_via:' || (select created_via from public.organizations where id = orgS) || '/' || (select created_via from public.organizations where id = orgM)
    || ' levels:' || (select string_agg(level, ',' order by sport) from public.teams where org_id = orgS);

  -- ---------- 8c. an unverified manager can't add people ----------
  select coach_invite_token into staffTok from public.teams where org_id = orgS and sport = 'baseball';
  select g.join_token into groupTok from public.coach_groups g join public.teams t on t.id = g.team_id where t.org_id = orgS and t.sport = 'baseball' limit 1;
  perform set_config('request.jwt.claims', json_build_object('sub', C, 'role', 'authenticated')::text, true); set local role authenticated;
  begin r := public.join_team_as_coach(staffTok, null); err := coalesce(r ->> 'error', 'joined'); exception when others then err := sqlerrm; end;
  out := out || ' 8c1 coach joins unverified:' || err;
  if err is distinct from 'facility_unverified' then fails := fails + 1; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role', 'authenticated')::text, true); set local role authenticated;
  begin r := public.join_group_via_token(groupTok, null); err := coalesce(r ->> 'error', 'joined'); exception when others then err := sqlerrm; end;
  out := out || ' 8c2 pitcher joins by code:' || coalesce(err, '-') || ' (code ' || (groupTok is not null) || ')';
  if groupTok is not null and err is distinct from 'facility_unverified' then fails := fails + 1; end if;
  reset role;
  -- the manager's own Create Child's Profile can't join the side either
  begin
    insert into public.pitcher_teams (pitcher_id, team_id) values (P, (select id from public.teams where org_id = orgS and sport = 'baseball'));
    err := 'inserted';
  exception when others then err := sqlerrm; end;
  out := out || ' 8c3 any roster insert:' || err;
  if err is distinct from 'facility_unverified' then fails := fails + 1; end if;
  -- verified: the same joins work
  update public.profiles set email_verified_at = now() where id = S;
  perform set_config('request.jwt.claims', json_build_object('sub', C, 'role', 'authenticated')::text, true); set local role authenticated;
  begin r := public.join_team_as_coach(staffTok, null); err := coalesce(r ->> 'error', r ->> 'status', 'joined'); exception when others then err := sqlerrm; end;
  out := out || ' 8c4 coach joins verified:' || err;
  if err = 'facility_unverified' or (r ->> 'ok') is distinct from 'true' then fails := fails + 1; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', S, 'role', 'authenticated')::text, true); set local role authenticated;
  ok := public.my_facility_needs_verify();             out := out || ' needs verify after:' || ok;
  if ok then fails := fails + 1; end if;
  reset role;
  -- an operator-made facility with an unverified manager is unaffected (M is unverified)
  select g.join_token into groupTok from public.coach_groups g join public.teams t on t.id = g.team_id where t.org_id = orgM and t.sport = 'baseball' limit 1;
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role', 'authenticated')::text, true); set local role authenticated;
  begin r := public.join_group_via_token(groupTok, null); err := coalesce(r ->> 'error', r ->> 'status', 'joined'); exception when others then err := sqlerrm; end;
  out := out || ' 8c5 operator facility, unverified manager, pitcher joins:' || coalesce(err, '-');
  if err = 'facility_unverified' then fails := fails + 1; end if;
  reset role;

  -- ---------- 8d. the daily cap ----------
  update public.rate_limit_config set max_count = (select count(*) from public.organizations where created_via = 'self_serve' and created_at > now() - interval '1 day')
   where key = 'facility_self_serve_day';
  perform set_config('request.jwt.claims', json_build_object('sub', C, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.create_facility_self('R7B Over The Cap'); out := out || ' 8d daily cap:' || coalesce(r ->> 'error', 'none');
  if r ->> 'error' is distinct from 'daily_cap' then fails := fails + 1; end if;
  -- ---------- clients can't reach the internals ----------
  begin perform public.f1_make_facility(C, 'R7B Direct', null, null, 'self_serve'); err := 'callable'; exception when others then err := 'refused'; end;
  out := out || ' internal helper:' || err;
  if err <> 'refused' then fails := fails + 1; end if;
  begin perform 1 from public.organizations limit 1; err := 'readable'; exception when others then err := 'refused'; end;
  out := out || ' organizations table:' || err;
  if err <> 'refused' then fails := fails + 1; end if;
  reset role;

  -- ---------- 9. policy count unchanged ----------
  select count(*) into pol1 from pg_policies where schemaname = 'public';
  out := out || ' | 9 policies ' || pol0 || '->' || pol1 || ' storage ' || (select count(*) from pg_policies where schemaname = 'storage');
  if pol1 <> 32 then fails := fails + 1; end if;
  out := out || ' | hard fails ' || fails;
  raise exception 'R7B(rolled back):%', out;
end $$;
