-- Rollback of 20261117000000_n1b_remove_from_group: restores F1-A's remove_from_group exactly (removing the last
-- group on a side also deletes the pitcher_teams row, so the pitcher leaves the side; G3 logs the departure).
-- Pitchers left with no group while the new version ran stay on the side; the manager removes them if wanted.
create or replace function public.remove_from_group(p_group uuid, p_pitcher uuid) returns jsonb
  language plpgsql security definer set search_path to '' as $$
declare v_team uuid; v_left boolean := false;
begin
  select team_id into v_team from public.coach_groups where id = p_group;
  if v_team is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if not public.f1a_may_edit_group(p_group) then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  delete from public.coach_group_members where group_id = p_group and pitcher_id = p_pitcher;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_in_group'); end if;
  if not exists (select 1 from public.coach_group_members m join public.coach_groups g on g.id = m.group_id
                  where g.team_id = v_team and m.pitcher_id = p_pitcher) then
    delete from public.pitcher_teams where team_id = v_team and pitcher_id = p_pitcher;
    v_left := found;
  end if;
  return jsonb_build_object('ok', true, 'left_side', v_left);
end;
$$;

