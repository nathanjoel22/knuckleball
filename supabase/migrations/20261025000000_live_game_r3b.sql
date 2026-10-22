-- Live Game R3, Stage B (Jordan + Joel, Oct 21 2026; plans/live-game-r3-review.md, decisions in
-- plans/live-game-r3-preconditions.md). A pitcher's line stays open for the runners he left on base.
--   * sessions.final_at: the full lock. Set at save unless he left a runner of his own on base; then by the next
--     pitcher's save (none of his runners still on), or by the 6-hour job. Every saved session before this is final.
--   * sessions.exit_runs / exit_er / exit_bb: charged to him after he left, written only by r3_apply_relief from the
--     reliever's own saved rows (charged_runs, charged_prev_session) in the reliever's sync_session.
--   * sessions.relieved_session_id (the game this one relieved) and left_owners ({"1": "<session id>", ...}: whose
--     runner each one on base was when he came out). runners_left stays the count it was.
--   * pitches / game_events: charged_runs ([{"s": "<owner session>", "u": true|false}], one per inherited run that
--     scored on the play) and charged_prev_session (whose walk it was).
--   * The H1 lock: relieved_session_id / left_owners never change after save; final_at / exit_* only by the server,
--     never once final.
--   * compute_game_summary adds exit_* to runs / er / bb and returns provisional; send-session-report refuses a
--     provisional game.
--   * pitches.hbp_swing dropped (R3 A1; unused since v282).
-- Policies: unchanged (29). Rollback: supabase/rollback/20261025000000_live_game_r3b_down.sql.
-- Test: supabase/tests/live_game_r3b.sql.

alter table public.sessions
  add column final_at timestamptz,
  add column exit_runs smallint,
  add column exit_er smallint,
  add column exit_bb smallint,
  add column relieved_session_id uuid references public.sessions(id),
  add column left_owners jsonb;
alter table public.sessions add constraint sessions_r3_exit_check
  check ((exit_runs is null and exit_er is null and exit_bb is null)
         or (kind = 'game' and exit_runs between 0 and 99 and exit_er between 0 and exit_runs and exit_bb between 0 and 99));
alter table public.sessions add constraint sessions_r3_relief_check
  check ((relieved_session_id is null and left_owners is null)
         or (kind = 'game' and (left_owners is null or jsonb_typeof(left_owners) = 'object')));
comment on column public.sessions.final_at is 'R3 Stage B: the full lock -- his line (exit_*) can''t change after this. NULL while runners he left on base may still score.';
comment on column public.sessions.relieved_session_id is 'R3 Stage B: the game this relief game took over from (its pitcher''s runners).';
comment on column public.sessions.left_owners is 'R3 Stage B: {"1"|"2"|"3": session id} -- whose runner each one on base was when he came out.';

alter table public.pitches add column charged_runs jsonb, add column charged_prev_session uuid;
alter table public.game_events add column charged_runs jsonb, add column charged_prev_session uuid;
alter table public.pitches add constraint pitches_r3_charged_check
  check (charged_runs is null or (kind = 'game' and jsonb_typeof(charged_runs) = 'array'));
alter table public.game_events add constraint game_events_r3_charged_check
  check (charged_runs is null or jsonb_typeof(charged_runs) = 'array');

alter table public.pitches drop constraint if exists pitches_hbp_swing_check;
alter table public.pitches drop column if exists hbp_swing;

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
      new.inherited_runners, new.runners_left, new.relieved_session_id, new.left_owners)
     is distinct from
     (old.id, old.pitcher_id, old.team_id, old.logged_by, old.started_at, old.created_at, old.kind, old.sport,
      old.charting_perspective, old.opponent, old.game_final_inning, old.game_outs_recorded, old.ra_on, old.pitch_count_adjust,
      old.inherited_runners, old.runners_left, old.relieved_session_id, old.left_owners) then
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
  -- R3 Stage B: the full lock and the stats charged after he left are written only by the server's own functions
  -- (sync_session's relief step, the 6-hour job, the backfill), never by an API caller, and never again once final.
  if (new.final_at, new.exit_runs, new.exit_er, new.exit_bb) is distinct from (old.final_at, old.exit_runs, old.exit_er, old.exit_bb) then
    if v_api then
      raise exception 'session_saved_locked' using detail = 'Only the server sets a game''s final line.';
    end if;
    if old.final_at is not null then
      raise exception 'session_saved_locked' using detail = 'This game''s line is final.';
    end if;
  end if;
  return new;   -- report_path / report_generated_at, and sealing an unsealed session, stay writable
end;
$function$;


-- Charge the pitchers whose runners scored off this relief game: the game it relieved, and up the chain (a second
-- reliever who inherited the starter's runner still charges the starter). Only from this game's own saved rows; at most
-- the runners each one left (plus the walk charged to him); never once he's final. Then the full lock for any of them
-- with no runner of his still on base when this pitcher came out. Called only by sync_session (as the owner).
create or replace function public.r3_apply_relief(p_relief uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.sessions%rowtype;
  o public.sessions%rowtype;
  cur uuid;
  depth int := 0;
  v_runs int; v_u int; v_bb int; v_room int;
  v_out jsonb := '[]'::jsonb;
begin
  select * into r from public.sessions where id = p_relief;
  if not found or r.relieved_session_id is null then
    return v_out;
  end if;
  cur := r.relieved_session_id;
  while cur is not null and depth < 10 loop
    depth := depth + 1;
    select * into o from public.sessions where id = cur for update;
    exit when not found;
    if o.final_at is null and o.kind = 'game' and o.team_id = r.team_id and o.id <> r.id then
      select count(*), count(*) filter (where coalesce((x ->> 'u')::boolean, false))
        into v_runs, v_u
        from (select jsonb_array_elements(p.charged_runs) as x from public.pitches p
               where p.session_id = r.id and jsonb_typeof(p.charged_runs) = 'array'
              union all
              select jsonb_array_elements(e.charged_runs) from public.game_events e
               where e.session_id = r.id and jsonb_typeof(e.charged_runs) = 'array') q
       where q.x ->> 's' = o.id::text;
      v_bb := 0;
      if o.id = r.relieved_session_id then   -- only the pitcher he took over from left a count behind
        v_bb := least(1, (select count(*) from public.pitches where session_id = r.id and charged_prev and charged_prev_session = o.id)
                       + (select count(*) from public.game_events where session_id = r.id and charged_prev and charged_prev_session = o.id));
      end if;
      v_room := greatest(0, coalesce(o.runners_left, 0) + coalesce(o.exit_bb, 0) + v_bb - coalesce(o.exit_runs, 0));
      v_runs := least(v_runs, v_room);
      v_u := least(v_u, v_runs);
      if v_runs > 0 or v_bb > 0 then
        update public.sessions
           set exit_runs = coalesce(exit_runs, 0) + v_runs,
               exit_er   = coalesce(exit_er, 0) + v_runs - v_u,
               exit_bb   = coalesce(exit_bb, 0) + v_bb
         where id = o.id;
      end if;
      if not exists (select 1 from jsonb_each_text(coalesce(r.left_owners, '{}'::jsonb)) x where x.value = o.id::text) then
        update public.sessions set final_at = now() where id = o.id;
      end if;
      v_out := v_out || jsonb_build_object('session', o.id, 'runs', v_runs, 'unearned', v_u, 'bb', v_bb);
    end if;
    cur := o.relieved_session_id;
  end loop;
  return v_out;
end;
$$;
revoke all on function public.r3_apply_relief(uuid) from public, anon, authenticated;

-- The 6-hour full lock: a game nobody linked to (reliever charted elsewhere or not at all) goes final 6 hours after
-- it was saved. pg_cron, every 15 minutes (as A1's job).
create or replace function public.r3_finalize_stale()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare n integer;
begin
  update public.sessions set final_at = now()
   where final_at is null and ended_at is not null and coalesce(sealed_at, ended_at) < now() - interval '6 hours';
  get diagnostics n = row_count;
  return n;
end;
$$;
revoke all on function public.r3_finalize_stale() from public, anon, authenticated;

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
  v_kind     text;
  v_rel      uuid;          -- R3 Stage B: the game this one relieved (validated below)
  v_owners   jsonb;         -- whose runner each one left on base was
  v_owner    public.sessions%rowtype;
  v_link     text := null;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'error', 'not_authenticated');
  end if;
  begin
    v_id      := (p_session ->> 'id')::uuid;
    v_pitcher := (p_session ->> 'pitcher_id')::uuid;
    v_team    := (p_session ->> 'team_id')::uuid;
    v_logged  := (p_session ->> 'logged_by')::uuid;
    v_rel     := nullif(p_session ->> 'relieved_session_id', '')::uuid;
    v_owners  := case when jsonb_typeof(p_session -> 'left_owners') = 'object' then p_session -> 'left_owners' end;
    if v_owners is not null then
      perform (x.value)::uuid from jsonb_each_text(v_owners) x;   -- every owner a session id
      if exists (select 1 from jsonb_object_keys(v_owners) k where k not in ('1', '2', '3')) then raise exception 'bad base'; end if;
    end if;
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
    v_kind := coalesce(nullif(p_session ->> 'kind', ''), 'bullpen');
    if v_kind <> 'game' then v_rel := null; v_owners := null; end if;
    -- R3 Stage B: a relief game names the game it relieved. Linked only when it's this team's game, another pitcher's,
    -- saved before this one started and within 6 hours of it, and the caller is a coach of the team or charted that
    -- game himself (a pitcher charting himself can't add runs to a teammate's line). Not saved yet: wait in the
    -- outbox (retried) for a day, then save unlinked -- nothing is ever discarded.
    if v_rel is not null then
      select * into v_owner from public.sessions where id = v_rel;
      if not found then
        if (p_session ->> 'ended_at')::timestamptz > now() - interval '24 hours' then
          return jsonb_build_object('ok', false, 'error', 'relieved_not_saved');
        end if;
        v_rel := null; v_link := 'not_found';
      elsif not (v_owner.kind = 'game' and v_owner.team_id = v_team and v_owner.pitcher_id is distinct from v_pitcher
                 and v_owner.deleted_at is null and v_owner.ended_at is not null
                 and v_owner.ended_at <= (p_session ->> 'started_at')::timestamptz + interval '5 minutes'
                 and (p_session ->> 'started_at')::timestamptz - v_owner.ended_at <= interval '6 hours'
                 and (public.is_team_coach(v_team) or public.is_my_profile(v_owner.logged_by))) then
        v_rel := null; v_link := 'refused';
      else
        v_link := 'linked';
      end if;
    end if;
    insert into public.sessions (id, pitcher_id, team_id, logged_by, started_at, ended_at, charting_perspective,
                                 kind, opponent, game_final_inning, game_outs_recorded, ra_on, pitch_count_adjust,
                                 inherited_runners, runners_left, relieved_session_id, left_owners, final_at)
    values (v_id, v_pitcher, v_team, v_logged,
            (p_session ->> 'started_at')::timestamptz, (p_session ->> 'ended_at')::timestamptz,
            coalesce(nullif(p_session ->> 'charting_perspective', ''), 'behind_catcher'),
            coalesce(nullif(p_session ->> 'kind', ''), 'bullpen'),
            nullif(p_session ->> 'opponent', ''),
            (p_session ->> 'game_final_inning')::smallint,
            (p_session ->> 'game_outs_recorded')::smallint,
            coalesce((p_session ->> 'ra_on')::boolean, false),   -- U14
            case when coalesce(nullif(p_session ->> 'kind', ''), 'bullpen') = 'game'
                 then greatest(0, least(999, coalesce((p_session ->> 'pitch_count_adjust')::int, 0))) else 0 end,   -- R3 (A4): never negative; an old app's -K / -B saves as 0
            case when coalesce(nullif(p_session ->> 'kind', ''), 'bullpen') = 'game'
                 then (p_session ->> 'inherited_runners')::smallint end,   -- Oct 21: runners on when a reliever started
            case when coalesce(nullif(p_session ->> 'kind', ''), 'bullpen') = 'game'
                 then (p_session ->> 'runners_left')::smallint end,   -- Oct 22: runners on base when he came out
            v_rel, v_owners,   -- R3 Stage B
            -- final now unless he left a runner of his own on base (then the next pitcher's save, or 6 hours, decides)
            case when exists (select 1 from jsonb_each_text(coalesce(v_owners, '{}'::jsonb)) x where x.value = v_id::text)
                 then null else now() end);
  end if;

  insert into public.pitches (id, session_id, type, velo, ts, target_row, target_col, actual_row, actual_col,
         accuracy_mode, batter_side, in_accuracy_zone, accuracy_zone_cells, kind, result, in_play_outcome,
         hit_type, fielder, delivery, inning, outs_before, balls_before, strikes_before, at_bat_index, bb_type,
         bb_x, bb_y, fielders, runners_before, batter_to, runner_advances, outs_on_play, runs_scored, sacrifice,
         bb_from_position, time_to_plate, spray_box, runners_after, spray_field, accuracy_hit_kind,
         unearned_runs, inherited_runs, charged_prev, charged_runs, charged_prev_session)
  select r.id, v_id, r.type, r.velo, coalesce(r.ts, now()), r.target_row, r.target_col,
         coalesce(r.actual_row, 0), coalesce(r.actual_col, 0),
         r.accuracy_mode, r.batter_side, r.in_accuracy_zone, r.accuracy_zone_cells,
         coalesce(r.kind, coalesce(nullif(p_session ->> 'kind', ''), 'bullpen')), r.result, r.in_play_outcome,
         r.hit_type, r.fielder, r.delivery, r.inning, r.outs_before, r.balls_before, r.strikes_before, r.at_bat_index,
         r.bb_type, r.bb_x, r.bb_y, r.fielders, r.runners_before, r.batter_to, r.runner_advances, r.outs_on_play,
         r.runs_scored, r.sacrifice, r.bb_from_position, r.time_to_plate, r.spray_box, r.runners_after, r.spray_field,
         r.accuracy_hit_kind,
         r.unearned_runs, r.inherited_runs, r.charged_prev,   -- Oct 21
         case when jsonb_typeof(r.charged_runs) = 'array' then r.charged_runs end, r.charged_prev_session   -- R3 Stage B
    from jsonb_populate_recordset(null::public.pitches, coalesce(p_pitches, '[]'::jsonb)) r
   where r.id is not null
  on conflict (id) do nothing;
  get diagnostics v_np = row_count;

  insert into public.game_events (id, session_id, at_bat_index, after_pitch_id, event_type, runners_before,
         runner_advances, outs_on_play, runs_scored, seq, inning_before, balls_before, strikes_before, outs_before,
         unearned_runs, inherited_runs, charged_prev, charged_runs, charged_prev_session)
  select e.id, v_id, e.at_bat_index,
         case when e.after_pitch_id in (select p.id from public.pitches p where p.session_id = v_id) then e.after_pitch_id end,
         e.event_type, e.runners_before, e.runner_advances, e.outs_on_play,
         e.runs_scored, e.seq, e.inning_before, e.balls_before, e.strikes_before, e.outs_before,
         e.unearned_runs, e.inherited_runs, e.charged_prev,   -- Oct 21
         case when jsonb_typeof(e.charged_runs) = 'array' then e.charged_runs end, e.charged_prev_session   -- R3 Stage B
    from jsonb_populate_recordset(null::public.game_events, coalesce(p_events, '[]'::jsonb)) e
   where e.id is not null
  on conflict (id) do nothing;
  get diagnostics v_ne = row_count;

  update public.sessions set sealed_at = now() where id = v_id;
  if v_link = 'linked' then
    perform public.r3_apply_relief(v_id);   -- R3 Stage B: charge the pitchers whose runners scored, same transaction
  end if;
  return jsonb_build_object('ok', true, 'status', v_status, 'pitches', v_np, 'events', v_ne)
         || case when v_link is not null then jsonb_build_object('relief', v_link) else '{}'::jsonb end;
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
  v_left smallint;
  v_final timestamptz;
  v_xr smallint; v_xer smallint; v_xbb smallint;
  v_result jsonb;
begin
  select kind, game_final_inning, game_outs_recorded, pitch_count_adjust, inherited_runners, runners_left,
         final_at, exit_runs, exit_er, exit_bb
    into v_kind, v_final_inning, v_outs_recorded, v_adjust, v_inherited, v_left, v_final, v_xr, v_xer, v_xbb
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
    -- R3 Stage B: plus the runs charged to him after he left (his runners who scored off the next pitcher)
    'runs', case when runs.pr is null and runs.er is null and v_xr is null then null else coalesce(runs.pr, 0) + coalesce(runs.er, 0) - runs.inh + coalesce(v_xr, 0) end,
    'er', case when runs.pu is null and runs.eu is null and v_xer is null then null
               else coalesce(runs.pr, 0) + coalesce(runs.er, 0) - runs.inh - coalesce(runs.pu, 0) - coalesce(runs.eu, 0) + coalesce(v_xer, 0) end,
    'exit_runs', v_xr, 'exit_er', v_xer, 'exit_bb', v_xbb,
    'provisional', v_final is null,   -- his line can still change (runners he left on); reports wait for final
    'ir', v_inherited,
    'irs', case when v_inherited is null then null else runs.inh end,
    'bb_charged_prev', bb_prev + ev_bb_prev,
    'runners_left', v_left,   -- Oct 22: runners on base when he came out (NULL: games saved before)
    'strikes', strikes,
    'strike_pct', case when pct_denom > 0 then round(100.0 * pct_num / pct_denom) else 0 end,
    'strike_pct_denominator', pct_denom,
    'in_zone', in_zone,
    'in_zone_pct', case when pitches > 0 then round(100.0 * in_zone / pitches) else 0 end,
    'first_pitch_pitches', fp_pitches,
    'first_pitch_strike_pct', case when fp_pitches > 0 then round(100.0 * fp_strikes / fp_pitches) else null end,
    'k', k + ev_k, 'bb', bb + ev_bb + coalesce(v_xbb, 0), 'h', h, 'xbh', xbh,
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

-- Every session saved before this is final (the backfill runs as the owner, so the lock allows it once).
update public.sessions set final_at = coalesce(sealed_at, ended_at) where ended_at is not null and final_at is null;

do $$ begin
  perform cron.unschedule('r3-final-lock');
exception when others then null;
end $$;
select cron.schedule('r3-final-lock', '*/15 * * * *', 'select public.r3_finalize_stale()');
