-- A1 follow-up (Joel, Oct 14 2026): coaches see "Account closing <date>" on the roster during a pitcher's 7-day
-- deletion grace. The deletion dates aren't client-readable columns; this returns them only for pitchers on a team
-- the caller coaches (the same check as get_roster_verification), and only for those scheduled. A managed player
-- closes with its own mark or its parent login's (a login's deletion takes its players with it).
-- Rollback: drop function public.get_roster_closing(uuid);
create or replace function public.get_roster_closing(p_team_id uuid)
returns table(pitcher_id uuid, closing_on timestamptz)
language sql
stable
security definer
set search_path to ''
as $$
  select pt.pitcher_id, coalesce(pr.deletion_due_at, acct.deletion_due_at)
  from public.pitcher_teams pt
  join public.profiles pr on pr.id = pt.pitcher_id
  join public.profiles acct on acct.id = pr.account_id
  where pt.team_id = p_team_id
    and public.is_team_coach(p_team_id)
    and coalesce(pr.deletion_due_at, acct.deletion_due_at) is not null;
$$;
revoke all on function public.get_roster_closing(uuid) from public, anon;
grant execute on function public.get_roster_closing(uuid) to authenticated;
