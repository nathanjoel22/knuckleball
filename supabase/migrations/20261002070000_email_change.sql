-- Change Email, one email (Joel, Oct 2 2026; auth-flow change signed off).
-- The address lives ONLY in auth.users (no profiles.email). Flow:
--   1. request-email-change (Edge Function, caller's JWT) calls
--      begin_email_change(new): records the request on the login's primary
--      profile (hidden columns), cancels any outstanding Knuckleball
--      verification link, rate-limits to one send per 10 minutes. The
--      function then has Supabase GENERATE (not send) the email-change link
--      and sends it through Resend in a Knuckleball template.
--   2. The link lands on the tracker (?email_change=1); the tracker calls
--      confirm_email_change(): succeeds only if the login's auth.users email
--      now equals the requested address with nothing pending -- i.e. the
--      new inbox's link was clicked. Sets email_verified_at and moves the
--      report address (contact_emails.pitcher) from the old to the new one
--      on every profile the login owns.
-- Verification never reads auth.users.email_confirmed_at (Amendment 9).
-- The only paths that set email_verified_at: verify_email (now bound to the
-- address the link was sent to) and confirm_email_change.
-- Rollback: supabase/rollback/20261002070000_email_change_down.sql

alter table public.profiles
  add column email_change_requested    text,          -- secret: never granted to clients
  add column email_change_from         text,          -- secret: the address being replaced
  add column email_change_requested_at timestamptz,   -- secret
  add column email_verify_sent_to      text;          -- secret: where the outstanding verify link went

comment on column public.profiles.email_change_requested is 'Change Email: the requested new address (lowercase); set by begin_email_change, cleared by confirm/abandon. Never client-readable.';
comment on column public.profiles.email_verify_sent_to is 'The address the outstanding email_verify_token was sent to; verify_email only redeems it while that is still the login''s address.';

-- Tokens issued before this migration were sent to the login's address at the
-- time. Bind each outstanding one to the CURRENT address: a login with an
-- email change still pending hasn't changed yet, so that is still right, and
-- the link stops working the moment the address changes.
update public.profiles pr
   set email_verify_sent_to = lower(u.email)
  from auth.users u
 where u.id = pr.id and pr.email_verify_token is not null;

-- ------------------------------------------------------------ begin
create or replace function public.begin_email_change(p_email text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $_$
declare
  v_uid   uuid := auth.uid();
  v_new   text := lower(btrim(coalesce(p_email, '')));
  v_cur   text;
  v_prim  public.profiles%rowtype;
  v_wait  int;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'not_authenticated');
  end if;
  if v_new !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' or length(v_new) > 254 then
    return jsonb_build_object('ok', false, 'error', 'invalid_email');
  end if;
  select lower(u.email) into v_cur from auth.users u where u.id = v_uid;
  if v_new = v_cur then
    return jsonb_build_object('ok', false, 'error', 'same_email');
  end if;
  select * into v_prim from public.profiles where id = v_uid for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'profile_missing');
  end if;
  if v_prim.email_change_requested_at is not null and v_prim.email_change_requested_at > now() - interval '10 minutes' then
    v_wait := ceil(extract(epoch from (v_prim.email_change_requested_at + interval '10 minutes' - now())));
    return jsonb_build_object('ok', false, 'error', 'too_soon', 'retry_after_seconds', v_wait);
  end if;
  update public.profiles
     set email_change_requested = v_new,
         email_change_from = v_cur,
         email_change_requested_at = now(),
         email_verify_token = null,            -- an outstanding link to the old address stops working
         email_verify_token_sent_at = null,
         email_verify_sent_to = null
   where id = v_uid;
  return jsonb_build_object('ok', true, 'current_email', v_cur, 'new_email', v_new);
end;
$_$;
revoke all on function public.begin_email_change(text) from public, anon;
grant execute on function public.begin_email_change(text) to authenticated;

-- The send failed (e.g. the address belongs to another account): forget the
-- request so the caller can try a different address right away.
create or replace function public.abandon_email_change()
returns void
language sql
security definer
set search_path = ''
as $$
  update public.profiles
     set email_change_requested = null, email_change_from = null, email_change_requested_at = null
   where id = auth.uid();
$$;
revoke all on function public.abandon_email_change() from public, anon;
grant execute on function public.abandon_email_change() to authenticated;

-- ------------------------------------------------------------ confirm
create or replace function public.confirm_email_change()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_email   text;
  v_pending text;
  v_prim    public.profiles%rowtype;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'error', 'not_authenticated');
  end if;
  select lower(u.email), nullif(u.email_change, '') into v_email, v_pending from auth.users u where u.id = v_uid;
  select * into v_prim from public.profiles where id = v_uid for update;
  if not found or v_prim.email_change_requested is null then
    return jsonb_build_object('ok', false, 'error', 'no_pending_change');
  end if;
  if v_pending is not null then
    -- Supabase is still waiting on a confirmation ("Secure email change" on
    -- needs the OLD inbox's link too) -- nothing is verified until it isn't.
    return jsonb_build_object('ok', false, 'error', 'still_pending');
  end if;
  if v_email is distinct from v_prim.email_change_requested then
    return jsonb_build_object('ok', false, 'error', 'email_mismatch');
  end if;

  update public.profiles
     set email_verified_at = now(),
         email_verify_token = null, email_verify_token_sent_at = null, email_verify_sent_to = null,
         email_change_requested = null, email_change_from = null, email_change_requested_at = null
   where id = v_uid;
  -- Reports follow the login's address: every profile this login owns
  -- (second sport, a parent's players) whose report address was the old one.
  update public.profiles
     set contact_emails = jsonb_set(coalesce(contact_emails, '{}'::jsonb), '{pitcher}', to_jsonb(v_email))
   where account_id = v_uid
     and lower(coalesce(contact_emails ->> 'pitcher', '')) in (coalesce(v_prim.email_change_from, ''), '');
  return jsonb_build_object('ok', true, 'email', v_email);
end;
$$;
revoke all on function public.confirm_email_change() from public, anon;
grant execute on function public.confirm_email_change() to authenticated;

-- ------------------------------------------------------------ bind verify links
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
      email_verify_sent_to = (select lower(u.email) from auth.users u where u.id = auth.uid())
  where id = auth.uid();

  if not found then
    raise exception 'profile not found for current user';
  end if;

  return v_token;
end;
$$;

create or replace function public.verify_email(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  -- Only while the link's address is still the login's address: a link sent
  -- to an address that has since been replaced verifies nothing.
  select pr.id into v_id
    from public.profiles pr join auth.users u on u.id = pr.id
   where pr.email_verify_token = p_token
     and pr.email_verify_sent_to is not null
     and pr.email_verify_sent_to = lower(u.email);
  if v_id is null then
    return jsonb_build_object('ok', false, 'error', 'invalid_or_used_token');
  end if;

  update public.profiles
  set email_verified_at = now(), email_verify_token = null, email_verify_token_sent_at = null, email_verify_sent_to = null
  where id = v_id;

  return jsonb_build_object('ok', true);
end;
$$;
