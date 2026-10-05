-- Teams hotfix (found by P1-09's precondition report, Joel approved Oct 5 2026; shipped ahead
-- of P1-09):
--   E1. sessions.team_id was ON DELETE CASCADE -- deleting a team deleted every session charted
--       for it (and their pitches and events). Now RESTRICT: the database refuses to delete a
--       team that has sessions, whoever asks. Sessions belong to the pitcher (D3) and are never
--       destroyed by a team action.
--   E2. "Coaches manage own teams" (FOR ALL) plus table-level INSERT/UPDATE/DELETE grants let a
--       head coach delete the team row (wiping sessions through E1) or rewrite any column
--       (coach_id, invite tokens, an unchecked name) with a crafted request. Clients now get no
--       direct writes on teams at all; every change goes through a SECURITY DEFINER function
--       (create_team, rename_team, rotate_*_invite, hand_off_team_head, and the new
--       set_team_level for the G3 Level of play setting, which the app wrote directly).
--       Head coaches keep reading their team through "Coaches view teams they belong to as staff"
--       (every head has a team_coaches row -- checked on both projects).
-- Policies: 35 -> 34. Rollback: supabase/rollback/20261005000000_teams_hotfix_down.sql

alter table public.sessions drop constraint sessions_team_id_fkey;
alter table public.sessions add constraint sessions_team_id_fkey
  foreign key (team_id) references public.teams(id) on delete restrict;

drop policy "Coaches manage own teams" on public.teams;
revoke insert, update, delete, truncate on public.teams from anon, authenticated;

create or replace function public.set_team_level(p_team_id uuid, p_level text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_team_head(p_team_id) then
    raise exception 'not authorized';
  end if;
  -- teams_level_check ties the level to the team's sport and refuses anything else.
  update public.teams set level = p_level where id = p_team_id;
end;
$$;
revoke all on function public.set_team_level(uuid, text) from public, anon;
grant execute on function public.set_team_level(uuid, text) to authenticated;
