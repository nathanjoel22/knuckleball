-- Uniform numbers: coach can set/change a pitcher's number, and pitcher + coach
-- edits reconcile.
--
-- Both sides write the SAME column (pitcher_teams.uniform_number), so there is
-- one source of truth and nothing to sync. What needs handling is two people
-- editing at once from stale screens. Every save therefore sends the number the
-- editor last SAW (p_expected, NULL = "it was unset"); if the database no longer
-- holds that, nothing is written and the caller gets {conflict: true, current: N}
-- so the UI can show the latest value instead of silently overwriting it.
--
-- Who may write: the pitcher for their own membership, or the coach of that team
-- (public.is_team_coach). Like set_my_uniform_number (20260921050000) this is a
-- function and not an UPDATE policy, because a plain update policy would also let
-- a pitcher rewrite team_id / pitcher_id on their own row.
--
-- set_my_uniform_number is left in place so any already-open pitcher tab keeps
-- saving until it reloads; it can be dropped in a later migration.
--
-- ---------------------------------------------------------------------------------
-- ROLLBACK (write a new migration with this body to revert):
--   drop function if exists public.set_uniform_number(uuid, uuid, smallint, smallint);
-- ---------------------------------------------------------------------------------

create or replace function public.set_uniform_number(
  p_team_id    uuid,
  p_pitcher_id uuid,
  p_number     smallint,
  p_expected   smallint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_current smallint;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if p_number is not null and (p_number < 0 or p_number > 99) then
    raise exception 'uniform number must be between 0 and 99';
  end if;

  if not (v_uid = p_pitcher_id or public.is_team_coach(p_team_id)) then
    raise exception 'not allowed';
  end if;

  -- Lock the membership row so two simultaneous saves serialise, then compare.
  select uniform_number into v_current
    from public.pitcher_teams
   where pitcher_id = p_pitcher_id and team_id = p_team_id
   for update;

  if not found then
    raise exception 'not a member of that team';
  end if;

  if v_current is distinct from p_expected then
    return jsonb_build_object('conflict', true, 'current', v_current);
  end if;

  update public.pitcher_teams
     set uniform_number = p_number
   where pitcher_id = p_pitcher_id and team_id = p_team_id;

  return jsonb_build_object('ok', true, 'number', p_number);
end;
$$;

revoke all on function public.set_uniform_number(uuid, uuid, smallint, smallint) from public, anon;
grant execute on function public.set_uniform_number(uuid, uuid, smallint, smallint) to authenticated;
