-- N1 Stage E (J1) acceptance: who may add a session note (is_coach_of_session, the session_notes INSERT rule).
-- Staging; everything rolled back (the block ends by raising its results). Fixture logins at example.invalid.
-- (1) a group coach on their own pitcher's facility session: allowed; (2) another coach on the same side, not the
-- pitcher's group: refused; (3) the side's manager: allowed; (4) a normal team's head as before: allowed;
-- (5) the pitcher: refused; (6) policies still 32.
do $$
declare
  M  uuid := 'cccccccc-0000-4000-8000-00000000e001'; CA uuid := 'cccccccc-0000-4000-8000-00000000e002';
  CB uuid := 'cccccccc-0000-4000-8000-00000000e003'; HT uuid := 'cccccccc-0000-4000-8000-00000000e004';
  P1 uuid := 'cccccccc-0000-4000-8000-00000000e011'; P2 uuid := 'cccccccc-0000-4000-8000-00000000e012';
  FB uuid; T uuid; tok text; gA uuid; r jsonb; pj jsonb; sF uuid := gen_random_uuid(); sT uuid := gen_random_uuid();
  out text := ''; fails int := 0; ok boolean;
  try_note constant text := 'insert into public.session_notes (session_id, author_id, author_name, body) values ($1, $2, $3, $4)';
begin
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', e || '@example.invalid',
         jsonb_build_object('full_name', nm, 'intended_role', 'coach', 'intended_sport', 'baseball'), now(), now()
    from (values (M, 'n1e-m', 'Mgr'), (CA, 'n1e-ca', 'Coach A'), (CB, 'n1e-cb', 'Coach B'), (HT, 'n1e-ht', 'Team Head')) x(u, e, nm);
  update public.profiles set email_verified_at = now(), age_attestation = 'adult', attested_at = now(), attested_via = 'signup',
         terms_version = '2026-10-17' where id in (M, CA, CB, HT);
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', e || '@example.invalid', '{}', now(), now()
    from (values (P1, 'n1e-p1'), (P2, 'n1e-p2')) x(u, e);
  insert into public.profiles (id, role, full_name, sport, email_verified_at, age_attestation, attested_at, attested_via, terms_version)
    values (P1, 'pitcher', 'Pitcher One', 'baseball', now(), 'adult', now(), 'signup', '2026-10-17'),
           (P2, 'pitcher', 'Pitcher Two', 'baseball', now(), 'adult', now(), 'signup', '2026-10-17');
  -- a facility (as facility-signup makes it) and a normal team
  tok := encode(gen_random_bytes(32), 'hex');
  insert into public.facility_invites (token, facility_name, manager_email, baseball_level, softball_level, expires_at)
    values (tok, 'N1E Test Facility', 'n1e-m@example.invalid', 'high_school', 'high_school_up', now() + interval '1 day');
  perform set_config('request.jwt.claims', json_build_object('sub', M, 'role', 'authenticated', 'email', 'n1e-m@example.invalid')::text, true);
  set local role authenticated;
  r := public.create_facility(tok);
  reset role;
  select id into FB from public.teams where org_id = (r ->> 'org_id')::uuid and sport = 'baseball';
  insert into public.team_coaches (team_id, coach_id, role) values (FB, CA, 'assistant'), (FB, CB, 'assistant');
  select id into gA from public.coach_groups where team_id = FB and coach_id = CA;
  insert into public.pitcher_teams (pitcher_id, team_id, joined_at) values (P1, FB, now() - interval '30 days');
  insert into public.coach_group_members (group_id, pitcher_id, flagged_new) values (gA, P1, false);
  T := public._create_team_with_head(HT, 'N1E Ordinary Team');
  insert into public.pitcher_teams (pitcher_id, team_id, joined_at) values (P2, T, now() - interval '30 days');
  -- one saved session on each, charted by the coach
  select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'fb', 'velo', 80, 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2)) into pj from generate_series(1, 3);
  perform set_config('request.jwt.claims', json_build_object('sub', CA, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.sync_session(jsonb_build_object('id', sF, 'pitcher_id', P1, 'team_id', FB, 'logged_by', CA, 'started_at', now() - interval '1 day', 'ended_at', now() - interval '1 day' + interval '20 minutes'), pj, '[]');
  reset role;
  if coalesce(r ->> 'error', '') <> '' then raise exception 'N1E fixture: facility session %', r; end if;
  select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'fb', 'velo', 80, 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2)) into pj from generate_series(1, 3);
  perform set_config('request.jwt.claims', json_build_object('sub', HT, 'role', 'authenticated')::text, true); set local role authenticated;
  r := public.sync_session(jsonb_build_object('id', sT, 'pitcher_id', P2, 'team_id', T, 'logged_by', HT, 'started_at', now() - interval '1 day', 'ended_at', now() - interval '1 day' + interval '20 minutes'), pj, '[]');
  reset role;
  if coalesce(r ->> 'error', '') <> '' then raise exception 'N1E fixture: team session %', r; end if;

  -- each attempt as that login, under RLS; a refusal is the RLS error
  for r in select * from jsonb_array_elements(jsonb_build_array(
      jsonb_build_object('k', '(1) group coach, own facility pitcher', 'who', CA, 'sid', sF, 'want', true),
      jsonb_build_object('k', '(2) other coach, same side', 'who', CB, 'sid', sF, 'want', false),
      jsonb_build_object('k', '(3) the manager', 'who', M, 'sid', sF, 'want', true),
      jsonb_build_object('k', '(4) normal team head', 'who', HT, 'sid', sT, 'want', true),
      jsonb_build_object('k', '(5) the pitcher', 'who', P1, 'sid', sF, 'want', false))) loop
    perform set_config('request.jwt.claims', json_build_object('sub', r ->> 'who', 'role', 'authenticated')::text, true);
    set local role authenticated;
    begin
      execute try_note using (r ->> 'sid')::uuid, (r ->> 'who')::uuid, 'Test', 'N1E test note';
      ok := true;
    exception when insufficient_privilege or check_violation then ok := false;
      when others then ok := false;
    end;
    reset role;
    out := out || ' | ' || (r ->> 'k') || ': ' || case when ok then 'allowed' else 'refused' end;
    if ok <> (r ->> 'want')::boolean then fails := fails + 1; end if;
  end loop;
  out := out || ' | (6) policies ' || (select count(*) from pg_policies where schemaname = 'public');
  if (select count(*) from pg_policies where schemaname = 'public') <> 32 then fails := fails + 1; end if;
  out := out || ' | fails ' || fails;
  raise exception 'N1E(rolled back):%', out;
end $$;
