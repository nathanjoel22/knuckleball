-- P1-15 — Delete a saved session, with a tombstone.
--
-- Joel's decision (Aug 28 2026): a saved session's pitch data is final for
-- everyone once "End session & save" is pressed. Deletion stays available (a
-- junk warmup pen should not pollute trend charts) but must leave a trace.
--
-- Deleting a saved session SOFT-deletes the session row (deleted_at + who/when
-- + a pitch_count snapshot) and HARD-deletes its pitches -- the pitch data is
-- genuinely gone. The client excludes soft-deleted sessions from every
-- calculation (stats, trends, reports) and renders a tombstone row in history.
--
-- Rights are unchanged from current RLS: a pitcher deletes their own sessions,
-- a coach deletes sessions on their team. The FOR ALL policies on
-- public.sessions / public.pitches already permit the UPDATE + DELETE this
-- does; no policy change. Track R (R5) later narrows the coach to
-- recording-team-only.
--
-- ---------------------------------------------------------------------------------
-- ROLLBACK (no auto-down; write a new migration with this body if you need to
-- revert):
--
--   -- FIRST: soft-deleted sessions have no pitch rows left. Once deleted_at is
--   -- dropped they reappear in history as empty (0-pitch) sessions. List them
--   --   select id, pitcher_id, team_id, pitch_count, deleted_by_role
--   --   from public.sessions where deleted_at is not null;
--   -- and decide per row whether to hard-delete:
--   --   delete from public.sessions where id in (...);
--
--   drop function if exists public.delete_session(uuid);
--   alter table public.sessions
--     drop constraint if exists sessions_deletion_check,
--     drop column if exists deleted_at,
--     drop column if exists deleted_by,
--     drop column if exists deleted_by_role,
--     drop column if exists pitch_count;
-- ---------------------------------------------------------------------------------


-- ============================================================================
-- Columns
-- ============================================================================

alter table public.sessions
  add column deleted_at      timestamptz,
  add column deleted_by      uuid references auth.users(id),
  add column deleted_by_role text,
  add column pitch_count     integer;

comment on column public.sessions.pitch_count is
  'Pitch-count snapshot taken at soft-delete time; NULL for live sessions (count them from public.pitches).';

-- A tombstone is all-or-nothing: either the session is live (all deletion
-- fields NULL) or it is fully attributed.
alter table public.sessions
  add constraint sessions_deletion_check check (
    deleted_at is null
    or (
      deleted_by is not null
      and deleted_by_role in ('pitcher', 'coach')
      and pitch_count is not null
      and pitch_count >= 0
    )
  );


-- ============================================================================
-- public.delete_session(session_id) -> jsonb
-- Atomic: mark the session, snapshot the count, purge the pitches, one txn.
-- SECURITY INVOKER so the caller's own RLS on sessions/pitches still gates
-- every statement -- this cannot touch a session the caller isn't entitled to.
-- The explicit check is for a clear error and to record which hat the caller
-- wore (pitcher deleting own vs coach deleting a team session).
-- ============================================================================

create or replace function public.delete_session(p_session_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_pitcher uuid;
  v_team    uuid;
  v_role    text;
  v_count   integer;
begin
  if v_uid is null then
    return jsonb_build_object('error', 'not authenticated');
  end if;

  -- RLS on this SELECT: a pitcher sees own sessions, a coach sees their team's.
  select pitcher_id, team_id into v_pitcher, v_team
  from public.sessions
  where id = p_session_id and deleted_at is null;
  if not found then
    return jsonb_build_object('error', 'session not found or already deleted');
  end if;

  if v_pitcher = v_uid then
    v_role := 'pitcher';
  elsif exists (select 1 from public.teams t where t.id = v_team and t.coach_id = v_uid) then
    v_role := 'coach';
  else
    return jsonb_build_object('error', 'not entitled to delete this session');
  end if;

  select count(*) into v_count from public.pitches where session_id = p_session_id;

  update public.sessions
     set deleted_at      = now(),
         deleted_by      = v_uid,
         deleted_by_role = v_role,
         pitch_count     = v_count
   where id = p_session_id;

  delete from public.pitches where session_id = p_session_id;

  return jsonb_build_object('ok', true, 'pitch_count', v_count, 'deleted_by_role', v_role);
end;
$$;

revoke all     on function public.delete_session(uuid) from public, anon;
grant  execute on function public.delete_session(uuid) to authenticated;
