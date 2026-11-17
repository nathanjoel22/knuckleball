-- N1 Stage B (J3, Joel, Nov 16 2026; plans/n1b-preconditions.md section 5): removing a pitcher from their last coach
-- group on a facility side no longer takes them off the side. The pitcher_teams row stays, so they're still on the
-- facility, listed under "No coach yet" for the manager. Only "Remove from facility" (the manager, with the removal
-- email) ends the membership. left_side is still returned (always false) so apps on v343 and earlier keep working.
-- No RLS change, no new table or column; create or replace keeps the existing grants.
-- Rollback: supabase/rollback/20261117000000_n1b_remove_from_group_down.sql. Test: supabase/tests/n1b_remove_from_group.sql.
create or replace function public.remove_from_group(p_group uuid, p_pitcher uuid) returns jsonb
  language plpgsql security definer set search_path to '' as $$
declare v_team uuid;
begin
  select team_id into v_team from public.coach_groups where id = p_group;
  if v_team is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if not public.f1a_may_edit_group(p_group) then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  delete from public.coach_group_members where group_id = p_group and pitcher_id = p_pitcher;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_in_group'); end if;
  return jsonb_build_object('ok', true, 'left_side', false);
end;
$$;
