-- SC1, the server half (Joel, Oct 28 2026; plans/sc1-preconditions.md and his answers there). Every saved session's
-- numbers are added up once, in the database, and kept in public.session_stats. Nothing in the app reads it yet.
--   * Hook: an AFTER trigger on sessions, so sync_session itself is unchanged. sync_session seals a session after its
--     pitches and events are in (same transaction), so the row sees all of them. The same trigger recomputes a game
--     when R3 changes it afterwards (exit_runs / exit_er / exit_bb by r3_apply_relief, final_at by r3_apply_relief or
--     the 6-hour job), and removes the row when the session becomes a tombstone (delete_session, the A1 purge -- the
--     session row stays, so ON DELETE CASCADE alone would never fire).
--   * Save anyway (Joel): a stats error never stops a save. It is caught (a savepoint), logged to
--     session_stats_failures, and the session has no row until public.sc1_try_finalize(id) is run again.
--   * Counts, never percentages: the app divides and rounds exactly as it does today, so the numbers match by
--     construction. Accuracy is the one U14 number (isHit): a stored hit kind 'exact' or 'ra', else the target cell.
--     Velocity leaves out Amendment 10's old 65 default (public.is_default_velo_reading). The pre-U7 relative accuracy
--     number is not stored (Joel). Games: compute_game_summary's JSON as-is (Joel: its rules everywhere), plus WP, BK,
--     SF / SAC and 1B / 2B / 3B / HR the way the report counts them.
--   * Read: exactly where the session's pitches are read (the pitches SELECT rule, through the same helpers; no
--     direct teams / pitcher_teams reference). No client writes. Policies 29 -> 30.
-- Rollback: supabase/rollback/20261028000000_sc1_session_stats_down.sql. Test: supabase/tests/sc1_session_stats.sql.

create table public.session_stats (
  session_id    uuid primary key references public.sessions(id) on delete cascade,
  pitcher_id    uuid,
  team_id       uuid,
  sport         text not null,
  kind          text not null,
  started_at    timestamptz not null,
  pitches       integer not null,             -- charted pitch rows
  pitch_count   integer not null,             -- with a game's + pitch count (pitch_count_adjust); = pitches for a pen
  strikes       integer not null,             -- pen: landed in the zone (isStrikeCell); game: the call (GAME_STRIKE_RESULTS)
  hits          integer not null,             -- the one accuracy number's numerator (isHit); denominator = pitches
  exact_hits    integer not null,             -- U14 hit kind 'exact'
  ra_hits       integer not null,             -- U14 hit kind 'ra'
  zone_total    integer not null,             -- U7 zone accuracy (older pens): pitches that had a zone
  zone_hits     integer not null,
  velo_n        integer not null,             -- readings that count (Amendment 10)
  velo_sum      integer not null,
  velo_min      integer,
  velo_max      integer,
  ttp_n         integer not null,             -- U11 time to home
  ttp_sum       numeric not null,
  by_type       jsonb not null,               -- per pitch type: the counts above, plus cells / side_cells / delivery_cells
  by_side       jsonb not null,               -- 'L' / 'R' / 'none': n, strikes, hits
  cells         jsonb not null,               -- "row-col" (catcher frame, as stored) -> pitches
  game          jsonb,                        -- games: compute_game_summary + wp, bk, sf, sac, h_1b, h_2b, h_3b, h_hr
  provisional   boolean not null default false,   -- a game whose line is still open (final_at NULL)
  stats_version integer not null,
  computed_at   timestamptz not null default now()
);

create table public.session_stats_failures (
  id         bigint generated always as identity primary key,
  session_id uuid not null,
  error      text not null,
  sqlstate   text,
  failed_at  timestamptz not null default now()
);

alter table public.session_stats enable row level security;
alter table public.session_stats_failures enable row level security;
revoke all on table public.session_stats from public, anon, authenticated;
revoke all on table public.session_stats_failures from public, anon, authenticated;
grant select on table public.session_stats to authenticated;

create policy "Session stats: read where the session's pitches are read" on public.session_stats
  for select using (exists (
    select 1 from public.sessions s
     where s.id = session_stats.session_id
       and (public.is_my_profile(s.pitcher_id) or public.is_team_coach(s.team_id)
            or public.is_current_coach_of_pitcher(s.pitcher_id, s.started_at))));

create or replace function public.finalize_session_stats(p_session uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s public.sessions%rowtype;
  v_strike_results constant text[] := array['strike_looking', 'strike_swinging', 'foul', 'foul_tip', 'in_play',
                                            'sac_bunt', 'sac_fly', 'dropped_third'];   -- GAME_STRIKE_RESULTS
  v_game jsonb;
  r record;
begin
  select * into s from public.sessions where id = p_session;
  if not found then return; end if;
  if s.deleted_at is not null or s.ended_at is null or s.sealed_at is null then
    delete from public.session_stats where session_id = p_session;   -- only saved, live sessions have numbers
    return;
  end if;

  if s.kind = 'game' then
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
      'h_hr', (select count(*) from public.pitches x where x.session_id = p_session and x.result = 'in_play' and x.in_play_outcome = 'hit' and x.hit_type = 'HR'));
  end if;

  with p as (
    select coalesce(x.type, '') as t,
           coalesce(x.batter_side, 'none') as side,
           coalesce(x.delivery, 'none') as dl,
           x.actual_row::text || '-' || x.actual_col::text as cell,
           x.velo, x.time_to_plate, x.accuracy_hit_kind, x.in_accuracy_zone,
           coalesce(case when s.kind = 'game' then x.result = any(v_strike_results)
                         else public.is_strike_cell(x.actual_row, x.actual_col) end, false) as k,
           coalesce(case when x.accuracy_hit_kind is not null then x.accuracy_hit_kind in ('exact', 'ra')
                         else x.target_row = x.actual_row and x.target_col = x.actual_col end, false) as hit,
           (x.velo is not null and not public.is_default_velo_reading(x.velo, x.ts)) as vok,
           (x.result not in ('interference', 'other')) as pct   -- compute_game_summary's strike % denominator
      from public.pitches x
     where x.session_id = p_session
  )
  select
    (select count(*) from p)::int as n,
    (select count(*) filter (where k) from p)::int as strikes,
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
                           from (select cell, count(*) as n from p where p.t = bt.t group by cell) c),
               'side_cells', (select jsonb_object_agg(sd.side, sd.cells)
                                from (select side, jsonb_object_agg(cell, n) as cells
                                        from (select side, cell, count(*) as n from p where p.t = bt.t group by side, cell) y
                                       group by side) sd),
               'delivery_cells', (select jsonb_object_agg(dd.dl, dd.cells)
                                    from (select dl, jsonb_object_agg(cell, n) as cells
                                            from (select dl, cell, count(*) as n from p where p.t = bt.t group by dl, cell) y
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
    coalesce((select jsonb_object_agg(c.cell, c.n) from (select cell, count(*) as n from p group by cell) c), '{}'::jsonb) as cells
  into r;

  insert into public.session_stats (session_id, pitcher_id, team_id, sport, kind, started_at, pitches, pitch_count,
         strikes, hits, exact_hits, ra_hits, zone_total, zone_hits, velo_n, velo_sum, velo_min, velo_max, ttp_n, ttp_sum,
         by_type, by_side, cells, game, provisional, stats_version, computed_at)
  values (s.id, s.pitcher_id, s.team_id, coalesce(s.sport, 'baseball'), coalesce(s.kind, 'bullpen'), s.started_at,
          r.n, greatest(0, r.n + case when s.kind = 'game' then coalesce(s.pitch_count_adjust, 0) else 0 end),
          r.strikes, r.hits, r.exact_hits, r.ra_hits, r.zone_total, r.zone_hits,
          r.velo_n, r.velo_sum, r.velo_min, r.velo_max, r.ttp_n, r.ttp_sum,
          r.by_type, r.by_side, r.cells, v_game, s.kind = 'game' and s.final_at is null, 1, now())
  on conflict (session_id) do update set
    pitcher_id = excluded.pitcher_id, team_id = excluded.team_id, sport = excluded.sport, kind = excluded.kind,
    started_at = excluded.started_at, pitches = excluded.pitches, pitch_count = excluded.pitch_count,
    strikes = excluded.strikes, hits = excluded.hits, exact_hits = excluded.exact_hits, ra_hits = excluded.ra_hits,
    zone_total = excluded.zone_total, zone_hits = excluded.zone_hits, velo_n = excluded.velo_n,
    velo_sum = excluded.velo_sum, velo_min = excluded.velo_min, velo_max = excluded.velo_max,
    ttp_n = excluded.ttp_n, ttp_sum = excluded.ttp_sum, by_type = excluded.by_type, by_side = excluded.by_side,
    cells = excluded.cells, game = excluded.game, provisional = excluded.provisional,
    stats_version = excluded.stats_version, computed_at = excluded.computed_at;
end;
$$;

-- Save anyway: any error in the stats is caught here (rolled back to this point only) and logged; the caller's save goes on.
create or replace function public.sc1_try_finalize(p_session uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_err text; v_state text;
begin
  begin
    perform public.finalize_session_stats(p_session);
    return true;
  exception when others then
    get stacked diagnostics v_err = message_text, v_state = returned_sqlstate;
  end;
  begin
    insert into public.session_stats_failures (session_id, error, sqlstate) values (p_session, v_err, v_state);
  exception when others then null;   -- even the log can't stop a save
  end;
  return false;
end;
$$;

create or replace function public.sc1_session_stats_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.deleted_at is not null then
    if old.deleted_at is null then
      begin
        delete from public.session_stats where session_id = new.id;   -- a tombstone has no numbers
      exception when others then null;
      end;
    end if;
  elsif new.sealed_at is not null
        and (old.sealed_at is null
             or old.exit_runs is distinct from new.exit_runs or old.exit_er is distinct from new.exit_er
             or old.exit_bb is distinct from new.exit_bb or old.final_at is distinct from new.final_at) then
    perform public.sc1_try_finalize(new.id);
  end if;
  return null;
end;
$$;

revoke all on function public.finalize_session_stats(uuid) from public, anon, authenticated;
revoke all on function public.sc1_try_finalize(uuid) from public, anon, authenticated;
revoke all on function public.sc1_session_stats_trigger() from public, anon, authenticated;

create trigger sessions_sc1_stats
  after update of sealed_at, exit_runs, exit_er, exit_bb, final_at, deleted_at on public.sessions
  for each row execute function public.sc1_session_stats_trigger();

-- Backfill: every saved, live session (all are sealed since the H1 grace close).
do $$
declare
  r record; v_ok int := 0; v_bad int := 0;
begin
  for r in select id from public.sessions where deleted_at is null and ended_at is not null and sealed_at is not null loop
    if public.sc1_try_finalize(r.id) then v_ok := v_ok + 1; else v_bad := v_bad + 1; end if;
  end loop;
  raise notice 'SC1 backfill: % rows written, % failures (see public.session_stats_failures)', v_ok, v_bad;
end $$;
