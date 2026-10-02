-- P1-10 (Joel, Oct 2 2026): age attestation, guardian approval for 13-17s.
--
-- Every LOGIN records an age bracket ('adult' | 'minor_13_17') and the
-- terms version it accepted -- on its PRIMARY profile (id = auth user id),
-- which S4 treats as the login's account record. Under 13 is refused in the
-- app before any account is created (no 'under_13' value exists). A 13-17
-- player names a parent/guardian email; the guardian approves by an emailed
-- link. Until then the player charts normally but reports are gated.
-- Coaches attest as adults only. No date of birth, ever.
--
-- Joel's calls: new accounts answer on every signup form; existing accounts
-- answer once in a box shown the next time they're ONLINE in the app (never
-- offline -- charting is never blocked); once answered, never again.
--
-- Secrets: guardian_email and guardian_consent_token are NOT granted to
-- clients (column grants, see 20261002040000) -- only these SECURITY DEFINER
-- functions touch them. Clients can't write any of the new columns.
-- Policy count unchanged (35).
--
-- Rollback: supabase/rollback/20261002050000_p1_10_attestation_down.sql

alter table public.profiles
  add column age_attestation          text check (age_attestation in ('adult', 'minor_13_17')),
  add column attested_at              timestamptz,
  add column attested_via             text check (attested_via in ('signup', 'catchup')),
  add column terms_version            text,
  add column guardian_email           text,
  add column guardian_consent_token   text unique,
  add column guardian_consent_sent_at timestamptz,
  add column guardian_consented_at    timestamptz,
  add column consent_via              text check (consent_via in ('guardian_email', 'parent_created'));

comment on column public.profiles.age_attestation is 'P1-10: the login''s self-attested age bracket, on its primary profile only. No date of birth is ever stored.';
comment on column public.profiles.guardian_consent_token is 'P1-10: one-time token in the guardian approval link. Never readable by clients.';
comment on column public.profiles.consent_via is 'P1-10: how guardian consent was given; parent_created is reserved for S4.';

-- Non-secret state is readable (the app needs it for the banner, the catch-up
-- box and the roster label). guardian_email / guardian_consent_token are not.
grant select (age_attestation, attested_at, attested_via, terms_version,
              guardian_consent_sent_at, guardian_consented_at, consent_via)
  on public.profiles to authenticated;

-- Hardening found while building P1-10: clients could INSERT a profile with
-- any column set (e.g. email_verified_at) for their own new login. No client
-- inserts profiles -- the SECURITY DEFINER setup functions do -- so clients
-- get no INSERT at all.
revoke insert on public.profiles from anon, authenticated;

-- Is this login a coach (any coach profile or coach membership, or a coach
-- signup in progress)? Coaches may only attest as adults.
create or replace function public.p1_10_login_is_coach(p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.profiles p where p.account_id = p_uid and p.role = 'coach')
      or exists (select 1 from public.team_coaches tc join public.profiles p on p.id = tc.coach_id where p.account_id = p_uid)
      or coalesce((select u.raw_user_meta_data ->> 'intended_role' from auth.users u where u.id = p_uid), '') = 'coach';
$$;
revoke all on function public.p1_10_login_is_coach(uuid) from public, anon, authenticated;

-- Record the caller's attestation (signup or catch-up).
create or replace function public.record_attestation(p_status text, p_terms_version text,
                                                      p_guardian_email text default null, p_via text default 'signup')
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := auth.uid();
  v_prim  public.profiles%rowtype;
  v_email text;
  v_mine  text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'not_authenticated');
  end if;
  if p_status not in ('adult', 'minor_13_17') then
    return jsonb_build_object('ok', false, 'error', 'invalid_status');
  end if;
  if p_terms_version is null or btrim(p_terms_version) = '' then
    return jsonb_build_object('ok', false, 'error', 'terms_required');
  end if;
  if p_via not in ('signup', 'catchup') then
    return jsonb_build_object('ok', false, 'error', 'invalid_via');
  end if;
  select * into v_prim from public.profiles where id = v_uid;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'profile_missing');
  end if;
  if p_status = 'minor_13_17' and public.p1_10_login_is_coach(v_uid) then
    return jsonb_build_object('ok', false, 'error', 'coaches_must_be_adults');
  end if;
  -- The bracket, once recorded, doesn't change here (no quiet "turning 18"
  -- to skip an approval); support can correct it.
  if v_prim.age_attestation is not null and v_prim.age_attestation <> p_status then
    return jsonb_build_object('ok', false, 'error', 'bracket_already_recorded');
  end if;

  if p_status = 'adult' then
    update public.profiles
       set age_attestation = 'adult',
           attested_at = coalesce(attested_at, now()),
           attested_via = coalesce(attested_via, p_via),
           terms_version = p_terms_version,
           guardian_email = null, guardian_consent_token = null, guardian_consent_sent_at = null
     where id = v_uid;
    return jsonb_build_object('ok', true, 'status', 'adult', 'needs_guardian', false);
  end if;

  v_email := lower(btrim(coalesce(p_guardian_email, '')));
  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' or length(v_email) > 254 then
    return jsonb_build_object('ok', false, 'error', 'invalid_guardian_email');
  end if;
  select lower(u.email) into v_mine from auth.users u where u.id = v_uid;
  if v_email = v_mine then
    return jsonb_build_object('ok', false, 'error', 'guardian_email_is_yours');
  end if;

  if v_prim.age_attestation = 'minor_13_17' and v_prim.guardian_email = v_email then
    update public.profiles set terms_version = p_terms_version where id = v_uid;   -- same answer again: no-op
  else
    update public.profiles
       set age_attestation = 'minor_13_17',
           attested_at = coalesce(attested_at, now()),
           attested_via = coalesce(attested_via, p_via),
           terms_version = p_terms_version,
           guardian_email = v_email,
           guardian_consent_token = replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''),
           guardian_consent_sent_at = null,
           guardian_consented_at = null,
           consent_via = null
     where id = v_uid;
  end if;
  return jsonb_build_object('ok', true, 'status', 'minor_13_17',
                            'needs_guardian', (select guardian_consented_at is null from public.profiles where id = v_uid));
end;
$$;
revoke all on function public.record_attestation(text, text, text, text) from public, anon;
grant execute on function public.record_attestation(text, text, text, text) to authenticated;

-- The caller's own guardian status (the teen sees the address he typed).
create or replace function public.my_guardian_status()
returns table (guardian_email text, sent_at timestamptz, consented_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select p.guardian_email, p.guardian_consent_sent_at, p.guardian_consented_at
    from public.profiles p where p.id = auth.uid();
$$;
revoke all on function public.my_guardian_status() from public, anon;
grant execute on function public.my_guardian_status() to authenticated;

-- For the guardian email Edge Function, with the CALLER's JWT: returns the
-- stored recipient + link token for the caller's own login, at most once per
-- 10 minutes (stamped atomically here, so two quick taps can't both send).
create or replace function public.claim_guardian_send()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_p   public.profiles%rowtype;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'not_authenticated');
  end if;
  select * into v_p from public.profiles where id = v_uid for update;
  if not found or v_p.age_attestation is distinct from 'minor_13_17' or v_p.guardian_consented_at is not null or v_p.guardian_email is null then
    return jsonb_build_object('ok', false, 'error', 'nothing_to_send');
  end if;
  if v_p.guardian_consent_sent_at is not null and v_p.guardian_consent_sent_at > now() - interval '10 minutes' then
    return jsonb_build_object('ok', false, 'error', 'too_soon',
                              'retry_after_seconds', ceil(extract(epoch from (v_p.guardian_consent_sent_at + interval '10 minutes' - now())))::int);
  end if;
  update public.profiles
     set guardian_consent_sent_at = now(),
         guardian_consent_token = coalesce(guardian_consent_token,
           replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''))
   where id = v_uid
  returning * into v_p;
  return jsonb_build_object('ok', true, 'email', v_p.guardian_email, 'token', v_p.guardian_consent_token,
                            'name', v_p.full_name, 'sport', v_p.sport);
end;
$$;
revoke all on function public.claim_guardian_send() from public, anon;
grant execute on function public.claim_guardian_send() to authenticated;

-- guardian-consent.html, before approving: who is this for? (first name and
-- sport only; nothing for a bad or used token).
create or replace function public.get_guardian_request(p_token text)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select jsonb_build_object('ok', true, 'first_name', split_part(btrim(p.full_name), ' ', 1), 'sport', p.sport)
       from public.profiles p
      where p_token ~ '^[0-9a-f]{64}$' and p.guardian_consent_token = p_token and p.guardian_consented_at is null),
    jsonb_build_object('ok', false, 'error', 'invalid_or_used_token'));
$$;
revoke all on function public.get_guardian_request(text) from public;
grant execute on function public.get_guardian_request(text) to anon, authenticated;

-- The guardian taps Approve.
create or replace function public.record_guardian_consent(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sport text;
begin
  update public.profiles
     set guardian_consented_at = now(), consent_via = 'guardian_email', guardian_consent_token = null
   where p_token ~ '^[0-9a-f]{64}$' and guardian_consent_token = p_token and guardian_consented_at is null
  returning sport into v_sport;
  if v_sport is null then
    return jsonb_build_object('ok', false, 'error', 'invalid_or_used_token');
  end if;
  return jsonb_build_object('ok', true, 'sport', v_sport);
end;
$$;
revoke all on function public.record_guardian_consent(text) from public;
grant execute on function public.record_guardian_consent(text) to anon, authenticated;

-- Joins refuse a login that hasn't attested (a crafted client can't skip
-- the question); a coach join also requires an adult.
create or replace function public.p1_10_join_block(p_coach boolean)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when (select p.age_attestation from public.profiles p where p.id = auth.uid()) is null then 'attestation_required'
    when p_coach and (select p.age_attestation from public.profiles p where p.id = auth.uid()) <> 'adult' then 'coaches_must_be_adults'
  end;
$$;
revoke all on function public.p1_10_join_block(boolean) from public, anon;
grant execute on function public.p1_10_join_block(boolean) to authenticated;

create or replace function public.join_team_as_coach(p_token text, p_profile uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

create or replace function public.join_team_via_invite(p_token text, p_profile uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

-- The report gate: login verified AND on a team AND (adult OR guardian-
-- approved). The Edge Function calls this; the caller check (Amendment 11)
-- is unchanged.
create or replace function public.is_pitcher_report_eligible(p_pitcher_id uuid)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select
    coalesce((select acct.email_verified_at is not null
                     and (acct.age_attestation = 'adult' or acct.guardian_consented_at is not null)
                from public.profiles pr join public.profiles acct on acct.id = pr.account_id
               where pr.id = p_pitcher_id), false)
    and exists (select 1 from public.pitcher_teams where pitcher_id = p_pitcher_id);
$$;

-- Why a pitcher's reports are gated, for the app's greyed-out buttons.
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
  end
    from public.profiles pr join public.profiles acct on acct.id = pr.account_id
   where pr.id = p_pitcher_id
     and (public.is_my_profile(p_pitcher_id) or public.is_coach_of_pitcher(p_pitcher_id));
$$;
revoke all on function public.pitcher_report_block(uuid) from public, anon;
grant execute on function public.pitcher_report_block(uuid) to authenticated;

-- Roster: verification plus the guardian state (no token, no guardian email).
drop function public.get_roster_verification(uuid);
create or replace function public.get_roster_verification(p_team_id uuid)
returns table(pitcher_id uuid, email text, email_confirmed boolean, guardian_pending boolean, age_answered boolean)
language sql
security definer
set search_path = ''
as $$
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
