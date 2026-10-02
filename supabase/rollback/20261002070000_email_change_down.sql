-- Down migration for 20261002070000_email_change.sql: restores the previous verification functions
-- and drops the Change Email request columns. Pending change requests are discarded.
drop function if exists public.begin_email_change(text);
drop function if exists public.abandon_email_change();
drop function if exists public.confirm_email_change();
CREATE OR REPLACE FUNCTION "public"."generate_email_verify_token"() RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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

CREATE OR REPLACE FUNCTION "public"."verify_email"("p_token" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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

alter table public.profiles drop column if exists email_change_requested, drop column if exists email_change_from,
  drop column if exists email_change_requested_at, drop column if exists email_verify_sent_to;
