-- U2a — Batter side: tappable silhouette, stored on every pitch.
--
-- Joel's decision (Sept 9 2026): batter side is capture-once data -- a pen
-- charted without it can never be split by handedness later. This column
-- is NULLABLE with NO DEFAULT, deliberately: legacy rows genuinely have no
-- recorded side (nobody observed it), and a default would silently label
-- historical pitches with a handedness that was never actually charted.
-- Every NEW pitch always writes a real 'R' or 'L' value from the client;
-- NULL only ever appears on rows written before this migration.
--
-- Rights are unchanged from current RLS: the existing policies on
-- public.pitches key off session ownership (pitcher_id / team-coach via
-- sessions), not specific columns, so this plain column addition needs no
-- policy change.
--
-- ---------------------------------------------------------------------------------
-- ROLLBACK (no auto-down; write a new migration with this body if you need to
-- revert):
--
--   alter table public.pitches
--     drop constraint if exists pitches_batter_side_check,
--     drop column if exists batter_side;
--
--   WARNING: this destroys captured handedness data permanently for any
--   pitch charted after this migration and before the rollback. Take the
--   pre-deploy backup seriously (BACKUPS.md) -- this is the one part of
--   this packet that is not freely reversible.
-- ---------------------------------------------------------------------------------


-- ============================================================================
-- Columns
-- ============================================================================

alter table public.pitches
  add column batter_side text;

alter table public.pitches
  add constraint pitches_batter_side_check
  check (batter_side is null or batter_side in ('R', 'L'));
