-- S4 Stage B (amended, Joel Oct 2 2026): parent-created players.
--   B2  add_player(): an adult-attested login creates a managed pitcher
--       profile (no email, no login, no age) with the parent's consent.
--   --  ensure_account_setup() can create a 'parent' primary profile.
--   --  parents, like coaches, can only attest 'adult'.
--   B6  the report gate also requires a managed player's consent stamp.
--   B9  get_roster_verification() returns `managed` ("Parent account").
-- No policy changes. Rollback: supabase/rollback/20261002060000_s4b_players_down.sql

-- ---------------------------------------------------------------- B2
create or replace function public.add_player(p_full_name text, p_sport text, p_throws text default null, p_consent boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := auth.uid();
  v_prim  public.profiles%rowtype;
  v_name  text := btrim(coalesce(p_full_name, ''));
  v_email text;
  v_new   uuid := gen_random_uuid();
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'not_authenticated');
  end if;
  if p_consent is not true then
    return jsonb_build_object('ok', false, 'error', 'consent_required');
  end if;
  if v_name = '' or length(v_name) > 80 then
    return jsonb_build_object('ok', false, 'error', 'invalid_name');
  end if;
  if p_sport is null or p_sport not in ('baseball', 'softball') then
    return jsonb_build_object('ok', false, 'error', 'invalid_sport');
  end if;
  if p_throws is not null and p_throws not in ('L', 'R') then
    return jsonb_build_object('ok', false, 'error', 'invalid_throws');
  end if;
  select * into v_prim from public.profiles where id = v_uid;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'profile_missing');
  end if;
  -- Only an adult can consent for a child (amended acceptance 10).
  if v_prim.age_attestation is distinct from 'adult' then
    return jsonb_build_object('ok', false, 'error', 'adult_required');
  end if;
  select u.email into v_email from auth.users u where u.id = v_uid;

  -- managed_by = the adult's primary profile; account_id = the adult's login.
  -- Reports default to the login's email (B4) -- the same "pitcher" contact
  -- slot every pitcher's own account email fills.
  insert into public.profiles (id, account_id, managed_by, role, full_name, sport, throws,
                               guardian_consented_at, consent_via, contact_emails)
  values (v_new, v_uid, v_uid, 'pitcher', v_name, p_sport, p_throws,
          now(), 'parent_created', jsonb_build_object('pitcher', coalesce(v_email, '')));
  return jsonb_build_object('ok', true, 'id', v_new);
end;
$$;
revoke all on function public.add_player(text, text, text, boolean) from public, anon;
grant execute on function public.add_player(text, text, text, boolean) to authenticated;

-- ------------------------------------------------ parent primary profile
create or replace function public.ensure_account_setup(p_role text default null::text, p_full_name text default null::text, p_team_name text default null::text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid             uuid := auth.uid();
  v_meta            jsonb;
  v_profile_role    text;
  v_resolved_role   text;
  v_resolved_name   text;
  v_resolved_team   text;
  v_has_profile     boolean;
  v_has_team        boolean;
  v_profile_created boolean := false;
  v_team_created    boolean := false;
begin
  if v_uid is null then
    return jsonb_build_object('error', 'not authenticated');
  end if;

  perform pg_advisory_xact_lock(hashtext('ensure_account_setup:' || v_uid::text));

  select raw_user_meta_data into v_meta from auth.users where id = v_uid;

  select role into v_profile_role from public.profiles where id = v_uid;
  v_has_profile := found;

  if not v_has_profile then
    v_resolved_role := coalesce(nullif(p_role, ''), nullif(v_meta ->> 'intended_role', ''));
    v_resolved_name := coalesce(nullif(p_full_name, ''), nullif(v_meta ->> 'full_name', ''));

    -- S4 B2: 'parent' (a login that manages players; never charts, no sport).
    if v_resolved_role in ('coach', 'pitcher', 'parent') and v_resolved_name is not null then
      insert into public.profiles (id, role, full_name)
      values (v_uid, v_resolved_role, v_resolved_name)
      on conflict (id) do nothing;

      select role into v_profile_role from public.profiles where id = v_uid;
      v_has_profile := found;
      v_profile_created := v_has_profile;
    end if;
  end if;

  if not v_has_profile then
    return jsonb_build_object(
      'profile',    'missing',
      'role',       null,
      'needs_role', true
    );
  end if;

  -- ---- Team (coach only) ----
  -- needs_team here still means "no team you HEAD" -- unchanged on purpose.
  -- This branch is what the explicit "create a team" recovery form
  -- (renderAccountSetupScreen / submitAccountSetup) drives: someone
  -- filling that in wants to become a NEW team's head regardless of
  -- whatever else they're already an assistant on, so "you already have
  -- team access" must never short-circuit it. The routing question this
  -- migration actually fixes -- whether an assistant-only coach even
  -- REACHES this recovery screen on a normal load -- is answered by
  -- loadTeams() (client) reading team_coaches instead of teams.coach_id,
  -- not by changing this function's own notion of needs_team.
  if v_profile_role = 'coach' then
    select exists (select 1 from public.teams where coach_id = v_uid) into v_has_team;

    if not v_has_team then
      v_resolved_team := coalesce(nullif(p_team_name, ''), nullif(v_meta ->> 'team_name', ''));
      if v_resolved_team is not null then
        perform public._create_team_with_head(v_uid, v_resolved_team);
        v_has_team     := true;
        v_team_created := true;
      end if;
    end if;

    return jsonb_build_object(
      'profile',    case when v_profile_created then 'created' else 'exists' end,
      'role',       'coach',
      'team',       case when v_team_created then 'created'
                         when v_has_team     then 'exists'
                         else 'missing' end,
      'needs_team', not v_has_team
    );
  end if;

  return jsonb_build_object(
    'profile', case when v_profile_created then 'created' else 'exists' end,
    'role',    case when v_profile_role = 'parent' then 'parent' else 'pitcher' end,
    'team',    'not_applicable'
  );
end;
$$;

-- Coaches AND parents can only be 'adult' (record_attestation's check).
create or replace function public.p1_10_login_is_coach(p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.profiles p where p.account_id = p_uid and p.role in ('coach', 'parent'))
      or exists (select 1 from public.team_coaches tc join public.profiles p on p.id = tc.coach_id where p.account_id = p_uid)
      or coalesce((select u.raw_user_meta_data ->> 'intended_role' from auth.users u where u.id = p_uid), '') in ('coach', 'parent');
$$;

-- ---------------------------------------------------------------- B6
-- The login (the parent's, for a managed player) is verified and consented
-- as before; a managed player ALSO needs its own consent stamp.
create or replace function public.is_pitcher_report_eligible(p_pitcher_id uuid)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select
    coalesce((select acct.email_verified_at is not null
                     and (acct.age_attestation = 'adult' or acct.guardian_consented_at is not null)
                     and (pr.managed_by is null or pr.guardian_consented_at is not null)
                from public.profiles pr join public.profiles acct on acct.id = pr.account_id
               where pr.id = p_pitcher_id), false)
    and exists (select 1 from public.pitcher_teams where pitcher_id = p_pitcher_id);
$$;

create or replace function public.pitcher_report_block(p_pitcher_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when acct.email_verified_at is null then 'unverified'
    when acct.age_attestation is null then 'age_not_answered'
    when acct.age_attestation = 'minor_13_17' and acct.guardian_consented_at is null then 'guardian_pending'
    when pr.managed_by is not null and pr.guardian_consented_at is null then 'consent_missing'
  end
    from public.profiles pr join public.profiles acct on acct.id = pr.account_id
   where pr.id = p_pitcher_id
     and (public.is_my_profile(p_pitcher_id) or public.is_coach_of_pitcher(p_pitcher_id));
$$;

-- ---------------------------------------------------------------- B9
drop function public.get_roster_verification(uuid);
create or replace function public.get_roster_verification(p_team_id uuid)
returns table(pitcher_id uuid, email text, email_confirmed boolean, guardian_pending boolean, age_answered boolean, managed boolean)
language sql
security definer
set search_path = ''
as $$
  select pt.pitcher_id, u.email, acct.email_verified_at is not null,
         (acct.age_attestation = 'minor_13_17' and acct.guardian_consented_at is null),
         acct.age_attestation is not null,
         pr.managed_by is not null
  from public.pitcher_teams pt
  join public.profiles pr on pr.id = pt.pitcher_id
  join auth.users u on u.id = pr.account_id
  join public.profiles acct on acct.id = pr.account_id
  where pt.team_id = p_team_id
    and public.is_team_coach(p_team_id);
$$;
revoke all on function public.get_roster_verification(uuid) from public, anon;
grant execute on function public.get_roster_verification(uuid) to authenticated;
