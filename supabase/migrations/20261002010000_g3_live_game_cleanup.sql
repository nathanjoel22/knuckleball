-- G3 (Joel, Oct 2 2026): Live Game cleanup + coach-notes follow-ups.
--
--  (2) Game reports count no-pitch events: game_events gains the count
--      before each event (and its order), written by the app from now on;
--      compute_game_summary adds IBB / auto-ball-four walks and auto-strike-
--      three strikeouts to BB / K / batters faced. Pitch stats are untouched.
--      (No game_events rows exist on staging or production as of this
--      migration, so nothing older needs a fallback.)
--  (3) Departed pitchers: sessions already carry the team they were charted
--      under (sessions.team_id) and coaches already read by that team
--      (is_team_coach(team_id)) -- that read rule is unchanged. New here: a
--      session can only be FILED under a team the pitcher is on now, or one
--      he has since left provided the session started before he left (a pen
--      charted offline before a removal still reaches the coach). Removal
--      deletes the pitcher_teams row, so departures are logged by trigger.
--      Coaches keep reading notes on their team's sessions after the
--      pitcher leaves; writing a note still needs him on the team.
--  (4) game_events.event_type gains 'illegal_pitch' (softball).
--  (5) game_events.event_type gains 'tiebreak_runner'; teams.level (level of
--      play, tied to the team's sport) decides when extra innings start.
--
-- No policy references teams or pitcher_teams directly (42P17).
--
-- Rollback (manual):
--   drop trigger if exists sessions_g3_team_check on public.sessions;
--   drop function if exists public.sessions_g3_team_check();
--   drop trigger if exists pitcher_teams_g3_departure on public.pitcher_teams;
--   drop function if exists public.pitcher_teams_g3_departure();
--   drop table if exists public.pitcher_team_departures;
--   drop policy "Notes readable by author, pitcher and his team's coaches" on public.session_notes;
--   create policy "Notes readable by author, pitcher and his coaches" on public.session_notes for select
--     using (author_id = auth.uid() or exists (select 1 from public.sessions s where s.id = session_notes.session_id
--            and s.pitcher_id = auth.uid()) or public.is_coach_of_session(session_id));
--   drop function if exists public.is_coach_of_session_team(uuid);
--   drop trigger if exists teams_z_level on public.teams; drop function if exists public.teams_level_default();
--   alter table public.teams drop constraint if exists teams_level_check; alter table public.teams drop column if exists level;
--   alter table public.game_events drop column if exists seq, drop column if exists inning_before,
--     drop column if exists balls_before, drop column if exists strikes_before, drop column if exists outs_before;
--   restore game_events_event_type_check without 'illegal_pitch','tiebreak_runner';
--   re-run 20260929010000_g2_foul_tip_strike_fix.sql's compute_game_summary.

-- ---------- (4)(5) event types + (2) count-before columns ----------
alter table public.game_events
  drop constraint game_events_event_type_check,
  add constraint game_events_event_type_check check (event_type in (
    'stolen_base','caught_stealing','pickoff','wild_pitch','passed_ball','balk','other',
    'intentional_walk','auto_ball','auto_strike','illegal_pitch','tiebreak_runner'
  ));

alter table public.game_events
  add column seq            integer,
  add column inning_before  smallint,
  add column balls_before   smallint,
  add column strikes_before smallint,
  add column outs_before    smallint;

comment on column public.game_events.seq is 'G3: the event''s place in the game''s one ordered log (shared with pitches.seq in the app). Null on rows saved before G3.';
comment on column public.game_events.balls_before is 'G3: the count when the event happened -- an auto ball with 3 balls before it is a walk.';

-- ---------- (5) level of play ----------
alter table public.teams add column level text;
update public.teams set level = case when sport = 'softball' then 'high_school_up' else 'college' end where level is null;
alter table public.teams alter column level set not null;
alter table public.teams add constraint teams_level_check check (
  (sport = 'baseball' and level in ('little_league','high_school','college'))
  or (sport = 'softball' and level in ('little_league','high_school_up'))
);
comment on column public.teams.level is 'G3: level of play, set by the head coach. Decides the first extra inning (baseball LL 7 / HS 8 / college 10; softball LL 7 / HS & up 8).';

-- New teams default by sport. Named to sort after teams_s1_sport, which
-- sets sport first.
create or replace function public.teams_level_default()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.level is null then
    new.level := case when new.sport = 'softball' then 'high_school_up' else 'college' end;
  end if;
  return new;
end;
$$;

create trigger teams_z_level
  before insert on public.teams
  for each row execute function public.teams_level_default();

-- ---------- (3) departures log + filing check ----------
create table public.pitcher_team_departures (
  pitcher_id uuid        not null references public.profiles(id) on delete cascade,
  team_id    uuid        not null references public.teams(id) on delete cascade,
  joined_at  timestamptz,
  left_at    timestamptz not null default now()
);
create index pitcher_team_departures_idx on public.pitcher_team_departures (pitcher_id, team_id);
comment on table public.pitcher_team_departures is
  'G3: one row each time a pitcher leaves or is removed from a team (pitcher_teams rows are deleted). Read only by SECURITY DEFINER functions; no client access.';
alter table public.pitcher_team_departures enable row level security;   -- no policies: no client access
revoke all on public.pitcher_team_departures from public, anon, authenticated;

create or replace function public.pitcher_teams_g3_departure()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.pitcher_team_departures (pitcher_id, team_id, joined_at)
  values (old.pitcher_id, old.team_id, old.joined_at);
  return old;
end;
$$;

create trigger pitcher_teams_g3_departure
  after delete on public.pitcher_teams
  for each row execute function public.pitcher_teams_g3_departure();

-- A new session may be filed under a team only if the pitcher is on it now,
-- or left it after the session started. team_id never changes afterwards.
create or replace function public.sessions_g3_team_check()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    if new.team_id is distinct from old.team_id then
      raise exception 'A session''s team can''t be changed' using errcode = 'check_violation';
    end if;
    return new;
  end if;
  if exists (select 1 from public.pitcher_teams pt where pt.pitcher_id = new.pitcher_id and pt.team_id = new.team_id)
     or exists (select 1 from public.pitcher_team_departures d
                 where d.pitcher_id = new.pitcher_id and d.team_id = new.team_id and new.started_at < d.left_at) then
    return new;
  end if;
  raise exception 'This pitcher isn''t on that team' using errcode = 'check_violation';
end;
$$;

create trigger sessions_g3_team_check
  before insert or update of team_id on public.sessions
  for each row execute function public.sessions_g3_team_check();

revoke all on function public.pitcher_teams_g3_departure() from public, anon, authenticated;
revoke all on function public.sessions_g3_team_check() from public, anon, authenticated;
revoke all on function public.teams_level_default() from public, anon, authenticated;

-- ---------- (3) notes: coaches keep reading their team's sessions' notes ----------
-- Is the caller a coach (head or assistant) of the team this session was
-- charted under? (No current-membership condition -- that stays on WRITES,
-- via is_coach_of_session.)
create or replace function public.is_coach_of_session_team(p_session_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.sessions s
      join public.team_coaches tc on tc.team_id = s.team_id and tc.coach_id = auth.uid()
     where s.id = p_session_id
  );
$$;
revoke all on function public.is_coach_of_session_team(uuid) from public, anon;
grant execute on function public.is_coach_of_session_team(uuid) to authenticated;

drop policy "Notes readable by author, pitcher and his coaches" on public.session_notes;
create policy "Notes readable by author, pitcher and his team's coaches"
  on public.session_notes for select
  using (
    author_id = auth.uid()
    or exists (select 1 from public.sessions s where s.id = session_notes.session_id and s.pitcher_id = auth.uid())
    or public.is_coach_of_session_team(session_id)
  );

-- ---------- (2) compute_game_summary counts walks / strikeouts from events ----------
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
      (result in ('strike_looking','strike_swinging','foul','foul_tip','in_play','sac_bunt','sac_fly','dropped_third')) as is_strike_result,
      (result not in ('interference','other')) as counts_toward_pct,
      public.is_strike_cell(actual_row, actual_col) as in_zone,
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
  -- G3: no-pitch events that end an at-bat. Not pitches -- they never touch
  -- pitch count, strike %, zone or first-pitch numbers.
  ev as (
    select at_bat_index,
      (event_type = 'intentional_walk' or (event_type = 'auto_ball' and balls_before >= 3)) as is_bb,
      (event_type = 'auto_strike' and strikes_before >= 2) as is_k
      from public.game_events
     where session_id = p_session_id and event_type in ('intentional_walk','auto_ball','auto_strike')
  ),
  evagg as (
    select count(*) filter (where is_bb) as ev_bb, count(*) filter (where is_k) as ev_k
      from ev
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
  from agg, evagg, bf;

  return v_result;
end;
$$;

revoke all on function public.compute_game_summary(uuid) from public, anon;
grant execute on function public.compute_game_summary(uuid) to authenticated;
