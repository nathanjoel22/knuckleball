-- A coach who was logged in and opened a team invite link got added to
-- pitcher_teams as a pitcher (join.html calls join_team_via_invite for any
-- existing session, and the function never checked the caller's role), so
-- the coach showed up on their own roster sidebar. Only pitchers join via
-- invite: reject callers whose profile role is 'coach'.
--
-- Body is otherwise identical to 20260919025421's version. CREATE OR REPLACE
-- keeps the existing grants (authenticated only, no anon).
--
-- Existing bad rows are NOT deleted here; clean them up by hand after
-- reviewing them (see the SELECT/DELETE in the PR / commit notes).
--
-- ---------------------------------------------------------------------------------
-- ROLLBACK: re-run the join_team_via_invite definition from
-- 20260919025421_r0_invite_links_deferred_verification.sql in a new migration.
-- ---------------------------------------------------------------------------------

create or replace function public.join_team_via_invite(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_team_id uuid;
  v_team_name text;
  v_role text;
begin
  if v_uid is null then
    return jsonb_build_object('error', 'not_authenticated');
  end if;

  select role into v_role from public.profiles where id = v_uid;
  if v_role = 'coach' then
    return jsonb_build_object('error', 'coach_cannot_join');
  end if;

  select id, name into v_team_id, v_team_name from public.teams where invite_token = p_token;
  if v_team_id is null then
    return jsonb_build_object('error', 'invalid_token');
  end if;

  insert into public.pitcher_teams (pitcher_id, team_id)
  values (v_uid, v_team_id)
  on conflict (pitcher_id, team_id) do nothing;

  return jsonb_build_object('ok', true, 'team_id', v_team_id, 'team_name', v_team_name);
end;
$$;
