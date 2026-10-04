-- H1 Part 2 (P1-06): limits on every function that sends email or writes a report file.
-- One config table (tunable without a deploy) and one event log, neither visible to clients.
-- The Edge Functions call rate_limit_take() with the SERVICE ROLE, passing the caller's
-- verified user id -- a client can't call it, so nobody can burn another person's allowance
-- or trip the daily circuit breaker without actually sending.
-- Rollback: supabase/rollback/20261003010000_h1_rate_limits_down.sql

create table public.rate_limit_config (
  key            text primary key,
  window_seconds integer not null check (window_seconds > 0),
  max_count      integer not null check (max_count >= 0),
  note           text
);
create table public.rate_limit_events (
  id        bigint generated always as identity primary key,
  kind      text not null,          -- a send ('report_email', ...) or 'to' (one row per recipient)
  actor     uuid,                   -- the login that asked
  recipient text,                   -- lowercase address, on 'to' rows
  via       text,                   -- on 'to' rows: which kind of send
  at        timestamptz not null default now()
);
create index rate_limit_events_actor on public.rate_limit_events (kind, actor, at);
create index rate_limit_events_recipient on public.rate_limit_events (recipient, at) where recipient is not null;
create index rate_limit_events_at on public.rate_limit_events (at);

alter table public.rate_limit_config enable row level security;   -- no policies: clients get nothing
alter table public.rate_limit_events enable row level security;
revoke all on public.rate_limit_config from anon, authenticated;
revoke all on public.rate_limit_events from anon, authenticated;

insert into public.rate_limit_config (key, window_seconds, max_count, note) values
  ('report_email_hour',    3600,  40,  'report emails sent per user per hour'),
  ('report_email_day',     86400, 150, 'report emails sent per user per day'),
  ('report_generate_hour', 3600,  60,  'reports generated without emailing, per user per hour'),
  ('verify_email_hour',    3600,  5,   'verification emails per user per hour'),
  ('guardian_email_day',   86400, 3,   'guardian approval emails per account per day (on top of the 10-minute rule)'),
  ('removal_notice_day',   86400, 20,  'removal notices per user per day'),
  ('email_change_day',     86400, 5,   'Change Email requests per user per day (on top of the 10-minute rule)'),
  ('recipient_day',        86400, 20,  'Knuckleball emails of any kind to one address per day'),
  ('verify_recipient_day', 86400, 10,  'verification emails to one address per day');

-- Check every limit for one send and, if all pass, record it. Returns
--   { ok: true, alert: bool }  or  { ok: false, error: 'rate_limited', limit, retry_at, message }.
-- p_global_cap: 90% of the Resend plan's daily quota (from the function's env var). When the
-- day's email count reaches it, every email send refuses; 'alert' is true exactly once a day so
-- the function can email Joel.
create or replace function public.rate_limit_take(p_actor uuid, p_kind text, p_recipients text[] default '{}', p_global_cap integer default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rcpts  text[] := coalesce((select array_agg(distinct lower(btrim(r))) from unnest(coalesce(p_recipients, '{}')) r
                               where btrim(coalesce(r, '')) <> ''), '{}');
  v_email  boolean := p_kind <> 'report_generate';
  v_cfg    public.rate_limit_config%rowtype;
  v_n      integer;
  v_oldest timestamptz;
  v_r      text;
  v_alert  boolean := false;
  v_keys   text[];
  v_k      text;
begin
  if p_kind not in ('report_email', 'report_generate', 'verify_email', 'guardian_email', 'removal_notice', 'email_change') then
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
    when 'email_change'    then array['email_change_day'] end;
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
$$;

create or replace function public.rate_limit_refusal(p_key text, p_retry_at timestamptz)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object('ok', false, 'error', 'rate_limited', 'limit', p_key, 'retry_at', p_retry_at,
    'message', case p_key
      when 'report_email_hour'    then 'You''ve sent a lot of reports in the last hour.'
      when 'report_email_day'     then 'You''ve reached today''s limit for emailing reports.'
      when 'report_generate_hour' then 'You''ve generated a lot of reports in the last hour.'
      when 'verify_email_hour'    then 'Too many verification emails in the last hour.'
      when 'verify_recipient_day' then 'That address has been sent a lot of verification emails today.'
      when 'guardian_email_day'   then 'The parent or guardian email has been sent the most times allowed today.'
      when 'removal_notice_day'   then 'You''ve sent the most removal notices allowed today.'
      when 'email_change_day'     then 'You''ve asked to change your email the most times allowed today.'
      when 'recipient_day'        then 'One of these addresses has received a lot of Knuckleball email today.'
      when 'global_day'           then 'Knuckleball has reached its email limit for today. Reports can still be generated and viewed; emails will work again tomorrow.'
      else 'Too many requests.' end
    || case when p_key = 'global_day' then '' else
         ' Try again in ' || case
           when p_retry_at - now() < interval '1 minute' then 'a minute'
           when p_retry_at - now() < interval '90 minutes' then ceil(extract(epoch from (p_retry_at - now())) / 60)::int || ' minutes'
           else ceil(extract(epoch from (p_retry_at - now())) / 3600)::int || ' hours' end || '.' end);
$$;

revoke all on function public.rate_limit_take(uuid, text, text[], integer) from public, anon, authenticated;
grant execute on function public.rate_limit_take(uuid, text, text[], integer) to service_role;
revoke all on function public.rate_limit_refusal(text, timestamptz) from public, anon, authenticated;
grant execute on function public.rate_limit_refusal(text, timestamptz) to service_role;
