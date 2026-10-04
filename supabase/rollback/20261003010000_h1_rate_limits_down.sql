-- Down migration for 20261003010000_h1_rate_limits.sql. Redeploy the Edge Functions from before
-- H1 first (they call rate_limit_take and would fail closed without it).
drop function if exists public.rate_limit_take(uuid, text, text[], integer);
drop function if exists public.rate_limit_refusal(text, timestamptz);
drop table if exists public.rate_limit_events;
drop table if exists public.rate_limit_config;
