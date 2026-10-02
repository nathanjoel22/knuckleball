-- Two pre-existing permission holes found by the S4 RLS matrix (Joel, Oct 2
-- 2026: fix after S4 Stage A). Both existed before S4; S4A deliberately kept
-- them identical so its before/after matrix stayed clean.
--
-- 1. pitcher_teams "Pitchers accept invite by inserting own membership" only
--    checked that the row was the caller's own profile -- so any signed-in
--    login (a stranger, or a coach) could put itself on ANY team's roster by
--    knowing the team's id. The only legitimate direct insert left is the
--    old email-invite page (accept-invite.html; 18 invites still pending on
--    production). The link joins (join_team_via_invite) are SECURITY DEFINER
--    and don't go through this policy. Now: the profile is one the caller
--    owns, it's a pitcher profile, AND there is a pending invite to that
--    team addressed to the caller's own login email.
--
-- 2. create_team let any profile -- a pitcher too -- create a team it heads.
--    Now only a coach profile can.
--
-- Policy count unchanged (35): one policy replaced. No policy references
-- teams and pitcher_teams directly (42P17) -- this one reads invites and
-- profiles only.
--
-- Rollback:
--   drop policy "Pitchers accept invite by inserting own membership" on public.pitcher_teams;
--   create policy "Pitchers accept invite by inserting own membership" on public.pitcher_teams
--     for insert with check (public.is_my_profile(pitcher_id));
--   and re-create create_team from 20261002020000_s4a_profiles.sql.

drop policy "Pitchers accept invite by inserting own membership" on public.pitcher_teams;
create policy "Pitchers accept invite by inserting own membership" on public.pitcher_teams for insert
  with check (
    public.is_my_profile(pitcher_id)
    and exists (select 1 from public.profiles pr where pr.id = pitcher_teams.pitcher_id and pr.role = 'pitcher')
    and exists (
      select 1 from public.invites i
       where i.team_id = pitcher_teams.team_id
         and i.status = 'pending'
         and lower(i.email) = lower(auth.jwt() ->> 'email')
    )
  );

create or replace function public.create_team(p_name text, p_profile uuid default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_coach uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if p_profile is not null then
    if not public.is_my_profile(p_profile) then raise exception 'not_your_profile'; end if;
    v_coach := p_profile;
  else
    v_coach := public.my_single_profile();
    if v_coach is null then raise exception 'profile_required'; end if;
  end if;
  if (select pr.role from public.profiles pr where pr.id = v_coach) is distinct from 'coach' then
    raise exception 'only_coaches_create_teams';
  end if;
  if p_name is null or btrim(p_name) = '' then
    raise exception 'team name cannot be blank';
  end if;
  return public._create_team_with_head(v_coach, btrim(p_name));
end;
$$;
