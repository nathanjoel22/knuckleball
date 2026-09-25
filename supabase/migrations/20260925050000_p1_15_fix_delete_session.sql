-- P1-15 follow-up -- precondition report (Sept 25 2026) found delete_session()
-- silently regressed when R6 rewrote it to add the head-only check: the
-- `delete from public.pitches where session_id = p_session_id;` line from the
-- original build (20260828164805) was dropped in the rewrite
-- (20260925000000_r6_coaching_staffs.sql). Since then, "deleting" a session
-- has correctly written the tombstone fields but left every pitch row (and
-- any leaderboard_exclusions row pointing at one) fully intact in the
-- database -- invisible in the app only because the client filters
-- deletedAt sessions out of state.sessions and the leaderboard filters
-- deleted_at is null, not because the data was actually gone. This
-- migration restores the hard-delete, repairs any damage already done, and
-- adds what P1-15's UI needs to attribute a tombstone by name (Approach d).
--
-- Also, per the precondition report: report-file cleanup on delete is
-- handled in the send-session-report Edge Function (a `deleteReport`
-- action added in this same change), not in SQL -- the `reports` bucket has
-- no policy of any kind on storage.objects (confirmed empirically), so
-- removing an object can only happen with the service-role key.
--
-- ---------------------------------------------------------------------------------
-- ROLLBACK (no auto-down; write a new migration with this body if you need to
-- revert):
--
--   alter table public.sessions drop column if exists deleted_by_name;
--
--   -- Restores the R6 body (still missing the pitches delete -- that
--   -- regression predates this migration and would return if rolled back):
--   create or replace function public.delete_session(p_session_id uuid)
--   returns jsonb
--   language plpgsql security definer set search_path = ''
--   as $$
--   declare
--     v_uid uuid := auth.uid(); v_pitcher uuid; v_team uuid; v_role text; v_count integer;
--   begin
--     if v_uid is null then return jsonb_build_object('error', 'not authenticated'); end if;
--     select pitcher_id, team_id into v_pitcher, v_team from public.sessions
--       where id = p_session_id and deleted_at is null;
--     if not found then return jsonb_build_object('error', 'session not found or already deleted'); end if;
--     if v_pitcher = v_uid then v_role := 'pitcher';
--     elsif public.is_team_head(v_team) then v_role := 'coach';
--     else return jsonb_build_object('error', 'not entitled to delete this session'); end if;
--     select count(*) into v_count from public.pitches where session_id = p_session_id;
--     update public.sessions set deleted_at = now(), deleted_by = v_uid,
--       deleted_by_role = v_role, pitch_count = v_count where id = p_session_id;
--     return jsonb_build_object('ok', true);
--   end;
--   $$;
-- ---------------------------------------------------------------------------------


-- ============================================================================
-- Column: attribution snapshot for the tombstone UI.
-- ============================================================================
--
-- Not fetched via a PostgREST embed at read time -- sessions.deleted_by
-- references auth.users(id), not profiles(id) (same as pitcher_id and
-- logged_by already do), so there's no FK PostgREST can walk to profiles
-- directly, and adding one just for this would be a bigger change than the
-- display need justifies. A pitcher also has no RLS grant to read a coach's
-- profiles row today (only coach-views-coach and coach-views-pitcher exist),
-- so a live join would need a new cross-role policy. Snapshotting the name
-- at the moment of deletion avoids both: delete_session runs as the caller,
-- reading the CALLER's OWN profiles row, which they can always read
-- regardless of any policy. Same reasoning as the existing pitch_count
-- snapshot -- the tombstone is a record of what happened, not a live view.
alter table public.sessions
  add column deleted_by_name text;

comment on column public.sessions.deleted_by_name is
  'Snapshot of profiles.full_name for deleted_by, taken at soft-delete time by delete_session(). NULL for live sessions and for any session deleted before this column existed.';


-- ============================================================================
-- Repair: any session already soft-deleted (since R6 shipped, or by the
-- original Aug 28 version -- this is idempotent either way) that still has
-- pitch rows sitting under it. A correctly-deleted session already has zero,
-- so this only touches the gap window. leaderboard_exclusions cascades from
-- the FK already in place.
-- ============================================================================

delete from public.pitches
 where session_id in (select id from public.sessions where deleted_at is not null);


-- ============================================================================
-- public.delete_session(p_session_id) -> jsonb
-- Restores the hard pitch-delete, adds the name snapshot, and returns
-- report_path so the client can ask send-session-report's new deleteReport
-- action to remove the stored file -- this function has no service-role
-- access itself and was never going to touch Storage directly.
-- ============================================================================

create or replace function public.delete_session(p_session_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_pitcher uuid;
  v_team    uuid;
  v_role    text;
  v_count   integer;
  v_name    text;
  v_report  text;
begin
  if v_uid is null then
    return jsonb_build_object('error', 'not authenticated');
  end if;

  select pitcher_id, team_id, report_path into v_pitcher, v_team, v_report
  from public.sessions
  where id = p_session_id and deleted_at is null;
  if not found then
    return jsonb_build_object('error', 'session not found or already deleted');
  end if;

  if v_pitcher = v_uid then
    v_role := 'pitcher';
  elsif public.is_team_head(v_team) then
    v_role := 'coach';
  else
    return jsonb_build_object('error', 'not entitled to delete this session');
  end if;

  select full_name into v_name from public.profiles where id = v_uid;

  select count(*) into v_count from public.pitches where session_id = p_session_id;

  update public.sessions
     set deleted_at      = now(),
         deleted_by      = v_uid,
         deleted_by_role = v_role,
         deleted_by_name = v_name,
         pitch_count     = v_count
   where id = p_session_id;

  delete from public.pitches where session_id = p_session_id;

  return jsonb_build_object('ok', true, 'report_path', v_report);
end;
$$;

-- Grants unchanged (already authenticated-only, revoked from public/anon
-- since the original migration; create or replace doesn't reset a
-- function's ACL).
