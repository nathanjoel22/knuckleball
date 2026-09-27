-- G1b-r -- revision to the game screen: scorebook glyphs, position-driven
-- batted-ball location, and three no-pitch game_events types (IBB/auto
-- ball/auto strike). Sequential after G1b (20260928000000). Staging only
-- until the UI work lands and is verified.
--
-- Precondition report (Sept 26 2026) confirmed on staging, before writing
-- this file:
--   pitches_result_check:         result in ('ball','strike_looking','strike_swinging','foul','in_play',
--                                             'hbp','sac_bunt','sac_fly','dropped_third','interference','other')
--   game_events_event_type_check: event_type in ('stolen_base','caught_stealing','pickoff','wild_pitch',
--                                                 'passed_ball','balk','other')
-- pitches_g1b_fields_check already leaves "which fields for which result"
-- as an application-level concern (no DB constraint ties bb_type to a
-- specific result) -- so decision 11 (bb_type allowed on a foul-bunt row,
-- result='foul') needs no schema change here, only application code.
--
-- batter_interference (BI, decision 10) is new and distinct from the
-- existing generic 'interference', which stays CI (catcher's interference,
-- forced-advance-to-1st, unchanged). foul_tip (FT) is a strike, handled in
-- app code the same as any other strike result.
--
-- ---------------------------------------------------------------------------------
-- ROLLBACK (no auto-down; write a new migration with this body if you need
-- to revert):
--
--   alter table public.pitches
--     drop constraint if exists pitches_g1b_fields_check,
--     drop column if exists bb_from_position;
--   alter table public.pitches
--     add constraint pitches_g1b_fields_check check (
--       (kind = 'bullpen'
--         and bb_type is null and bb_x is null and bb_y is null and fielders is null
--         and runners_before is null and batter_to is null and runner_advances is null
--         and outs_on_play is null and runs_scored is null and sacrifice is null)
--       or (kind = 'game')
--     );
--   alter table public.pitches
--     drop constraint pitches_result_check,
--     add constraint pitches_result_check check (result in (
--       'ball', 'strike_looking', 'strike_swinging', 'foul', 'in_play',
--       'hbp', 'sac_bunt', 'sac_fly', 'dropped_third', 'interference', 'other'
--     ));
--     -- Note: any row already carrying 'batter_interference' or 'foul_tip'
--     -- violates the restored constraint. Decide per row before reverting.
--   alter table public.game_events
--     drop constraint game_events_event_type_check,
--     add constraint game_events_event_type_check check (event_type in
--       ('stolen_base','caught_stealing','pickoff','wild_pitch','passed_ball','balk','other'));
--     -- Note: any row already carrying 'intentional_walk'/'auto_ball'/
--     -- 'auto_strike' violates the restored constraint. Decide per row
--     -- before reverting.
-- ---------------------------------------------------------------------------------


-- ============================================================================
-- pitches.bb_from_position: true when bb_x/bb_y came from the tapped
-- position's own anchor coordinate (decision 5) rather than a precise tap
-- -- which is every in-play/E/FC row in this build, since precise
-- tap-to-locate is deferred. NULL for every non-in-play pitch and every
-- bullpen pitch, same rule as bb_type/bb_x/bb_y.
-- ============================================================================

alter table public.pitches
  add column bb_from_position boolean;

comment on column public.pitches.bb_from_position is
  'True when bb_x/bb_y are the tapped fielding position''s own anchor coordinate (G1b-r decision 5), not a precise tap. Every in-play/E/FC row in this build has this true -- precise tap-to-locate is a deferred refinement. NULL for every non-in-play pitch and every bullpen pitch.';

alter table public.pitches
  drop constraint pitches_g1b_fields_check,
  add constraint pitches_g1b_fields_check check (
    (kind = 'bullpen'
      and bb_type is null and bb_x is null and bb_y is null and fielders is null
      and runners_before is null and batter_to is null and runner_advances is null
      and outs_on_play is null and runs_scored is null and sacrifice is null
      and bb_from_position is null)
    or (kind = 'game')
  );


-- ============================================================================
-- pitches.result: widen for BI (batter's interference, decision 10 -- an
-- out, distinct from the existing generic 'interference' which stays CI)
-- and FT (foul tip, decision 10 -- a strike).
-- ============================================================================

alter table public.pitches
  drop constraint pitches_result_check,
  add constraint pitches_result_check check (result in (
    'ball', 'strike_looking', 'strike_swinging', 'foul', 'in_play',
    'hbp', 'sac_bunt', 'sac_fly', 'dropped_third', 'interference', 'other',
    'batter_interference', 'foul_tip'
  ));


-- ============================================================================
-- game_events.event_type: three no-pitch events (decision 10) -- IBB, an
-- automatic ball, an automatic strike. None is a pitch, none counts toward
-- strike %, each is its own line in the at-bat log (application-level, no
-- schema change needed beyond the allowed value).
-- ============================================================================

alter table public.game_events
  drop constraint game_events_event_type_check,
  add constraint game_events_event_type_check check (event_type in (
    'stolen_base','caught_stealing','pickoff','wild_pitch','passed_ball','balk','other',
    'intentional_walk','auto_ball','auto_strike'
  ));
