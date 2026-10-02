-- DOWN migration for 20261002050000_p1_10_attestation.sql (restores production as of Oct 2 2026;
-- the four functions below are copied verbatim from production before P1-10).
begin;
drop function if exists public.pitcher_report_block(uuid);
drop function if exists public.record_guardian_consent(text);
drop function if exists public.get_guardian_request(text);
drop function if exists public.claim_guardian_send();
drop function if exists public.my_guardian_status();
drop function if exists public.record_attestation(text, text, text, text);
drop function if exists public.p1_10_join_block(boolean);
drop function if exists public.p1_10_login_is_coach(uuid);
drop function public.get_roster_verification(uuid);
CREATE OR REPLACE FUNCTION public.get_roster_verification(p_team_id uuid)
 RETURNS TABLE(pitcher_id uuid, email text, email_confirmed boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select pt.pitcher_id, u.email, acct.email_verified_at is not null
  from public.pitcher_teams pt
  join public.profiles pr on pr.id = pt.pitcher_id
  join auth.users u on u.id = pr.account_id
  join public.profiles acct on acct.id = pr.account_id
  where pt.team_id = p_team_id
    and public.is_team_coach(p_team_id);
$function$
;

CREATE OR REPLACE FUNCTION public.is_pitcher_report_eligible(p_pitcher_id uuid)
 RETURNS boolean
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select
    coalesce((select acct.email_verified_at is not null
                from public.profiles pr join public.profiles acct on acct.id = pr.account_id
               where pr.id = p_pitcher_id), false)
    and exists (select 1 from public.pitcher_teams where pitcher_id = p_pitcher_id);
$function$
;

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
begin
  if auth.uid() is null then
    return jsonb_build_object('error', 'not_authenticated');
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
  if v_role = 'pitcher' then
    return jsonb_build_object('error', 'pitcher_cannot_join');
  end if;

  if v_team_id is null then
    return jsonb_build_object('error', 'invalid_token');
  end if;

  insert into public.team_coaches (team_id, coach_id, role, invited_by)
  values (v_team_id, v_prof, 'assistant', v_head_id)
  on conflict (team_id, coach_id) do nothing;

  return jsonb_build_object('ok', true, 'team_id', v_team_id, 'team_name', v_team_name, 'profile_id', v_prof);
end;
$function$
;

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
begin
  if auth.uid() is null then
    return jsonb_build_object('error', 'not_authenticated');
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
  if v_role in ('coach', 'parent') then
    return jsonb_build_object('error', 'coach_cannot_join');
  end if;

  if v_team_id is null then
    return jsonb_build_object('error', 'invalid_token');
  end if;

  insert into public.pitcher_teams (pitcher_id, team_id)
  values (v_prof, v_team_id)
  on conflict (pitcher_id, team_id) do nothing;

  return jsonb_build_object('ok', true, 'team_id', v_team_id, 'team_name', v_team_name, 'profile_id', v_prof);
end;
$function$

;
grant execute on function public.get_roster_verification(uuid) to authenticated;
alter table public.profiles
  drop column if exists consent_via, drop column if exists guardian_consented_at, drop column if exists guardian_consent_sent_at,
  drop column if exists guardian_consent_token, drop column if exists guardian_email, drop column if exists terms_version,
  drop column if exists attested_via, drop column if exists attested_at, drop column if exists age_attestation;
-- Insert rights as they were before P1-10 (column list from production).
grant insert (account_id, contact_emails, created_at, email_verified_at, email_verify_token, email_verify_token_sent_at,
  full_name, headshot_updated_at, id, managed_by, pitch_types, relative_accuracy_enabled, role,
  setup_dismissed_at, sport, throws, uses_radar_gun) on public.profiles to authenticated;
commit;
