-- R0 follow-up — issuing a new verification token always invalidates any
-- prior verification, so Change Email can't leave a stale "verified" flag
-- pointing at an address that's no longer the account's.
--
-- Why: generate_email_verify_token() only ever touched email_verify_token /
-- email_verify_token_sent_at, never email_verified_at. That's harmless for
-- the two existing callers (post-signup send, Resend button) since
-- email_verified_at is already null in both cases -- but Change Email
-- (bullpen-tracker.html's submitChangeEmail, wired up alongside this
-- migration to call send-verification-email once auth.users.email has
-- actually updated) is the first caller where a profile can ALREADY be
-- verified when a new token gets issued. Without this, a pitcher who
-- verifies address A, then changes to address B, would keep showing as
-- verified for B without anyone ever having confirmed B belongs to them.
--
-- Folding this into generate_email_verify_token() itself (rather than a
-- separate reset step only Change Email calls) makes it a general
-- invariant -- "a fresh token means the previous verification, if any, no
-- longer counts" -- true for every caller, not a special case bolted on
-- for one of them.
--
-- Staging precondition confirmed with Joel before building this: Supabase's
-- "Secure email change" is off on staging, so auth.users.email updates
-- synchronously when updateUser({email}) is called -- no separate Supabase
-- confirmation email, no pending/deferred state to race against. Confirmed
-- empirically the OPPOSITE case first (Secure email change was on when
-- this was tested): auth.users.email only updated 17s after updateUser()
-- returned, once Supabase's own confirmation link was clicked (see
-- email_change_sent_at / updated_at on a real staging row) -- calling our
-- own send-verification-email immediately after updateUser() would have
-- fired to the OLD address in that configuration. Production has not had
-- this setting checked or changed.

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
  set email_verify_token = v_token,
      email_verify_token_sent_at = now(),
      email_verified_at = null
  where id = auth.uid();

  if not found then
    raise exception 'profile not found for current user';
  end if;

  return v_token;
end;
$$;

-- Grants unchanged from when this function was first created (still
-- revoked from public/anon, authenticated-only) -- CREATE OR REPLACE
-- doesn't reset a function's ACL, same note as the last time this
-- migration series touched an existing function's body.

-- ---------------------------------------------------------------------------------
-- ROLLBACK (no auto-down; write a new migration with this body if you need to
-- revert) -- restores the pre-this-migration body, which never touched
-- email_verified_at:
--
--   create or replace function public.generate_email_verify_token()
--   returns text
--   language plpgsql security definer set search_path = ''
--   as $$
--   declare
--     v_token text;
--   begin
--     if auth.uid() is null then
--       raise exception 'not authenticated';
--     end if;
--     v_token := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
--     update public.profiles
--     set email_verify_token = v_token, email_verify_token_sent_at = now()
--     where id = auth.uid();
--     if not found then
--       raise exception 'profile not found for current user';
--     end if;
--     return v_token;
--   end;
--   $$;
-- ---------------------------------------------------------------------------------
