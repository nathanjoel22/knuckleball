-- Live Game Release 2 (Joel, Oct 20 2026; branch live-game-back-more; plans/live-game-r2.md, no packet).
--   * pitches / game_events: unearned_runs and inherited_runs (how many of the play's runs_scored were unearned for
--     this pitcher, and how many were the previous pitcher's inherited runners), charged_prev (a walk charged to the
--     previous pitcher: the reliever took over at 2-0, 2-1, 3-0, 3-1 or 3-2). Games only.
--   * sessions.inherited_runners: runners on base when a reliever started (games; locked once saved).
--   * sync_session writes them; compute_game_summary: 'runs' = charged to this pitcher, 'er', 'ir', 'irs',
--     'bb_charged_prev', and 'bb' leaves charged-to-previous walks out. NULL for games saved before (not tracked).
-- Policies: unchanged. Rollback: supabase/rollback/20261021000000_live_game_r2_down.sql

alter table public.pitches
  add column unearned_runs smallint,
  add column inherited_runs smallint,
  add column charged_prev boolean;
alter table public.pitches add constraint pitches_r2_runs_check check (
  (unearned_runs is null or unearned_runs between 0 and 4) and (inherited_runs is null or inherited_runs between 0 and 4)
  and (kind = 'game' or (unearned_runs is null and inherited_runs is null and charged_prev is null)));
alter table public.game_events
  add column unearned_runs smallint,
  add column inherited_runs smallint,
  add column charged_prev boolean;
alter table public.game_events add constraint game_events_r2_runs_check check (
  (unearned_runs is null or unearned_runs between 0 and 4) and (inherited_runs is null or inherited_runs between 0 and 4));
alter table public.sessions add column inherited_runners smallint;
alter table public.sessions add constraint sessions_inherited_runners_check
  check (inherited_runners is null or (kind = 'game' and inherited_runners between 0 and 3));

CREATE OR REPLACE FUNCTION public.sessions_h1_lock()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_api boolean := current_user in ('authenticated', 'anon', 'service_role');
  v_pitcher uuid := new.pitcher_id;
  v_logged  uuid := new.logged_by;
begin
  if old.ended_at is null then
    return new;   -- a legacy unsaved row (none on production): finishes through the old path
  end if;
  if new.ended_at is distinct from old.ended_at then
    raise exception 'session_saved_locked' using detail = 'A saved session can''t be un-saved or re-timed.';
  end if;
  -- A1: the account-deletion function may clear these two (to NULL only).
  if not v_api then
    if new.pitcher_id is null then v_pitcher := old.pitcher_id; end if;
    if new.logged_by  is null then v_logged  := old.logged_by;  end if;
  end if;
  if (new.id, v_pitcher, new.team_id, v_logged, new.started_at, new.created_at, new.kind, new.sport,
      new.charting_perspective, new.opponent, new.game_final_inning, new.game_outs_recorded, new.ra_on, new.pitch_count_adjust,
      new.inherited_runners)
     is distinct from
     (old.id, old.pitcher_id, old.team_id, old.logged_by, old.started_at, old.created_at, old.kind, old.sport,
      old.charting_perspective, old.opponent, old.game_final_inning, old.game_outs_recorded, old.ra_on, old.pitch_count_adjust,
      old.inherited_runners) then
    raise exception 'session_saved_locked' using detail = 'Who and what a saved session belongs to can''t change.';
  end if;
  if old.sealed_at is not null and new.sealed_at is distinct from old.sealed_at then
    raise exception 'session_saved_locked' using detail = 'A sealed session stays sealed.';
  end if;
  -- The tombstone is written only by the server's own functions (delete_session, a1_purge_profile run as owner).
  -- Any API caller -- the app, a crafted request, the service role -- is refused.
  if v_api
     and (new.deleted_at, new.deleted_by, new.deleted_by_role, new.deleted_by_name, new.pitch_count)
         is distinct from (old.deleted_at, old.deleted_by, old.deleted_by_role, old.deleted_by_name, old.pitch_count) then
    raise exception 'session_saved_locked' using detail = 'Only delete_session() can delete a session.';
  end if;
  return new;   -- report_path / report_generated_at, and sealing an unsealed session, stay writable
end;
$function$;

CREATE OR REPLACE FUNCTION public.sync_session(p_session jsonb, p_pitches jsonb DEFAULT '[]'::jsonb, p_events jsonb DEFAULT '[]'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_id       uuid;
  v_pitcher  uuid;
  v_team     uuid;
  v_logged   uuid;
  v_existing public.sessions%rowtype;
  v_status   text := 'saved';
  v_np       int := 0;
  v_ne       int := 0;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'error', 'not_authenticated');
  end if;
  begin
    v_id      := (p_session ->> 'id')::uuid;
    v_pitcher := (p_session ->> 'pitcher_id')::uuid;
    v_team    := (p_session ->> 'team_id')::uuid;
    v_logged  := (p_session ->> 'logged_by')::uuid;
  exception when others then
    return jsonb_build_object('ok', false, 'error', 'invalid_session');
  end;
  if v_id is null or v_pitcher is null or v_team is null or v_logged is null
     or jsonb_typeof(coalesce(p_pitches, '[]'::jsonb)) <> 'array'
     or jsonb_typeof(coalesce(p_events, '[]'::jsonb)) <> 'array' then
    return jsonb_build_object('ok', false, 'error', 'invalid_session');
  end if;
  if nullif(p_session ->> 'ended_at', '') is null or nullif(p_session ->> 'started_at', '') is null then
    return jsonb_build_object('ok', false, 'error', 'not_saved');   -- nothing unsaved ever reaches the server
  end if;

  select * into v_existing from public.sessions where id = v_id;
  if found then
    if not (public.is_my_profile(v_existing.pitcher_id) or public.is_team_coach(v_existing.team_id)) then
      return jsonb_build_object('ok', false, 'error', 'not_entitled');
    end if;
    if v_existing.sealed_at is not null then
      return jsonb_build_object('ok', true, 'status', 'already_saved', 'pitches', 0, 'events', 0);
    end if;
    v_status := 'completed';   -- an old-app sync that didn't finish
  else
    -- The caller is this pitcher, or a coach of the session's team, charting as one of
    -- their own profiles.
    if not (public.is_my_profile(v_pitcher) or public.is_team_coach(v_team)) or not public.is_my_profile(v_logged) then
      return jsonb_build_object('ok', false, 'error', 'not_entitled');
    end if;
    insert into public.sessions (id, pitcher_id, team_id, logged_by, started_at, ended_at, charting_perspective,
                                 kind, opponent, game_final_inning, game_outs_recorded, ra_on, pitch_count_adjust,
                                 inherited_runners)
    values (v_id, v_pitcher, v_team, v_logged,
            (p_session ->> 'started_at')::timestamptz, (p_session ->> 'ended_at')::timestamptz,
            coalesce(nullif(p_session ->> 'charting_perspective', ''), 'behind_catcher'),
            coalesce(nullif(p_session ->> 'kind', ''), 'bullpen'),
            nullif(p_session ->> 'opponent', ''),
            (p_session ->> 'game_final_inning')::smallint,
            (p_session ->> 'game_outs_recorded')::smallint,
            coalesce((p_session ->> 'ra_on')::boolean, false),   -- U14
            case when coalesce(nullif(p_session ->> 'kind', ''), 'bullpen') = 'game'
                 then coalesce((p_session ->> 'pitch_count_adjust')::smallint, 0) else 0 end,   -- Oct 19: + / - pitch count
            case when coalesce(nullif(p_session ->> 'kind', ''), 'bullpen') = 'game'
                 then (p_session ->> 'inherited_runners')::smallint end);   -- Oct 21: runners on when a reliever started
  end if;

  insert into public.pitches (id, session_id, type, velo, ts, target_row, target_col, actual_row, actual_col,
         accuracy_mode, batter_side, in_accuracy_zone, accuracy_zone_cells, kind, result, in_play_outcome,
         hit_type, fielder, delivery, inning, outs_before, balls_before, strikes_before, at_bat_index, bb_type,
         bb_x, bb_y, fielders, runners_before, batter_to, runner_advances, outs_on_play, runs_scored, sacrifice,
         bb_from_position, time_to_plate, spray_box, runners_after, spray_field, accuracy_hit_kind, hbp_swing,
         unearned_runs, inherited_runs, charged_prev)
  select r.id, v_id, r.type, r.velo, coalesce(r.ts, now()), r.target_row, r.target_col,
         coalesce(r.actual_row, 0), coalesce(r.actual_col, 0),
         r.accuracy_mode, r.batter_side, r.in_accuracy_zone, r.accuracy_zone_cells,
         coalesce(r.kind, coalesce(nullif(p_session ->> 'kind', ''), 'bullpen')), r.result, r.in_play_outcome,
         r.hit_type, r.fielder, r.delivery, r.inning, r.outs_before, r.balls_before, r.strikes_before, r.at_bat_index,
         r.bb_type, r.bb_x, r.bb_y, r.fielders, r.runners_before, r.batter_to, r.runner_advances, r.outs_on_play,
         r.runs_scored, r.sacrifice, r.bb_from_position, r.time_to_plate, r.spray_box, r.runners_after, r.spray_field,
         r.accuracy_hit_kind, r.hbp_swing,   -- Oct 20
         r.unearned_runs, r.inherited_runs, r.charged_prev   -- Oct 21
    from jsonb_populate_recordset(null::public.pitches, coalesce(p_pitches, '[]'::jsonb)) r
   where r.id is not null
  on conflict (id) do nothing;
  get diagnostics v_np = row_count;

  insert into public.game_events (id, session_id, at_bat_index, after_pitch_id, event_type, runners_before,
         runner_advances, outs_on_play, runs_scored, seq, inning_before, balls_before, strikes_before, outs_before,
         unearned_runs, inherited_runs, charged_prev)
  select e.id, v_id, e.at_bat_index,
         case when e.after_pitch_id in (select p.id from public.pitches p where p.session_id = v_id) then e.after_pitch_id end,
         e.event_type, e.runners_before, e.runner_advances, e.outs_on_play,
         e.runs_scored, e.seq, e.inning_before, e.balls_before, e.strikes_before, e.outs_before,
         e.unearned_runs, e.inherited_runs, e.charged_prev   -- Oct 21
    from jsonb_populate_recordset(null::public.game_events, coalesce(p_events, '[]'::jsonb)) e
   where e.id is not null
  on conflict (id) do nothing;
  get diagnostics v_ne = row_count;

  update public.sessions set sealed_at = now() where id = v_id;
  return jsonb_build_object('ok', true, 'status', v_status, 'pitches', v_np, 'events', v_ne);
end;
$function$;


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
  v_adjust smallint;
  v_inherited smallint;
  v_result jsonb;
begin
  select kind, game_final_inning, game_outs_recorded, pitch_count_adjust, inherited_runners
    into v_kind, v_final_inning, v_outs_recorded, v_adjust, v_inherited
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
      (result in ('strike_looking','strike_swinging','foul','foul_tip','in_play','sac_bunt','sac_fly','dropped_third')) as is_strike_result,
      (result not in ('interference','other')) as counts_toward_pct,
      public.is_strike_cell(actual_row, actual_col) as in_zone,
      -- Oct 20: a foul bunt on two strikes is a strikeout too (Joel)
      ((result in ('strike_looking','strike_swinging','foul_tip') and strikes_before >= 2)
        or (result = 'foul' and bb_type = 'bunt' and strikes_before >= 2)) as is_regular_k_out,
      (result = 'dropped_third' or (result in ('strike_looking','strike_swinging','foul_tip') and strikes_before >= 2)
        or (result = 'foul' and bb_type = 'bunt' and strikes_before >= 2)) as is_k,
      (result = 'ball' and balls_before >= 3 and not coalesce(charged_prev, false)) as is_bb,   -- Oct 21: not a walk charged to the previous pitcher
      (result = 'ball' and balls_before >= 3 and coalesce(charged_prev, false)) as is_bb_prev,
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
  -- G3: no-pitch events that end an at-bat. Not pitches -- they never touch
  -- pitch count, strike %, zone or first-pitch numbers.
  ev as (
    select at_bat_index,
      (event_type = 'intentional_walk' or (event_type = 'auto_ball' and balls_before >= 3)) and not coalesce(charged_prev, false) as is_bb,
      (event_type = 'intentional_walk' or (event_type = 'auto_ball' and balls_before >= 3)) and coalesce(charged_prev, false) as is_bb_prev,
      (event_type = 'auto_strike' and strikes_before >= 2) as is_k
      from public.game_events
     where session_id = p_session_id and event_type in ('intentional_walk','auto_ball','auto_strike')
  ),
  evagg as (
    select count(*) filter (where is_bb) as ev_bb, count(*) filter (where is_k) as ev_k, count(*) filter (where is_bb_prev) as ev_bb_prev
      from ev
  ),
  -- Oct 19: runs, from every pitch's and event's runs_scored; NULL when nothing in the game recorded runs (games
  -- charted on the field before runs were tracked left the column empty).
  runs as (
    select (select sum(runs_scored) from public.pitches where session_id = p_session_id)  as pr,
           (select sum(runs_scored) from public.game_events where session_id = p_session_id) as er,
           -- Oct 21: inherited runs (the previous pitcher's) and unearned runs; NULL sums = not tracked (games before)
           coalesce((select sum(inherited_runs) from public.pitches where session_id = p_session_id), 0)
             + coalesce((select sum(inherited_runs) from public.game_events where session_id = p_session_id), 0) as inh,
           (select sum(unearned_runs) from public.pitches where session_id = p_session_id) as pu,
           (select sum(unearned_runs) from public.game_events where session_id = p_session_id) as eu
  ),
  bf as (
    select count(distinct ab) as batters_faced from (
      select at_bat_index as ab from f where at_bat_index is not null
      union
      select at_bat_index from ev where (is_bb or is_k) and at_bat_index is not null
    ) x
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
      count(*) filter (where is_bb_prev) as bb_prev,
      count(*) filter (where is_hit) as h,
      count(*) filter (where is_xbh) as xbh,
      count(*) filter (where is_inplay_out) as outs_in_play,
      count(*) filter (where is_error) as errors,
      count(*) filter (where is_hbp) as hbp,
      count(*) filter (where is_regular_k_out) as regular_k_outs,
      count(*) filter (where is_sac_out) as sac_outs,
      count(*) filter (where is_dropped_third_out) as dropped_third_outs,
      max(inning) as max_inning
    from f
  )
  select jsonb_build_object(
    'pitches', pitches,
    'pitch_count', greatest(0, pitches + coalesce(v_adjust, 0)),   -- Oct 19: the pitch count with + / - (the rates still use pitches)
    -- Oct 21: runs charged to this pitcher (inherited runners who scored are the previous pitcher's)
    'runs', case when runs.pr is null and runs.er is null then null else coalesce(runs.pr, 0) + coalesce(runs.er, 0) - runs.inh end,
    'er', case when runs.pu is null and runs.eu is null then null
               else coalesce(runs.pr, 0) + coalesce(runs.er, 0) - runs.inh - coalesce(runs.pu, 0) - coalesce(runs.eu, 0) end,
    'ir', v_inherited,
    'irs', case when v_inherited is null then null else runs.inh end,
    'bb_charged_prev', bb_prev + ev_bb_prev,
    'strikes', strikes,
    'strike_pct', case when pct_denom > 0 then round(100.0 * pct_num / pct_denom) else 0 end,
    'strike_pct_denominator', pct_denom,
    'in_zone', in_zone,
    'in_zone_pct', case when pitches > 0 then round(100.0 * in_zone / pitches) else 0 end,
    'first_pitch_pitches', fp_pitches,
    'first_pitch_strike_pct', case when fp_pitches > 0 then round(100.0 * fp_strikes / fp_pitches) else null end,
    'k', k + ev_k, 'bb', bb + ev_bb, 'h', h, 'xbh', xbh,
    'outs_in_play', outs_in_play, 'errors', errors, 'hbp', hbp,
    'batters_faced', bf.batters_faced,
    'outs_recorded', coalesce(v_outs_recorded, regular_k_outs + ev_k + outs_in_play + sac_outs + dropped_third_outs),
    'outs_source', case when v_outs_recorded is not null then 'counter' else 'derived' end,
    'final_inning', coalesce(v_final_inning, greatest(max_inning, 1)),
    'final_inning_source', case when v_final_inning is not null then 'counter' else 'derived' end
  ) into v_result
  from agg, evagg, bf, runs;

  return v_result;
end;
$$;
