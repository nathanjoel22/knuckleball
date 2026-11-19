-- Rollback for 20261122000000_r7c_roles.sql (R7 Stage C). Profiles a login gained by a link stay (they are real roles
-- with real data); only the functions go back to their definitions from before (copied from staging Nov 19 2026,
-- identical on production), and the three new columns go.
drop function if exists public.set_opening_role(uuid, uuid);
drop function if exists public.my_roles();
drop function if exists public.join_team_via_invite(text, uuid, boolean);
drop function if exists public.join_group_via_token(text, uuid, boolean);
drop function if exists public.join_team_as_coach(text, uuid, boolean);
CREATE OR REPLACE FUNCTION public.join_team_via_invite(p_token text, p_profile uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_prof uuid;
  v_team_id uuid;
  v_team_name text;
  v_team_sport text;
  v_role text;
  v_block text;
begin
  if auth.uid() is null then
    return jsonb_build_object('error', 'not_authenticated');
  end if;
  v_block := public.p1_10_join_block(false);
  if v_block is not null then
    return jsonb_build_object('error', v_block);
  end if;

  select id, name, sport into v_team_id, v_team_name, v_team_sport from public.teams where invite_token = p_token;

  if p_profile is not null then
    if not public.is_my_profile(p_profile) then
      return jsonb_build_object('error', 'not_your_profile');
    end if;
    v_prof := p_profile;
  else
    v_prof := (select pr.id from public.profiles pr
                where pr.account_id = auth.uid() and pr.managed_by is null
                  and pr.role = 'pitcher' and pr.sport = v_team_sport);
    v_prof := coalesce(v_prof, public.my_single_profile());
    if v_prof is null then
      return jsonb_build_object('error', 'profile_required');
    end if;
  end if;

  select role into v_role from public.profiles where id = v_prof;
  if v_role in ('coach', 'parent', 'child') then   -- F1-G: the creating parent joins the player, never the child's sign-in
    return jsonb_build_object('error', 'coach_cannot_join');
  end if;

  if v_team_id is null then
    return jsonb_build_object('error', 'invalid_token');
  end if;
  if public.is_team_archived(v_team_id) then
    return jsonb_build_object('error', 'team_archived');   -- P1-09
  end if;

  insert into public.pitcher_teams (pitcher_id, team_id)
  values (v_prof, v_team_id)
  on conflict (pitcher_id, team_id) do nothing;

  return jsonb_build_object('ok', true, 'team_id', v_team_id, 'team_name', v_team_name, 'profile_id', v_prof);
end;
$function$;

CREATE OR REPLACE FUNCTION public.join_group_via_token(p_token text, p_profile uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.join_team_as_coach(p_token text, p_profile uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_prof uuid;
  v_role text;
  v_team_id uuid;
  v_team_name text;
  v_team_sport text;
  v_head_id uuid;
  v_block text;
begin
  if auth.uid() is null then
    return jsonb_build_object('error', 'not_authenticated');
  end if;
  v_block := public.p1_10_join_block(true);
  if v_block is not null then
    return jsonb_build_object('error', v_block);
  end if;

  select id, name, coach_id, sport into v_team_id, v_team_name, v_head_id, v_team_sport
    from public.teams where coach_invite_token = p_token;

  if p_profile is not null then
    if not public.is_my_profile(p_profile) then
      return jsonb_build_object('error', 'not_your_profile');
    end if;
    v_prof := p_profile;
  else
    v_prof := (select pr.id from public.profiles pr
                where pr.account_id = auth.uid() and pr.managed_by is null
                  and pr.role = 'coach' and pr.sport = v_team_sport);
    v_prof := coalesce(v_prof, public.my_single_profile());
    if v_prof is null then
      return jsonb_build_object('error', 'profile_required');
    end if;
  end if;

  select role into v_role from public.profiles where id = v_prof;
  if v_role in ('pitcher', 'child') then   -- F1-G
    return jsonb_build_object('error', 'pitcher_cannot_join');
  end if;

  if v_team_id is null then
    return jsonb_build_object('error', 'invalid_token');
  end if;
  if public.is_team_archived(v_team_id) then
    return jsonb_build_object('error', 'team_archived');   -- P1-09
  end if;

  insert into public.team_coaches (team_id, coach_id, role, invited_by)
  values (v_team_id, v_prof, 'assistant', v_head_id)
  on conflict (team_id, coach_id) do nothing;

  return jsonb_build_object('ok', true, 'team_id', v_team_id, 'team_name', v_team_name, 'profile_id', v_prof);
end;
$function$;

revoke all on function public.join_team_via_invite(text, uuid) from public, anon;
grant execute on function public.join_team_via_invite(text, uuid) to authenticated;
revoke all on function public.join_group_via_token(text, uuid) from public, anon;
grant execute on function public.join_group_via_token(text, uuid) to authenticated;
revoke all on function public.join_team_as_coach(text, uuid) from public, anon;
grant execute on function public.join_team_as_coach(text, uuid) to authenticated;
CREATE OR REPLACE FUNCTION public.accept_player_link(p_token text, p_terms_version text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare i public.player_link_invites%rowtype; v_uid uuid := auth.uid(); v_prim public.profiles%rowtype; v_player public.profiles%rowtype;
begin
  if v_uid is null then return jsonb_build_object('ok', false, 'error', 'not_authenticated'); end if;
  select * into i from public.player_link_invites where token = p_token for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if i.used_at is not null then
    if i.used_by = v_uid then return jsonb_build_object('ok', true, 'player_id', i.player_id, 'role', i.role, 'status', 'done'); end if;
    return jsonb_build_object('ok', false, 'error', 'used');
  end if;
  if i.expires_at < now() then return jsonb_build_object('ok', false, 'error', 'expired'); end if;
  select * into v_player from public.profiles where id = i.player_id;
  if v_player.account_id = v_uid then return jsonb_build_object('ok', false, 'error', 'already_yours'); end if;
  if exists (select 1 from public.player_links where player_id = i.player_id and login = v_uid) then
    return jsonb_build_object('ok', false, 'error', 'already_linked');
  end if;
  perform pg_advisory_xact_lock(hashtext('f1g:' || i.player_id::text));
  if (select count(*) from public.player_links where player_id = i.player_id and role = i.role) >= public.f1g_role_cap(i.role) then
    return jsonb_build_object('ok', false, 'error', 'limit_reached');
  end if;
  select * into v_prim from public.profiles where id = v_uid;
  if i.role = 'child' then
    if p_terms_version is null or btrim(p_terms_version) = '' then return jsonb_build_object('ok', false, 'error', 'terms_required'); end if;
    if exists (select 1 from public.profiles where account_id = v_uid and role <> 'child')
       or exists (select 1 from public.player_links where login = v_uid) then
      return jsonb_build_object('ok', false, 'error', 'login_in_use');
    end if;
    if v_prim.id is null then
      insert into public.profiles (id, account_id, role, full_name) values (v_uid, v_uid, 'child', v_player.full_name);
    end if;
    update public.profiles
       set age_attestation = 'minor_13_17', attested_at = now(), attested_via = 'signup', terms_version = p_terms_version,
           guardian_consented_at = now(), consent_via = 'parent_link',
           guardian_email = null, guardian_consent_token = null, guardian_consent_sent_at = null
     where id = v_uid;
  else
    if v_prim.id is null or v_prim.role <> 'parent' then return jsonb_build_object('ok', false, 'error', 'not_a_parent_login'); end if;
    if v_prim.age_attestation is distinct from 'adult' then return jsonb_build_object('ok', false, 'error', 'adult_required'); end if;
  end if;
  insert into public.player_links (player_id, login, role) values (i.player_id, v_uid, i.role);
  update public.player_link_invites set used_at = now(), used_by = v_uid where token = p_token;
  return jsonb_build_object('ok', true, 'player_id', i.player_id, 'role', i.role, 'sport', v_player.sport);
end;
$function$;

CREATE OR REPLACE FUNCTION public.facility_email_status(p_email text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select case
    when u.id is null then 'new'
    when exists (select 1 from public.organizations o where o.manager_login = u.id) then 'facility'
    when exists (select 1 from public.team_coaches tc join public.profiles pr on pr.id = tc.coach_id where pr.account_id = u.id)
      or exists (select 1 from public.pitcher_teams pt join public.profiles pr on pr.id = pt.pitcher_id where pr.account_id = u.id) then 'in_use'
    when exists (select 1 from public.profiles pr where pr.id = u.id and pr.role <> 'coach') then 'not_coach'
    else 'free'
  end
  from (select 1) one left join auth.users u on lower(u.email) = lower(btrim(p_email));
$function$;

CREATE OR REPLACE FUNCTION public.f1_make_facility(p_uid uuid, p_name text, p_bb_level text, p_sb_level text, p_via text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_prim public.profiles%rowtype; v_bb uuid; v_sb uuid; v_org uuid; v_team uuid; v_name text;
begin
  if exists (select 1 from public.organizations o where o.manager_login = p_uid) then
    return jsonb_build_object('ok', false, 'error', 'already_manager');
  end if;
  -- A fresh login only: none of its profiles is on a team or staff yet.
  if exists (select 1 from public.team_coaches tc join public.profiles pr on pr.id = tc.coach_id where pr.account_id = p_uid)
     or exists (select 1 from public.pitcher_teams pt join public.profiles pr on pr.id = pt.pitcher_id where pr.account_id = p_uid) then
    return jsonb_build_object('ok', false, 'error', 'login_in_use');
  end if;
  select * into v_prim from public.profiles where id = p_uid;
  if not found then
    v_name := nullif(btrim((select u.raw_user_meta_data ->> 'full_name' from auth.users u where u.id = p_uid)), '');
    if v_name is null then return jsonb_build_object('ok', false, 'error', 'name_required'); end if;
    insert into public.profiles (id, role, full_name, sport) values (p_uid, 'coach', v_name, 'baseball');
    select * into v_prim from public.profiles where id = p_uid;
  end if;
  if v_prim.role <> 'coach' then return jsonb_build_object('ok', false, 'error', 'not_a_coach_login'); end if;
  select id into v_bb from public.profiles where account_id = p_uid and role = 'coach' and managed_by is null and sport = 'baseball' limit 1;
  select id into v_sb from public.profiles where account_id = p_uid and role = 'coach' and managed_by is null and sport = 'softball' limit 1;
  if v_bb is null then
    v_bb := gen_random_uuid();
    insert into public.profiles (id, account_id, role, full_name, sport) values (v_bb, p_uid, 'coach', v_prim.full_name, 'baseball');
  end if;
  if v_sb is null then
    v_sb := gen_random_uuid();
    insert into public.profiles (id, account_id, role, full_name, sport) values (v_sb, p_uid, 'coach', v_prim.full_name, 'softball');
  end if;

  insert into public.organizations (name, manager_login, created_via) values (btrim(p_name), p_uid, p_via) returning id into v_org;
  -- Both sides, as _create_team_with_head does (the invite token comes from the existing trigger), plus org and kind.
  -- A null level takes the teams' default (teams_level_default).
  insert into public.teams (coach_id, name, coach_invite_token, coach_invite_token_rotated_at, org_id, kind, level)
    values (v_bb, btrim(p_name), replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''), now(),
            v_org, 'facility', p_bb_level) returning id into v_team;
  insert into public.team_coaches (team_id, coach_id, role) values (v_team, v_bb, 'head');
  insert into public.teams (coach_id, name, coach_invite_token, coach_invite_token_rotated_at, org_id, kind, level)
    values (v_sb, btrim(p_name), replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''), now(),
            v_org, 'facility', p_sb_level) returning id into v_team;
  insert into public.team_coaches (team_id, coach_id, role) values (v_team, v_sb, 'head');
  return jsonb_build_object('ok', true, 'org_id', v_org);
end;
$function$;

drop function if exists public.r7_add_role_profile(text, text, text);
alter table public.profiles drop column if exists opens_team;
alter table public.profiles drop column if exists opens_profile;
alter table public.profiles drop constraint if exists profiles_created_via_check;
alter table public.profiles drop column if exists created_via;
