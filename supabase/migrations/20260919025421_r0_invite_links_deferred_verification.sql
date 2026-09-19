-- R0 — Invite links replace email invites; deferred email verification.
--
-- Why: university mail gateways (Mimecast at Cairn, Proofpoint/Defender
-- elsewhere) silently quarantine invite emails from a young sending domain.
-- Joel is personally permitted at Cairn -- that does not transfer to
-- program #2. A shareable invite LINK has no such dependency: it can be
-- texted, posted to GroupMe, read aloud, or scanned as a QR code.
--
-- Escalate-if resolved (Sept 19 2026, Joel's sign-off): this project's
-- Supabase Auth "Confirm email" setting currently blocks signUp() from
-- returning a session until the confirmation link is clicked (confirmed
-- via coach-signup.html's own `if(!signUpData.session)` branch, and
-- empirically -- 0 of 17 unconfirmed auth.users rows on production have
-- ever signed in). Achieving "immediately in their account, prompted to
-- verify until they do" requires turning that setting OFF (a Supabase
-- Dashboard change, tracked separately -- this migration does not and
-- cannot touch it) and tracking verification ourselves. Rather than a
-- second, duplicate `profiles.email_verified_at` column that could drift
-- out of sync, this migration reads auth.users.email_confirmed_at
-- directly (still maintained by Supabase's own confirm/change-email flows
-- regardless of whether sign-in is gated on it) through the two
-- SECURITY DEFINER accessors below -- the only way to read it at all,
-- since auth.users is never exposed to PostgREST/RLS.

-- ============================================================================
-- (a) Team invite token
-- ============================================================================

alter table public.teams
  add column invite_token text,
  add column invite_token_rotated_at timestamptz;

comment on column public.teams.invite_token is
  'CSPRNG token (64 hex chars: two gen_random_uuid() calls, dashes stripped,
   concatenated -- pgcrypto/gen_random_bytes is not enabled on this project,
   confirmed while writing this migration, so this avoids that dependency
   entirely; gen_random_uuid() is core Postgres, no extension needed) for the
   shareable join link. Regenerating (rotate_team_invite) overwrites it,
   instantly invalidating the old link. Never derived from team id/name/timestamp.';
comment on column public.teams.invite_token_rotated_at is
  'When invite_token was last (re)generated. Set alongside invite_token, always.';

-- Backfill every existing team with a real token now, so every coach has a
-- working invite link the moment this migration lands -- no team is ever
-- left without one.
update public.teams
set invite_token = replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''),
    invite_token_rotated_at = now()
where invite_token is null;

alter table public.teams alter column invite_token set not null;
alter table public.teams add constraint teams_invite_token_key unique (invite_token);

-- ============================================================================
-- (b) Resolve a token to a team NAME ONLY, for the logged-out join page.
-- Deliberately a function, never a policy on teams -- CLAUDE.md RLS rule 3
-- (teams/pitcher_teams must never risk the 42P17 recursion) and the
-- existing is_team_coach/is_team_member pattern this follows. anon must be
-- able to call this (the whole point is showing the team name before
-- signup), but it can only ever return a name for a token it's given --
-- there is no way to enumerate teams through it.
-- ============================================================================

create or replace function public.resolve_team_invite(p_token text)
returns table(team_id uuid, team_name text)
language sql
security definer
set search_path = ''
as $$
  select id, name from public.teams where invite_token = p_token;
$$;

revoke all on function public.resolve_team_invite(text) from public;
grant execute on function public.resolve_team_invite(text) to anon, authenticated;

-- ============================================================================
-- (c) Join a team via token. Idempotent: pitcher_teams already has a
-- PRIMARY KEY on (pitcher_id, team_id) (confirmed via pg_constraint before
-- writing this), so ON CONFLICT DO NOTHING is a real no-op on a second
-- open of the same link, not a second row. Rejects an unknown/rotated
-- token with a plain error code the client turns into a clear message,
-- not a raw Postgres error.
-- ============================================================================

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
begin
  if v_uid is null then
    return jsonb_build_object('error', 'not_authenticated');
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

-- This project has a default privilege (ALTER DEFAULT PRIVILEGES ... GRANT
-- EXECUTE ON FUNCTIONS TO anon, authenticated) that auto-grants anon
-- execute on every new function in public, regardless of `revoke ... from
-- public` -- confirmed via pg_default_acl while building this migration,
-- and empirically: this exact function showed anon=X in pg_proc.proacl on
-- staging after the first version of this migration, despite the line
-- above. `public` and `anon` are different roles; revoking from one
-- doesn't touch a grant already made directly to the other. Every
-- function below that can WRITE, or that exposes a specific user's email,
-- explicitly revokes from anon too -- matching the one function in this
-- schema that already does this (ensure_account_setup). Read-only
-- boolean helpers like is_team_coach/is_team_member don't bother, and
-- neither does resolve_team_invite below, which anon is meant to call.
revoke all on function public.join_team_via_invite(text) from public, anon;
grant execute on function public.join_team_via_invite(text) to authenticated;

-- ============================================================================
-- (b continued) Regenerate a team's invite token. Coach-only, enforced by
-- is_team_coach (the existing helper, not a fresh ad hoc check) -- raises
-- rather than silently no-op-ing for a non-coach caller.
-- ============================================================================

create or replace function public.rotate_team_invite(p_team_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_new_token text;
begin
  if not public.is_team_coach(p_team_id) then
    raise exception 'not authorized';
  end if;

  v_new_token := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
  update public.teams
  set invite_token = v_new_token, invite_token_rotated_at = now()
  where id = p_team_id;

  return v_new_token;
end;
$$;

revoke all on function public.rotate_team_invite(uuid) from public, anon;
grant execute on function public.rotate_team_invite(uuid) to authenticated;

-- ============================================================================
-- Verification-status accessors. auth.users is never exposed to PostgREST
-- or readable under any RLS policy -- these two functions are the only
-- sanctioned way anything reads email_confirmed_at, and each returns only
-- what the caller is entitled to see (their own row; their own team's
-- roster, gated by is_team_coach exactly like get_roster_verification's
-- sibling reads elsewhere in this schema).
-- ============================================================================

create or replace function public.my_verification_status()
returns table(email text, email_confirmed boolean)
language sql
security definer
set search_path = ''
as $$
  select email, email_confirmed_at is not null
  from auth.users
  where id = auth.uid();
$$;

revoke all on function public.my_verification_status() from public, anon;
grant execute on function public.my_verification_status() to authenticated;

create or replace function public.get_roster_verification(p_team_id uuid)
returns table(pitcher_id uuid, email text, email_confirmed boolean)
language sql
security definer
set search_path = ''
as $$
  select u.id, u.email, u.email_confirmed_at is not null
  from public.pitcher_teams pt
  join auth.users u on u.id = pt.pitcher_id
  where pt.team_id = p_team_id
    and public.is_team_coach(p_team_id);
$$;

revoke all on function public.get_roster_verification(uuid) from public, anon;
grant execute on function public.get_roster_verification(uuid) to authenticated;

-- ============================================================================
-- Item (g): report-recipient gating. send-session-report reads no table
-- today (confirmed while reporting the Preconditions) -- this is its
-- first-ever database read, and it needs to answer "is THIS pitcher_id
-- verified" for an arbitrary pitcher_id named in the payload, not just the
-- caller's own status (my_verification_status) or a coach's own roster
-- (get_roster_verification, gated on is_team_coach -- wrong shape here,
-- since a pitcher can send their own report too). Returns only a boolean,
-- never the email itself -- any authenticated caller may check any
-- pitcher_id's status, which is exactly what the function needs and low
-- enough sensitivity (a yes/no, not the address) to not warrant scoping
-- further.
-- ============================================================================

create or replace function public.is_pitcher_verified(p_pitcher_id uuid)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select coalesce(
    (select email_confirmed_at is not null from auth.users where id = p_pitcher_id),
    false
  );
$$;

revoke all on function public.is_pitcher_verified(uuid) from public, anon;
grant execute on function public.is_pitcher_verified(uuid) to authenticated;

-- send-session-report needs to check "does this pitcher's own account
-- email appear in the recipient list while unverified" -- a plain boolean
-- membership test done entirely server-side, so the Edge Function (which
-- is called with the AUTHENTICATED CALLER's own JWT, same trust level as
-- any other RPC caller -- not service-role) never needs to see the actual
-- account email at all, just the yes/no answer to "would this array of
-- addresses include a blocked one." p_emails is matched case-insensitively.
create or replace function public.pitcher_email_report_blocked(p_pitcher_id uuid, p_emails text[])
returns boolean
language sql
security definer
set search_path = ''
as $$
  select exists (
    select 1 from auth.users u
    where u.id = p_pitcher_id
      and u.email_confirmed_at is null
      and lower(u.email) = any (select lower(e) from unnest(p_emails) as e)
  );
$$;

revoke all on function public.pitcher_email_report_blocked(uuid, text[]) from public, anon;
grant execute on function public.pitcher_email_report_blocked(uuid, text[]) to authenticated;

-- ---------------------------------------------------------------------------------
-- ROLLBACK (no auto-down; write a new migration with this body if you need to
-- revert):
--
--   drop function if exists public.pitcher_email_report_blocked(uuid, text[]);
--   drop function if exists public.is_pitcher_verified(uuid);
--   drop function if exists public.get_roster_verification(uuid);
--   drop function if exists public.my_verification_status();
--   drop function if exists public.rotate_team_invite(uuid);
--   drop function if exists public.join_team_via_invite(text);
--   drop function if exists public.resolve_team_invite(text);
--   alter table public.teams drop constraint if exists teams_invite_token_key;
--   alter table public.teams
--     drop column if exists invite_token,
--     drop column if exists invite_token_rotated_at;
--
--   -- Any invite link already shared before a rollback breaks permanently --
--   -- there is no way to recreate the exact same token. This is the accepted
--   -- tradeoff of a rollback here, same as U4's report-link rollback note.
-- ---------------------------------------------------------------------------------
