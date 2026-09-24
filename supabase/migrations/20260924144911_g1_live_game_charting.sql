-- G1 -- Live Game charting. A bullpen measures intent->outcome (target vs
-- actual); a game can't know intent, so it measures outcome->result (where
-- it landed, what happened). Two additions:
--
-- 1. sessions.kind -- which mode a whole session was charted in. Fixed at
--    creation, never changed after (charting perspective is already
--    locked the same way after the first pitch; kind is locked from
--    before the first pitch, since the chooser runs before anything else).
--    Existing rows are all bullpens.
--
-- 2. pitches.kind -- DENORMALIZED from the session on purpose, not looked
--    up via a trigger. A plain CHECK constraint can only see columns on
--    its own row, and acceptance check 11 specifically wants a CHECK (not
--    app-code, not a trigger) that rejects a bullpen pitch missing a
--    target and a game pitch that has one. Copying kind onto the pitch
--    once at insert (pitches are immutable after save, per CLAUDE.md) is
--    the standard way to get real constraint-level enforcement out of
--    what is, conceptually, a property of the whole session.
--
-- target_row/target_col relax from NOT NULL DEFAULT 0 to nullable -- a
-- game pitch has no target, only where it actually landed
-- (actual_row/actual_col, unchanged, still NOT NULL for every pitch of
-- either kind). accuracy_mode was already nullable; nothing to do there.
--
-- New nullable columns, meaningful only when kind = 'game': result,
-- in_play_outcome, hit_type, fielder, delivery, and the count/inning
-- state BEFORE this pitch (inning, outs_before, balls_before,
-- strikes_before, at_bat_index) -- storing the count before rather than
-- after makes each pitch row self-contained and replayable later, per
-- the packet's own framing of this as the first stage of the intent-vs-
-- result work. Deliberately NOT enforcing these against kind with a
-- second CHECK (unlike target_row/col, which acceptance testing
-- specifically exercises) -- keeping the one asked-for constraint
-- precise rather than adding unasked-for rigidity around columns that
-- are simply unused, not dangerous, when null on a bullpen pitch.
--
-- RLS is untouched -- every pitches/sessions policy is an EXISTS check on
-- session ownership (pitcher_id / is_team_coach), never referencing any
-- column this migration adds or changes. Confirmed by reading every
-- policy before writing this (precondition report, point 2).
--
-- ---------------------------------------------------------------------------------
-- ROLLBACK (no auto-down; write a new migration with this body if you need to
-- revert):
--
--   alter table public.pitches drop constraint if exists pitches_target_matches_kind;
--   alter table public.pitches
--     drop column if exists kind,
--     drop column if exists result,
--     drop column if exists in_play_outcome,
--     drop column if exists hit_type,
--     drop column if exists fielder,
--     drop column if exists delivery,
--     drop column if exists inning,
--     drop column if exists outs_before,
--     drop column if exists balls_before,
--     drop column if exists strikes_before,
--     drop column if exists at_bat_index;
--   alter table public.pitches
--     alter column target_row set default 0,
--     alter column target_col set default 0;
--   update public.pitches set target_row = 0 where target_row is null;
--   update public.pitches set target_col = 0 where target_col is null;
--   alter table public.pitches
--     alter column target_row set not null,
--     alter column target_col set not null;
--   alter table public.sessions drop column if exists kind;
--   -- Reverting after any real game data exists destroys that data's
--   -- shape permanently (no target to backfill) -- take the pre-deploy
--   -- backup seriously, same warning as the batter_side migration.
-- ---------------------------------------------------------------------------------

alter table public.sessions
  add column kind text not null default 'bullpen' check (kind in ('bullpen', 'game'));

comment on column public.sessions.kind is
  'G1: which mode this whole session was charted in. Fixed at creation
   (the chooser runs before the first pitch, before charting_perspective
   is even asked), never changed after. Every existing row is a bullpen.
   Games are kept separate everywhere that computes accuracy/command/zone
   results and never feed the team leaderboard -- see the G1 precondition
   report for the exact list of call sites.';

alter table public.pitches
  alter column target_row drop not null,
  alter column target_row drop default,
  alter column target_col drop not null,
  alter column target_col drop default;

alter table public.pitches
  add column kind text not null default 'bullpen' check (kind in ('bullpen', 'game')),
  add column result text check (result in (
    'ball', 'strike_looking', 'strike_swinging', 'foul', 'in_play',
    'hbp', 'sac_bunt', 'sac_fly', 'dropped_third', 'interference', 'other'
  )),
  add column in_play_outcome text check (in_play_outcome in ('hit', 'out', 'error')),
  add column hit_type text check (hit_type in ('1B', '2B', '3B', 'HR')),
  add column fielder text check (fielder in ('P', 'C', '1B', '2B', '3B', 'SS', 'LF', 'CF', 'RF')),
  add column delivery text check (delivery in ('set', 'windup')),
  add column inning smallint,
  add column outs_before smallint,
  add column balls_before smallint,
  add column strikes_before smallint,
  add column at_bat_index smallint;

alter table public.pitches
  add constraint pitches_target_matches_kind check (
    (kind = 'bullpen' and target_row is not null and target_col is not null)
    or
    (kind = 'game' and target_row is null and target_col is null)
  );

comment on column public.pitches.kind is
  'G1: copied from the parent session''s kind at insert time (a session''s
   kind never changes, and pitches are immutable after save, so this never
   drifts from it). Denormalized specifically so pitches_target_matches_kind
   can be a real CHECK constraint instead of a trigger -- a CHECK can only
   see its own row.';
