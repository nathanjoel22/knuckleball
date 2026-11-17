-- N1 Stage E (J1, Joel, Nov 16-17 2026; plans/n1e-preconditions.md section 4): coaches leave a note on the recap,
-- facility coaches too. On a facility team a note needs the pitcher in the coach's own group, or the side's manager
-- (coach_sees_pitcher). Normal teams are unchanged. Used only by the session_notes INSERT rule; no policy changes (32).
-- Rollback: supabase/rollback/20261118000000_n1e_facility_notes_down.sql. Test: supabase/tests/n1e_facility_notes.sql.
create or replace function public.is_coach_of_session(p_session_id uuid) returns boolean
  language sql stable security definer set search_path to '' as $$
  select exists (
    select 1
      from public.sessions s
      join public.team_coaches tc on tc.team_id = s.team_id
      join public.profiles cp on cp.id = tc.coach_id and cp.account_id = auth.uid()
      join public.pitcher_teams pt on pt.team_id = s.team_id and pt.pitcher_id = s.pitcher_id
     where s.id = p_session_id
       and s.started_at >= pt.joined_at
       and (not public.is_facility_team(s.team_id) or public.coach_sees_pitcher(s.team_id, s.pitcher_id))
  );
$$;
