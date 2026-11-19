-- R7 Stage C (Joel, Nov 19 2026; plans/r7-one-login.md Stage C, decisions in plans/r7-preconditions.md items 4, 6, 8):
-- one login, more than one role. A role is a profile on the login (coach / pitcher, per sport), a parent's players or
-- player links, or a facility (organizations.manager_login). A role is gained ONLY by the function that accepts a link
-- of that type, and only when the page asks (p_add_role, after "Join as a pitcher too?" / "Join the staff too?").
--
--  (1) profiles gains created_via (how a profile came to be: 'signup' when null), opens_profile and opens_team (on the
--      login's primary profile: what sign-in opens; null = the primary / the app's default). Readable by the login
--      (column grant); written only by set_opening_role.
--  (2) r7_add_role_profile(role, sport, via): the one place a role profile is made for the caller (adult, never a
--      child sign-in, never a second of the same role and sport). Not callable by clients.
--  (3) join_team_via_invite / join_group_via_token gain p_add_role (coach or parent login -> pitcher);
--      join_team_as_coach gains p_add_role (adult pitcher or parent login -> coach). Without it, they behave as before.
--      Old signatures are dropped (PostgREST calls by name; the new parameter has a default, so old apps still work).
--  (4) accept_player_link: any adult login may be a guardian / family member (was: parent logins only); a child
--      sign-in never ('child_login'). f1_make_facility / facility_email_status: any adult login may run a facility
--      (was: fresh coach logins only); a child sign-in or an under-18 can't ('child_login' / 'adult_required').
--  (5) my_roles(): the login's roles in plain names for the switcher; set_opening_role(profile, team).
-- Kept: every age rule (P1-10), coaches_must_be_adults, a child sign-in's single role, one facility per login,
-- create_team for coaches only, add_sport_profile. No policy is added or changed: public stays 32, storage 12.
-- Rollback: supabase/rollback/20261122000000_r7c_roles_down.sql. Tests: supabase/tests/r7c_roles.sql,
-- supabase/tests/r7_roles_matrix.sql.

-- (1)
alter table public.profiles add column created_via text;
alter table public.profiles add constraint profiles_created_via_check check (created_via is null or created_via in
  ('signup', 'team_link', 'qr_code', 'staff_link', 'facility', 'add_sport', 'player_created', 'player_link'));
alter table public.profiles add column opens_profile uuid references public.profiles(id) on delete set null;
alter table public.profiles add column opens_team uuid references public.teams(id) on delete set null;
comment on column public.profiles.created_via is 'R7 Stage C: how this profile came to be (null = signup, from before R7). Roles gained by a link say which.';
comment on column public.profiles.opens_profile is 'R7 Stage C: on a primary profile, which role sign-in opens (null = the app default). set_opening_role only.';
comment on column public.profiles.opens_team is 'R7 Stage C: with opens_profile, the team that role opens on. set_opening_role only.';
grant select (created_via, opens_profile, opens_team) on public.profiles to authenticated;

-- (2)
create or replace function public.r7_add_role_profile(p_role text, p_sport text, p_via text)
returns uuid language plpgsql security definer set search_path to '' as $$
declare v_uid uuid := auth.uid(); v_prim public.profiles%rowtype; v_id uuid;
begin
  if v_uid is null or p_role not in ('coach', 'pitcher') or p_sport not in ('baseball', 'softball') then return null; end if;
  select * into v_prim from public.profiles where id = v_uid;
  if not found or v_prim.role = 'child' or coalesce(v_prim.age_attestation, '') <> 'adult' then return null; end if;
  select id into v_id from public.profiles where account_id = v_uid and managed_by is null and role = p_role and sport = p_sport;
  if v_id is not null then return v_id; end if;
  v_id := gen_random_uuid();
  insert into public.profiles (id, account_id, role, full_name, sport, created_via)
    values (v_id, v_uid, p_role, v_prim.full_name, p_sport, p_via);
  return v_id;
end;
$$;
revoke all on function public.r7_add_role_profile(text, text, text) from public, anon, authenticated;

-- (3)
drop function public.join_team_via_invite(text, uuid);
drop function public.join_group_via_token(text, uuid);
drop function public.join_team_as_coach(text, uuid);
CREATE OR REPLACE FUNCTION public.join_team_via_invite(p_token text, p_profile uuid DEFAULT NULL::uuid, p_add_role boolean DEFAULT false)
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
    -- R7 Stage C: a coach or parent login asked (p_add_role, after "Join as a pitcher too?") gains a pitcher profile in
    -- the team's sport. Only when the login has no pitcher profile at all (another sport's is S1's "add sport" path).
    if v_prof is null and p_add_role and v_team_sport is not null
       and not exists (select 1 from public.profiles pr where pr.account_id = auth.uid() and pr.managed_by is null and pr.role = 'pitcher') then
      v_prof := public.r7_add_role_profile('pitcher', v_team_sport, 'team_link');
      if v_prof is null then return jsonb_build_object('error', 'coach_cannot_join'); end if;
    end if;
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

CREATE OR REPLACE FUNCTION public.join_group_via_token(p_token text, p_profile uuid DEFAULT NULL::uuid, p_add_role boolean DEFAULT false)
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
    -- R7 Stage C: as join_team_via_invite -- a coach or parent login that asked gains a pitcher profile (adults only: below)
    if v_prof is null and p_add_role
       and not exists (select 1 from public.profiles pr where pr.account_id = auth.uid() and pr.managed_by is null and pr.role = 'pitcher')
       and coalesce((select age_attestation from public.profiles where id = auth.uid()), '') = 'adult' then
      v_prof := public.r7_add_role_profile('pitcher', v_sport, 'qr_code');
      if v_prof is null then return jsonb_build_object('error', 'coach_cannot_join'); end if;
    end if;
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

CREATE OR REPLACE FUNCTION public.join_team_as_coach(p_token text, p_profile uuid DEFAULT NULL::uuid, p_add_role boolean DEFAULT false)
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
    -- R7 Stage C: an adult pitcher or parent login that asked ("Join the staff too?") gains a coach profile in the
    -- team's sport (the 18+ rule is p1_10_join_block above; a child sign-in is refused inside r7_add_role_profile).
    if v_prof is null and p_add_role and v_team_sport is not null then
      v_prof := public.r7_add_role_profile('coach', v_team_sport, 'staff_link');
      if v_prof is null then return jsonb_build_object('error', 'pitcher_cannot_join'); end if;
    end if;
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

revoke all on function public.join_team_via_invite(text, uuid, boolean) from public, anon;
grant execute on function public.join_team_via_invite(text, uuid, boolean) to authenticated;
revoke all on function public.join_group_via_token(text, uuid, boolean) from public, anon;
grant execute on function public.join_group_via_token(text, uuid, boolean) to authenticated;
revoke all on function public.join_team_as_coach(text, uuid, boolean) from public, anon;
grant execute on function public.join_team_as_coach(text, uuid, boolean) to authenticated;

-- (4)
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
    -- R7 Stage C: any adult login may be a guardian or family member (it gains the Parent role); never a child sign-in
    if v_prim.id is null then return jsonb_build_object('ok', false, 'error', 'not_a_parent_login'); end if;
    if v_prim.role = 'child' then return jsonb_build_object('ok', false, 'error', 'child_login'); end if;
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
    -- R7 Stage C: a coach, pitcher or parent login may also run a facility; only a child sign-in or an under-18 can't
    when exists (select 1 from public.profiles pr where pr.id = u.id and (pr.role = 'child' or coalesce(pr.age_attestation, 'adult') <> 'adult')) then 'child'
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
  -- R7 Stage C: any adult login may also run a facility (no "fresh login only"); never a child sign-in or an under-18.
  select * into v_prim from public.profiles where id = p_uid;
  if not found then
    v_name := nullif(btrim((select u.raw_user_meta_data ->> 'full_name' from auth.users u where u.id = p_uid)), '');
    if v_name is null then return jsonb_build_object('ok', false, 'error', 'name_required'); end if;
    insert into public.profiles (id, role, full_name, sport) values (p_uid, 'coach', v_name, 'baseball');
    select * into v_prim from public.profiles where id = p_uid;
  end if;
  if v_prim.role = 'child' then return jsonb_build_object('ok', false, 'error', 'child_login'); end if;
  if coalesce(v_prim.age_attestation, 'adult') <> 'adult' then return jsonb_build_object('ok', false, 'error', 'adult_required'); end if;
  select id into v_bb from public.profiles where account_id = p_uid and role = 'coach' and managed_by is null and sport = 'baseball' limit 1;
  select id into v_sb from public.profiles where account_id = p_uid and role = 'coach' and managed_by is null and sport = 'softball' limit 1;
  if v_bb is null then
    v_bb := gen_random_uuid();
    insert into public.profiles (id, account_id, role, full_name, sport, created_via) values (v_bb, p_uid, 'coach', v_prim.full_name, 'baseball', 'facility');
  end if;
  if v_sb is null then
    v_sb := gen_random_uuid();
    insert into public.profiles (id, account_id, role, full_name, sport, created_via) values (v_sb, p_uid, 'coach', v_prim.full_name, 'softball', 'facility');
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

-- (5) The login's roles, for the switcher. One row per role and place: a coach profile per team it coaches ('coach';
-- 'facility' when the login runs that team's facility, 'facility_coach' at someone else's), a pitcher profile with its
-- teams' names, a parent's players and linked players. A coach login's no-email players are not its roles.
create or replace function public.my_roles()
returns table (profile_id uuid, team_id uuid, kind text, label text, sport text, opens boolean)
language sql stable security definer set search_path to '' as $$
  with me as (select p.id, p.role, p.opens_profile, p.opens_team from public.profiles p where p.id = auth.uid()),
  r as (
    select pr.id profile_id, t.id team_id,
           case when t.kind = 'facility' and o.manager_login = auth.uid() then 'facility'
                when t.kind = 'facility' then 'facility_coach' else 'coach' end kind,
           coalesce(o.name, t.name) label, pr.sport
      from public.profiles pr join public.team_coaches tc on tc.coach_id = pr.id
      join public.teams t on t.id = tc.team_id left join public.organizations o on o.id = t.org_id
     where pr.account_id = auth.uid() and pr.managed_by is null and pr.role = 'coach' and t.archived_at is null
    union all
    select pr.id, null, 'coach', null, pr.sport from public.profiles pr
     where pr.account_id = auth.uid() and pr.managed_by is null and pr.role = 'coach'
       and not exists (select 1 from public.team_coaches tc join public.teams t on t.id = tc.team_id
                        where tc.coach_id = pr.id and t.archived_at is null)
    union all
    select pr.id, null, 'pitcher',
           (select string_agg(t.name, ', ' order by t.name) from public.pitcher_teams pt join public.teams t on t.id = pt.team_id
             where pt.pitcher_id = pr.id and t.archived_at is null), pr.sport
      from public.profiles pr where pr.account_id = auth.uid() and pr.managed_by is null and pr.role = 'pitcher'
    union all
    select pr.id, null, 'parent', pr.full_name, pr.sport from public.profiles pr, me
     where pr.managed_by = me.id and me.role <> 'coach'
    union all
    select pl.player_id, null, case when pl.role = 'family' then 'family' else 'parent' end, pr.full_name, pr.sport
      from public.player_links pl join public.profiles pr on pr.id = pl.player_id
     where pl.login = auth.uid() and pl.role in ('guardian', 'family'))
  select r.profile_id, r.team_id, r.kind, r.label, r.sport,
         coalesce(r.profile_id = me.opens_profile and (me.opens_team is null or r.team_id = me.opens_team), false)
    from r left join me on true;
$$;
revoke all on function public.my_roles() from public, anon;
grant execute on function public.my_roles() to authenticated;

create or replace function public.set_opening_role(p_profile uuid, p_team uuid default null)
returns jsonb language plpgsql security definer set search_path to '' as $$
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'error', 'not_authenticated'); end if;
  if p_profile is not null and not exists (select 1 from public.my_roles() r
       where r.profile_id = p_profile and (p_team is null or r.team_id = p_team)) then
    return jsonb_build_object('ok', false, 'error', 'not_your_role');
  end if;
  update public.profiles set opens_profile = p_profile, opens_team = case when p_profile is null then null else p_team end
   where id = auth.uid();
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.set_opening_role(uuid, uuid) from public, anon;
grant execute on function public.set_opening_role(uuid, uuid) to authenticated;
