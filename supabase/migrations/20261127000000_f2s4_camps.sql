-- F2 Stage 4 (Joel, Nov 20 2026; decisions in plans/f2-preconditions.md): Create Temporary Team/Camp Roster. A facility
-- manager makes a camp on one side: a name, one coach, pitchers from anywhere on the side, and one day or a range
-- (Eastern days, as every date rule here). The camp's coach charts its pitchers on its days only -- the same narrow grant
-- as a one-session assignment (the charting fields, nothing else), for as many sessions as the days allow. Each camp
-- session carries the camp (camp_id) and a copy of its name (camp_name) for History. A pitcher's own coach never changes.
-- No grant and no policy on the two new tables (policies stay 32); nothing existing reads them.

create table public.camp_rosters (
  id          uuid primary key default gen_random_uuid(),
  team_id     uuid not null references public.teams(id) on delete cascade,   -- the facility side (so one sport)
  name        text not null check (char_length(btrim(name)) between 2 and 60),
  coach_id    uuid references public.profiles(id) on delete set null,       -- a deleted coach's camp lists for nobody
  first_day   date not null,
  last_day    date not null,
  created_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  ended_at    timestamptz,                                                    -- ended early (kept: its name stays on sessions)
  check (last_day >= first_day and last_day - first_day <= 92)
);
create index camp_rosters_team on public.camp_rosters (team_id);
create index camp_rosters_coach on public.camp_rosters (coach_id);
create table public.camp_roster_pitchers (
  camp_id    uuid not null references public.camp_rosters(id) on delete cascade,
  pitcher_id uuid not null references public.profiles(id) on delete cascade,
  primary key (camp_id, pitcher_id)
);
alter table public.camp_rosters enable row level security;
alter table public.camp_roster_pitchers enable row level security;
revoke all on public.camp_rosters from public, anon, authenticated;
revoke all on public.camp_roster_pitchers from public, anon, authenticated;

-- The session carries its camp; camps are never deleted (only ended), so a session's camp never disappears.
alter table public.sessions add column camp_id uuid references public.camp_rosters(id) on delete restrict,
                            add column camp_name text;

-- Saved sessions can't change their camp (the H1 lock, for the two new columns).
create or replace function public.sessions_f2_camp_lock()
 returns trigger language plpgsql set search_path to '' as $$
begin
  if old.ended_at is not null and (new.camp_id, new.camp_name) is distinct from (old.camp_id, old.camp_name) then
    raise exception 'session_saved_locked' using detail = 'A saved session''s camp can''t change.';
  end if;
  return new;
end;
$$;
create trigger sessions_f2_camp_lock before update on public.sessions for each row execute function public.sessions_f2_camp_lock();

-- Today, Eastern.
create or replace function public.f2_today_et() returns date language sql stable set search_path to '' as $$
  select (now() at time zone 'America/New_York')::date
$$;

-- The caller is the side's manager (head of a facility side), as their coach profile on it.
create or replace function public.f2_side_manager(p_team uuid)
 returns uuid language sql stable security definer set search_path to '' as $$
  select t.coach_id from public.teams t join public.profiles pr on pr.id = t.coach_id
   where t.id = p_team and t.kind = 'facility' and pr.account_id = auth.uid()
$$;
revoke all on function public.f2_side_manager(uuid) from public, anon, authenticated;

-- Shared checks for create / update: name, coach on the side, every pitcher on the side, the days.
create or replace function public.f2_camp_check(p_team uuid, p_name text, p_coach uuid, p_pitchers uuid[], p_first date, p_last date)
 returns text language plpgsql stable security definer set search_path to '' as $$
begin
  if char_length(btrim(coalesce(p_name, ''))) not between 2 and 60 then return 'name_invalid'; end if;
  if p_first is null or coalesce(p_last, p_first) < p_first or coalesce(p_last, p_first) - p_first > 92 then return 'dates_invalid'; end if;
  if not exists (select 1 from public.team_coaches where team_id = p_team and coach_id = p_coach) then return 'not_a_coach'; end if;
  if coalesce(cardinality(p_pitchers), 0) = 0 then return 'no_pitchers'; end if;
  if exists (select 1 from unnest(p_pitchers) x(id) where not exists (select 1 from public.pitcher_teams pt where pt.team_id = p_team and pt.pitcher_id = x.id)) then
    return 'not_on_side';
  end if;
  return null;
end;
$$;
revoke all on function public.f2_camp_check(uuid, text, uuid, uuid[], date, date) from public, anon, authenticated;

create or replace function public.create_camp(p_team uuid, p_name text, p_coach uuid, p_pitchers uuid[], p_first date, p_last date default null)
 returns jsonb language plpgsql volatile security definer set search_path to '' as $$
declare me uuid := public.f2_side_manager(p_team); err text; v_id uuid;
begin
  if me is null then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  if (select archived_at from public.teams where id = p_team) is not null then return jsonb_build_object('ok', false, 'error', 'team_archived'); end if;
  err := public.f2_camp_check(p_team, p_name, p_coach, p_pitchers, p_first, p_last);
  if err is not null then return jsonb_build_object('ok', false, 'error', err); end if;
  insert into public.camp_rosters (team_id, name, coach_id, first_day, last_day, created_by)
    values (p_team, btrim(p_name), p_coach, p_first, coalesce(p_last, p_first), me) returning id into v_id;
  insert into public.camp_roster_pitchers (camp_id, pitcher_id) select v_id, x from unnest(p_pitchers) x group by x;
  return jsonb_build_object('ok', true, 'id', v_id);
end;
$$;
revoke all on function public.create_camp(uuid, text, uuid, uuid[], date, date) from public, anon;
grant execute on function public.create_camp(uuid, text, uuid, uuid[], date, date) to authenticated;

create or replace function public.update_camp(p_id uuid, p_name text, p_coach uuid, p_pitchers uuid[], p_first date, p_last date default null)
 returns jsonb language plpgsql volatile security definer set search_path to '' as $$
declare c public.camp_rosters%rowtype; err text;
begin
  select * into c from public.camp_rosters where id = p_id;
  if not found or public.f2_side_manager(c.team_id) is null then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  if c.ended_at is not null then return jsonb_build_object('ok', false, 'error', 'camp_ended'); end if;
  err := public.f2_camp_check(c.team_id, p_name, p_coach, p_pitchers, p_first, p_last);
  if err is not null then return jsonb_build_object('ok', false, 'error', err); end if;
  update public.camp_rosters set name = btrim(p_name), coach_id = p_coach, first_day = p_first, last_day = coalesce(p_last, p_first), updated_at = now()
   where id = p_id;
  delete from public.camp_roster_pitchers where camp_id = p_id and pitcher_id <> all(p_pitchers);
  insert into public.camp_roster_pitchers (camp_id, pitcher_id) select p_id, x from unnest(p_pitchers) x group by x on conflict do nothing;
  return jsonb_build_object('ok', true, 'id', p_id);
end;
$$;
revoke all on function public.update_camp(uuid, text, uuid, uuid[], date, date) from public, anon;
grant execute on function public.update_camp(uuid, text, uuid, uuid[], date, date) to authenticated;

create or replace function public.end_camp(p_id uuid)
 returns jsonb language plpgsql volatile security definer set search_path to '' as $$
declare c public.camp_rosters%rowtype;
begin
  select * into c from public.camp_rosters where id = p_id;
  if not found or public.f2_side_manager(c.team_id) is null then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  if c.ended_at is null then update public.camp_rosters set ended_at = now(), updated_at = now() where id = p_id; end if;
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.end_camp(uuid) from public, anon;
grant execute on function public.end_camp(uuid) to authenticated;

-- The manager's list: the side's live camps (not ended, last day today or later, Eastern), each with its coach and pitchers.
create or replace function public.facility_camps(p_team uuid)
 returns jsonb language plpgsql stable security definer set search_path to '' as $$
begin
  if public.f2_side_manager(p_team) is null then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  return jsonb_build_object('ok', true, 'camps', coalesce((
    select jsonb_agg(jsonb_build_object('id', c.id, 'name', c.name, 'coach_id', c.coach_id, 'coach_name', cp.full_name,
             'first_day', c.first_day, 'last_day', c.last_day,
             'pitchers', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'name', p.full_name) order by p.full_name)
                                     from public.camp_roster_pitchers x join public.profiles p on p.id = x.pitcher_id where x.camp_id = c.id), '[]'::jsonb))
           order by c.first_day, c.name)
      from public.camp_rosters c left join public.profiles cp on cp.id = c.coach_id
     where c.team_id = p_team and c.ended_at is null and c.last_day >= public.f2_today_et()), '[]'::jsonb));
end;
$$;
revoke all on function public.facility_camps(uuid) from public, anon;
grant execute on function public.facility_camps(uuid) to authenticated;

-- The camp coach's list: their live camps, each pitcher with exactly the charting fields (as my_assignments).
create or replace function public.my_camps()
 returns jsonb language sql stable security definer set search_path to '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', c.id, 'team_id', c.team_id, 'name', c.name, 'first_day', c.first_day, 'last_day', c.last_day,
           'pitchers', coalesce((select jsonb_agg(jsonb_build_object(
                 'id', p.id, 'full_name', p.full_name, 'sport', p.sport, 'pitch_types', p.pitch_types, 'throws', p.throws,
                 'uses_radar_gun', p.uses_radar_gun, 'relative_accuracy_enabled', p.relative_accuracy_enabled,
                 'zones', coalesce((select jsonb_agg(jsonb_build_object('pitch_type', z.pitch_type, 'batter_side', z.batter_side, 'cells', z.cells))
                                      from public.accuracy_zones z where z.pitcher_id = p.id), '[]'::jsonb)) order by p.full_name)
               from public.camp_roster_pitchers x join public.profiles p on p.id = x.pitcher_id where x.camp_id = c.id), '[]'::jsonb))
           order by c.first_day, c.name), '[]'::jsonb)
    from public.camp_rosters c
    join public.profiles cp on cp.id = c.coach_id and cp.account_id = auth.uid()
    join public.teams t on t.id = c.team_id and t.archived_at is null
   where c.ended_at is null and c.last_day >= public.f2_today_et()
$$;
revoke all on function public.my_camps() from public, anon;
grant execute on function public.my_camps() to authenticated;

-- sync_session: F2 Stage 1's definition plus the camp (marked "F2 Stage 4").
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
    v_owners  := case when jsonb_typeof(p_session -> 'left_owners') = 'object' then p_session -> 'left_owners' end;
    if v_owners is not null then
      perform (x.value)::uuid from jsonb_each_text(v_owners) x;   -- every owner a session id
      if exists (select 1 from jsonb_object_keys(v_owners) k where k not in ('1', '2', '3')) then raise exception 'bad base'; end if;
    end if;
  exception when others then
    return jsonb_build_object('ok', false, 'error', 'invalid_session');
  end;
  if v_id is null or v_pitcher is null or v_logged is null   -- P2-01: v_team may be NULL (an independent pen)
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
                                 camp_id, camp_name)
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
            v_camp, v_camp_name);   -- F2 Stage 4
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
