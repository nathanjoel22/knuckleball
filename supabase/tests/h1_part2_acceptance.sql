-- H1 Part 2 acceptance (database side): limits scripted against rate_limit_take(), called the
-- way the Edge Functions call it (service role). Rolled back. Run after (or with) the migration.
do $$
declare
  C  uuid := 'aaaaaaaa-0000-4000-8000-0000000000e1';   -- a coach sending reports
  U  uuid := 'aaaaaaaa-0000-4000-8000-0000000000e2';   -- a pitcher
  r jsonb; i int; n int; out text := ''; first_refusal int; v text;
begin
  execute 'set local role service_role';
  -- 5. report emails: 40 per hour per user
  first_refusal := null;
  for i in 1..41 loop
    r := public.rate_limit_take(C, 'report_email', array['player' || i || '@example.invalid'], 1000);
    if not (r->>'ok')::boolean and first_refusal is null then first_refusal := i; out := out || '5. report email #' || i || ': ' || (r->>'message'); end if;
  end loop;
  execute 'reset role';
  update public.rate_limit_events set at = at - interval '61 minutes' where actor = C and kind = 'report_email';   -- the hour passes
  execute 'set local role service_role';
  r := public.rate_limit_take(C, 'report_email', array['player99@example.invalid'], 1000);
  out := out || ' | after the hour: ' || (r->>'ok');
  -- generating without emailing doesn't count against email limits
  r := public.rate_limit_take(C, 'report_generate', '{}', null);
  out := out || ' | generate-only while near email limits: ' || (r->>'ok');
  -- 21st email to one address in a day (any kind)
  first_refusal := null;
  for i in 1..21 loop
    r := public.rate_limit_take(U, case when i % 2 = 0 then 'report_email' else 'removal_notice' end, array['Mom@Example.invalid'], 1000);
    if not (r->>'ok')::boolean and first_refusal is null then first_refusal := i; out := out || ' | email #' || i || ' to one address today: ' || (r->>'message'); end if;
  end loop;
  -- 6. verification: 5 per hour per user; 10 per day to one address
  first_refusal := null;
  for i in 1..6 loop
    r := public.rate_limit_take(U, 'verify_email', array['u-own@example.invalid'], 1000);
    if not (r->>'ok')::boolean and first_refusal is null then first_refusal := i; out := out || ' | 6. verification #' || i || ' this hour: ' || (r->>'message'); end if;
  end loop;
  execute 'reset role';
  update public.rate_limit_events set at = at - interval '61 minutes' where actor = U and kind in ('verify_email');
  execute 'set local role service_role';
  r := public.rate_limit_take(U, 'verify_email', array['u-own@example.invalid'], 1000); out := out || ', after the hour: ' || (r->>'ok');
  first_refusal := null;
  for i in 1..12 loop
    r := public.rate_limit_take(gen_random_uuid(), 'verify_email', array['shared@example.invalid'], 1000);
    if not (r->>'ok')::boolean and first_refusal is null then first_refusal := i; out := out || ', verification #' || i || ' to one address today (different users): ' || (r->>'limit'); end if;
  end loop;
  -- guardian: 3 per day per account
  first_refusal := null;
  for i in 1..4 loop
    r := public.rate_limit_take(U, 'guardian_email', array['guardian-' || i || '@example.invalid'], 1000);
    if not (r->>'ok')::boolean and first_refusal is null then first_refusal := i; out := out || ' | guardian #' || i || ' today: ' || (r->>'message'); end if;
  end loop;
  -- removal notices 20/day, email changes 5/day
  first_refusal := null;
  for i in 1..6 loop
    r := public.rate_limit_take(C, 'email_change', array['new' || i || '@example.invalid'], 1000);
    if not (r->>'ok')::boolean and first_refusal is null then first_refusal := i; out := out || ' | email change #' || i || ' today: refused'; end if;
  end loop;
  execute 'reset role';
  delete from public.rate_limit_events;

  -- 8. a normal day: one coach, 15 pens, each report to the pitcher + the coach + a parent, plus a game report
  execute 'set local role service_role';
  n := 0;
  for i in 1..15 loop
    r := public.rate_limit_take(C, 'report_email', array['p' || i || '@example.invalid', 'coach@example.invalid', 'parent' || i || '@example.invalid'], 90);
    if not (r->>'ok')::boolean then n := n + 1; end if;
  end loop;
  r := public.rate_limit_take(C, 'report_email', array['p1@example.invalid', 'coach@example.invalid'], 90); if not (r->>'ok')::boolean then n := n + 1; end if;
  for i in 1..15 loop r := public.rate_limit_take(C, 'report_generate', '{}', null); if not (r->>'ok')::boolean then n := n + 1; end if; end loop;
  out := out || ' | 8. normal day (16 report emails, 47 recipients, 15 views): refusals=' || n;
  execute 'reset role';
  delete from public.rate_limit_events;

  -- 7. circuit breaker with a low cap: refuses, alert exactly once
  execute 'set local role service_role';
  for i in 1..5 loop
    r := public.rate_limit_take(gen_random_uuid(), 'verify_email', array['b' || i || '@example.invalid'], 3);
    out := out || case when i = 1 then ' | 7. breaker cap 3: ' else ', ' end || '#' || i || '=' || case when (r->>'ok')::boolean then 'sent' else 'refused(alert=' || (r->>'alert') || ')' end;
  end loop;
  r := public.rate_limit_take(gen_random_uuid(), 'report_generate', '{}', null);
  out := out || ' | generate-only while the breaker is tripped: ' || (r->>'ok');
  out := out || ' | breaker message: ' || (public.rate_limit_take(gen_random_uuid(), 'report_email', array['z@example.invalid'], 3) ->> 'message');
  execute 'reset role';

  -- 9. clients can't touch the tables or the function
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub', U, 'role','authenticated')::text, true);
  begin select count(*) into n from public.rate_limit_events; out := out || ' | 9. client select events: ALLOWED (BAD)'; exception when others then out := out || ' | 9. client select events: refused'; end;
  begin insert into public.rate_limit_events (kind) values ('x'); out := out || ', insert: ALLOWED (BAD)'; exception when others then out := out || ', insert: refused'; end;
  begin select count(*) into n from public.rate_limit_config; out := out || ', select config: ALLOWED (BAD)'; exception when others then out := out || ', select config: refused'; end;
  begin r := public.rate_limit_take(U, 'verify_email', '{}', 1000); out := out || ', call rate_limit_take: ALLOWED (BAD)'; exception when others then out := out || ', call rate_limit_take: refused'; end;
  execute 'reset role';
  execute 'set local role anon';
  begin select count(*) into n from public.rate_limit_events; out := out || ', anon select: ALLOWED (BAD)'; exception when others then out := out || ', anon select: refused'; end;
  execute 'reset role';
  raise exception 'RESULTS(rolled back):%', out;
end $$;
