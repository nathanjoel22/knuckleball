-- U5 -- Charting perspective: ask at session start, normalize at capture.
--
-- Bullpens are typically charted from behind the PITCHER; games are charted
-- from behind the PLATE. Those two views are horizontal mirrors of each
-- other, and until now the app silently assumed catcher's-eye view for
-- every tap -- a session charted from behind the pitcher stored every pitch
-- mirrored, invisibly, because totals/strike%/accuracy% are unaffected by a
-- column mirror.
--
-- charting_perspective records where the charter physically stood for a
-- given session. It does NOT change how stored coordinates are interpreted
-- downstream: bullpen-tracker.html normalizes at the moment of capture (the
-- one place a tap becomes a stored pitch), mirroring the column index once
-- when charting_perspective is 'behind_pitcher' so pitches.actual_col /
-- target_col are ALWAYS in the catcher's frame regardless of this column's
-- value. This column exists so the app knows which transform to apply when
-- re-deriving screen positions for the charter currently looking at the
-- device (the live relative-accuracy glow, the in-session pitch log) -- it
-- is not read by history/heat-map rendering, the accuracy logic, or the
-- emailed report, all of which operate on already-canonical coordinates and
-- need no perspective awareness at all.
--
-- CONFIRMED by Joel (Sept 8 2026): every session charted to date, staging
-- and production, was charted from behind the catcher -- the default below
-- is what keeps every existing row correct with no backfill.
--
-- Rights are unchanged from current RLS: the existing FOR ALL policies on
-- public.sessions key off pitcher_id / team-coach ownership, not specific
-- columns, so this plain column addition needs no policy change.
--
-- ---------------------------------------------------------------------------------
-- ROLLBACK (no auto-down; write a new migration with this body if you need to
-- revert):
--
--   alter table public.sessions
--     drop constraint if exists sessions_charting_perspective_check,
--     drop column if exists charting_perspective;
--
--   Any session charted behind-the-pitcher before a rollback keeps its
--   already-normalized (catcher-frame) pitch coordinates -- normalization
--   happens once, at capture, in the client, and is never undone by
--   removing this column.
-- ---------------------------------------------------------------------------------


-- ============================================================================
-- Columns
-- ============================================================================

alter table public.sessions
  add column charting_perspective text not null default 'behind_catcher';

alter table public.sessions
  add constraint sessions_charting_perspective_check
  check (charting_perspective in ('behind_catcher', 'behind_pitcher'));
