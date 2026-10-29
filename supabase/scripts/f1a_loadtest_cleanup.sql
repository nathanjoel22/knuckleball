-- F1-A load test: remove everything the seed made (STAGING ONLY). DRY RUN by default: it does the whole cleanup, reports
-- the counts and rolls back. Set dry_run to false to really remove it.
--   supabase db query --linked --project-ref wpsscxwawgiwmifpjpec -f supabase/scripts/f1a_loadtest_cleanup.sql
-- Removes: the "LoadTest Training Center" facility (its sessions -- pitches, events and stats go with them -- roster,
-- staff, groups, both teams, the organization and its signup link), the LoadTest players, and the test logins
-- (f1a-*@example.com). Staging Pitcher, Testing Gas and Babe Ruth only leave the facility; their own sessions are
-- untouched.
do $$
declare
  dry_run constant boolean := true;
  KNIGHTS constant uuid := '18fa6885-c85e-4c2a-88e9-e301c6f93723';
  v_org uuid; v_teams uuid[]; v_logins uuid[]; n_s int; n_pt int; n_prof int; n_users int;
begin
  if not exists (select 1 from public.teams where id = KNIGHTS and name = 'Staging Knights') then
    raise exception 'refused: this is not the staging project';
  end if;
  select id into v_org from public.organizations where name = 'LoadTest Training Center';
  select array_agg(id) into v_teams from public.teams where org_id = v_org;
  select array_agg(id) into v_logins from auth.users where email like 'f1a-%@example.com';
  delete from public.sessions where team_id = any(v_teams);                       get diagnostics n_s = row_count;
  delete from public.pitcher_teams where team_id = any(v_teams);                  get diagnostics n_pt = row_count;
  delete from public.team_coaches where team_id = any(v_teams);                   -- their groups go with them (trigger)
  delete from public.teams where id = any(v_teams);                               -- departures cascade
  delete from public.facility_invites where org_id = v_org or facility_name = 'LoadTest Training Center';
  delete from public.organizations where id = v_org;
  -- the test logins' profiles (players go with their parent: managed_by cascades), then the logins
  delete from public.profiles where account_id = any(v_logins) and managed_by is not null;
  delete from public.profiles where account_id = any(v_logins);                   get diagnostics n_prof = row_count;
  delete from auth.users where id = any(v_logins);                                get diagnostics n_users = row_count;
  if dry_run then
    raise exception 'CLEANUP DRY RUN (rolled back): % sessions, % roster rows, % profiles (plus players), % logins; facility gone: %',
      n_s, n_pt, n_prof, n_users, not exists (select 1 from public.organizations where name = 'LoadTest Training Center');
  end if;
  raise notice 'cleanup done: % sessions, % roster rows, % profiles, % logins', n_s, n_pt, n_prof, n_users;
end $$;
