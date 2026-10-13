-- Undo 20261012000000_live_game_intent: game pitches go back to having no target.
-- This REFUSES (the add constraint fails) if any game pitch was saved with an intended spot -- those rows would have
-- to be dealt with first (and that is saved pitch data, which is immutable; ask Joel). Check first:
--   select count(*) from public.pitches where kind = 'game' and target_row is not null;
alter table public.pitches drop constraint pitches_target_matches_kind;
alter table public.pitches add constraint pitches_target_matches_kind check (
  (kind = 'bullpen' and target_row is not null and target_col is not null)
  or
  (kind = 'game' and target_row is null and target_col is null)
);
