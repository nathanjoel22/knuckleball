-- Rollback for 20261121000000_r7b_facility_self_serve.sql (R7 Stage B). Self-serve facilities stay as ordinary
-- facilities (only the created_via / notified_at record goes); create_facility and rate_limit_take go back to their
-- definitions from before (copied from production, Nov 19 2026, identical on staging).
drop trigger if exists pitcher_teams_r7_verify_gate on public.pitcher_teams;
drop trigger if exists team_coaches_r7_verify_gate on public.team_coaches;
drop function if exists public.r7_facility_verify_gate();
drop function if exists public.r7_facility_unverified(uuid);
drop function if exists public.my_facility_needs_verify();
drop function if exists public.create_facility_self(text);
CREATE OR REPLACE FUNCTION public.create_facility(p_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := auth.uid();
  v public.facility_invites%rowtype;
  v_email text; v_prim public.profiles%rowtype; v_bb uuid; v_sb uuid; v_org uuid; v_team uuid; v_name text;
begin
  if v_uid is null then return jsonb_build_object('ok', false, 'error', 'not_authenticated'); end if;
  select * into v from public.facility_invites where token = p_token for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if v.used_at is not null then
    if v.used_by = v_uid then return jsonb_build_object('ok', true, 'status', 'already_created', 'org_id', v.org_id); end if;
    return jsonb_build_object('ok', false, 'error', 'used');
  end if;
  if v.expires_at < now() then return jsonb_build_object('ok', false, 'error', 'expired'); end if;
  select lower(u.email) into v_email from auth.users u where u.id = v_uid;
  if v_email is distinct from lower(btrim(v.manager_email)) then return jsonb_build_object('ok', false, 'error', 'wrong_email'); end if;
  if exists (select 1 from public.organizations o where o.manager_login = v_uid) then
    return jsonb_build_object('ok', false, 'error', 'already_manager');
  end if;
  -- A fresh login only: none of its profiles is on a team or staff yet.
  if exists (select 1 from public.team_coaches tc join public.profiles pr on pr.id = tc.coach_id where pr.account_id = v_uid)
     or exists (select 1 from public.pitcher_teams pt join public.profiles pr on pr.id = pt.pitcher_id where pr.account_id = v_uid) then
    return jsonb_build_object('ok', false, 'error', 'login_in_use');
  end if;
  select * into v_prim from public.profiles where id = v_uid;
  if not found then
    v_name := nullif(btrim((select u.raw_user_meta_data ->> 'full_name' from auth.users u where u.id = v_uid)), '');
    if v_name is null then return jsonb_build_object('ok', false, 'error', 'name_required'); end if;
    insert into public.profiles (id, role, full_name, sport) values (v_uid, 'coach', v_name, 'baseball');
    select * into v_prim from public.profiles where id = v_uid;
  end if;
  if v_prim.role <> 'coach' then return jsonb_build_object('ok', false, 'error', 'not_a_coach_login'); end if;
  select id into v_bb from public.profiles where account_id = v_uid and role = 'coach' and managed_by is null and sport = 'baseball' limit 1;
  select id into v_sb from public.profiles where account_id = v_uid and role = 'coach' and managed_by is null and sport = 'softball' limit 1;
  if v_bb is null then
    v_bb := gen_random_uuid();
    insert into public.profiles (id, account_id, role, full_name, sport) values (v_bb, v_uid, 'coach', v_prim.full_name, 'baseball');
  end if;
  if v_sb is null then
    v_sb := gen_random_uuid();
    insert into public.profiles (id, account_id, role, full_name, sport) values (v_sb, v_uid, 'coach', v_prim.full_name, 'softball');
  end if;

  insert into public.organizations (name, manager_login) values (btrim(v.facility_name), v_uid) returning id into v_org;
  -- Both sides, as _create_team_with_head does (the invite token comes from the existing trigger), plus org and kind.
  insert into public.teams (coach_id, name, coach_invite_token, coach_invite_token_rotated_at, org_id, kind, level)
    values (v_bb, btrim(v.facility_name), replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''), now(),
            v_org, 'facility', v.baseball_level) returning id into v_team;
  insert into public.team_coaches (team_id, coach_id, role) values (v_team, v_bb, 'head');
  insert into public.teams (coach_id, name, coach_invite_token, coach_invite_token_rotated_at, org_id, kind, level)
    values (v_sb, btrim(v.facility_name), replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''), now(),
            v_org, 'facility', v.softball_level) returning id into v_team;
  insert into public.team_coaches (team_id, coach_id, role) values (v_team, v_sb, 'head');

  update public.facility_invites set used_at = now(), used_by = v_uid, org_id = v_org where token = p_token;
  return jsonb_build_object('ok', true, 'status', 'created', 'org_id', v_org);
end;
$function$;
drop function if exists public.f1_make_facility(uuid, text, text, text, text);
CREATE OR REPLACE FUNCTION public.rate_limit_take(p_actor uuid, p_kind text, p_recipients text[] DEFAULT '{}'::text[], p_global_cap integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_rcpts  text[] := coalesce((select array_agg(distinct lower(btrim(r))) from unnest(coalesce(p_recipients, '{}')) r
                               where btrim(coalesce(r, '')) <> ''), '{}');
  v_email  boolean := p_kind not in ('report_generate', 'account_export');   -- A1: an export is a download, not an email
  v_cfg    public.rate_limit_config%rowtype;
  v_n      integer;
  v_oldest timestamptz;
  v_r      text;
  v_alert  boolean := false;
  v_keys   text[];
  v_k      text;
begin
  if p_kind not in ('report_email', 'report_generate', 'verify_email', 'guardian_email', 'removal_notice', 'email_change', 'account_deletion', 'account_export') then
    raise exception 'unknown rate-limit kind: %', p_kind;
  end if;
  perform pg_advisory_xact_lock(hashtext('rate_limit:' || coalesce(p_actor::text, '-')));
  delete from public.rate_limit_events where at < now() - interval '7 days';

  -- per-user limits for this kind
  v_keys := case p_kind
    when 'report_email'    then array['report_email_hour', 'report_email_day']
    when 'report_generate' then array['report_generate_hour']
    when 'verify_email'    then array['verify_email_hour']
    when 'guardian_email'  then array['guardian_email_day']
    when 'removal_notice'  then array['removal_notice_day']
    when 'email_change'    then array['email_change_day']
    when 'account_deletion' then array['account_deletion_day']   -- A1
    when 'account_export'  then array['account_export_day'] end;   -- A1
  foreach v_k in array v_keys loop
    select * into v_cfg from public.rate_limit_config where key = v_k;
    continue when not found;
    select count(*), min(at) into v_n, v_oldest from public.rate_limit_events
     where kind = p_kind and actor = p_actor and at > now() - make_interval(secs => v_cfg.window_seconds);
    if v_n >= v_cfg.max_count then
      return public.rate_limit_refusal(v_k, coalesce(v_oldest, now()) + make_interval(secs => v_cfg.window_seconds));
    end if;
  end loop;

  if v_email then
    -- per-recipient limits
    foreach v_r in array v_rcpts loop
      select * into v_cfg from public.rate_limit_config where key = 'recipient_day';
      if found then
        select count(*), min(at) into v_n, v_oldest from public.rate_limit_events
         where kind = 'to' and recipient = v_r and at > now() - make_interval(secs => v_cfg.window_seconds);
        if v_n >= v_cfg.max_count then
          return public.rate_limit_refusal('recipient_day', coalesce(v_oldest, now()) + make_interval(secs => v_cfg.window_seconds));
        end if;
      end if;
      if p_kind = 'verify_email' then
        select * into v_cfg from public.rate_limit_config where key = 'verify_recipient_day';
        if found then
          select count(*), min(at) into v_n, v_oldest from public.rate_limit_events
           where kind = 'to' and via = 'verify_email' and recipient = v_r and at > now() - make_interval(secs => v_cfg.window_seconds);
          if v_n >= v_cfg.max_count then
            return public.rate_limit_refusal('verify_recipient_day', coalesce(v_oldest, now()) + make_interval(secs => v_cfg.window_seconds));
          end if;
        end if;
      end if;
    end loop;

    -- the daily circuit breaker (every Knuckleball email, everyone)
    if p_global_cap is not null then
      perform pg_advisory_xact_lock(hashtext('rate_limit:global'));
      select count(*), min(at) into v_n, v_oldest from public.rate_limit_events
       where kind = 'to' and at > now() - interval '1 day';
      if v_n + greatest(array_length(v_rcpts, 1), 1) > p_global_cap then
        if not exists (select 1 from public.rate_limit_events where kind = 'breaker_alert' and at > now() - interval '1 day') then
          insert into public.rate_limit_events (kind) values ('breaker_alert');
          v_alert := true;
        end if;
        return public.rate_limit_refusal('global_day', coalesce(v_oldest, now()) + interval '1 day') || jsonb_build_object('alert', v_alert);
      end if;
    end if;
  end if;

  insert into public.rate_limit_events (kind, actor) values (p_kind, p_actor);
  if v_email then
    insert into public.rate_limit_events (kind, actor, recipient, via)
      select 'to', p_actor, r, p_kind from unnest(v_rcpts) r;
  end if;
  return jsonb_build_object('ok', true, 'alert', false);
end;
$function$;
delete from public.rate_limit_config where key in ('facility_self_serve_day', 'facility_notify_day');
delete from public.rate_limit_events where kind = 'facility_notify';
alter table public.organizations drop constraint if exists organizations_created_via_check;
alter table public.organizations drop column if exists created_via;
alter table public.organizations drop column if exists notified_at;
