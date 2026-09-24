-- Fix: Resend was silently un-verifying already-verified accounts.
--
-- Root cause (full writeup: session notes, Sept 24 2026): 20260921010145
-- made generate_email_verify_token() unconditionally null
-- profiles.email_verified_at on every call, so that Change Email couldn't
-- leave a stale "verified" flag pointing at an address nobody re-confirmed.
-- That reasoning is correct for Change Email specifically, but the same
-- function is also the ONLY thing behind the plain "Resend verification
-- email" button -- and state.myVerification is fetched once per app load
-- and never refreshed, so a pitcher who verifies in one tab and then hits
-- Resend on another, still-open, stale tab gets their real, just-completed
-- verification wiped. This is exactly what happened to two real pitchers
-- (Jack Croft, Christian Geiger) on 2026-09-24: both verified, then a few
-- minutes later showed unverified again, with a freshly (re)issued token
-- as the tell.
--
-- Fix, in two single-purpose pieces rather than one shared function with a
-- flag a future caller could forget to set:
--   1. generate_email_verify_token() reverts to never touching
--      email_verified_at at all (its pre-20260921010145 body) -- issuing a
--      token is now unconditionally safe for every caller, present or
--      future, with nothing left to get wrong by omission.
--   2. invalidate_my_email_verification(), new, does only the one thing
--      Change Email actually needs -- clear the caller's own verification.
--      bullpen-tracker.html's submitChangeEmail() is updated in this same
--      change to call it explicitly, right after auth.updateUser({email})
--      succeeds and before requesting a new verification email.
--
-- Restoring Jack and Christian: NOT done here. Per the same investigation,
-- verify_email() itself is proven correct -- the fix is to have each of
-- them click Resend once (now safe) and then the resulting link once, not
-- to hand-write email_verified_at back to a timestamp nobody actually
-- confirmed.
--
-- ---------------------------------------------------------------------------------
-- ROLLBACK (no auto-down; write a new migration with this body if you need
-- to revert):
--
--   drop function if exists public.invalidate_my_email_verification();
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
--     set email_verify_token = v_token, email_verify_token_sent_at = now(),
--         email_verified_at = null
--     where id = auth.uid();
--     if not found then
--       raise exception 'profile not found for current user';
--     end if;
--     return v_token;
--   end;
--   $$;
--
--   -- Also revert submitChangeEmail() in bullpen-tracker.html to drop the
--   -- invalidate_my_email_verification() call this change adds.
-- ---------------------------------------------------------------------------------

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
      email_verify_token_sent_at = now()
  where id = auth.uid();

  if not found then
    raise exception 'profile not found for current user';
  end if;

  return v_token;
end;
$$;

-- Grants unchanged from when this function was first created (still
-- revoked from public/anon, authenticated-only) -- CREATE OR REPLACE
-- doesn't reset a function's ACL.

-- Change Email's own, explicit invalidation step -- the only caller that
-- should ever exist for this. auth.uid()-scoped like every sibling here
-- (my_verification_status, generate_email_verify_token, verify_email);
-- there is no p_pitcher_id parameter to abuse, on purpose.
create or replace function public.invalidate_my_email_verification()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  update public.profiles
  set email_verified_at = null
  where id = auth.uid();
end;
$$;

revoke all on function public.invalidate_my_email_verification() from public, anon;
grant execute on function public.invalidate_my_email_verification() to authenticated;
