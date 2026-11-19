-- Rollback for 20261124000000_sr1b_baselines.sql (SR1 Stage B). The two functions are new and nothing stores their
-- output, so dropping them is the whole rollback. (After Stage C, the report function calls session_baselines: roll
-- Stage C back first.)
drop function if exists public.session_baselines(uuid);
drop function if exists public.sr1_session_level(uuid);
