-- C1 Stage C (Joel, Nov 25 2026; plans/c1-charting-parts.md, decisions in plans/c1-preconditions.md): putting the pieces
-- of a shared session together. Each charter saved their own piece (sync_session, Stage B), marked with the live
-- session and each pitch's number (live_seq). When every piece is in -- every part's holder has left and every piece
-- they left with is saved (or deleted) -- the server CREATES one combined session from them, pitch by pitch:
--   * the call (type, target) from the Intent piece, everything else (location, result, the play, velocity, the
--     game's events, the line) from the Outcome piece; a pitch in one piece only keeps only that part;
--   * an Outcome pitch that was never matched (live_seq null) is kept with no call; an unmatched call is left out
--     ("we can only report what we can reconcile");
--   * a part nobody ever charted is simply empty (charted_intent / charted_outcome say which);
--   * accuracy (pens) scores exact / miss where both parts exist; Relative Accuracy needs both on one device, so none.
-- The pieces are never edited (saved sessions are immutable): the combined session points back (compiled_from), the
-- app hides a piece once its combined session exists, and a piece never has a stats row, leaderboard row or baseline.
-- Three hours (pg_cron c1-compile-stale, every 15 minutes): a live session with a part still open three hours after the
-- most recent saved piece (or with no activity for three hours) is closed and compiled "as it was": an open part with
-- no saved piece is filled from what reached the server as it was tapped (live_pitches).
-- The report is made as for any new session (the first time someone with report rights has it on screen) and frozen.
-- Policies unchanged (32 / 12). Rollback: supabase/rollback/20261201000000_c1c_compile_down.sql.

alter table public.sessions add column compiled_from uuid references public.live_sessions(id) on delete set null;
create unique index sessions_compiled_from on public.sessions (compiled_from) where compiled_from is not null;
comment on column public.sessions.compiled_from is 'C1 Stage C: this session was put together from the pieces of that live session.';
alter table public.live_sessions add column compiled_session_id uuid references public.sessions(id) on delete set null,
  add column compiled_at timestamptz, add column compile_error text;

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
      new.inherited_runners, new.runners_left, new.relieved_session_id, new.left_owners, new.purpose,
      new.charted_intent, new.charted_outcome, new.live_session_id, new.live_part, new.compiled_from)   -- C1 Stage A / B / C
     is distinct from
     (old.id, old.pitcher_id, old.team_id, old.logged_by, old.started_at, old.created_at, old.kind, old.sport,
      old.charting_perspective, old.opponent, old.game_final_inning, old.game_outs_recorded, old.ra_on, old.pitch_count_adjust,
      old.inherited_runners, old.runners_left, old.relieved_session_id, old.left_owners, old.purpose,
      old.charted_intent, old.charted_outcome, old.live_session_id, old.live_part, old.compiled_from) then
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

CREATE OR REPLACE FUNCTION public.finalize_session_stats(p_session uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  s public.sessions%rowtype;
  v_strike_results constant text[] := array['strike_looking', 'strike_swinging', 'foul', 'foul_tip', 'in_play',
                                            'sac_bunt', 'sac_fly', 'dropped_third'];   -- GAME_STRIKE_RESULTS
  v_game jsonb;
  r record;
begin
  select * into s from public.sessions where id = p_session;
  if not found then return; end if;
  if s.deleted_at is not null or s.ended_at is null or s.sealed_at is null or s.live_part is not null then   -- C1 C: a piece has no numbers (its combined session does)
    delete from public.session_stats where session_id = p_session;   -- only saved, live sessions have numbers
    return;
  end if;

  if s.kind = 'game' and s.charted_outcome then   -- C1 Stage A: an Intent-only game has no line (no results, counts or outs)
    v_game := public.compute_game_summary(p_session);
    if v_game is null or v_game ? 'error' then
      raise exception 'compute_game_summary: %', coalesce(v_game ->> 'error', 'null');
    end if;
    -- What the report's pitching line adds (template_game.ts): one WP per (inning, batter, count) however many runners
    -- moved on it; BK = balks, softball's illegal pitch too; SF / SAC; hits by type.
    v_game := v_game || jsonb_build_object(
      'wp', (select count(distinct coalesce(e.inning_before::text, '') || '|' || coalesce(e.at_bat_index::text, '') || '|'
                                   || coalesce(e.balls_before::text, '') || '|' || coalesce(e.strikes_before::text, ''))
               from public.game_events e where e.session_id = p_session and e.event_type = 'wild_pitch'),
      'bk', (select count(*) from public.game_events e
              where e.session_id = p_session
                and (e.event_type = 'balk' or (s.sport = 'softball' and e.event_type = 'illegal_pitch'))),
      'sf',  (select count(*) from public.pitches x where x.session_id = p_session and x.sacrifice = 'SF'),
      'sac', (select count(*) from public.pitches x where x.session_id = p_session and x.sacrifice = 'SAC'),
      'h_1b', (select count(*) from public.pitches x where x.session_id = p_session and x.result = 'in_play' and x.in_play_outcome = 'hit' and x.hit_type = '1B'),
      'h_2b', (select count(*) from public.pitches x where x.session_id = p_session and x.result = 'in_play' and x.in_play_outcome = 'hit' and x.hit_type = '2B'),
      'h_3b', (select count(*) from public.pitches x where x.session_id = p_session and x.result = 'in_play' and x.in_play_outcome = 'hit' and x.hit_type = '3B'),
      'h_hr', (select count(*) from public.pitches x where x.session_id = p_session and x.result = 'in_play' and x.in_play_outcome = 'hit' and x.hit_type = 'HR'),
      -- v2: History's game card innings (gameStats: the highest inning a pitch was thrown in, at least 1) -- not the
      -- summary's final_inning, which counts the inning the counter moved on to after his last out
      'innings', (select greatest(1, coalesce(max(x.inning), 1)) from public.pitches x where x.session_id = p_session));
  end if;

  with p as (
    select coalesce(x.type, '') as t,
           coalesce(x.batter_side, 'none') as side,
           coalesce(x.delivery, 'none') as dl,
           x.actual_row::text || '-' || x.actual_col::text as cell,
           x.velo, x.time_to_plate, x.accuracy_hit_kind, x.in_accuracy_zone,
           coalesce(case when s.kind = 'game' then x.result = any(v_strike_results)
                         else public.is_strike_cell(x.actual_row, x.actual_col) end, false) as k,
           x.actual_row is not null and x.target_row is not null and coalesce(case when x.accuracy_hit_kind is not null then x.accuracy_hit_kind in ('exact', 'ra')
                         else x.target_row = x.actual_row and x.target_col = x.actual_col end, false) as hit,
           (x.velo is not null and not public.is_default_velo_reading(x.velo, x.ts)) as vok,
           (x.result not in ('interference', 'other')) as pct,   -- compute_game_summary's strike % denominator
           (x.actual_row is not null) as located,                                   -- C1 Stage A
           (x.actual_row is not null and x.target_row is not null) as scored     -- both parts: the only pitches accuracy uses
      from public.pitches x
     where x.session_id = p_session
  )
  select
    (select count(*) from p)::int as n,
    (select count(*) filter (where k) from p)::int as strikes,
    (select count(*) filter (where located) from p)::int as located,
    (select count(*) filter (where scored) from p)::int as scored,
    (select count(*) filter (where hit) from p)::int as hits,
    (select count(*) filter (where accuracy_hit_kind = 'exact') from p)::int as exact_hits,
    (select count(*) filter (where accuracy_hit_kind = 'ra') from p)::int as ra_hits,
    (select count(*) filter (where in_accuracy_zone is not null) from p)::int as zone_total,
    (select count(*) filter (where in_accuracy_zone) from p)::int as zone_hits,
    (select count(*) filter (where vok) from p)::int as velo_n,
    (select coalesce(sum(velo) filter (where vok), 0) from p)::int as velo_sum,
    (select min(velo) filter (where vok) from p) as velo_min,
    (select max(velo) filter (where vok) from p) as velo_max,
    (select count(time_to_plate) from p)::int as ttp_n,
    (select coalesce(sum(time_to_plate), 0) from p) as ttp_sum,
    coalesce((
      select jsonb_object_agg(bt.t, jsonb_build_object(
               'n', bt.n, 'strikes', bt.strikes, 'hits', bt.hits, 'exact', bt.exact_hits, 'ra', bt.ra_hits,
               'zone_total', bt.zone_total, 'zone_hits', bt.zone_hits,
               'velo_n', bt.velo_n, 'velo_sum', bt.velo_sum, 'velo_min', bt.velo_min, 'velo_max', bt.velo_max)
             || case when s.kind = 'game' then jsonb_build_object('pct_n', bt.pct_n) else '{}'::jsonb end
             || jsonb_build_object(
               'cells', (select jsonb_object_agg(c.cell, c.n)
                           from (select cell, count(*) as n from p where p.t = bt.t and cell is not null group by cell) c),
               'side_strikes', (select jsonb_object_agg(sk.side, sk.k)
                                  from (select side, count(*) filter (where k) as k from p where p.t = bt.t group by side) sk),
               'delivery_strikes', (select jsonb_object_agg(dk.dl, dk.k)
                                      from (select dl, count(*) filter (where k) as k from p where p.t = bt.t group by dl) dk),
               'side_cells', (select jsonb_object_agg(sd.side, sd.cells)
                                from (select side, jsonb_object_agg(cell, n) as cells
                                        from (select side, cell, count(*) as n from p where p.t = bt.t and cell is not null group by side, cell) y
                                       group by side) sd),
               'delivery_cells', (select jsonb_object_agg(dd.dl, dd.cells)
                                    from (select dl, jsonb_object_agg(cell, n) as cells
                                            from (select dl, cell, count(*) as n from p where p.t = bt.t and cell is not null group by dl, cell) y
                                           group by dl) dd)))
        from (select t, count(*) as n, count(*) filter (where k) as strikes, count(*) filter (where hit) as hits,
                     count(*) filter (where accuracy_hit_kind = 'exact') as exact_hits,
                     count(*) filter (where accuracy_hit_kind = 'ra') as ra_hits,
                     count(*) filter (where in_accuracy_zone is not null) as zone_total,
                     count(*) filter (where in_accuracy_zone) as zone_hits,
                     count(*) filter (where vok) as velo_n, coalesce(sum(velo) filter (where vok), 0) as velo_sum,
                     min(velo) filter (where vok) as velo_min, max(velo) filter (where vok) as velo_max,
                     count(*) filter (where pct) as pct_n
                from p group by t) bt), '{}'::jsonb) as by_type,
    coalesce((
      select jsonb_object_agg(bs.side, jsonb_build_object('n', bs.n, 'strikes', bs.strikes, 'hits', bs.hits))
        from (select side, count(*) as n, count(*) filter (where k) as strikes, count(*) filter (where hit) as hits
                from p group by side) bs), '{}'::jsonb) as by_side,
    coalesce((select jsonb_object_agg(c.cell, c.n) from (select cell, count(*) as n from p where cell is not null group by cell) c), '{}'::jsonb) as cells
  into r;

  insert into public.session_stats (session_id, pitcher_id, team_id, sport, kind, started_at, pitches, pitch_count,
         strikes, hits, exact_hits, ra_hits, zone_total, zone_hits, velo_n, velo_sum, velo_min, velo_max, ttp_n, ttp_sum,
         by_type, by_side, cells, game, provisional, stats_version, computed_at, purpose,
         located, scored, charted_intent, charted_outcome)
  values (s.id, s.pitcher_id, s.team_id, coalesce(s.sport, 'baseball'), coalesce(s.kind, 'bullpen'), s.started_at,
          r.n, greatest(0, r.n + case when s.kind = 'game' then coalesce(s.pitch_count_adjust, 0) else 0 end),
          r.strikes, r.hits, r.exact_hits, r.ra_hits, r.zone_total, r.zone_hits,
          r.velo_n, r.velo_sum, r.velo_min, r.velo_max, r.ttp_n, r.ttp_sum,
          r.by_type, r.by_side, r.cells, v_game, s.kind = 'game' and s.final_at is null and s.charted_outcome, 3, now(), s.purpose,   -- SR1 Stage A: carried, not computed
          r.located, r.scored, s.charted_intent, s.charted_outcome)   -- C1 Stage A: v3
  on conflict (session_id) do update set
    pitcher_id = excluded.pitcher_id, team_id = excluded.team_id, sport = excluded.sport, kind = excluded.kind,
    started_at = excluded.started_at, pitches = excluded.pitches, pitch_count = excluded.pitch_count,
    strikes = excluded.strikes, hits = excluded.hits, exact_hits = excluded.exact_hits, ra_hits = excluded.ra_hits,
    zone_total = excluded.zone_total, zone_hits = excluded.zone_hits, velo_n = excluded.velo_n,
    velo_sum = excluded.velo_sum, velo_min = excluded.velo_min, velo_max = excluded.velo_max,
    ttp_n = excluded.ttp_n, ttp_sum = excluded.ttp_sum, by_type = excluded.by_type, by_side = excluded.by_side,
    cells = excluded.cells, game = excluded.game, provisional = excluded.provisional,
    stats_version = excluded.stats_version, computed_at = excluded.computed_at, purpose = excluded.purpose,
    located = excluded.located, scored = excluded.scored, charted_intent = excluded.charted_intent,
    charted_outcome = excluded.charted_outcome;
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_team_leaderboard(p_team_id uuid, p_window text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  c_tz       constant text := 'America/New_York';
  v_is_coach boolean;
  v_min      integer;
  v_start    timestamptz;
  v_end      timestamptz;
  v_result   jsonb;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  -- F1-A: a training facility has no leaderboard.
  if public.is_facility_team(p_team_id) then
    raise exception 'facility_team';
  end if;

  v_is_coach := public.is_team_coach(p_team_id);
  if not (v_is_coach or public.is_team_member(p_team_id) or public.f1g_linked_team(p_team_id, false)) then   -- F1-G: + linked parent / child
    raise exception 'not allowed';
  end if;

  if p_window = 'week' then
    v_min   := 10;
    v_start := date_trunc('week', now() at time zone c_tz) at time zone c_tz;
    v_end   := (date_trunc('week', now() at time zone c_tz) + interval '7 days') at time zone c_tz;
  elsif p_window = 'month' then
    v_min   := 25;
    v_start := date_trunc('month', now() at time zone c_tz) at time zone c_tz;
    v_end   := (date_trunc('month', now() at time zone c_tz) + interval '1 month') at time zone c_tz;
  elsif p_window = 'all' then
    v_min := 50;
  else
    raise exception 'invalid window';
  end if;

  -- P1-09: an archived team shows an empty board, like softball.
  if public.is_team_archived(p_team_id) then
    return jsonb_build_object(
      'window', p_window, 'minimum', v_min, 'is_coach', v_is_coach, 'generated_at', now(),
      'velocity', '[]'::jsonb, 'accuracy', '[]'::jsonb, 'strike', '[]'::jsonb,
      'disabled', 'archived');
  end if;

  if (select t.sport from public.teams t where t.id = p_team_id) = 'softball' then
    return jsonb_build_object(
      'window', p_window, 'minimum', v_min, 'is_coach', v_is_coach, 'generated_at', now(),
      'velocity', '[]'::jsonb, 'accuracy', '[]'::jsonb, 'strike', '[]'::jsonb,
      'disabled', 'softball');
  end if;

  with members as (
    select pt.pitcher_id, pr.full_name, pt.uniform_number
      from public.pitcher_teams pt
      join public.profiles pr on pr.id = pt.pitcher_id
     where pt.team_id = p_team_id
  ),
  pit as (
    select s.pitcher_id, p.id as pitch_id, p.ts, p.velo,
           (p.actual_row between 1 and 3 and p.actual_col between 1 and 3) as is_strike,
           -- U14 (Joel, Oct 15): one accuracy number. A pitch with a stored hit kind counts exact AND relative-accuracy
           -- hits; an older pitch keeps the exact-cell rule it always had.
           (case when p.accuracy_hit_kind is not null then p.accuracy_hit_kind in ('exact', 'ra')
                 else p.target_row = p.actual_row and p.target_col = p.actual_col end)   as is_exact,
           (p.velo is not null
              and not public.is_default_velo_reading(p.velo, p.ts)
              and not exists (select 1 from public.leaderboard_exclusions e
                               where e.pitch_id = p.id and e.team_id = p_team_id)) as velo_ok
      from public.pitches p
      join public.sessions s on s.id = p.session_id
     where s.team_id = p_team_id
       and s.deleted_at is null
       and s.kind = 'bullpen'
       and s.charted_intent and s.charted_outcome   -- C1 Stage A: only pens charted in full
       and s.live_part is null                     -- C1 Stage C: a piece never counts (its combined session does)
       and s.pitcher_id in (select pitcher_id from members)
       and (v_start is null or (p.ts >= v_start and p.ts < v_end))
  ),
  agg as (
    select m.pitcher_id, m.full_name, m.uniform_number,
           count(*)::int as n,
           round(100.0 * count(*) filter (where pit.is_exact)  / count(*))::int as acc,
           round(100.0 * count(*) filter (where pit.is_strike) / count(*))::int as strike
      from members m
      join pit on pit.pitcher_id = m.pitcher_id
     group by m.pitcher_id, m.full_name, m.uniform_number
  ),
  peak as (
    select distinct on (pitcher_id) pitcher_id, pitch_id, ts, velo
      from pit
     where velo_ok
     order by pitcher_id, velo desc, ts asc
  ),
  vel as (
    select a.full_name, a.uniform_number, a.n, a.pitcher_id, k.velo, k.pitch_id, k.ts,
           rank() over (order by k.velo desc) as rk
      from agg a
      join peak k on k.pitcher_id = a.pitcher_id
  ),
  acc as (
    select a.full_name, a.uniform_number, a.n, a.pitcher_id, a.acc as val,
           (a.n >= v_min) as qualified,
           case when a.n >= v_min then rank() over (partition by (a.n >= v_min) order by a.acc desc) end as rk
      from agg a
  ),
  stk as (
    select a.full_name, a.uniform_number, a.n, a.pitcher_id, a.strike as val,
           (a.n >= v_min) as qualified,
           case when a.n >= v_min then rank() over (partition by (a.n >= v_min) order by a.strike desc) end as rk
      from agg a
  )
  select jsonb_strip_nulls(jsonb_build_object(
    'window',       p_window,
    'minimum',      v_min,
    'is_coach',     v_is_coach,
    'window_start', v_start,
    'generated_at', now(),
    'velocity', coalesce((
      select jsonb_agg(jsonb_build_object(
               'rank', v.rk, 'name', v.full_name, 'number', v.uniform_number,
               'value', v.velo, 'pitch_count', v.n, 'is_me', public.can_chart_for(v.pitcher_id),
               'peak_pitch_id', case when v_is_coach then v.pitch_id end,
               'peak_pitch_ts', case when v_is_coach then v.ts end
             ) order by v.rk, v.full_name)
        from vel v), '[]'::jsonb),
    'accuracy', coalesce((
      select jsonb_agg(jsonb_build_object(
               'rank', x.rk, 'name', x.full_name, 'number', x.uniform_number,
               'value', x.val, 'pitch_count', x.n, 'qualified', x.qualified,
               'is_me', public.can_chart_for(x.pitcher_id)
             ) order by x.qualified desc, x.rk, x.n desc, x.full_name)
        from acc x), '[]'::jsonb),
    'strike', coalesce((
      select jsonb_agg(jsonb_build_object(
               'rank', x.rk, 'name', x.full_name, 'number', x.uniform_number,
               'value', x.val, 'pitch_count', x.n, 'qualified', x.qualified,
               'is_me', public.can_chart_for(x.pitcher_id)
             ) order by x.qualified desc, x.rk, x.n desc, x.full_name)
        from stk x), '[]'::jsonb),
    'excluded', case when v_is_coach then coalesce((
      select jsonb_agg(jsonb_build_object(
               'pitch_id', e.pitch_id, 'name', pr.full_name, 'value', pi.velo,
               'pitch_ts', pi.ts, 'excluded_at', e.excluded_at
             ) order by e.excluded_at desc)
        from public.leaderboard_exclusions e
        join public.pitches  pi on pi.id = e.pitch_id
        join public.sessions se on se.id = pi.session_id
        join public.profiles pr on pr.id = se.pitcher_id
       where e.team_id = p_team_id), '[]'::jsonb) end
  ))
  into v_result;

  return v_result;
end;
$function$;

-- Build the combined session. p_fill: parts with no saved piece to take from live_pitches (the three-hour job only).
create or replace function public.c1_compile(p_live uuid, p_fill text[] default '{}')
 returns uuid language plpgsql volatile security definer set search_path to '' as $$
declare
  l public.live_sessions%rowtype; b public.sessions%rowtype;
  v_ip uuid[]; v_op uuid[]; v_all uuid[]; v_id uuid := gen_random_uuid();
  v_fi boolean; v_fo boolean; v_hi boolean; v_ho boolean; v_n int;
begin
  select * into l from public.live_sessions where id = p_live for update;
  if not found or l.compiled_at is not null then return l.compiled_session_id; end if;
  v_ip := array(select s.id from public.sessions s where s.live_session_id = p_live and s.live_part = 'intent' and s.deleted_at is null and s.sealed_at is not null);
  v_op := array(select s.id from public.sessions s where s.live_session_id = p_live and s.live_part = 'outcome' and s.deleted_at is null and s.sealed_at is not null);
  v_all := v_ip || v_op;
  v_fi := cardinality(v_ip) = 0 and 'intent' = any(p_fill) and exists (select 1 from public.live_pitches x where x.live_id = p_live and x.intent_at is not null and not x.no_pitch);
  v_fo := cardinality(v_op) = 0 and 'outcome' = any(p_fill) and exists (select 1 from public.live_pitches x where x.live_id = p_live and x.outcome is not null);
  v_hi := cardinality(v_ip) > 0 or v_fi;
  v_ho := cardinality(v_op) > 0 or v_fo;
  if not (v_hi or v_ho) then   -- nothing was saved or reached the server: nothing to put together
    update public.live_sessions set compiled_at = now(), closed_at = coalesce(closed_at, now()) where id = p_live;
    return null;
  end if;
  -- the session's own fields: the Outcome piece's (it charted the game), else the Intent piece's
  select * into b from public.sessions s where s.id = any(v_all) order by (s.live_part = 'outcome') desc, s.ended_at desc limit 1;
  insert into public.sessions (id, pitcher_id, team_id, logged_by, started_at, ended_at, charting_perspective, kind, opponent,
         game_final_inning, game_outs_recorded, ra_on, pitch_count_adjust, inherited_runners, runners_left, purpose,
         charted_intent, charted_outcome, compiled_from, final_at)
  select v_id, l.pitcher_id, l.team_id,
         coalesce(b.logged_by, (select lp.holder_profile from public.live_parts lp where lp.live_id = p_live and lp.holder_profile is not null order by lp.joined_at limit 1), l.pitcher_id),
         coalesce((select min(s.started_at) from public.sessions s where s.id = any(v_all)), l.started_at),
         greatest(coalesce((select max(s.ended_at) from public.sessions s where s.id = any(v_all)), l.last_activity_at), l.started_at + interval '1 second'),
         coalesce(b.charting_perspective, 'behind_catcher'), l.kind,
         (select s.opponent from public.sessions s where s.id = any(v_op) and s.opponent is not null limit 1),
         case when l.kind = 'game' then (select max(s.game_final_inning) from public.sessions s where s.id = any(v_op)) end,
         case when l.kind = 'game' then (select sum(s.game_outs_recorded) from public.sessions s where s.id = any(v_op)) end,
         false,
         case when l.kind = 'game' then coalesce((select sum(s.pitch_count_adjust) from public.sessions s where s.id = any(v_op)), 0) else 0 end,
         case when l.kind = 'game' then (select s.inherited_runners from public.sessions s where s.id = any(v_op) order by s.started_at limit 1) end,
         case when l.kind = 'game' then (select s.runners_left from public.sessions s where s.id = any(v_op) order by s.ended_at desc limit 1) end,
         case when l.kind = 'bullpen' then coalesce((select s.purpose from public.sessions s where s.id = any(v_op) and s.purpose is not null limit 1),
                                                    (select s.purpose from public.sessions s where s.id = any(v_ip) and s.purpose is not null limit 1)) end,
         v_hi, v_ho, p_live, now();

  -- the pitches: every Outcome pitch (with its call when matched), then calls with no Outcome pitch at that number
  with o as (
    select p.id as src, p.type, p.velo, p.ts, p.actual_row, p.actual_col, p.accuracy_mode, p.batter_side, p.result, p.in_play_outcome,
           p.hit_type, p.fielder, p.delivery, p.inning, p.outs_before, p.balls_before, p.strikes_before, p.at_bat_index, p.bb_type,
           p.bb_x, p.bb_y, p.fielders, p.runners_before, p.batter_to, p.runner_advances, p.outs_on_play, p.runs_scored, p.sacrifice,
           p.bb_from_position, p.time_to_plate, p.spray_box, p.runners_after, p.spray_field, p.unearned_runs, p.inherited_runs,
           p.charged_prev, p.play_flags, p.live_seq
      from public.pitches p where p.session_id = any(v_op)
    union all
    select null, x.outcome ->> 'type', (x.outcome ->> 'velo')::int, x.outcome_at, (x.outcome ->> 'actual_row')::int, (x.outcome ->> 'actual_col')::int,
           null, x.outcome ->> 'batter_side', x.outcome ->> 'result', x.outcome ->> 'in_play_outcome', x.outcome ->> 'hit_type',
           null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null,
           null, null, null, null, null, null, null, x.seq
      from public.live_pitches x where v_fo and x.live_id = p_live and x.outcome is not null
  ), i as (
    select p.live_seq, p.type, p.target_row, p.target_col, p.batter_side, p.ts, p.delivery
      from public.pitches p where p.session_id = any(v_ip) and p.live_seq is not null
    union all
    select x.seq, x.type, x.target_row::int, x.target_col::int, x.batter_side, x.intent_at, null
      from public.live_pitches x where v_fi and x.live_id = p_live and x.intent_at is not null and not x.no_pitch
  )
  insert into public.pitches (id, session_id, type, velo, ts, target_row, target_col, actual_row, actual_col, accuracy_mode, batter_side, in_accuracy_zone, accuracy_zone_cells, kind, result, in_play_outcome, hit_type, fielder, delivery, inning, outs_before, balls_before, strikes_before, at_bat_index, bb_type, bb_x, bb_y, fielders, runners_before, batter_to, runner_advances, outs_on_play, runs_scored, sacrifice, bb_from_position, time_to_plate, spray_box, runners_after, spray_field, accuracy_hit_kind, unearned_runs, inherited_runs, charged_prev, play_flags, live_seq)
  select case when o.src is not null then md5(v_id::text || o.src::text)::uuid else md5(v_id::text || 'o' || coalesce(o.live_seq, 0)::text || o.ts::text)::uuid end,
         v_id, coalesce(i.type, o.type), o.velo, coalesce(o.ts, i.ts), i.target_row, i.target_col, o.actual_row, o.actual_col,
         o.accuracy_mode, coalesce(o.batter_side, i.batter_side), null::boolean, null::text[], l.kind, o.result, o.in_play_outcome,
         o.hit_type, o.fielder, coalesce(o.delivery, i.delivery), o.inning, o.outs_before, o.balls_before, o.strikes_before, o.at_bat_index, o.bb_type,
         o.bb_x, o.bb_y, o.fielders, o.runners_before, o.batter_to, o.runner_advances, o.outs_on_play, o.runs_scored, o.sacrifice,
         o.bb_from_position, o.time_to_plate, o.spray_box, o.runners_after, o.spray_field,
         case when i.target_row is not null and o.actual_row is not null then case when i.target_row = o.actual_row and i.target_col = o.actual_col then 'exact' else 'miss' end end,
         o.unearned_runs, o.inherited_runs, o.charged_prev, o.play_flags, coalesce(o.live_seq, i.live_seq)
    from o left join i on i.live_seq = o.live_seq
  union all
  select md5(v_id::text || 'i' || i.live_seq::text)::uuid, v_id, i.type, null, i.ts, i.target_row, i.target_col, null, null,
         null, i.batter_side, null, null, l.kind, null, null, null, null, i.delivery, null, null, null, null, null, null,
         null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, i.live_seq
    from i where not exists (select 1 from o where o.live_seq = i.live_seq);
  get diagnostics v_n = row_count;

  -- a game's events, from the Outcome piece(s), each pointing at its pitch in the combined session
  insert into public.game_events (id, session_id, at_bat_index, after_pitch_id, event_type, runners_before, runner_advances,
         outs_on_play, runs_scored, seq, inning_before, balls_before, strikes_before, outs_before, unearned_runs, inherited_runs, charged_prev)
  select md5(v_id::text || e.id::text)::uuid, v_id, e.at_bat_index,
         case when e.after_pitch_id is not null then md5(v_id::text || e.after_pitch_id::text)::uuid end,
         e.event_type, e.runners_before, e.runner_advances, e.outs_on_play, e.runs_scored, e.seq, e.inning_before,
         e.balls_before, e.strikes_before, e.outs_before, e.unearned_runs, e.inherited_runs, e.charged_prev
    from public.game_events e where e.session_id = any(v_op);

  update public.sessions set sealed_at = now() where id = v_id;   -- saved: the stats row follows (sessions_sc1_stats)
  update public.live_sessions set compiled_session_id = v_id, compiled_at = now(), compile_error = null, closed_at = coalesce(closed_at, now())
   where id = p_live;
  return v_id;
end;
$$;
revoke all on function public.c1_compile(uuid, text[]) from public, anon, authenticated;

-- Put the pieces together if they're all in; never stops the save that called it (an error is kept on the live row).
create or replace function public.c1_try_compile(p_live uuid)
 returns void language plpgsql volatile security definer set search_path to '' as $$
begin
  if exists (select 1 from public.live_parts where live_id = p_live and left_at is null) then return; end if;   -- someone's still charting
  if exists (select 1 from public.live_parts lp where lp.live_id = p_live and lp.piece_session_id is not null
              and not exists (select 1 from public.sessions s where s.id = lp.piece_session_id and (s.sealed_at is not null or s.deleted_at is not null))) then
    return;   -- a piece is still on its way (saved on a device, not synced yet)
  end if;
  begin
    perform public.c1_compile(p_live, '{}');
  exception when others then
    update public.live_sessions set compile_error = left(sqlerrm, 500) where id = p_live;
  end;
end;
$$;
revoke all on function public.c1_try_compile(uuid) from public, anon, authenticated;

-- The three-hour rule.
create or replace function public.c1_compile_stale()
 returns integer language plpgsql volatile security definer set search_path to '' as $$
declare r record; v_fill text[]; n int := 0;
begin
  for r in
    select l.id from public.live_sessions l
     where l.compiled_at is null
       and (l.last_activity_at < now() - interval '3 hours'
            or (select max(s.sealed_at) from public.sessions s where s.live_session_id = l.id) < now() - interval '3 hours')
  loop
    -- the parts still open with no saved piece are filled "as they were" from what reached the server
    v_fill := array(select lp.part from public.live_parts lp where lp.live_id = r.id and lp.left_at is null
                       and not exists (select 1 from public.sessions s where s.live_session_id = r.id and s.live_part = lp.part and s.deleted_at is null));
    update public.live_parts set left_at = now() where live_id = r.id and left_at is null;
    update public.live_sessions set closed_at = coalesce(closed_at, now()) where id = r.id;
    begin
      perform public.c1_compile(r.id, v_fill);
      n := n + 1;
    exception when others then
      update public.live_sessions set compile_error = left(sqlerrm, 500), compiled_at = now() where id = r.id;   -- not retried forever
    end;
  end loop;
  return n;
end;
$$;
revoke all on function public.c1_compile_stale() from public, anon, authenticated;

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
  v_assign   uuid;          -- F2: the one-session assignment this session was charted under
  v_assigned boolean := false;
  v_camp     uuid;          -- F2 Stage 4: the camp this session was charted for
  v_camp_name text;
  v_intent   boolean;       -- C1 Stage A: which parts this session charted (missing = both, as every older app)
  v_outcome  boolean;
  v_live     uuid;          -- C1 Stage B: the live session this piece belongs to (Stage C compiles the pieces)
  v_lpart    text;
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
    v_assign  := nullif(p_session ->> 'assignment_id', '')::uuid;   -- F2
    v_camp    := nullif(p_session ->> 'camp_id', '')::uuid;         -- F2 Stage 4
    v_intent  := coalesce((p_session ->> 'charted_intent')::boolean, true);    -- C1 Stage A
    v_outcome := coalesce((p_session ->> 'charted_outcome')::boolean, true);
    v_live    := nullif(p_session ->> 'live_session_id', '')::uuid;   -- C1 Stage B
    v_lpart   := case when p_session ->> 'live_part' in ('intent', 'outcome') then p_session ->> 'live_part' end;
    v_owners  := case when jsonb_typeof(p_session -> 'left_owners') = 'object' then p_session -> 'left_owners' end;
    if v_owners is not null then
      perform (x.value)::uuid from jsonb_each_text(v_owners) x;   -- every owner a session id
      if exists (select 1 from jsonb_object_keys(v_owners) k where k not in ('1', '2', '3')) then raise exception 'bad base'; end if;
    end if;
  exception when others then
    return jsonb_build_object('ok', false, 'error', 'invalid_session');
  end;
  if v_id is null or v_pitcher is null or v_logged is null   -- P2-01: v_team may be NULL (an independent pen)
     or not (v_intent or v_outcome)                           -- C1 Stage A: at least one part
     or jsonb_typeof(coalesce(p_pitches, '[]'::jsonb)) <> 'array'
     or jsonb_typeof(coalesce(p_events, '[]'::jsonb)) <> 'array' then
    return jsonb_build_object('ok', false, 'error', 'invalid_session');
  end if;
  if nullif(p_session ->> 'ended_at', '') is null or nullif(p_session ->> 'started_at', '') is null then
    return jsonb_build_object('ok', false, 'error', 'not_saved');   -- nothing unsaved ever reaches the server
  end if;

  select * into v_existing from public.sessions where id = v_id;
  if found then
    if not (public.can_chart_for(v_existing.pitcher_id) or public.coach_sees_pitcher(v_existing.team_id, v_existing.pitcher_id)) then   -- F1-G: + linked parent / child
      -- F2 (b): its own charter, once it's saved, hears that it's saved (an assigned coach can't read it any more)
      if v_existing.sealed_at is not null and v_existing.logged_by is not null and public.is_my_profile(v_existing.logged_by) then
        return jsonb_build_object('ok', true, 'status', 'already_saved', 'pitches', 0, 'events', 0);
      end if;
      return jsonb_build_object('ok', false, 'error', 'not_entitled');
    end if;
    if v_existing.sealed_at is not null then
      return jsonb_build_object('ok', true, 'status', 'already_saved', 'pitches', 0, 'events', 0);
    end if;
    v_status := 'completed';   -- an old-app sync that didn't finish
  else
    -- F2 (a): an open assignment the caller holds, for this pitcher and side, charted inside its window
    if v_assign is not null and exists (
         select 1 from public.session_assignments a
           join public.profiles c on c.id = a.coach_id
          where a.id = v_assign and a.pitcher_id = v_pitcher and a.team_id is not distinct from v_team
            and a.coach_id = v_logged and c.account_id = auth.uid()
            and a.released_at is null
            and (p_session ->> 'started_at')::timestamptz <= a.window_ends_at
            and (p_session ->> 'started_at')::timestamptz >= a.created_at - interval '5 minutes'
            and (a.cancelled_at is null or (p_session ->> 'started_at')::timestamptz < a.cancelled_at)) then
      v_assigned := true;
    end if;
    -- F2 Stage 4: a camp the caller coaches, on this side, with this pitcher in it, on one of its days (Eastern), and
    -- started before any early end; its name is copied onto the session, so a later rename never changes it
    if v_camp is not null then
      select c.name into v_camp_name from public.camp_rosters c join public.profiles cp on cp.id = c.coach_id
       where c.id = v_camp and c.team_id is not distinct from v_team and c.coach_id = v_logged and cp.account_id = auth.uid()
         and exists (select 1 from public.camp_roster_pitchers x where x.camp_id = c.id and x.pitcher_id = v_pitcher)
         and ((p_session ->> 'started_at')::timestamptz at time zone 'America/New_York')::date between c.first_day and c.last_day
         and (c.ended_at is null or (p_session ->> 'started_at')::timestamptz < c.ended_at);
      if v_camp_name is null then v_camp := null; end if;   -- not a valid camp session: saved (if otherwise allowed) with no camp
    end if;
    -- The caller is this pitcher, or a coach of the session's team, charting as one of
    -- their own profiles (F2: or the coach a one-session assignment names; Stage 4: or the camp's coach).
    if not (public.can_chart_for(v_pitcher) or public.coach_sees_pitcher(v_team, v_pitcher) or v_assigned or v_camp is not null)
       or not (public.is_my_profile(v_logged) or (v_logged = v_pitcher and public.can_chart_for(v_pitcher))) then
      -- F1-G: a linked parent or the child's sign-in charts AS the player (logged_by = the player, as when the
      -- creating parent charts), so History never calls it "Logged by coach"   -- F1-A: a facility assistant charts only their group
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
      -- P2-01: relief linking stays between games of one team; written NULL-safe so a missing team refuses (fails closed)
      elsif not (v_owner.kind = 'game' and v_team is not null and v_owner.team_id is not distinct from v_team
                 and v_owner.pitcher_id is distinct from v_pitcher
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
                                 inherited_runners, runners_left, relieved_session_id, left_owners, final_at, purpose,
                                 camp_id, camp_name, charted_intent, charted_outcome, live_session_id, live_part)
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
                 then null else now() end,
            -- SR1 Stage A: a bullpen's purpose from the start screen; anything else (a game, no tag, a value this
            -- server doesn't know) saves as no tag, so a session never sticks in the outbox over its tag
            case when coalesce(nullif(p_session ->> 'kind', ''), 'bullpen') = 'bullpen'
                  and p_session ->> 'purpose' in ('command', 'velocity', 'short_pen')
                 then p_session ->> 'purpose' end,
            v_camp, v_camp_name,   -- F2 Stage 4
            v_intent, v_outcome,   -- C1 Stage A
            case when v_lpart is not null and exists (select 1 from public.live_parts lp where lp.live_id = v_live and lp.holder_login = auth.uid()) then v_live end,
            case when v_lpart is not null and exists (select 1 from public.live_parts lp where lp.live_id = v_live and lp.holder_login = auth.uid()) then v_lpart end);   -- C1 Stage B: only a live session the caller charted in
  end if;

  insert into public.pitches (id, session_id, type, velo, ts, target_row, target_col, actual_row, actual_col,
         accuracy_mode, batter_side, in_accuracy_zone, accuracy_zone_cells, kind, result, in_play_outcome,
         hit_type, fielder, delivery, inning, outs_before, balls_before, strikes_before, at_bat_index, bb_type,
         bb_x, bb_y, fielders, runners_before, batter_to, runner_advances, outs_on_play, runs_scored, sacrifice,
         bb_from_position, time_to_plate, spray_box, runners_after, spray_field, accuracy_hit_kind,
         unearned_runs, inherited_runs, charged_prev, charged_runs, charged_prev_session, play_flags, live_seq)
  select r.id, v_id, r.type, r.velo, coalesce(r.ts, now()),
         -- C1 Stage A: a part that wasn't charted is empty, never a default. With Outcome, a missing location still
         -- saves as 0-0 as it always has (older apps); without it, there is none. Without Intent, there is no target.
         case when v_intent then r.target_row end, case when v_intent then r.target_col end,
         case when v_outcome then coalesce(r.actual_row, 0) else r.actual_row end,
         case when v_outcome then coalesce(r.actual_col, 0) else r.actual_col end,
         r.accuracy_mode, r.batter_side, r.in_accuracy_zone, r.accuracy_zone_cells,
         coalesce(r.kind, coalesce(nullif(p_session ->> 'kind', ''), 'bullpen')), r.result, r.in_play_outcome,
         r.hit_type, r.fielder, r.delivery, r.inning, r.outs_before, r.balls_before, r.strikes_before, r.at_bat_index,
         r.bb_type, r.bb_x, r.bb_y, r.fielders, r.runners_before, r.batter_to, r.runner_advances, r.outs_on_play,
         r.runs_scored, r.sacrifice, r.bb_from_position, r.time_to_plate, r.spray_box, r.runners_after, r.spray_field,
         r.accuracy_hit_kind,
         r.unearned_runs, r.inherited_runs, r.charged_prev,   -- Oct 21
         case when jsonb_typeof(r.charged_runs) = 'array' then r.charged_runs end, r.charged_prev_session,   -- R3 Stage B
         r.play_flags,   -- C1 Stage A (More Plays)
         r.live_seq      -- C1 Stage B: the live session's pitch number (null: not matched)
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
  -- C1 Stage C: a piece of a live session -- once every piece is in, the pieces are put together (never stops a save)
  if v_status = 'saved' and v_lpart is not null and v_live is not null then perform public.c1_try_compile(v_live); end if;
  -- F2: the save releases the assignment it was charted under (same transaction: a failed save releases nothing)
  if v_assign is not null then
    update public.session_assignments a set released_at = now(), session_id = v_id
     where a.id = v_assign and a.released_at is null and a.pitcher_id = v_pitcher
       and exists (select 1 from public.profiles c where c.id = a.coach_id and c.account_id = auth.uid());
  end if;
  if v_link = 'linked' then
    perform public.r3_apply_relief(v_id);   -- R3 Stage B: charge the pitchers whose runners scored, same transaction
  end if;
  return jsonb_build_object('ok', true, 'status', v_status, 'pitches', v_np, 'events', v_ne)
         || case when v_link is not null then jsonb_build_object('relief', v_link) else '{}'::jsonb end;
end;
$function$;

-- Leaving may be the last thing missing (the pieces were already saved).
create or replace function public.live_leave(p_live uuid, p_piece uuid default null)
 returns jsonb language plpgsql volatile security definer set search_path to '' as $$
begin
  update public.live_parts set left_at = now(), piece_session_id = coalesce(p_piece, piece_session_id)
   where live_id = p_live and holder_login = auth.uid() and left_at is null;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_holding'); end if;
  update public.live_sessions set last_activity_at = now(),
         closed_at = case when exists (select 1 from public.live_parts where live_id = p_live and left_at is null) then null else now() end
   where id = p_live;
  perform public.c1_try_compile(p_live);   -- C1 Stage C
  return jsonb_build_object('ok', true);
end;
$$;

select cron.schedule('c1-compile-stale', '*/15 * * * *', $$select public.c1_compile_stale()$$);

-- Pieces saved before this (Stage B, since Nov 24): no numbers of their own; then put together any whose pieces are all in.
delete from public.session_stats where session_id in (select id from public.sessions where live_part is not null);
do $$
declare r record;
begin
  for r in select id from public.live_sessions where compiled_at is null and closed_at is not null loop
    perform public.c1_try_compile(r.id);
  end loop;
end $$;
