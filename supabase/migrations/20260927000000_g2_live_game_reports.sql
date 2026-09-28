-- G2 -- Live Game reports. Schema half: opponent label, the two persisted
-- game counters decision 4 needs, the dropped-third out/safe distinction,
-- and the one shared SQL function that computes every number History's
-- game row and the report BOTH show, so they can never disagree (drafting
-- decision 1).
--
-- ---------------------------------------------------------------------------------
-- ROLLBACK (no auto-down; write a new migration with this body if you need
-- to revert):
--
--   drop function if exists public.compute_game_summary(uuid);
--   drop function if exists public.is_strike_cell(integer, integer);
--
--   alter table public.pitches
--     drop constraint if exists pitches_in_play_outcome_check,
--     add constraint pitches_in_play_outcome_check
--       check (in_play_outcome = any (array['hit','out','error']));
--     -- Note: any row already carrying 'reached' violates the restored
--     -- constraint. Decide per row (usually: back to NULL) before adding it
--     -- back, same caution as any down-migration that narrows a CHECK.
--
--   alter table public.sessions
--     drop constraint if exists sessions_game_fields_check,
--     drop column if exists opponent,
--     drop column if exists game_final_inning,
--     drop column if exists game_outs_recorded;
-- ---------------------------------------------------------------------------------


-- ============================================================================
-- sessions: opponent + the two counters decision 4 needs (outs/innings from
-- the tracker, not re-derived from pitch rows -- a caught-stealing out has
-- no pitch row at all).
-- ============================================================================

alter table public.sessions
  add column opponent text,
  add column game_final_inning smallint,
  add column game_outs_recorded smallint;

alter table public.sessions
  add constraint sessions_opponent_length check (opponent is null or char_length(opponent) <= 60);

comment on column public.sessions.opponent is
  'Optional, free text, editable up to save. NULL renders as "Game · <date>"; set renders as "vs <opponent> · <date>". NULL for every bullpen.';
comment on column public.sessions.game_final_inning is
  'The tracker''s own inning counter at save time (G2). NULL for a bullpen, and NULL for a game saved before this column existed -- the renderer falls back to max(pitches.inning) for those and labels it "outs from pitches", never invents.';
comment on column public.sessions.game_outs_recorded is
  'The tracker''s own outs counter at save time (G2) -- this is the reason it exists: a caught-stealing out (gameBumpOuts()) advances this with no pitch row behind it at all, so it cannot be recovered from pitches after the fact. NULL for a bullpen and for a pre-G2 game (same pitch-derived fallback as game_final_inning).';

alter table public.sessions
  add constraint sessions_game_fields_check check (
    (kind = 'bullpen' and opponent is null and game_final_inning is null and game_outs_recorded is null)
    or (kind = 'game')
    -- opponent/game_final_inning/game_outs_recorded are all still nullable
    -- for a game: opponent because it's genuinely optional, the counters
    -- because a pre-G2 game predates them (see the fallback above).
  );


-- ============================================================================
-- pitches: dropped-third strike now records whether the batter was retired
-- or reached -- reuses in_play_outcome (already nullable, already means
-- "what happened to the ball/runner," already varies by result the same
-- way hit_type/fielder do) rather than a new column. 'reached' is only
-- ever written for result='dropped_third'; result='in_play' keeps using
-- exactly hit/out/error as before -- nothing about that path changes.
-- G1b widens this same constraint again (drop and re-add, adding 'fc') as
-- its own sequential migration -- not done here, so this migration stays
-- scoped to exactly what G2 itself needs.
-- ============================================================================

alter table public.pitches
  drop constraint pitches_in_play_outcome_check,
  add constraint pitches_in_play_outcome_check
    check (in_play_outcome = any (array['hit','out','error','reached']));


-- ============================================================================
-- is_strike_cell: the one predicate behind every strike%/in-zone% number in
-- the product. Already existed inline, duplicated, in get_team_leaderboard
-- (20260924150000) and independently in two TS copies (client
-- bullpen-tracker.html, server helpers.ts) -- not touching those three (out
-- of scope, and the leaderboard is explicitly "unchanged" per G1/G2). This
-- is the first SQL-callable copy, for compute_game_summary below, which is
-- new. Every session today is the 5-cell grid (no grid_size column exists
-- yet), so this is not parameterized the way the TS server copy is --
-- add a size parameter here too if/when a second grid size actually ships.
-- ============================================================================

create or replace function public.is_strike_cell(p_row integer, p_col integer)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_row between 1 and 3 and p_col between 1 and 3;
$$;


-- ============================================================================
-- compute_game_summary(session_id): the ONE definition of every number that
-- appears in BOTH History's game row and the report's header/summary tiles
-- (drafting decision 1). SECURITY INVOKER, not DEFINER -- this reads only
-- what the caller's own RLS on sessions/pitches already lets them read
-- (pitcher owns / coach manages), so it grants nothing beyond what a caller
-- could already compute themselves from the raw rows; there is no
-- privilege reason for this to run as anyone else. Called by the client
-- (History) and by send-session-report (through the caller's own
-- RLS-scoped client, same as every other read in that function) so the two
-- can never compute a different number from the same pitches.
--
-- Report-only sections (per-type, per-inning, results-by-count, per-side,
-- velocity, recent-pens, cross-game trends) are NOT here -- History never
-- shows them, so there is nothing for them to disagree with, and they stay
-- in the Edge Function's own compute.ts alongside their bullpen
-- equivalents.
-- ============================================================================

create or replace function public.compute_game_summary(p_session_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_kind text;
  v_final_inning smallint;
  v_outs_recorded smallint;
  v_result jsonb;
begin
  select kind, game_final_inning, game_outs_recorded
    into v_kind, v_final_inning, v_outs_recorded
    from public.sessions
   where id = p_session_id;

  if not found then
    return jsonb_build_object('error', 'session not found or not accessible');
  end if;
  if v_kind <> 'game' then
    return jsonb_build_object('error', 'not a game session');
  end if;

  with p as (
    select * from public.pitches where session_id = p_session_id
  ),
  f as (
    select
      *,
      (result in ('strike_looking','strike_swinging','foul','in_play','sac_bunt','sac_fly','dropped_third')) as is_strike_result,
      (result not in ('interference','other')) as counts_toward_pct,
      public.is_strike_cell(actual_row, actual_col) as in_zone,
      (result in ('strike_looking','strike_swinging') and strikes_before >= 2) as is_regular_k_out,
      (result = 'dropped_third' or (result in ('strike_looking','strike_swinging') and strikes_before >= 2)) as is_k,
      (result = 'ball' and balls_before >= 3) as is_bb,
      (result = 'in_play' and in_play_outcome = 'hit') as is_hit,
      (result = 'in_play' and in_play_outcome in ('hit') and hit_type in ('2B','3B','HR')) as is_xbh,
      (result = 'in_play' and in_play_outcome = 'out') as is_inplay_out,
      (result = 'in_play' and in_play_outcome = 'error') as is_error,
      (result = 'hbp') as is_hbp,
      (result in ('sac_bunt','sac_fly')) as is_sac_out,
      (result = 'dropped_third' and in_play_outcome = 'out') as is_dropped_third_out,
      (balls_before = 0 and strikes_before = 0) as is_first_pitch
    from p
  ),
  agg as (
    select
      count(*) as pitches,
      count(*) filter (where is_strike_result) as strikes,
      count(*) filter (where counts_toward_pct) as pct_denom,
      count(*) filter (where is_strike_result and counts_toward_pct) as pct_num,
      count(*) filter (where in_zone) as in_zone,
      count(*) filter (where is_first_pitch) as fp_pitches,
      count(*) filter (where is_first_pitch and is_strike_result) as fp_strikes,
      count(*) filter (where is_k) as k,
      count(*) filter (where is_bb) as bb,
      count(*) filter (where is_hit) as h,
      count(*) filter (where is_xbh) as xbh,
      count(*) filter (where is_inplay_out) as outs_in_play,
      count(*) filter (where is_error) as errors,
      count(*) filter (where is_hbp) as hbp,
      count(distinct at_bat_index) filter (where at_bat_index is not null) as batters_faced,
      -- A regular (non-dropped-third) strikeout is ALWAYS an out. A
      -- dropped-third strikeout is an out only when in_play_outcome='out'
      -- (it's still a K either way -- see is_k -- but not automatically an
      -- out, which is the entire reason that column got widened). Keeping
      -- these as two separate, non-overlapping counts here rather than
      -- reusing is_k for both purposes -- collapsing them double-counted a
      -- dropped-third out and, worse, counted a dropped-third "reached" as
      -- an out it explicitly wasn't. Caught by testing the derived-outs
      -- fallback path against a hand calculation, not by inspection.
      count(*) filter (where is_regular_k_out) as regular_k_outs,
      count(*) filter (where is_sac_out) as sac_outs,
      count(*) filter (where is_dropped_third_out) as dropped_third_outs,
      max(inning) as max_inning
    from f
  )
  select jsonb_build_object(
    'pitches', pitches,
    'strikes', strikes,
    'strike_pct', case when pct_denom > 0 then round(100.0 * pct_num / pct_denom) else 0 end,
    'strike_pct_denominator', pct_denom,
    'in_zone', in_zone,
    'in_zone_pct', case when pitches > 0 then round(100.0 * in_zone / pitches) else 0 end,
    'first_pitch_pitches', fp_pitches,
    'first_pitch_strike_pct', case when fp_pitches > 0 then round(100.0 * fp_strikes / fp_pitches) else null end,
    'k', k, 'bb', bb, 'h', h, 'xbh', xbh,
    'outs_in_play', outs_in_play, 'errors', errors, 'hbp', hbp,
    'batters_faced', batters_faced,
    -- Outs/innings: the tracker's own counters win when present (decision
    -- 4); NULL only for a game saved before this column existed, where the
    -- best available number is derived from pitch rows and must be labeled
    -- as such by the caller -- this function reports which source it used
    -- so neither History nor the report has to re-decide that.
    'outs_recorded', coalesce(v_outs_recorded, regular_k_outs + outs_in_play + sac_outs + dropped_third_outs),
    'outs_source', case when v_outs_recorded is not null then 'counter' else 'derived' end,
    'final_inning', coalesce(v_final_inning, greatest(max_inning, 1)),
    'final_inning_source', case when v_final_inning is not null then 'counter' else 'derived' end
  ) into v_result
  from agg;

  return v_result;
end;
$$;

revoke all on function public.compute_game_summary(uuid) from public, anon;
grant execute on function public.compute_game_summary(uuid) to authenticated;
revoke all on function public.is_strike_cell(integer, integer) from public, anon;
grant execute on function public.is_strike_cell(integer, integer) to authenticated;
