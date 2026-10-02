-- Down migration for 20261002060000_s4b_players.sql: restores the P1-10 definitions.
-- Run BEFORE deleting any parent/managed profiles is considered; it does not touch data.
drop function if exists public.add_player(text, text, text, boolean);
CREATE OR REPLACE FUNCTION "public"."ensure_account_setup"("p_role" "text" DEFAULT NULL::"text", "p_full_name" "text" DEFAULT NULL::"text", "p_team_name" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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

    if v_resolved_role in ('coach', 'pitcher') and v_resolved_name is not null then
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
    'role',    'pitcher',
    'team',    'not_applicable'
  );
end;
$$;

CREATE OR REPLACE FUNCTION "public"."p1_10_login_is_coach"("p_uid" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select exists (select 1 from public.profiles p where p.account_id = p_uid and p.role = 'coach')
      or exists (select 1 from public.team_coaches tc join public.profiles p on p.id = tc.coach_id where p.account_id = p_uid)
      or coalesce((select u.raw_user_meta_data ->> 'intended_role' from auth.users u where u.id = p_uid), '') = 'coach';
$$;

CREATE OR REPLACE FUNCTION "public"."is_pitcher_report_eligible"("p_pitcher_id" "uuid") RETURNS boolean
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select
    coalesce((select acct.email_verified_at is not null
                     and (acct.age_attestation = 'adult' or acct.guardian_consented_at is not null)
                from public.profiles pr join public.profiles acct on acct.id = pr.account_id
               where pr.id = p_pitcher_id), false)
    and exists (select 1 from public.pitcher_teams where pitcher_id = p_pitcher_id);
$$;

CREATE OR REPLACE FUNCTION "public"."pitcher_report_block"("p_pitcher_id" "uuid") RETURNS "text"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select case
    when acct.email_verified_at is null then 'unverified'
    when acct.age_attestation is null then 'age_not_answered'
    when acct.age_attestation = 'minor_13_17' and acct.guardian_consented_at is null then 'guardian_pending'
  end
    from public.profiles pr join public.profiles acct on acct.id = pr.account_id
   where pr.id = p_pitcher_id
     and (public.is_my_profile(p_pitcher_id) or public.is_coach_of_pitcher(p_pitcher_id));
$$;

drop function public.get_roster_verification(uuid);
CREATE OR REPLACE FUNCTION "public"."get_roster_verification"("p_team_id" "uuid") RETURNS TABLE("pitcher_id" "uuid", "email" "text", "email_confirmed" boolean, "guardian_pending" boolean, "age_answered" boolean)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select pt.pitcher_id, u.email, acct.email_verified_at is not null,
         (acct.age_attestation = 'minor_13_17' and acct.guardian_consented_at is null),
         acct.age_attestation is not null
  from public.pitcher_teams pt
  join public.profiles pr on pr.id = pt.pitcher_id
  join auth.users u on u.id = pr.account_id
  join public.profiles acct on acct.id = pr.account_id
  where pt.team_id = p_team_id
    and public.is_team_coach(p_team_id);
$$;

revoke all on function public.get_roster_verification(uuid) from public, anon;
grant execute on function public.get_roster_verification(uuid) to authenticated;
