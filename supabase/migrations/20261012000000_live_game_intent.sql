-- Live Game intent (Joel, Oct 12 2026).
-- With "Turn on Intent?" answered Yes at the start of a Live Game, the charter taps where the pitch was called
-- (from PitchCom, game-day watches, GoRout, ...) and then where it went -- so a game pitch may now carry a target,
-- exactly like a bullpen pitch. Without Intent a game pitch still has no target.
--
-- G1's pitches_target_matches_kind required game pitches to have NO target. It becomes: a bullpen pitch always has
-- one (unchanged); a game pitch has both target_row and target_col, or neither. Nothing else changes; no data is
-- touched; every existing row already satisfies the new rule (it is strictly looser).
alter table public.pitches drop constraint pitches_target_matches_kind;
alter table public.pitches add constraint pitches_target_matches_kind check (
  (kind = 'bullpen' and target_row is not null and target_col is not null)
  or
  (kind = 'game' and ((target_row is null and target_col is null) or (target_row is not null and target_col is not null)))
);
