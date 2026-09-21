-- U8: team leaderboard (peak velocity, overall accuracy, strike %), weekly / monthly / all-time.
--
-- PRIVACY BOUNDARY. No policy on sessions or pitches is widened: a pitcher still cannot
-- read a teammate's sessions or pitches. The board comes from ONE SECURITY DEFINER function,
-- get_team_leaderboard(), which first checks the caller is a member or the coach of the team
-- (via is_team_member / is_team_coach, CLAUDE.md landmine 1) and then returns ONLY per-pitcher
-- aggregates: display name, team uniform number, category value, pitch count, rank, qualified
-- flag. No pitch rows, locations or session details. The one exception is the coach, who also
-- gets the id and date of each pitcher's peak-velocity pitch and the list of excluded readings,
-- because the exclude control needs them. Revoked from anon.
--
-- WHAT COUNTS. Sessions filed to this team only, not soft-deleted; pitchers who are CURRENT
-- members only. Windows are in America/New_York: week = Monday 00:00 through Sunday, month =
-- calendar month, all-time = everything. A pitch belongs to a window by pitches.ts (when it was
-- charted).
--   * Peak velocity: max recorded velocity. NULL excluded, coach-excluded readings excluded,
--     and pre-U6 default 65s excluded (is_default_velo_reading below). No minimum.
--   * Overall accuracy: % of pitches whose landing cell equals the target cell.
--   * Strike %: % of pitches landing in the inner 3x3 (rows 1-3, cols 1-3) -- the same test as
--     isStrikeCell() in bullpen-tracker.html and send-session-report/index.ts.
--   * Accuracy and strike % need a minimum number of pitches in the window: 10 (week),
--     25 (month), 50 (all-time). Ranking is on the displayed whole-number percentage, and ties
--     share a rank (1, 1, 3). Pitchers under the minimum are returned unranked, after the ranked.
--
-- LOCKSTEP PAIR. is_default_velo_reading() and U6_CUTOFF_TS in bullpen-tracker.html are the same
-- rule and must change together: a velocity of exactly 65 on a pitch charted before the U6
-- cutoff is the old slider's untouched default, i.e. NO reading. (1789965601 =
-- 2026-09-21 04:40:01 UTC.) Stored pitches are never modified.
--
-- leaderboard_exclusions lets a team's coach throw out one bad velocity reading without touching
-- the pitch itself. RLS: only that team's coach (is_team_coach) can read, insert or delete.
--
-- ---------------------------------------------------------------------------------
-- ROLLBACK (no automatic down-migration: write a NEW migration with this body and deploy it
-- staging-first, per DEPLOY.md):
--
--   drop function if exists public.get_team_leaderboard(uuid, text);
--   drop table if exists public.leaderboard_exclusions;
--   drop function if exists public.leaderboard_exclusions_stamp();
--   drop function if exists public.is_default_velo_reading(integer, timestamptz);
--
-- Dropping leaderboard_exclusions forgets which readings a coach excluded. No pitch data is
-- touched either way.
-- ---------------------------------------------------------------------------------

-- 1. The one server-side definition of "pre-U6 default 65".
create or replace function public.is_default_velo_reading(p_velo integer, p_ts timestamptz)
returns boolean
language sql
stable
set search_path = ''
as $$
  select p_velo = 65 and p_ts < to_timestamp(1789965601)   -- keep in lockstep with U6_CUTOFF_TS
$$;

-- 2. Coach-excluded readings. Real foreign keys (CLAUDE.md landmine 2).
create table public.leaderboard_exclusions (
  pitch_id    uuid        not null references public.pitches(id) on delete cascade,
  team_id     uuid        not null references public.teams(id) on delete cascade,
  excluded_by uuid        references public.profiles(id) on delete set null,
  excluded_at timestamptz not null default now(),
  primary key (pitch_id, team_id)
);

alter table public.leaderboard_exclusions enable row level security;

revoke all on table public.leaderboard_exclusions from anon, public;
grant select, insert, delete on table public.leaderboard_exclusions to authenticated;

create policy "Coach manages leaderboard exclusions for own team"
  on public.leaderboard_exclusions
  for all
  to authenticated
  using      (public.is_team_coach(team_id))
  with check (public.is_team_coach(team_id));

create or replace function public.leaderboard_exclusions_stamp()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.excluded_by := auth.uid();
  new.excluded_at := now();
  return new;
end;
$$;

create trigger leaderboard_exclusions_stamp
  before insert on public.leaderboard_exclusions
  for each row execute function public.leaderboard_exclusions_stamp();

-- 3. The board.
create or replace function public.get_team_leaderboard(p_team_id uuid, p_window text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c_tz       constant text := 'America/New_York';
  v_uid      uuid := auth.uid();
  v_is_coach boolean;
  v_min      integer;
  v_start    timestamptz;
  v_end      timestamptz;
  v_result   jsonb;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  v_is_coach := public.is_team_coach(p_team_id);
  if not (v_is_coach or public.is_team_member(p_team_id)) then
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
    v_min := 50;   -- v_start / v_end stay null: no bounds
  else
    raise exception 'invalid window';
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
           (p.target_row = p.actual_row and p.target_col = p.actual_col)   as is_exact,
           (p.velo is not null
              and not public.is_default_velo_reading(p.velo, p.ts)
              and not exists (select 1 from public.leaderboard_exclusions e
                               where e.pitch_id = p.id and e.team_id = p_team_id)) as velo_ok
      from public.pitches p
      join public.sessions s on s.id = p.session_id
     where s.team_id = p_team_id
       and s.deleted_at is null
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
               'value', v.velo, 'pitch_count', v.n, 'is_me', (v.pitcher_id = v_uid),
               'peak_pitch_id', case when v_is_coach then v.pitch_id end,
               'peak_pitch_ts', case when v_is_coach then v.ts end
             ) order by v.rk, v.full_name)
        from vel v), '[]'::jsonb),
    'accuracy', coalesce((
      select jsonb_agg(jsonb_build_object(
               'rank', x.rk, 'name', x.full_name, 'number', x.uniform_number,
               'value', x.val, 'pitch_count', x.n, 'qualified', x.qualified,
               'is_me', (x.pitcher_id = v_uid)
             ) order by x.qualified desc, x.rk, x.n desc, x.full_name)
        from acc x), '[]'::jsonb),
    'strike', coalesce((
      select jsonb_agg(jsonb_build_object(
               'rank', x.rk, 'name', x.full_name, 'number', x.uniform_number,
               'value', x.val, 'pitch_count', x.n, 'qualified', x.qualified,
               'is_me', (x.pitcher_id = v_uid)
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
$$;

revoke all on function public.get_team_leaderboard(uuid, text) from public, anon;
grant execute on function public.get_team_leaderboard(uuid, text) to authenticated;
