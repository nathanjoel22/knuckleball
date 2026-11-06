-- U15 set_pitch_arsenal (staging; everything rolled back -- the block ends by raising its results).
-- Fixture logins (example.invalid): HT head of team T, AS its assistant, X head of another team, ADL an adult pitcher on
-- T, PAR a parent with a created player KID (on no team), M a facility manager, CA / CB coaches on the baseball side
-- with KF in coach A's group, HZ head of an archived team Z with ZP on it.
do $$
declare
  HT uuid := 'aaaaaaaa-0000-4000-8000-0000000015a1'; AS_ uuid := 'aaaaaaaa-0000-4000-8000-0000000015a2';
  X uuid := 'aaaaaaaa-0000-4000-8000-0000000015a3';  ADL uuid := 'aaaaaaaa-0000-4000-8000-0000000015a4';
  PAR uuid := 'aaaaaaaa-0000-4000-8000-0000000015a5'; M uuid := 'aaaaaaaa-0000-4000-8000-0000000015a6';
  CA uuid := 'aaaaaaaa-0000-4000-8000-0000000015a7'; CB uuid := 'aaaaaaaa-0000-4000-8000-0000000015a8';
  KF uuid := 'aaaaaaaa-0000-4000-8000-0000000015a9'; HZ uuid := 'aaaaaaaa-0000-4000-8000-0000000015aa';
  ZP uuid := 'aaaaaaaa-0000-4000-8000-0000000015ab';
  T uuid; Z uuid; XT uuid; KID uuid; tok text; org uuid; FB uuid; mBB uuid; gA uuid; r jsonb; out text := ''; fails int := 0;
  c record; res text; got text[];
begin
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', e || '@example.invalid', md, now(), now()
    from (values (HT, 'u15-ht', '{"full_name":"Team Head","intended_role":"coach","intended_sport":"baseball"}'::jsonb),
                 (AS_, 'u15-as', '{"full_name":"Assistant","intended_role":"coach","intended_sport":"baseball"}'::jsonb),
                 (X, 'u15-x', '{"full_name":"Other Head","intended_role":"coach","intended_sport":"baseball"}'::jsonb),
                 (M, 'u15-m', '{"full_name":"Mona Manager","intended_role":"coach","intended_sport":"baseball"}'::jsonb),
                 (CA, 'u15-ca', '{"full_name":"Coach A","intended_role":"coach","intended_sport":"baseball"}'::jsonb),
                 (CB, 'u15-cb', '{"full_name":"Coach B","intended_role":"coach","intended_sport":"baseball"}'::jsonb),
                 (HZ, 'u15-hz', '{"full_name":"Archived Head","intended_role":"coach","intended_sport":"baseball"}'::jsonb),
                 (ADL, 'u15-adl', '{}'::jsonb), (PAR, 'u15-par', '{}'::jsonb), (KF, 'u15-kf', '{}'::jsonb), (ZP, 'u15-zp', '{}'::jsonb)) x(u, e, md);
  insert into public.profiles (id, role, full_name, sport) values (PAR, 'parent', 'Pat Parent', null),
    (ADL, 'pitcher', 'Ada Adult', 'baseball'), (KF, 'pitcher', 'Fay Facility', 'baseball'), (ZP, 'pitcher', 'Zed Archived', 'baseball');
  update public.profiles set email_verified_at = now(), age_attestation = 'adult', attested_at = now(), attested_via = 'signup', terms_version = '2026-10-17'
   where id in (HT, AS_, X, M, CA, CB, HZ, ADL, PAR, KF, ZP);
  T := public._create_team_with_head(HT, 'U15 Team');
  XT := public._create_team_with_head(X, 'U15 Other Team');
  Z := public._create_team_with_head(HZ, 'U15 Archived Team');
  insert into public.team_coaches (team_id, coach_id, role, invited_by) values (T, AS_, 'assistant', HT);
  insert into public.pitcher_teams (pitcher_id, team_id) values (ADL, T), (ZP, Z);
  update public.teams set archived_at = now() where id = Z;
  perform set_config('request.jwt.claims', json_build_object('sub', PAR, 'role', 'authenticated')::text, true); set local role authenticated;
  KID := (public.add_player('Kit Kid', 'baseball', 'R', true) ->> 'id')::uuid;
  reset role;
  insert into public.facility_invites (facility_name, manager_email, baseball_level, softball_level)
    values ('U15 Test Facility', 'u15-m@example.invalid', 'high_school', 'high_school_up') returning token into tok;
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated')::text, true); set local role authenticated;
  org := (public.create_facility(tok) ->> 'org_id')::uuid;
  reset role;
  select id, coach_id into FB, mBB from public.teams where org_id = org and sport = 'baseball';
  insert into public.team_coaches (team_id, coach_id, role, invited_by) values (FB, CA, 'assistant', mBB), (FB, CB, 'assistant', mBB);
  select id into gA from public.coach_groups where team_id = FB and coach_id = CA;
  insert into public.pitcher_teams (pitcher_id, team_id) values (KF, FB);
  insert into public.coach_group_members (group_id, pitcher_id, flagged_new) values (gA, KF, false);

  -- who may write whose arsenal: expected 'ok' or 'not allowed'
  for c in select * from (values
      ('pitcher own', ADL, ADL, 'ok'), ('head of team', HT, ADL, 'ok'), ('assistant of team', AS_, ADL, 'ok'),
      ('other team head', X, ADL, 'not allowed'), ('pitcher on another', ADL, KID, 'not allowed'),
      ('parent own player', PAR, KID, 'ok'), ('coach of no team, player', HT, KID, 'not allowed'),
      ('facility manager', M, KF, 'ok'), ('group coach', CA, KF, 'ok'), ('other group coach', CB, KF, 'not allowed'),
      ('archived team head', HZ, ZP, 'not allowed'), ('pitcher on archived', ZP, ZP, 'ok'),
      ('parent row itself', PAR, PAR, 'not allowed'), ('coach own profile', HT, HT, 'not allowed')) v(nm, who, tgt, want) loop
    perform set_config('request.jwt.claims', json_build_object('sub', c.who, 'role', 'authenticated')::text, true); set local role authenticated;
    begin
      perform public.set_pitch_arsenal(c.tgt, array['Slider', 'Changeup']);
      res := 'ok';
    exception when others then res := sqlerrm; end;
    reset role;
    out := out || ' | ' || c.nm || '=' || res;
    if res <> c.want then fails := fails + 1; out := out || ' (WRONG)'; end if;
  end loop;

  -- validation and order (as the pitcher)
  perform set_config('request.jwt.claims', json_build_object('sub', ADL, 'role', 'authenticated')::text, true); set local role authenticated;
  perform public.set_pitch_arsenal(ADL, array['Curveball', 'Four-Seam Fastball', 'Curveball', 'Slider']);
  select pitch_types into got from public.profiles where id = ADL;
  out := out || ' | dedupe keeps order=' || array_to_string(got, ',');
  if got <> array['Curveball', 'Four-Seam Fastball', 'Slider'] then fails := fails + 1; end if;
  begin perform public.set_pitch_arsenal(ADL, null); res := 'saved'; exception when others then res := sqlerrm; end;
  out := out || ' | null=' || res; if res <> 'invalid pitch list' then fails := fails + 1; end if;
  begin perform public.set_pitch_arsenal(ADL, array[' ']); res := 'saved'; exception when others then res := sqlerrm; end;
  out := out || ' | blank=' || res; if res <> 'invalid pitch list' then fails := fails + 1; end if;
  begin perform public.set_pitch_arsenal(ADL, array(select 'P' || i from generate_series(1, 21) i)); res := 'saved'; exception when others then res := sqlerrm; end;
  out := out || ' | 21 pitches=' || res; if res <> 'invalid pitch list' then fails := fails + 1; end if;
  perform public.set_pitch_arsenal(ADL, '{}');
  out := out || ' | empty list=' || (select cardinality(pitch_types) from public.profiles where id = ADL);
  reset role;
  -- not signed in
  begin
    perform set_config('request.jwt.claims', '{"role":"anon"}', true); set local role anon;
    perform public.set_pitch_arsenal(ADL, array['Slider']); res := 'saved';
  exception when others then res := sqlerrm; end;
  reset role;
  out := out || ' | anon=' || res; if res = 'saved' then fails := fails + 1; end if;
  out := out || ' | policies=' || (select count(*) from pg_policies where schemaname = 'public');

  raise exception 'RESULT fails=% %', fails, out;
end $$;
