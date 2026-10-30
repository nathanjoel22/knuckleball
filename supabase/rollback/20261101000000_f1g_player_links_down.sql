-- Rollback for 20261101000000_f1g_player_links (F1-G). Refuses while anyone is linked or a child's sign-in exists
-- (their profiles would break the restored role constraint); remove the links and those logins first.
do $$
begin
  if exists (select 1 from public.player_links) or exists (select 1 from public.profiles where role = 'child') then
    raise exception 'f1g_down: linked sign-ins exist -- remove them first';
  end if;
end $$;

-- read rules back to their F1-C1 form
alter policy "Sessions: read by the pitcher, the recording team's coaches and" on public.sessions
  using (public.is_my_profile(pitcher_id) or public.coach_sees_pitcher(team_id, pitcher_id) or public.is_current_coach_of_pitcher(pitcher_id, started_at));
alter policy "Sessions: report link written by the pitcher and the team's coa" on public.sessions
  using (public.is_my_profile(pitcher_id) or public.coach_sees_pitcher(team_id, pitcher_id))
  with check (public.is_my_profile(pitcher_id) or public.coach_sees_pitcher(team_id, pitcher_id));
alter policy "Pitches: read by the pitcher, the recording team's coaches and " on public.pitches
  using (exists (select 1 from public.sessions s where s.id = pitches.session_id
                   and (public.is_my_profile(s.pitcher_id) or public.coach_sees_pitcher(s.team_id, s.pitcher_id) or public.is_current_coach_of_pitcher(s.pitcher_id, s.started_at))));
alter policy "Game events: read by the pitcher, the recording team's coaches " on public.game_events
  using (exists (select 1 from public.sessions s where s.id = game_events.session_id
                   and (public.is_my_profile(s.pitcher_id) or public.coach_sees_pitcher(s.team_id, s.pitcher_id) or public.is_current_coach_of_pitcher(s.pitcher_id, s.started_at))));
alter policy "Session stats: read where the session's pitches are read" on public.session_stats
  using (exists (select 1 from public.sessions s where s.id = session_stats.session_id
                   and (public.is_my_profile(s.pitcher_id) or public.coach_sees_pitcher(s.team_id, s.pitcher_id) or public.is_current_coach_of_pitcher(s.pitcher_id, s.started_at))));
alter policy "Notes readable by author, pitcher, the recording team's coaches" on public.session_notes
  using (public.is_my_profile(author_id)
         or exists (select 1 from public.sessions s where s.id = session_notes.session_id and public.is_my_profile(s.pitcher_id))
         or public.is_coach_of_session_team(session_id)
         or exists (select 1 from public.sessions s where s.id = session_notes.session_id and public.is_current_coach_of_pitcher(s.pitcher_id, s.started_at)));
alter policy "Users view own profile" on public.profiles using (account_id = auth.uid());
alter policy "Pitchers view own memberships" on public.pitcher_teams using (public.is_my_profile(pitcher_id));
alter policy "Pitchers view teams they belong to" on public.teams using (public.is_team_member(id));
alter policy "Pitcher or their coach manages zones" on public.accuracy_zones
  using (public.is_my_profile(pitcher_id) or public.is_coach_of_pitcher(pitcher_id))
  with check (public.is_my_profile(pitcher_id) or public.is_coach_of_pitcher(pitcher_id));

-- functions back to their F1-C1 definitions
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
    if not (public.is_my_profile(v_existing.pitcher_id) or public.coach_sees_pitcher(v_existing.team_id, v_existing.pitcher_id)) then
      return jsonb_build_object('ok', false, 'error', 'not_entitled');
    end if;
    if v_existing.sealed_at is not null then
      return jsonb_build_object('ok', true, 'status', 'already_saved', 'pitches', 0, 'events', 0);
    end if;
    v_status := 'completed';   -- an old-app sync that didn't finish
  else
    -- The caller is this pitcher, or a coach of the session's team, charting as one of
    -- their own profiles.
    if not (public.is_my_profile(v_pitcher) or public.coach_sees_pitcher(v_team, v_pitcher)) or not public.is_my_profile(v_logged) then   -- F1-A: a facility assistant charts only their group
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
               'value', v.velo, 'pitch_count', v.n, 'is_me', public.is_my_profile(v.pitcher_id),
               'peak_pitch_id', case when v_is_coach then v.pitch_id end,
               'peak_pitch_ts', case when v_is_coach then v.ts end
             ) order by v.rk, v.full_name)
        from vel v), '[]'::jsonb),
    'accuracy', coalesce((
      select jsonb_agg(jsonb_build_object(
               'rank', x.rk, 'name', x.full_name, 'number', x.uniform_number,
               'value', x.val, 'pitch_count', x.n, 'qualified', x.qualified,
               'is_me', public.is_my_profile(x.pitcher_id)
             ) order by x.qualified desc, x.rk, x.n desc, x.full_name)
        from acc x), '[]'::jsonb),
    'strike', coalesce((
      select jsonb_agg(jsonb_build_object(
               'rank', x.rk, 'name', x.full_name, 'number', x.uniform_number,
               'value', x.val, 'pitch_count', x.n, 'qualified', x.qualified,
               'is_me', public.is_my_profile(x.pitcher_id)
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

CREATE OR REPLACE FUNCTION public.pitcher_report_block(p_pitcher_id uuid)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select case
    when acct.email_verified_at is null then 'unverified'
    when acct.age_attestation is null then 'age_not_answered'
    when acct.age_attestation = 'minor_13_17' and acct.guardian_consented_at is null then 'guardian_pending'
    when pr.managed_by is not null and pr.guardian_consented_at is null then 'consent_missing'
  end
    from public.profiles pr join public.profiles acct on acct.id = pr.account_id
   where pr.id = p_pitcher_id
     and (public.is_my_profile(p_pitcher_id) or public.is_coach_of_pitcher(p_pitcher_id));
$function$;

CREATE OR REPLACE FUNCTION public.s1_profiles_sport()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_intended text;
begin
  if tg_op = 'INSERT' then
    new.account_id := coalesce(new.account_id, new.id);
    if new.role = 'parent' then
      return new;   -- S4: parents never chart; sport stays null (CHECK)
    end if;
    if new.sport is null then
      select nullif(u.raw_user_meta_data ->> 'intended_sport', '') into v_intended
        from auth.users u where u.id = new.id;
      new.sport := case when v_intended in ('baseball', 'softball') then v_intended else 'baseball' end;
    end if;
    return new;
  end if;
  if new.sport is distinct from old.sport and (
       exists (select 1 from public.sessions s where s.pitcher_id = old.id)
    or exists (select 1 from public.pitcher_teams pt where pt.pitcher_id = old.id)
    or exists (select 1 from public.team_coaches tc where tc.coach_id = old.id)) then
    raise exception 'sport_locked'
      using detail = 'This profile already has sessions or a team, so its sport can''t change.';
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.join_team_via_invite(p_token text, p_profile uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_prof uuid;
  v_team_id uuid;
  v_team_name text;
  v_team_sport text;
  v_role text;
  v_block text;
begin
  if auth.uid() is null then
    return jsonb_build_object('error', 'not_authenticated');
  end if;
  v_block := public.p1_10_join_block(false);
  if v_block is not null then
    return jsonb_build_object('error', v_block);
  end if;

  select id, name, sport into v_team_id, v_team_name, v_team_sport from public.teams where invite_token = p_token;

  if p_profile is not null then
    if not public.is_my_profile(p_profile) then
      return jsonb_build_object('error', 'not_your_profile');
    end if;
    v_prof := p_profile;
  else
    v_prof := (select pr.id from public.profiles pr
                where pr.account_id = auth.uid() and pr.managed_by is null
                  and pr.role = 'pitcher' and pr.sport = v_team_sport);
    v_prof := coalesce(v_prof, public.my_single_profile());
    if v_prof is null then
      return jsonb_build_object('error', 'profile_required');
    end if;
  end if;

  select role into v_role from public.profiles where id = v_prof;
  if v_role in ('coach', 'parent') then
    return jsonb_build_object('error', 'coach_cannot_join');
  end if;

  if v_team_id is null then
    return jsonb_build_object('error', 'invalid_token');
  end if;
  if public.is_team_archived(v_team_id) then
    return jsonb_build_object('error', 'team_archived');   -- P1-09
  end if;

  insert into public.pitcher_teams (pitcher_id, team_id)
  values (v_prof, v_team_id)
  on conflict (pitcher_id, team_id) do nothing;

  return jsonb_build_object('ok', true, 'team_id', v_team_id, 'team_name', v_team_name, 'profile_id', v_prof);
end;
$function$;

CREATE OR REPLACE FUNCTION public.join_team_as_coach(p_token text, p_profile uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_prof uuid;
  v_role text;
  v_team_id uuid;
  v_team_name text;
  v_team_sport text;
  v_head_id uuid;
  v_block text;
begin
  if auth.uid() is null then
    return jsonb_build_object('error', 'not_authenticated');
  end if;
  v_block := public.p1_10_join_block(true);
  if v_block is not null then
    return jsonb_build_object('error', v_block);
  end if;

  select id, name, coach_id, sport into v_team_id, v_team_name, v_head_id, v_team_sport
    from public.teams where coach_invite_token = p_token;

  if p_profile is not null then
    if not public.is_my_profile(p_profile) then
      return jsonb_build_object('error', 'not_your_profile');
    end if;
    v_prof := p_profile;
  else
    v_prof := (select pr.id from public.profiles pr
                where pr.account_id = auth.uid() and pr.managed_by is null
                  and pr.role = 'coach' and pr.sport = v_team_sport);
    v_prof := coalesce(v_prof, public.my_single_profile());
    if v_prof is null then
      return jsonb_build_object('error', 'profile_required');
    end if;
  end if;

  select role into v_role from public.profiles where id = v_prof;
  if v_role = 'pitcher' then
    return jsonb_build_object('error', 'pitcher_cannot_join');
  end if;

  if v_team_id is null then
    return jsonb_build_object('error', 'invalid_token');
  end if;
  if public.is_team_archived(v_team_id) then
    return jsonb_build_object('error', 'team_archived');   -- P1-09
  end if;

  insert into public.team_coaches (team_id, coach_id, role, invited_by)
  values (v_team_id, v_prof, 'assistant', v_head_id)
  on conflict (team_id, coach_id) do nothing;

  return jsonb_build_object('ok', true, 'team_id', v_team_id, 'team_name', v_team_name, 'profile_id', v_prof);
end;
$function$;

CREATE OR REPLACE FUNCTION public.chat_family_ok(p_pitcher uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select coalesce((
    select p.account_id = auth.uid()
           and acct.age_attestation is not null
           and (acct.age_attestation = 'adult' or acct.guardian_consented_at is not null)
      from public.profiles p join public.profiles acct on acct.id = p.account_id
     where p.id = p_pitcher), false);
$function$;

CREATE OR REPLACE FUNCTION public.chat_my_orgs()
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select o.id from public.organizations o where o.manager_login = auth.uid()
  union
  select tt.org_id from public.team_coaches tc join public.profiles pr on pr.id = tc.coach_id join public.teams tt on tt.id = tc.team_id
   where pr.account_id = auth.uid() and tt.org_id is not null
  union
  select tt.org_id from public.pitcher_teams pt join public.profiles p on p.id = pt.pitcher_id join public.teams tt on tt.id = pt.team_id
   where p.account_id = auth.uid() and tt.org_id is not null and public.chat_family_ok(pt.pitcher_id)
  union   -- a departed family still reads its closed threads
  select t.org_id from public.chat_threads t join public.profiles p on p.id = t.pitcher_id where p.account_id = auth.uid();
$function$;

CREATE OR REPLACE FUNCTION public.chat_my_threads()
 RETURNS TABLE(thread_id uuid, kind text, team_id uuid, sport text, title text, subtitle text, access text, archived boolean, last_at timestamp with time zone, last_preview text, last_author text, unread integer, i_manage boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare t record; v_access text; v_uid uuid := auth.uid();
begin
  for t in select th.*, o.name as org_name, o.manager_login,
                  tm.sport as t_sport, p.full_name as pitcher_name, cp.full_name as coach_name
             from public.chat_threads th join public.organizations o on o.id = th.org_id
             left join public.teams tm on tm.id = th.team_id
             left join public.profiles p on p.id = th.pitcher_id
             left join public.coach_groups g on g.id = th.group_id
             left join public.profiles cp on cp.id = g.coach_id
            where th.org_id in (select public.chat_my_orgs()) loop
    v_access := public.chat_access(t.id);
    continue when v_access is null;
    continue when t.last_message_at is null and not (t.kind = 'facility' and v_access = 'post');
    thread_id := t.id; kind := t.kind; team_id := t.team_id; sport := t.t_sport; access := v_access;
    archived := t.archived_at is not null; last_at := t.last_message_at;
    i_manage := t.manager_login = v_uid;
    if t.kind = 'facility' then
      title := 'Everyone at ' || t.org_name; subtitle := null;
    elsif t.pitcher_id is not null and exists (select 1 from public.profiles x where x.id = t.pitcher_id and x.account_id = v_uid) then
      title := coalesce(t.coach_name, 'Former coach'); subtitle := t.pitcher_name;    -- the family sees the coach
    else
      title := coalesce(t.pitcher_name, 'Deleted account'); subtitle := coalesce(t.coach_name, 'No coach');
    end if;
    select case when m.deleted_at is not null then 'This message was deleted' when m.author_deleted then 'Deleted account'
                else left(m.body, 140) end, m.author_name
      into last_preview, last_author
      from public.chat_messages m where m.thread_id = t.id order by m.created_at desc limit 1;
    select count(*) into unread from public.chat_messages m
     where m.thread_id = t.id and m.author_login is distinct from v_uid and m.deleted_at is null
       and m.created_at > coalesce((select r.last_read_at from public.chat_reads r where r.thread_id = t.id and r.login = v_uid), '-infinity');
    return next;
  end loop;
end;
$function$;

CREATE OR REPLACE FUNCTION public.chat_compose_targets()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select coalesce(jsonb_agg(x order by x ->> 'sort'), '[]'::jsonb) from (
    select jsonb_build_object('kind', 'facility', 'org_id', o.id, 'label', 'Everyone at ' || o.name, 'sort', '0' || o.name) x
      from public.organizations o where o.manager_login = auth.uid()
    union all
    select jsonb_build_object('kind', 'private', 'group_id', g.id, 'pitcher_id', p.id, 'label', p.full_name,
                              'detail', 'Family of ' || p.full_name, 'sport', tm.sport, 'sort', '1' || p.full_name)
      from public.coach_groups g join public.profiles cp on cp.id = g.coach_id and cp.account_id = auth.uid()
      join public.coach_group_members m on m.group_id = g.id join public.profiles p on p.id = m.pitcher_id
      join public.teams tm on tm.id = g.team_id
     where tm.kind = 'facility' and tm.archived_at is null
    union all
    select jsonb_build_object('kind', 'private', 'group_id', g.id, 'pitcher_id', p.id, 'label', cp.full_name,
                              'detail', 'Coach for ' || p.full_name, 'sport', tm.sport, 'sort', '2' || cp.full_name)
      from public.profiles p join public.coach_group_members m on m.pitcher_id = p.id
      join public.coach_groups g on g.id = m.group_id join public.profiles cp on cp.id = g.coach_id
      join public.teams tm on tm.id = g.team_id
     where p.account_id = auth.uid() and p.role = 'pitcher' and tm.kind = 'facility' and tm.archived_at is null
       and public.chat_family_ok(p.id)
  ) s;
$function$;

CREATE OR REPLACE FUNCTION public.chat_post(p_thread uuid, p_body text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare t public.chat_threads%rowtype; v_body text := btrim(coalesce(p_body, '')); v_prof uuid; v_role text; v_name text; v_id uuid;
begin
  if public.chat_access(p_thread) is distinct from 'post' then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  if char_length(v_body) < 1 or char_length(v_body) > 2000 then return jsonb_build_object('ok', false, 'error', 'invalid_length'); end if;
  select * into t from public.chat_threads where id = p_thread;
  if t.kind = 'facility' then
    select tm.coach_id into v_prof from public.teams tm where tm.org_id = t.org_id order by tm.sport limit 1;
    v_role := 'manager';
  else
    select g.coach_id into v_prof from public.coach_groups g join public.profiles pr on pr.id = g.coach_id
     where g.id = t.group_id and pr.account_id = auth.uid();
    if v_prof is not null then v_role := 'coach';
    else
      select case when p.managed_by is null then p.id else p.managed_by end, case when p.managed_by is null then 'pitcher' else 'parent' end
        into v_prof, v_role from public.profiles p where p.id = t.pitcher_id;
    end if;
  end if;
  select full_name into v_name from public.profiles where id = v_prof;
  insert into public.chat_messages (thread_id, author_profile_id, author_login, author_name, author_role, body)
    values (p_thread, v_prof, auth.uid(), coalesce(v_name, 'Someone'), v_role, v_body) returning id into v_id;
  update public.chat_threads set last_message_at = now() where id = p_thread;
  insert into public.chat_reads (thread_id, login, last_read_at) values (p_thread, auth.uid(), now())
    on conflict (thread_id, login) do update set last_read_at = excluded.last_read_at;
  return jsonb_build_object('ok', true, 'id', v_id);
end;
$function$;

drop function public.chat_is_family(uuid);
drop function public.create_player_link(uuid, text);
drop function public.cancel_player_link(uuid, text);
drop function public.player_link_info(text);
drop function public.accept_player_link(text, text);
drop function public.my_linked_players();
drop function public.player_access(uuid);
drop function public.remove_player_link(uuid, uuid);
drop function public.leave_player(uuid);
drop function public.f1g_role_cap(text);
drop function public.f1g_is_creator(uuid);
drop function public.f1g_linked_team(uuid, boolean);
drop function public.can_chart_for(uuid);
drop function public.is_linked_to(uuid);
drop function public.player_link_role(uuid);
drop table public.player_link_invites;
drop table public.player_links;

alter table public.profiles drop constraint profiles_consent_via_check;
alter table public.profiles add constraint profiles_consent_via_check check (consent_via = any (array['guardian_email', 'parent_created']));
alter table public.profiles drop constraint profiles_sport_check;
alter table public.profiles add constraint profiles_sport_check check (
  (role = 'parent' and sport is null) or (role <> 'parent' and sport = any (array['baseball', 'softball'])));
alter table public.profiles drop constraint profiles_role_check;
alter table public.profiles add constraint profiles_role_check check (role = any (array['coach', 'pitcher', 'parent']));
