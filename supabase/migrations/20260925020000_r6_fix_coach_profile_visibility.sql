-- R6 follow-up — fix a real missing-read caught live during the staging
-- browser pass.
--
-- loadCoachAdminData's "coaching staff" list embeds team_coaches with
-- profiles to show each coach's name. Two coaches on the SAME team had no
-- RLS policy letting either read the OTHER's profiles row -- only
-- "Users view own profile" (id = auth.uid()) and "Coaches view their
-- pitchers' profiles" (pitcher_teams-based) existed, neither of which
-- covers one coach reading a fellow coach's row. PostgREST doesn't error
-- on this -- it silently returns profiles: null for the row RLS filtered
-- out of the embed -- so the head's own row showed with a name (their own
-- profile, allowed by "Users view own profile") while every OTHER coach
-- on the team showed as null, and the reverse for an assistant looking at
-- the head. Caught by actually reading a fellow coach's name in a real
-- staging session, not by the mock harness this shipped against first
-- (which fakes the embed result directly and so never exercises RLS).
--
-- ---------------------------------------------------------------------------------
-- ROLLBACK: drop policy "Coaches view their fellow coaches' profiles" on public.profiles;
-- ---------------------------------------------------------------------------------

create policy "Coaches view their fellow coaches' profiles" on public.profiles
  for select using (
    exists (
      select 1 from public.team_coaches tc
       where tc.coach_id = profiles.id
         and public.is_team_coach(tc.team_id)
    )
  );
