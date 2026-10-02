-- Email change acceptance, part 2 of 2 (database side). Rolled back. Run as
--   cat supabase/tests/email_change_setup.sql supabase/migrations/20261002070000_email_change.sql \
--       supabase/tests/email_change_acceptance.sql > /tmp/x.sql
--   supabase db query --linked --project-ref <staging> -f /tmp/x.sql
-- Supabase's half (the click applying the change) is simulated on auth.users.
do $$
declare
  X uuid := 'aaaaaaaa-0000-4000-8000-0000000000c1';  -- verified pitcher who changes email
  Y uuid := 'aaaaaaaa-0000-4000-8000-0000000000c2';  -- unverified, holds a verify link
  L uuid := 'aaaaaaaa-0000-4000-8000-0000000000c3';  -- link from before the migration
  out text := ''; r jsonb; c int; v text; tok text; kid uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at) values
    (X, '00000000-0000-0000-0000-000000000000','authenticated','authenticated','ec-old@example.invalid','{}', now(), now()),
    (Y, '00000000-0000-0000-0000-000000000000','authenticated','authenticated','ec-y-old@example.invalid','{}', now(), now());
  insert into public.profiles (id, role, full_name, sport, email_verified_at, age_attestation, attested_at, attested_via, terms_version, contact_emails) values
    (X, 'pitcher', 'Xena Change', 'baseball', '2026-09-01', 'adult', now(), 'signup', '2026-10-03', '{"pitcher":"ec-old@example.invalid","coach":"coach@example.invalid"}'),
    (Y, 'pitcher', 'Yuri Unverified', 'baseball', null, null, null, null, null, '{}');

  out := 'backfill: legacy link bound to ' || (select email_verify_sent_to from public.profiles where id = L);

  perform set_config('request.jwt.claims', json_build_object('sub', X, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.add_player('Kid Change', 'baseball', 'R', true); kid := (r->>'id')::uuid;
  r := public.begin_email_change('not an email'); out := out || ' | 1 bad: ' || (r->>'error');
  r := public.begin_email_change('EC-Old@example.invalid'); out := out || ', same: ' || (r->>'error');
  r := public.begin_email_change(' EC-New@Example.invalid '); out := out || ', begin: ' || (r->>'ok') || ' new=' || (r->>'new_email');
  r := public.begin_email_change('ec-other@example.invalid'); out := out || ' | 2 again: ' || (r->>'error') || ' (' || (r->>'retry_after_seconds') || 's)';
  begin select email_change_requested into v from public.profiles where id = X; out := out || ' | 8 reads request: ALLOWED (BAD)';
  exception when others then out := out || ' | 8 client reads request column: refused'; end;
  begin update public.profiles set email_verified_at = now() where id = X; get diagnostics c = row_count; out := out || ', client sets verified: ' || c || ' rows (BAD)';
  exception when others then out := out || ', client sets verified: refused'; end;
  execute 'reset role';
  out := out || ' | pending: still verified=' || (select (email_verified_at is not null) || ' requested=' || email_change_requested || ' from=' || email_change_from from public.profiles where id = X);

  -- 3. Supabase still waiting (link not clicked / secure change on)
  update auth.users set email_change = 'ec-new@example.invalid' where id = X;
  perform set_config('request.jwt.claims', json_build_object('sub', X, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.confirm_email_change(); out := out || ' | 3 before click: ' || (r->>'error');
  execute 'reset role';
  -- 4. the click applies it
  update public.profiles set email_verified_at = null where id = X;   -- prove confirm is what sets it
  update auth.users set email = 'ec-new@example.invalid', email_change = '' where id = X;
  perform set_config('request.jwt.claims', json_build_object('sub', X, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.confirm_email_change(); out := out || ' | 4 after click: ' || (r->>'ok') || ' email=' || (r->>'email');
  r := public.confirm_email_change(); out := out || ' | 5 reused: ' || (r->>'error');
  execute 'reset role';
  out := out || ', db: verified=' || (select (email_verified_at > now() - interval '1 minute') || ' request cleared=' || (email_change_requested is null)
         || ' reports to=' || (contact_emails->>'pitcher') || ' coach kept=' || (contact_emails->>'coach') from public.profiles where id = X)
         || ', player reports to=' || (select contact_emails->>'pitcher' from public.profiles where id = kid);

  -- 6. mismatch: the login ended up on a different address than requested
  update public.profiles set email_change_requested_at = now() - interval '11 minutes' where id = X;
  perform set_config('request.jwt.claims', json_build_object('sub', X, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.begin_email_change('ec-third@example.invalid');
  execute 'reset role';
  update auth.users set email = 'ec-somewhere-else@example.invalid' where id = X;
  perform set_config('request.jwt.claims', json_build_object('sub', X, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.confirm_email_change(); out := out || ' | 6 different address: ' || (r->>'error');
  -- 10. abandon
  perform public.abandon_email_change();
  execute 'reset role';
  out := out || ' | 10 abandon cleared: ' || (select email_change_requested is null and email_change_requested_at is null from public.profiles where id = X);

  -- 7. verify links are tied to the address they went to
  perform set_config('request.jwt.claims', json_build_object('sub', Y, 'role','authenticated')::text, true); execute 'set local role authenticated';
  tok := public.generate_email_verify_token();
  execute 'reset role';
  out := out || ' | 7 link sent to ' || (select email_verify_sent_to from public.profiles where id = Y);
  update auth.users set email = 'ec-y-new@example.invalid' where id = Y;
  execute 'set local role anon';
  r := public.verify_email(tok); out := out || ', redeemed after address changed: ' || coalesce(r->>'error', 'VERIFIED (BAD)');
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', Y, 'role','authenticated')::text, true); execute 'set local role authenticated';
  tok := public.generate_email_verify_token();
  execute 'reset role';
  execute 'set local role anon';
  r := public.verify_email(tok); out := out || ', fresh link to the new address: ' || (r->>'ok');
  r := public.verify_email(tok); out := out || ', reused: ' || (r->>'error');
  -- legacy link: valid while the address is unchanged
  r := public.verify_email(repeat('ab', 32)); out := out || ' | legacy link, address unchanged: ' || coalesce(r->>'ok', r->>'error');
  -- 9. anon can't start or confirm a change
  begin r := public.begin_email_change('x@example.invalid'); out := out || ' | 9 anon begin: ALLOWED (BAD)';
  exception when others then out := out || ' | 9 anon begin: refused'; end;
  begin r := public.confirm_email_change(); out := out || ', anon confirm: ALLOWED (BAD)';
  exception when others then out := out || ', anon confirm: refused'; end;
  execute 'reset role';
  out := out || ' | Y verified now: ' || (select email_verified_at is not null from public.profiles where id = Y);

  raise exception 'RESULTS(rolled back):%', out;
end $$;
