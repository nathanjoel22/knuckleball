-- Rollback of 20261118000000_n1e_facility_notes: restores the body as it was on production on Nov 17 2026 (F1-A: no
-- notes in a facility). Notes written while the new version ran stay; no more can be added on facility teams.
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
       and not public.is_facility_team(s.team_id)   -- F1-A: no notes in a facility (Chat replaces them)
  );

$$;
