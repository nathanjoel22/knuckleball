-- Rollback of 20261028000000_sc1_session_stats: the trigger, the three functions and the two tables (the stats rows and
-- the failure log are lost; nothing else held them). No existing table, function or policy was changed by SC1, so
-- nothing is restored. Policies 30 -> 29.

drop trigger if exists sessions_sc1_stats on public.sessions;
drop function if exists public.sc1_session_stats_trigger();
drop function if exists public.sc1_try_finalize(uuid);
drop function if exists public.finalize_session_stats(uuid);
drop table if exists public.session_stats_failures;
drop table if exists public.session_stats;
