-- Per-team uniform number. A pitcher can be on several teams with a different
-- number on each, so it lives on the membership row (pitcher_teams), not on the
-- profile. Coaches see it in place of the roster's 01, 02, 03... and the roster
-- is sorted by it. Nullable: no number until the pitcher sets one.
--
-- 0-99 covers every real uniform number ("00" and "0" are indistinguishable as
-- an integer; if that ever matters, switch to text).
--
-- Writes go through set_my_uniform_number() and NOT a new UPDATE policy:
-- pitcher_teams has no UPDATE policy today, and a plain "update own row" policy
-- would also let a pitcher rewrite team_id / pitcher_id on their own row (i.e.
-- move themselves onto any team). The function changes this one column, on the
-- caller's own membership only. Reads need no change: coaches already read
-- their teams' memberships and pitchers their own.
--
-- ---------------------------------------------------------------------------------
-- ROLLBACK (write a new migration with this body to revert):
--   drop function if exists public.set_my_uniform_number(uuid, smallint);
--   alter table public.pitcher_teams drop column if exists uniform_number;
-- ---------------------------------------------------------------------------------

alter table public.pitcher_teams
  add column uniform_number smallint
  constraint pitcher_teams_uniform_number_range check (uniform_number between 0 and 99);

create or replace function public.set_my_uniform_number(p_team_id uuid, p_number smallint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  update public.pitcher_teams
     set uniform_number = p_number
   where pitcher_id = auth.uid()
     and team_id = p_team_id;

  if not found then
    raise exception 'not a member of that team';
  end if;
end;
$$;

-- This project auto-grants execute on new functions to anon (see the note in
-- 20260919025421); revoke from both, grant only to signed-in users.
revoke all on function public.set_my_uniform_number(uuid, smallint) from public, anon;
grant execute on function public.set_my_uniform_number(uuid, smallint) to authenticated;
