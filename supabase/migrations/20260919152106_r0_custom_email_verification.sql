-- R0 follow-up — custom email verification, replacing auth.users.email_confirmed_at.
--
-- Why: the prior R0 migration (20260919025421) read
-- auth.users.email_confirmed_at as "verified." That's wrong the moment
-- Supabase's own "Confirm email" toggle goes off (Joel's requirement:
-- new pitchers must be able to sign up and use the app before verifying,
-- via a coach-shared join link) -- with that toggle off, Supabase stamps
-- email_confirmed_at at signup for everyone, so every function built on
-- it would silently report "verified" for an account nobody ever checked.
-- Confirmed by grep across this repo and by querying pg_proc/pg_policies/
-- pg_views/pg_trigger on both projects: the only things that ever read
-- email_confirmed_at are the four functions this migration repoints below
-- (my_verification_status, get_roster_verification, is_pitcher_verified,
-- pitcher_email_report_blocked) -- no policy, view, or trigger touches it.
--
-- Verification becomes ours: a token we generate, an email we send
-- ourselves via Resend (send-verification-email, mirroring
-- send-session-report -- caller's own JWT, never service-role), and our
-- own profiles.email_verified_at column. auth.users.email is still the
-- source of truth for the account's actual address (unchanged, still
-- read directly) -- only the CONFIRMED boolean moves off Supabase's own
-- bookkeeping.

-- ============================================================================
-- (a) Verification state, owned by us.
-- ============================================================================

alter table public.profiles
  add column email_verify_token text,
  add column email_verify_token_sent_at timestamptz,
  add column email_verified_at timestamptz;

comment on column public.profiles.email_verify_token is
  'CSPRNG token (64 hex chars: two gen_random_uuid() calls, dashes stripped,
   concatenated -- pgcrypto/gen_random_bytes is not enabled on this project,
   same approach as teams.invite_token). Set by generate_email_verify_token(),
   cleared the moment verify_email() succeeds -- null the rest of the time.
   Regenerating overwrites it, invalidating any link already sent.';
comment on column public.profiles.email_verify_token_sent_at is
  'When email_verify_token was last (re)generated. Set alongside the token, always.';
comment on column public.profiles.email_verified_at is
  'When this profile''s account email was verified through OUR OWN flow.
   Never read auth.users.email_confirmed_at as a substitute for this --
   that column means something different (whether Supabase itself gated
   sign-in on confirmation) and is meaningless once "Confirm email" is off,
   since Supabase stamps it for everyone at signup in that configuration.';

alter table public.profiles
  add constraint profiles_email_verify_token_key unique (email_verify_token);

-- Backfill: a ONE-TIME update, not a trigger or a view. Every account that
-- already passed Supabase's own confirmation gate under the old flow (every
-- account on this project today, pre-R0) is grandfathered in as verified --
-- re-verifying them would be gratuitous churn, and for a .edu address it
-- might be genuinely impossible, which is the exact problem R0 exists to
-- solve. Anyone whose auth.users.email_confirmed_at is null stays
-- unverified under the new system too.
update public.profiles pr
set email_verified_at = now()
from auth.users u
where u.id = pr.id
  and u.email_confirmed_at is not null
  and pr.email_verified_at is null;

-- ============================================================================
-- (b) Generate a token for the CALLING user only, scoped by auth.uid() --
-- never takes a target id, so there is no way to generate a token for
-- someone else's account.
-- ============================================================================

create or replace function public.generate_email_verify_token()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_token text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  v_token := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');

  update public.profiles
  set email_verify_token = v_token, email_verify_token_sent_at = now()
  where id = auth.uid();

  if not found then
    -- The profile row must already exist (join.html/coach-signup.html both
    -- call ensure_account_setup() before this) -- if it doesn't, generating
    -- a token nobody can ever redeem is worse than failing loudly here.
    raise exception 'profile not found for current user';
  end if;

  return v_token;
end;
$$;

-- Same default-privilege gotcha as every write-capable function added in
-- the prior R0 migration (confirmed again here via pg_proc.proacl) --
-- `revoke ... from public` alone does not touch anon's separately-granted
-- default privilege on new functions in this project.
revoke all on function public.generate_email_verify_token() from public, anon;
grant execute on function public.generate_email_verify_token() to authenticated;

-- ============================================================================
-- (c) Redeem a token. Deliberately anon-callable -- clicked from an email,
-- quite possibly on a device or browser with no session at all, same
-- trust model as resolve_team_invite. Token in the URL is the credential;
-- a wrong or already-used token gets one plain, non-leaky message, never
-- a raw Postgres error.
-- ============================================================================

create or replace function public.verify_email(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  select id into v_id from public.profiles where email_verify_token = p_token;
  if v_id is null then
    return jsonb_build_object('ok', false, 'error', 'invalid_or_used_token');
  end if;

  update public.profiles
  set email_verified_at = now(), email_verify_token = null, email_verify_token_sent_at = null
  where id = v_id;

  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.verify_email(text) from public;
grant execute on function public.verify_email(text) to anon, authenticated;

-- ============================================================================
-- (d) Repoint the four functions that used to read
-- auth.users.email_confirmed_at. Every one of the four gets repointed --
-- is_pitcher_verified has no caller in the client today, but leaving one
-- sibling reading a column that no longer means anything is how a future
-- session reintroduces exactly this bug. Return shapes are unchanged
-- (still a boolean called "email_confirmed" in two of them) so no client
-- code needs to change alongside this -- only what backs the boolean does.
-- auth.users is still read for the actual email address itself, which
-- hasn't moved; only the confirmed/verified boolean is repointed.
-- ============================================================================

create or replace function public.my_verification_status()
returns table(email text, email_confirmed boolean)
language sql
security definer
set search_path = ''
as $$
  select u.email, pr.email_verified_at is not null
  from auth.users u
  join public.profiles pr on pr.id = u.id
  where u.id = auth.uid();
$$;

create or replace function public.get_roster_verification(p_team_id uuid)
returns table(pitcher_id uuid, email text, email_confirmed boolean)
language sql
security definer
set search_path = ''
as $$
  select u.id, u.email, pr.email_verified_at is not null
  from public.pitcher_teams pt
  join auth.users u on u.id = pt.pitcher_id
  join public.profiles pr on pr.id = pt.pitcher_id
  where pt.team_id = p_team_id
    and public.is_team_coach(p_team_id);
$$;

create or replace function public.is_pitcher_verified(p_pitcher_id uuid)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select coalesce(
    (select email_verified_at is not null from public.profiles where id = p_pitcher_id),
    false
  );
$$;

create or replace function public.pitcher_email_report_blocked(p_pitcher_id uuid, p_emails text[])
returns boolean
language sql
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from auth.users u
    join public.profiles pr on pr.id = u.id
    where u.id = p_pitcher_id
      and pr.email_verified_at is null
      and lower(u.email) = any (select lower(e) from unnest(p_emails) as e)
  );
$$;

-- Grants on all four are unchanged from the prior migration (still
-- revoked from public/anon, still authenticated-only) -- CREATE OR REPLACE
-- does not reset a function's ACL, but stating that plainly rather than
-- leaving it implicit, since this migration's whole point is not leaving
-- things implicit.

-- ---------------------------------------------------------------------------------
-- ROLLBACK (no auto-down; write a new migration with this body if you need to
-- revert). Restores the four functions to their PRE-this-migration bodies
-- (reading auth.users.email_confirmed_at again -- only correct if Supabase's
-- own "Confirm email" toggle is back on for that environment when this runs),
-- drops the two new functions, drops the new columns:
--
--   create or replace function public.my_verification_status()
--   returns table(email text, email_confirmed boolean)
--   language sql security definer set search_path = ''
--   as $$ select email, email_confirmed_at is not null from auth.users where id = auth.uid(); $$;
--
--   create or replace function public.get_roster_verification(p_team_id uuid)
--   returns table(pitcher_id uuid, email text, email_confirmed boolean)
--   language sql security definer set search_path = ''
--   as $$ select u.id, u.email, u.email_confirmed_at is not null
--     from public.pitcher_teams pt join auth.users u on u.id = pt.pitcher_id
--     where pt.team_id = p_team_id and public.is_team_coach(p_team_id); $$;
--
--   create or replace function public.is_pitcher_verified(p_pitcher_id uuid)
--   returns boolean language sql security definer set search_path = ''
--   as $$ select coalesce((select email_confirmed_at is not null from auth.users where id = p_pitcher_id), false); $$;
--
--   create or replace function public.pitcher_email_report_blocked(p_pitcher_id uuid, p_emails text[])
--   returns boolean language sql security definer set search_path = ''
--   as $$ select exists (select 1 from auth.users u where u.id = p_pitcher_id
--     and u.email_confirmed_at is null
--     and lower(u.email) = any (select lower(e) from unnest(p_emails) as e)); $$;
--
--   drop function if exists public.verify_email(text);
--   drop function if exists public.generate_email_verify_token();
--   alter table public.profiles drop constraint if exists profiles_email_verify_token_key;
--   alter table public.profiles
--     drop column if exists email_verify_token,
--     drop column if exists email_verify_token_sent_at,
--     drop column if exists email_verified_at;
--
--   -- Any verification link already sent before a rollback breaks permanently --
--   -- there is no way to recreate the exact same token. Same accepted tradeoff
--   -- as the team-invite-token rollback note in the prior R0 migration.
-- ---------------------------------------------------------------------------------
