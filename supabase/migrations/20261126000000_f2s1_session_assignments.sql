-- F2 Stage 1 (Joel, Nov 20 2026; plans/f2-facility-assignments-birthdays-camps.md, decisions in plans/f2-preconditions.md):
-- any coach in a training facility finds any facility pitcher by name and assigns them to a coach (themself or another)
-- for ONE session. The assigned coach can chart that one session and nothing else: no History, reports, notes, card,
-- contacts or chat. The save releases it in the same transaction.
--
-- Nothing existing is widened: session_assignments has no client grant and no policy (policies stay 32), and no existing
-- function or policy reads it -- coach_sees_pitcher, the chat functions and every read rule are untouched, so an
-- assignment counts nowhere visibility or chat is decided. The only reads are the functions below.

create table public.session_assignments (
  id             uuid primary key default gen_random_uuid(),
  team_id        uuid not null references public.teams(id) on delete cascade,        -- the facility side
  pitcher_id     uuid not null references public.profiles(id) on delete cascade,
  coach_id       uuid not null references public.profiles(id) on delete cascade,     -- the coach profile on that side
  assigned_by    uuid references public.profiles(id) on delete set null,
  created_at     timestamptz not null default now(),
  window_ends_at timestamptz not null default now() + interval '24 hours',           -- unused after this: gone
  session_id     uuid,                                                               -- the session that released it
  released_at    timestamptz,
  cancelled_at   timestamptz,
  cancelled_by   uuid references public.profiles(id) on delete set null
);
create unique index session_assignments_open on public.session_assignments (pitcher_id, coach_id)
  where released_at is null and cancelled_at is null;
create index session_assignments_coach on public.session_assignments (coach_id) where released_at is null and cancelled_at is null;
alter table public.session_assignments enable row level security;   -- and no policy: clients reach it only through the functions
revoke all on public.session_assignments from public, anon, authenticated;

-- The caller's coach profile on a facility side (staff row: head or assistant), or null.
create or replace function public.f2_my_side_coach(p_team uuid)
 returns uuid language sql stable security definer set search_path to '' as $$
  select tc.coach_id from public.team_coaches tc
    join public.profiles pr on pr.id = tc.coach_id
    join public.teams t on t.id = tc.team_id
   where tc.team_id = p_team and pr.account_id = auth.uid() and t.kind = 'facility'
   limit 1
$$;
revoke all on function public.f2_my_side_coach(uuid) from public, anon, authenticated;

-- Search: every pitcher on the facility side, by name. Caller: a coach on that side's staff (the manager included).
-- 2+ characters, at most 20. Returns id and name; `mine` when the caller already coaches them (it opens as usual);
-- `coach` only when two results share a name, to tell them apart.
create or replace function public.facility_pitcher_search(p_team uuid, p_q text)
 returns jsonb language plpgsql stable security definer set search_path to '' as $$
declare
  q text := btrim(coalesce(p_q, ''));
  res jsonb;
begin
  if public.f2_my_side_coach(p_team) is null then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  if length(q) < 2 then return jsonb_build_object('ok', true, 'results', '[]'::jsonb); end if;
  q := replace(replace(replace(q, '\', '\\'), '%', '\%'), '_', '\_');
  with hits as (
    select p.id, p.full_name
      from public.pitcher_teams pt join public.profiles p on p.id = pt.pitcher_id
     where pt.team_id = p_team and p.full_name ilike '%' || q || '%'
     order by p.full_name, p.id
     limit 20
  ), dup as (select full_name from hits group by full_name having count(*) > 1)
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', h.id, 'name', h.full_name,
           'mine', public.coach_sees_pitcher(p_team, h.id),
           'coach', case when h.full_name in (select full_name from dup) then
             (select string_agg(cp.full_name, ' / ' order by cp.full_name)
                from public.coach_group_members m join public.coach_groups g on g.id = m.group_id
                join public.profiles cp on cp.id = g.coach_id
               where g.team_id = p_team and m.pitcher_id = h.id) end)
           order by h.full_name), '[]'::jsonb)
    into res from hits h;
  return jsonb_build_object('ok', true, 'results', res);
end;
$$;
revoke all on function public.facility_pitcher_search(uuid, text) from public, anon;
grant execute on function public.facility_pitcher_search(uuid, text) to authenticated;

-- The side's coaches a pitcher can be assigned to (any coach on the side may assign; this lists the choices).
create or replace function public.facility_side_coaches(p_team uuid)
 returns jsonb language plpgsql stable security definer set search_path to '' as $$
begin
  if public.f2_my_side_coach(p_team) is null then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  return jsonb_build_object('ok', true, 'coaches', coalesce((
    select jsonb_agg(jsonb_build_object('id', tc.coach_id, 'name', pr.full_name, 'me', pr.account_id = auth.uid())
                     order by (pr.account_id = auth.uid()) desc, pr.full_name)
      from public.team_coaches tc join public.profiles pr on pr.id = tc.coach_id
     where tc.team_id = p_team), '[]'::jsonb));
end;
$$;
revoke all on function public.facility_side_coaches(uuid) from public, anon;
grant execute on function public.facility_side_coaches(uuid) to authenticated;

-- Assign a pitcher to a coach (the caller or another coach on the side) for one session.
create or replace function public.assign_session(p_team uuid, p_pitcher uuid, p_coach uuid)
 returns jsonb language plpgsql volatile security definer set search_path to '' as $$
declare
  me uuid := public.f2_my_side_coach(p_team);
  t public.teams%rowtype;
  a public.session_assignments%rowtype;
begin
  if me is null then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  select * into t from public.teams where id = p_team;
  if t.archived_at is not null then return jsonb_build_object('ok', false, 'error', 'team_archived'); end if;
  if not exists (select 1 from public.pitcher_teams where team_id = p_team and pitcher_id = p_pitcher) then
    return jsonb_build_object('ok', false, 'error', 'not_on_side');
  end if;
  if not exists (select 1 from public.team_coaches where team_id = p_team and coach_id = p_coach) then
    return jsonb_build_object('ok', false, 'error', 'not_a_coach');
  end if;
  -- the coach already has this pitcher (their group, or the manager): nothing to grant
  if p_coach = t.coach_id or exists (select 1 from public.coach_group_members m join public.coach_groups g on g.id = m.group_id
                                      where g.team_id = p_team and g.coach_id = p_coach and m.pitcher_id = p_pitcher) then
    return jsonb_build_object('ok', true, 'status', 'already_coach');
  end if;
  -- an expired, unused one makes way
  update public.session_assignments set cancelled_at = now()
   where pitcher_id = p_pitcher and coach_id = p_coach and released_at is null and cancelled_at is null and window_ends_at < now();
  select * into a from public.session_assignments
   where pitcher_id = p_pitcher and coach_id = p_coach and released_at is null and cancelled_at is null;
  if found then return jsonb_build_object('ok', true, 'status', 'already_assigned', 'id', a.id, 'window_ends_at', a.window_ends_at); end if;
  insert into public.session_assignments (team_id, pitcher_id, coach_id, assigned_by)
    values (p_team, p_pitcher, p_coach, me) returning * into a;
  return jsonb_build_object('ok', true, 'status', 'assigned', 'id', a.id, 'window_ends_at', a.window_ends_at);
end;
$$;
revoke all on function public.assign_session(uuid, uuid, uuid) from public, anon;
grant execute on function public.assign_session(uuid, uuid, uuid) to authenticated;

-- Cancel: whoever assigned it, the assigned coach (a discard on the device), or the side's manager.
create or replace function public.cancel_assignment(p_id uuid)
 returns jsonb language plpgsql volatile security definer set search_path to '' as $$
declare a public.session_assignments%rowtype; me uuid;
begin
  select * into a from public.session_assignments where id = p_id;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  me := public.f2_my_side_coach(a.team_id);
  if me is null or not (me = a.assigned_by or me = a.coach_id
                        or me = (select coach_id from public.teams where id = a.team_id)) then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  if a.released_at is not null or a.cancelled_at is not null then return jsonb_build_object('ok', true, 'status', 'already_ended'); end if;
  update public.session_assignments set cancelled_at = now(), cancelled_by = me where id = p_id;
  return jsonb_build_object('ok', true, 'status', 'cancelled');
end;
$$;
revoke all on function public.cancel_assignment(uuid) from public, anon;
grant execute on function public.cancel_assignment(uuid) to authenticated;

-- The device's one read of an assigned pitcher: exactly what charting needs. Never contacts, uniform, level, headshot,
-- history, notes or the card. Open, unexpired assignments held by any of the caller's coach profiles.
create or replace function public.my_assignments()
 returns jsonb language sql stable security definer set search_path to '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', a.id, 'team_id', a.team_id, 'coach_id', a.coach_id, 'window_ends_at', a.window_ends_at,
           'pitcher', jsonb_build_object('id', p.id, 'full_name', p.full_name, 'sport', p.sport, 'pitch_types', p.pitch_types,
                                         'throws', p.throws, 'uses_radar_gun', p.uses_radar_gun,
                                         'relative_accuracy_enabled', p.relative_accuracy_enabled),
           'zones', coalesce((select jsonb_agg(jsonb_build_object('pitch_type', z.pitch_type, 'batter_side', z.batter_side, 'cells', z.cells))
                                from public.accuracy_zones z where z.pitcher_id = p.id), '[]'::jsonb))
           order by a.created_at), '[]'::jsonb)
    from public.session_assignments a
    join public.profiles p on p.id = a.pitcher_id
    join public.profiles c on c.id = a.coach_id and c.account_id = auth.uid()
    join public.teams t on t.id = a.team_id and t.archived_at is null
   where a.released_at is null and a.cancelled_at is null and a.window_ends_at > now()
$$;
revoke all on function public.my_assignments() from public, anon;
grant execute on function public.my_assignments() to authenticated;

-- sync_session: SR1 Stage A's definition plus two F2 changes, marked "F2":
--  (a) a new session may be saved by the coach holding an open assignment the session names (p_session.assignment_id)
--      for this pitcher and side, started inside its window (and before any cancel) -- so a session charted offline and
--      synced days later is still accepted; the same transaction releases the assignment;
--  (b) the charter of a session that's already saved gets `already_saved` even when he can no longer read it (a retry
--      after a lost response would otherwise stick in his outbox as not_entitled).
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
    -- The caller is this pitcher, or a coach of the session's team, charting as one of
    -- their own profiles (F2: or the coach a one-session assignment names).
    if not (public.can_chart_for(v_pitcher) or public.coach_sees_pitcher(v_team, v_pitcher) or v_assigned)
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
                                 inherited_runners, runners_left, relieved_session_id, left_owners, final_at, purpose)
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
                 then p_session ->> 'purpose' end);
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

-- A1: deleting an account removes its assignments (cascades on pitcher / coach); an assigner's deletion leaves the
-- row with assigned_by null. Nothing else to purge.
