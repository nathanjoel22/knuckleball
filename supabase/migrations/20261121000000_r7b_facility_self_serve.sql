-- R7 Stage B (Joel, Nov 19 2026; plans/r7-one-login.md, decisions in plans/r7-preconditions.md item 5): a facility can
-- sign itself up from the New account form, with no link from Knuckleball.
--
--  (1) organizations gains created_via ('operator_link' / 'self_serve'; every existing row is an operator link) and
--      notified_at (when Joel's one email about a self-serve facility went out).
--  (2) f1_make_facility(login, name, levels, via): create_facility's body, moved, so both ways in make the same thing
--      by construction (one organization, both facility sides, the manager head of both). Not callable by clients.
--  (3) create_facility(token) calls it; nothing it does or refuses changes.
--  (4) create_facility_self(name): the self-serve way in. One facility per login (already_manager), a fresh login only
--      (login_in_use), the 18+ answer already recorded (adult_required), and a daily cap on self-serve facilities for
--      everyone (rate_limit_config 'facility_self_serve_day', default 20, tunable without a deploy). Levels are left to
--      the teams' default (as a coach's team); the manager sets them in Account.
--  (5) Verified before adding people: a self-serve facility whose manager hasn't verified their email (profiles.
--      email_verified_at on the primary profile, set only by verify_email / confirm_email_change; auth.users.
--      email_confirmed_at is never read) can't gain a pitcher (pitcher_teams) or a coach other than the manager
--      (team_coaches). One BEFORE INSERT trigger on each covers every way in (codes, staff links, invites, Create
--      Child's Profile). my_facility_needs_verify() tells the app to say so. Operator-made facilities are unaffected.
--  (6) rate_limit_take gains the 'facility_notify' kind for facility-notify's email to the operator.
-- No policy is added or changed: public stays 32, storage 12.
-- Rollback: supabase/rollback/20261121000000_r7b_facility_self_serve_down.sql. Test: supabase/tests/r7b_facility_self.sql.

-- (1)
alter table public.organizations add column created_via text not null default 'operator_link';
alter table public.organizations add constraint organizations_created_via_check check (created_via in ('operator_link', 'self_serve'));
alter table public.organizations add column notified_at timestamptz;
comment on column public.organizations.created_via is 'R7 Stage B: operator_link (facility-signup.html?t=, from operator.html) or self_serve (the New account form).';
comment on column public.organizations.notified_at is 'R7 Stage B: when facility-notify emailed the operator about this self-serve facility (once).';

insert into public.rate_limit_config (key, window_seconds, max_count, note) values
  ('facility_self_serve_day', 86400, 20, 'R7: self-serve facilities created per day, everyone (create_facility_self)'),
  ('facility_notify_day', 86400, 5, 'R7: facility-notify emails to the operator per manager login per day');

-- (2)
create or replace function public.f1_make_facility(p_uid uuid, p_name text, p_bb_level text, p_sb_level text, p_via text)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare
  v_prim public.profiles%rowtype; v_bb uuid; v_sb uuid; v_org uuid; v_team uuid; v_name text;
begin
  if exists (select 1 from public.organizations o where o.manager_login = p_uid) then
    return jsonb_build_object('ok', false, 'error', 'already_manager');
  end if;
  -- A fresh login only: none of its profiles is on a team or staff yet.
  if exists (select 1 from public.team_coaches tc join public.profiles pr on pr.id = tc.coach_id where pr.account_id = p_uid)
     or exists (select 1 from public.pitcher_teams pt join public.profiles pr on pr.id = pt.pitcher_id where pr.account_id = p_uid) then
    return jsonb_build_object('ok', false, 'error', 'login_in_use');
  end if;
  select * into v_prim from public.profiles where id = p_uid;
  if not found then
    v_name := nullif(btrim((select u.raw_user_meta_data ->> 'full_name' from auth.users u where u.id = p_uid)), '');
    if v_name is null then return jsonb_build_object('ok', false, 'error', 'name_required'); end if;
    insert into public.profiles (id, role, full_name, sport) values (p_uid, 'coach', v_name, 'baseball');
    select * into v_prim from public.profiles where id = p_uid;
  end if;
  if v_prim.role <> 'coach' then return jsonb_build_object('ok', false, 'error', 'not_a_coach_login'); end if;
  select id into v_bb from public.profiles where account_id = p_uid and role = 'coach' and managed_by is null and sport = 'baseball' limit 1;
  select id into v_sb from public.profiles where account_id = p_uid and role = 'coach' and managed_by is null and sport = 'softball' limit 1;
  if v_bb is null then
    v_bb := gen_random_uuid();
    insert into public.profiles (id, account_id, role, full_name, sport) values (v_bb, p_uid, 'coach', v_prim.full_name, 'baseball');
  end if;
  if v_sb is null then
    v_sb := gen_random_uuid();
    insert into public.profiles (id, account_id, role, full_name, sport) values (v_sb, p_uid, 'coach', v_prim.full_name, 'softball');
  end if;

  insert into public.organizations (name, manager_login, created_via) values (btrim(p_name), p_uid, p_via) returning id into v_org;
  -- Both sides, as _create_team_with_head does (the invite token comes from the existing trigger), plus org and kind.
  -- A null level takes the teams' default (teams_level_default).
  insert into public.teams (coach_id, name, coach_invite_token, coach_invite_token_rotated_at, org_id, kind, level)
    values (v_bb, btrim(p_name), replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''), now(),
            v_org, 'facility', p_bb_level) returning id into v_team;
  insert into public.team_coaches (team_id, coach_id, role) values (v_team, v_bb, 'head');
  insert into public.teams (coach_id, name, coach_invite_token, coach_invite_token_rotated_at, org_id, kind, level)
    values (v_sb, btrim(p_name), replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''), now(),
            v_org, 'facility', p_sb_level) returning id into v_team;
  insert into public.team_coaches (team_id, coach_id, role) values (v_team, v_sb, 'head');
  return jsonb_build_object('ok', true, 'org_id', v_org);
end;
$$;
revoke all on function public.f1_make_facility(uuid, text, text, text, text) from public, anon, authenticated;

-- (3)
create or replace function public.create_facility(p_token text)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare
  v_uid uuid := auth.uid();
  v public.facility_invites%rowtype;
  v_email text; r jsonb;
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
  r := public.f1_make_facility(v_uid, v.facility_name, v.baseball_level, v.softball_level, 'operator_link');
  if not (r ->> 'ok')::boolean then return r; end if;
  update public.facility_invites set used_at = now(), used_by = v_uid, org_id = (r ->> 'org_id')::uuid where token = p_token;
  return jsonb_build_object('ok', true, 'status', 'created', 'org_id', (r ->> 'org_id')::uuid);
end;
$$;

-- (4)
create or replace function public.create_facility_self(p_facility_name text)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare
  v_uid uuid := auth.uid();
  v_name text := btrim(coalesce(p_facility_name, ''));
  v_cfg public.rate_limit_config%rowtype; v_n integer; v_att text; r jsonb;
begin
  if v_uid is null then return jsonb_build_object('ok', false, 'error', 'not_authenticated'); end if;
  if char_length(v_name) < 2 or char_length(v_name) > 60 then return jsonb_build_object('ok', false, 'error', 'name_invalid'); end if;
  select age_attestation into v_att from public.profiles where id = v_uid;
  if v_att is distinct from 'adult' then return jsonb_build_object('ok', false, 'error', 'adult_required'); end if;
  perform pg_advisory_xact_lock(hashtext('r7:facility_self_serve'));
  select * into v_cfg from public.rate_limit_config where key = 'facility_self_serve_day';
  if found then
    select count(*) into v_n from public.organizations
     where created_via = 'self_serve' and created_at > now() - make_interval(secs => v_cfg.window_seconds);
    if v_n >= v_cfg.max_count then return jsonb_build_object('ok', false, 'error', 'daily_cap'); end if;
  end if;
  r := public.f1_make_facility(v_uid, v_name, null, null, 'self_serve');
  if not (r ->> 'ok')::boolean then return r; end if;
  return jsonb_build_object('ok', true, 'status', 'created', 'org_id', (r ->> 'org_id')::uuid);
end;
$$;
revoke all on function public.create_facility_self(text) from public, anon;
grant execute on function public.create_facility_self(text) to authenticated;

-- (5)
create or replace function public.r7_facility_unverified(p_team uuid)
returns boolean language sql stable security definer set search_path to '' as $$
  select exists (
    select 1 from public.teams t
      join public.organizations o on o.id = t.org_id
      join public.profiles m on m.id = o.manager_login
     where t.id = p_team and t.kind = 'facility' and o.created_via = 'self_serve' and m.email_verified_at is null);
$$;
revoke all on function public.r7_facility_unverified(uuid) from public, anon, authenticated;

create or replace function public.r7_facility_verify_gate()
returns trigger language plpgsql security definer set search_path to '' as $$
begin
  if not public.r7_facility_unverified(new.team_id) then return new; end if;
  -- the manager's own coach profiles (both sides' head rows) are the facility itself, not people added to it
  -- (nested: plpgsql doesn't short-circuit, and a pitcher_teams row has no coach_id)
  if tg_table_name = 'team_coaches' then
    if exists (select 1 from public.profiles pr join public.teams t on t.id = new.team_id join public.organizations o on o.id = t.org_id
                where pr.id = new.coach_id and pr.account_id = o.manager_login) then
      return new;
    end if;
  end if;
  raise exception 'facility_unverified' using hint = 'The facility manager must verify their email before coaches or pitchers can join.';
end;
$$;
revoke all on function public.r7_facility_verify_gate() from public, anon, authenticated;
create trigger pitcher_teams_r7_verify_gate before insert on public.pitcher_teams
  for each row execute function public.r7_facility_verify_gate();
create trigger team_coaches_r7_verify_gate before insert on public.team_coaches
  for each row execute function public.r7_facility_verify_gate();

create or replace function public.my_facility_needs_verify()
returns boolean language sql stable security definer set search_path to '' as $$
  select exists (
    select 1 from public.organizations o join public.profiles m on m.id = o.manager_login
     where o.manager_login = auth.uid() and o.created_via = 'self_serve' and m.email_verified_at is null);
$$;
revoke all on function public.my_facility_needs_verify() from public, anon;
grant execute on function public.my_facility_needs_verify() to authenticated;

-- (6)
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
  if p_kind not in ('report_email', 'report_generate', 'verify_email', 'guardian_email', 'removal_notice', 'email_change', 'account_deletion', 'account_export', 'facility_notify') then
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
    when 'account_export'  then array['account_export_day']   -- A1
    when 'facility_notify' then array['facility_notify_day'] end;   -- R7 Stage B
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
