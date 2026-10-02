-- Security fix (Joel, Oct 2 2026): two secret columns were readable by
-- people who must never see them. Found during the P1-10 precondition
-- report; confirmed on staging (real personas) and production (read-only).
--
--  1. teams.invite_token and teams.coach_invite_token were readable by every
--     member of the team (the "Pitchers view teams they belong to" and
--     coaches' read policies cover the whole row). R6 meant to column-revoke
--     them; the table-level SELECT grant was still in place, so the revoke
--     never took effect. A pitcher could read the COACH invite token and join
--     his own team as an assistant coach under a second login.
--  2. profiles.email_verify_token was readable by a pitcher's coaches ("Coaches
--     view their pitchers' profiles"), letting a coach verify a pitcher's email
--     without the pitcher -- defeating the report gate's verification check.
--
-- Fix: replace the table-level SELECT grant with an explicit column list that
-- leaves the secrets out. Rows are still governed by the same RLS policies
-- (unchanged, count 35); this only removes columns. The secrets stay
-- reachable through the SECURITY DEFINER functions built for them
-- (get_team_invite_links for the head coach; generate_email_verify_token /
-- verify_email / send-verification-email). Safe by default from here on: a
-- NEW column on either table is unreadable by clients until a migration
-- grants it.
--
-- Rollback:
--   grant select on public.profiles to authenticated;
--   grant select on public.teams to authenticated, anon;

revoke select on public.profiles from anon, authenticated;
grant select (
  id, account_id, is_primary, managed_by, role, sport, full_name, pitch_types, created_at,
  contact_emails, email_verified_at, email_verify_token_sent_at, throws, relative_accuracy_enabled,
  uses_radar_gun, setup_dismissed_at, headshot_updated_at
) on public.profiles to authenticated;

revoke select on public.teams from anon, authenticated;
grant select (
  id, coach_id, name, created_at, invite_token_rotated_at, coach_invite_token_rotated_at, sport, level
) on public.teams to anon, authenticated;
