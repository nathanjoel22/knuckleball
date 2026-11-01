-- Operator page for facility signup links (Joel, Oct 31 2026): instead of pasting SQL, the operator fills in a form on
-- operator.html and the facility-invites Edge Function (OPERATOR_EMAILS only) writes facility_invites with the service
-- role. This function lets it warn before making a link that can't work: create_facility needs a login that isn't
-- on a team or staff yet (login_in_use) and isn't a pitcher or parent login (not_a_coach_login).
-- Service role only. No table or policy changes (policies stay 32).
-- Rollback: supabase/rollback/20261103000000_operator_facility_links_down.sql.
create function public.facility_email_status(p_email text) returns text
  language sql stable security definer set search_path to '' as $$
  select case
    when u.id is null then 'new'
    when exists (select 1 from public.organizations o where o.manager_login = u.id) then 'facility'
    when exists (select 1 from public.team_coaches tc join public.profiles pr on pr.id = tc.coach_id where pr.account_id = u.id)
      or exists (select 1 from public.pitcher_teams pt join public.profiles pr on pr.id = pt.pitcher_id where pr.account_id = u.id) then 'in_use'
    when exists (select 1 from public.profiles pr where pr.id = u.id and pr.role <> 'coach') then 'not_coach'
    else 'free'
  end
  from (select 1) one left join auth.users u on lower(u.email) = lower(btrim(p_email));
$$;
revoke execute on function public.facility_email_status(text) from public, anon, authenticated;
grant execute on function public.facility_email_status(text) to service_role;
