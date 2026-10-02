-- Email change acceptance, part 1 of 2: a login with an OUTSTANDING verify link
-- from before the migration (run BEFORE 20261002070000_email_change.sql, same transaction).
insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at) values
  ('aaaaaaaa-0000-4000-8000-0000000000c3', '00000000-0000-0000-0000-000000000000','authenticated','authenticated','ec-legacy@example.invalid','{}', now(), now());
insert into public.profiles (id, role, full_name, sport, email_verify_token, email_verify_token_sent_at)
  values ('aaaaaaaa-0000-4000-8000-0000000000c3', 'pitcher', 'Lee Legacy', 'baseball', repeat('ab', 32), now());
