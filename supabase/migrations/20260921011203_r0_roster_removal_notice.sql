-- R0 follow-up — notify a player by email when a coach removes them from
-- a roster. Caught live during the staging walkthrough: removal itself
-- (window.removeRosterPitcher) was already a plain, unconfirmed delete --
-- CLAUDE.md's own Roster & visibility model already calls for "explicit
-- confirmation" on removal, so that's a compliance gap fixed alongside
-- this in bullpen-tracker.html, not a schema change. This migration is
-- just the server-side support for the notification email Joel asked for
-- on top of that.
--
-- Design: send-removal-notice (new Edge Function, caller's own JWT, no
-- service-role) calls this function BEFORE the client performs the
-- actual delete -- ordering matters, because once the pitcher_teams row
-- is gone there's no remaining way to verify "was this pitcher really on
-- this coach's team" at all. Verifying first means the function can prove
-- both facts that matter (caller really coaches this team; this pitcher
-- really is on it right now) before ever looking up a real email address.
--
-- Deliberately returns the email AND team name together, both looked up
-- server-side -- auth.users.email is never exposed to PostgREST directly,
-- and the team name is authoritative (not whatever string a client
-- payload claims) so the notice text can't be spoofed to say something
-- untrue. Never returns anything if either check fails, rather than a
-- partial or best-guess result.
--
-- The removal delete itself proceeds regardless of whether this call (or
-- the email send after it) succeeds -- a coach removing someone must
-- never be blocked by a Resend hiccup. Best-effort, same pattern as the
-- post-signup verification-email send in join.html.

create or replace function public.get_removal_notice_info(p_pitcher_id uuid, p_team_id uuid)
returns table(email text, team_name text)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_team_coach(p_team_id) then
    raise exception 'not authorized';
  end if;

  if not exists (
    select 1 from public.pitcher_teams
    where pitcher_id = p_pitcher_id and team_id = p_team_id
  ) then
    raise exception 'pitcher is not a member of this team';
  end if;

  return query
    select u.email, t.name
    from auth.users u, public.teams t
    where u.id = p_pitcher_id and t.id = p_team_id;
end;
$$;

revoke all on function public.get_removal_notice_info(uuid, uuid) from public, anon;
grant execute on function public.get_removal_notice_info(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------------
-- ROLLBACK (no auto-down; write a new migration with this body if you need to
-- revert):
--
--   drop function if exists public.get_removal_notice_info(uuid, uuid);
--
--   -- Also revert bullpen-tracker.html's removeRosterPitcher to skip the
--   -- send-removal-notice call, and remove/undeploy that Edge Function.
-- ---------------------------------------------------------------------------------
