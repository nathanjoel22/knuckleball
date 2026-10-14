-- A1 (Oct 14 2026): rate_limit_take() accepts the two A1 kinds -- account_deletion (an email: per-user 5/day,
-- the per-recipient limit and the circuit breaker) and account_export (a download, 3/day, not an email). Otherwise
-- identical to the live H1 function.
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
