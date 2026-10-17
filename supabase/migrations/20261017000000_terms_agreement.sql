-- Terms agreement (Joel, Oct 17 2026): privacy policy / terms 2026-10-17 let Knuckleball LLC license or sell
-- charting data. Existing logins see a one-time "I agree" box in the app; this records the click.
--
-- On the login's PRIMARY profile (the account record, as P1-10's age answer):
--   terms_version   -- already there (P1-10): the version the login last accepted
--   terms_agreed_at -- NEW: when it accepted that version in the app's box
-- New sign-ups keep recording terms_version through record_attestation (with attested_at); unchanged.
--
-- Clients can read terms_agreed_at (column grant) but write it only through agree_to_terms().
-- No policy change (34 before and after).
--
-- Rollback: supabase/rollback/20261017000000_terms_agreement_down.sql

alter table public.profiles add column terms_agreed_at timestamptz;

comment on column public.profiles.terms_agreed_at is
  'Terms agreement (Oct 17 2026): when the login accepted terms_version in the app''s "I agree" box. Primary profile only.';

grant select (terms_agreed_at) on public.profiles to authenticated;

-- The caller's login agrees to a terms version. Idempotent: agreeing again to the version already recorded keeps the
-- first timestamp.
create or replace function public.agree_to_terms(p_terms_version text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_prim public.profiles%rowtype;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'not_authenticated');
  end if;
  if p_terms_version is null or p_terms_version !~ '^\d{4}-\d{2}-\d{2}$' then
    return jsonb_build_object('ok', false, 'error', 'invalid_version');
  end if;
  select * into v_prim from public.profiles where id = v_uid for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'profile_missing');
  end if;
  if v_prim.terms_version = p_terms_version and v_prim.terms_agreed_at is not null then
    return jsonb_build_object('ok', true, 'agreed_at', v_prim.terms_agreed_at, 'already', true);
  end if;
  update public.profiles
     set terms_version = p_terms_version, terms_agreed_at = now()
   where id = v_uid
  returning * into v_prim;
  return jsonb_build_object('ok', true, 'agreed_at', v_prim.terms_agreed_at, 'already', false);
end;
$$;
revoke all on function public.agree_to_terms(text) from public, anon;
grant execute on function public.agree_to_terms(text) to authenticated;
