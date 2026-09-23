-- U4b Phase 2 -- report eligibility gate now checks TWO things, not one:
-- the pitcher's email is verified, AND they currently have a pitcher_teams
-- row (Joel, Sept 2026: "dual verification is just that you must have
-- verified your email and be on a team. this only applies until we have
-- individual users but for now it all works" -- i.e. this is a deliberate,
-- temporary restriction until solo/team-less pitcher accounts are a
-- supported concept, not a permanent design decision).
--
-- Renaming is_pitcher_verified -> is_pitcher_report_eligible rather than
-- redefining it under the old name, and rather than adding a new function
-- beside it: this repo already hit the exact failure mode of leaving a
-- narrower/stale sibling function around once (see
-- 20260921004607_r0_report_gate_blocks_entire_send.sql dropping
-- pitcher_email_report_blocked for precisely this reason), and a function
-- literally named "is_pitcher_verified" that silently also gates on team
-- membership would be the same trap from the other direction -- a name
-- that no longer says what the function checks. is_pitcher_verified's only
-- caller anywhere in this repo is send-session-report/index.ts (confirmed
-- by grep before writing this), so renaming it is a zero-risk, single-call-site change.

drop function if exists public.is_pitcher_verified(uuid);

create function public.is_pitcher_report_eligible(p_pitcher_id uuid)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select
    coalesce((select email_verified_at is not null from public.profiles where id = p_pitcher_id), false)
    and exists (select 1 from public.pitcher_teams where pitcher_id = p_pitcher_id);
$$;

revoke all on function public.is_pitcher_report_eligible(uuid) from public, anon;
grant execute on function public.is_pitcher_report_eligible(uuid) to authenticated;

-- ---------------------------------------------------------------------------------
-- ROLLBACK (no auto-down; write a new migration with this body if you need to
-- revert). Restores is_pitcher_verified to its pre-this-migration body
-- (email verification only, no team check) and drops the new function:
--
--   create or replace function public.is_pitcher_verified(p_pitcher_id uuid)
--   returns boolean language sql security definer set search_path = ''
--   as $$ select coalesce((select email_verified_at is not null from public.profiles where id = p_pitcher_id), false); $$;
--   revoke all on function public.is_pitcher_verified(uuid) from public, anon;
--   grant execute on function public.is_pitcher_verified(uuid) to authenticated;
--   drop function if exists public.is_pitcher_report_eligible(uuid);
