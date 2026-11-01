-- F1-B: QR join codes -- one per coach per facility side (coach_groups.join_token, made by F1-A). Scanning opens
-- join.html?c=<token>: the parent flow (sign in or make a parent account, then pick or add the player), or an adult
-- pitcher's own account; never a 13-17 self-join (Joel, F1-G answer A). Joining adds the facility membership and the
-- coach-group row, flagged New; a pitcher already at the facility is added to this coach's group too (decision E).
-- Decisions: plans/f1b-preconditions.md (Joel, Oct 31 2026). No table, column or policy changes (policies stay 32).
-- Rollback: supabase/rollback/20261102000000_f1b_qr_join_down.sql. Test: supabase/tests/f1b_acceptance.sql.

-- F1-A meant clients to read only these columns (join_token never; added_by not), but Supabase's default table-wide
-- grants on a new table stayed on (F1-A revoked only insert/update/delete), so the side's coaches could read every
-- group's join code. Found by this stage's test (Oct 31). Back to the intended column grants; the app reads only these.
revoke all on public.coach_groups, public.coach_group_members from authenticated;
grant select (id, team_id, coach_id, created_at) on public.coach_groups to authenticated;
grant select (group_id, pitcher_id, added_at, flagged_new) on public.coach_group_members to authenticated;

-- What a code is for, before signing in (the code itself is the secret: 64 random hex characters).
create function public.group_join_info(p_token text) returns jsonb
  language sql stable security definer set search_path to '' as $$
  select coalesce((
    select jsonb_build_object('status', case when t.archived_at is not null then 'archived' else 'ok' end,
             'facility_name', o.name, 'coach_name', cp.full_name, 'sport', t.sport, 'team_name', t.name)
      from public.coach_groups g join public.teams t on t.id = g.team_id and t.kind = 'facility'
      join public.organizations o on o.id = t.org_id
      left join public.profiles cp on cp.id = g.coach_id
     where g.join_token = p_token), jsonb_build_object('status', 'not_found'));
$$;
grant execute on function public.group_join_info(text) to anon, authenticated;

-- Join through a coach's code. p_profile: which of the caller's profiles joins (a parent's player, or the adult
-- pitcher's own); omitted = the login's pitcher profile in that sport, as join_team_via_invite does.
create function public.join_group_via_token(p_token text, p_profile uuid default null) returns jsonb
  language plpgsql security definer set search_path to '' as $$
declare v_group uuid; v_team uuid; v_sport text; v_name text; v_archived timestamptz; v_prof uuid; v_p public.profiles%rowtype;
        v_block text; v_new boolean;
begin
  if auth.uid() is null then return jsonb_build_object('error', 'not_authenticated'); end if;
  v_block := public.p1_10_join_block(false);
  if v_block is not null then return jsonb_build_object('error', v_block); end if;
  select g.id, t.id, t.sport, t.name, t.archived_at into v_group, v_team, v_sport, v_name, v_archived
    from public.coach_groups g join public.teams t on t.id = g.team_id and t.kind = 'facility' where g.join_token = p_token;
  if v_group is null then return jsonb_build_object('error', 'invalid_token'); end if;
  if v_archived is not null then return jsonb_build_object('error', 'team_archived'); end if;
  if p_profile is not null then
    if not public.is_my_profile(p_profile) then return jsonb_build_object('error', 'not_your_profile'); end if;
    v_prof := p_profile;
  else
    v_prof := (select pr.id from public.profiles pr where pr.account_id = auth.uid() and pr.managed_by is null
                and pr.role = 'pitcher' and pr.sport = v_sport);
    v_prof := coalesce(v_prof, public.my_single_profile());
    if v_prof is null then return jsonb_build_object('error', 'profile_required'); end if;
  end if;
  select * into v_p from public.profiles where id = v_prof;
  if v_p.role in ('coach', 'parent', 'child') then return jsonb_build_object('error', 'coach_cannot_join'); end if;
  -- a code is for parents and adult pitchers: a pitcher's own login must be 18+ (decision A)
  if v_p.managed_by is null and coalesce((select age_attestation from public.profiles where id = auth.uid()), '') <> 'adult' then
    return jsonb_build_object('error', 'adult_required');
  end if;
  insert into public.pitcher_teams (pitcher_id, team_id) values (v_prof, v_team)
    on conflict (pitcher_id, team_id) do nothing;   -- a cross-sport join raises sport_mismatch (S1 trigger)
  insert into public.coach_group_members (group_id, pitcher_id, added_by, flagged_new) values (v_group, v_prof, null, true)
    on conflict (group_id, pitcher_id) do nothing;
  v_new := found;
  return jsonb_build_object('ok', true, 'team_id', v_team, 'team_name', v_name, 'profile_id', v_prof, 'already', not v_new);
end;
$$;

-- The codes the caller may show, print and regenerate: their own group(s), and every group on a side they manage.
create function public.my_group_codes() returns jsonb
  language sql stable security definer set search_path to '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('group_id', g.id, 'team_id', t.id, 'sport', t.sport, 'facility_name', o.name,
           'coach_name', cp.full_name, 'token', g.join_token, 'mine', cp.account_id = auth.uid())
           order by t.sport, (cp.account_id = auth.uid()) desc, cp.full_name), '[]'::jsonb)
    from public.coach_groups g join public.teams t on t.id = g.team_id and t.kind = 'facility' and t.archived_at is null
    join public.organizations o on o.id = t.org_id
    join public.profiles cp on cp.id = g.coach_id
   where cp.account_id = auth.uid() or public.is_org_manager(t.id);
$$;

-- A new code for a group: the old one stops at once; pitchers who joined with it stay.
create function public.rotate_group_code(p_group uuid) returns jsonb
  language plpgsql security definer set search_path to '' as $$
declare v_token text;
begin
  if not public.f1a_may_edit_group(p_group) then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  update public.coach_groups set join_token = replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '')
   where id = p_group returning join_token into v_token;
  return jsonb_build_object('ok', true, 'token', v_token);
end;
$$;

revoke execute on function public.join_group_via_token(text, uuid), public.my_group_codes(), public.rotate_group_code(uuid) from public, anon;
grant execute on function public.join_group_via_token(text, uuid), public.my_group_codes(), public.rotate_group_code(uuid) to authenticated;
