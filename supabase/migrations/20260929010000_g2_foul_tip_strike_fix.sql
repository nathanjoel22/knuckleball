-- G2 follow-up: compute_game_summary() undercounted foul_tip. Found while
-- reviewing the G2 renderer WIP with Joel (Sept 28, 2026 chat) -- the
-- client's own live-charting logic (bullpen-tracker.html's
-- GAME_STRIKE_RESULTS and gameStats(), unchanged, already correct) has
-- always treated a foul tip as: always a strike (like a plain foul), and,
-- unlike a plain foul, ABLE to be strike three -- a caught foul tip with 2
-- strikes already is a real strikeout. compute_game_summary (created in
-- 20260927000000_g2_live_game_reports.sql, deployed to production the same
-- day as this file) left foul_tip out of is_strike_result, is_k, AND
-- is_regular_k_out entirely, so any historical game containing a foul-tip
-- row would disagree with itself: correct live, wrong in History/the report.
--
-- Joel's ruling, verbatim: "a foul tip into the catchers glove on strike
-- three would be a strike and if caught, a strikeout." Confirmed
-- separately that a foul ball should always count as a strike toward
-- strike % even though it can never itself be strike three -- that part of
-- compute_game_summary was already correct and is untouched here.
--
-- No column/constraint change -- this is create-or-replace on the same
-- function signature, so no down-migration mechanics beyond restoring the
-- old body (below).
--
-- ---------------------------------------------------------------------------------
-- ROLLBACK (no auto-down; write a new migration with this body if you need
-- to revert -- restores the pre-fix predicates verbatim from
-- 20260927000000_g2_live_game_reports.sql):
--
--   -- (re-run the full CREATE OR REPLACE FUNCTION from that file, i.e.
--   -- is_strike_result/is_k/is_regular_k_out WITHOUT 'foul_tip')
-- ---------------------------------------------------------------------------------

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
      -- Fix: foul_tip added -- always a strike, same as a plain foul.
      (result in ('strike_looking','strike_swinging','foul','foul_tip','in_play','sac_bunt','sac_fly','dropped_third')) as is_strike_result,
      (result not in ('interference','other')) as counts_toward_pct,
      public.is_strike_cell(actual_row, actual_col) as in_zone,
      -- Fix: foul_tip added -- unlike a plain foul, CAN be strike three.
      (result in ('strike_looking','strike_swinging','foul_tip') and strikes_before >= 2) as is_regular_k_out,
      (result = 'dropped_third' or (result in ('strike_looking','strike_swinging','foul_tip') and strikes_before >= 2)) as is_k,
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
