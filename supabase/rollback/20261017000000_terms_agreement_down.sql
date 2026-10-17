-- Down for 20261017000000_terms_agreement.sql. Drops the agreement timestamps (terms_version stays).
drop function if exists public.agree_to_terms(text);
alter table public.profiles drop column if exists terms_agreed_at;
