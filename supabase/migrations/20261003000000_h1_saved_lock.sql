-- H1 Part 1 (P1-16) + Part 3a, with Joel's Oct 3 decisions: saved sessions are locked in the
-- database, and a saved session reaches the server in ONE atomic call (sync_session) that
-- inserts the session, its pitches and its events and seals it. Absorbs SC2 (insert-only sync).
--
--   - Nothing reaches the server until "End session & save" (Joel accepts this): every
--     session row is saved (ended_at set) when it is written.
--   - sealed_at: set by sync_session once every pitch and event is in. After it, nothing can
--     be added, changed or removed except through delete_session()'s tombstone.
--   - GRACE PATH (14 days after the production deploy, Joel): devices still on the old app
--     (v144 and earlier) write sessions/pitches/events directly. Their INSERTs stay allowed,
--     only into saved-but-unsealed sessions, and an unchanged re-send is ignored instead of
--     failing. A follow-up migration closes the path (drops the "H1 grace" policies and
--     seals every remaining session) once production shows no old-path writes for a week.
--   - Part 3a: no client DELETE on sessions, pitches or game_events. Deleting is only
--     delete_session() (pitcher for own sessions, the team's HEAD coach; assistants refused --
--     already its rule), which writes the tombstone.
-- Policies: 35 -> 35 during the grace period (each table: read + old-app insert + old-app
-- re-send/report-link update); 35 -> 29 when the grace-closing migration drops the six grace rules. None references
-- teams and pitcher_teams directly (42P17): they use is_my_profile / is_team_coach.
-- Rollback: supabase/rollback/20261003000000_h1_saved_lock_down.sql

alter table public.sessions add column sealed_at timestamptz;
comment on column public.sessions.sealed_at is
  'H1: set by sync_session() once the session, its pitches and its events are all in. After it nothing can be added; updates are already locked once ended_at is set.';

-- Sessions written more than 14 days ago are complete (any old-app retry still in flight is
-- newer than that). Newer ones stay unsealed so an old app can finish a half-done sync; the
-- grace-closing migration seals the rest.
update public.sessions set sealed_at = now()
 where ended_at is not null and created_at < now() - interval '14 days';

-- ------------------------------------------------------------------ sessions lock
create or replace function public.sessions_h1_lock()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.ended_at is null then
    return new;   -- a legacy unsaved row (none on production): finishes through the old path
  end if;
  if new.ended_at is distinct from old.ended_at then
    raise exception 'session_saved_locked' using detail = 'A saved session can''t be un-saved or re-timed.';
  end if;
  if (new.id, new.pitcher_id, new.team_id, new.logged_by, new.started_at, new.created_at, new.kind, new.sport,
      new.charting_perspective, new.opponent, new.game_final_inning, new.game_outs_recorded)
     is distinct from
     (old.id, old.pitcher_id, old.team_id, old.logged_by, old.started_at, old.created_at, old.kind, old.sport,
      old.charting_perspective, old.opponent, old.game_final_inning, old.game_outs_recorded) then
    raise exception 'session_saved_locked' using detail = 'Who and what a saved session belongs to can''t change.';
  end if;
  if old.sealed_at is not null and new.sealed_at is distinct from old.sealed_at then
    raise exception 'session_saved_locked' using detail = 'A sealed session stays sealed.';
  end if;
  -- The tombstone is written only by the server's own functions (delete_session runs as its
  -- owner). Any API caller -- the app, a crafted request, the service role -- is refused.
  if current_user in ('authenticated', 'anon', 'service_role')
     and (new.deleted_at, new.deleted_by, new.deleted_by_role, new.deleted_by_name, new.pitch_count)
         is distinct from (old.deleted_at, old.deleted_by, old.deleted_by_role, old.deleted_by_name, old.pitch_count) then
    raise exception 'session_saved_locked' using detail = 'Only delete_session() can delete a session.';
  end if;
  return new;   -- report_path / report_generated_at, and sealing an unsealed session, stay writable
end;
$$;
create trigger sessions_h1_lock before update on public.sessions
  for each row execute function public.sessions_h1_lock();

-- ------------------------------------------------------------------ pitches / game_events lock
create or replace function public.h1_child_lock()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_ended  timestamptz;
  v_sealed timestamptz;
  v_exists boolean;
begin
  select s.ended_at, s.sealed_at into v_ended, v_sealed
    from public.sessions s where s.id = new.session_id;
  if tg_op = 'INSERT' then
    if v_sealed is null then
      return new;
    end if;
    -- Sealed: an old app re-sending a row that's already there is skipped; anything new is refused.
    if tg_table_name = 'pitches' then
      select exists (select 1 from public.pitches where id = new.id) into v_exists;
    else
      select exists (select 1 from public.game_events where id = new.id) into v_exists;
    end if;
    if v_exists then
      return null;
    end if;
    raise exception 'session_sealed_locked' using detail = 'This session is saved; nothing can be added to it.';
  end if;

  -- UPDATE (every caller, server functions included)
  if v_ended is null then
    return new;
  end if;
  if to_jsonb(new) = to_jsonb(old) then
    return null;   -- an unchanged re-send (an old app's upsert retry): skipped, not an error
  end if;
  if tg_table_name = 'game_events' then
    if to_jsonb(new) ->> 'after_pitch_id' is null
       and (to_jsonb(new) - 'after_pitch_id') = (to_jsonb(old) - 'after_pitch_id') then
      return new;  -- the after_pitch_id foreign key clearing itself when its pitch is deleted
    end if;
  end if;
  raise exception 'session_saved_locked' using detail = 'A saved session''s pitches and events can''t be changed.';
end;
$$;
create trigger pitches_h1_lock before insert or update on public.pitches
  for each row execute function public.h1_child_lock();
create trigger game_events_h1_lock before insert or update on public.game_events
  for each row execute function public.h1_child_lock();

-- ------------------------------------------------------------------ policies
drop policy "Pitchers manage own sessions" on public.sessions;
drop policy "Coaches manage sessions for their team" on public.sessions;
drop policy "Coaches view sessions logged under their team" on public.sessions;

create policy "Sessions: read by the pitcher and the team's coaches" on public.sessions
  for select using (public.is_my_profile(pitcher_id) or public.is_team_coach(team_id));
-- Kept for the report link (send-session-report writes report_path with the caller's own
-- client); sessions_h1_lock limits a saved session to exactly those columns.
create policy "Sessions: report link written by the pitcher and the team's coaches" on public.sessions
  for update using (public.is_my_profile(pitcher_id) or public.is_team_coach(team_id))
  with check (public.is_my_profile(pitcher_id) or public.is_team_coach(team_id));
create policy "H1 grace: old-app session insert" on public.sessions
  for insert with check ((public.is_my_profile(pitcher_id) or public.is_team_coach(team_id))
                         and ended_at is not null and sealed_at is null);

drop policy "Pitchers manage pitches in own sessions" on public.pitches;
drop policy "Coaches manage pitches for their team's sessions" on public.pitches;
drop policy "Coaches view pitches for their team's sessions" on public.pitches;

create policy "Pitches: read by the pitcher and the team's coaches" on public.pitches
  for select using (exists (select 1 from public.sessions s where s.id = pitches.session_id
                            and (public.is_my_profile(s.pitcher_id) or public.is_team_coach(s.team_id))));
-- An old app re-sends with an upsert (ON CONFLICT DO UPDATE), which needs an UPDATE rule. It
-- changes nothing: h1_child_lock skips an identical re-send and refuses any real change.
create policy "H1 grace: old-app pitch re-send" on public.pitches
  for update using (exists (select 1 from public.sessions s where s.id = pitches.session_id
                            and s.sealed_at is null
                            and (public.is_my_profile(s.pitcher_id) or public.is_team_coach(s.team_id))))
  with check (exists (select 1 from public.sessions s where s.id = pitches.session_id
                      and s.sealed_at is null
                      and (public.is_my_profile(s.pitcher_id) or public.is_team_coach(s.team_id))));
create policy "H1 grace: old-app pitch insert" on public.pitches
  for insert with check (exists (select 1 from public.sessions s where s.id = pitches.session_id
                                 and s.ended_at is not null and s.sealed_at is null
                                 and (public.is_my_profile(s.pitcher_id) or public.is_team_coach(s.team_id))));

drop policy "Pitchers manage events in own sessions" on public.game_events;
drop policy "Coaches manage events for their team's sessions" on public.game_events;
drop policy "Coaches view events for their team's sessions" on public.game_events;

create policy "Game events: read by the pitcher and the team's coaches" on public.game_events
  for select using (exists (select 1 from public.sessions s where s.id = game_events.session_id
                            and (public.is_my_profile(s.pitcher_id) or public.is_team_coach(s.team_id))));
create policy "H1 grace: old-app event re-send" on public.game_events
  for update using (exists (select 1 from public.sessions s where s.id = game_events.session_id
                            and s.sealed_at is null
                            and (public.is_my_profile(s.pitcher_id) or public.is_team_coach(s.team_id))))
  with check (exists (select 1 from public.sessions s where s.id = game_events.session_id
                      and s.sealed_at is null
                      and (public.is_my_profile(s.pitcher_id) or public.is_team_coach(s.team_id))));
create policy "H1 grace: old-app event insert" on public.game_events
  for insert with check (exists (select 1 from public.sessions s where s.id = game_events.session_id
                                 and s.ended_at is not null and s.sealed_at is null
                                 and (public.is_my_profile(s.pitcher_id) or public.is_team_coach(s.team_id))));

-- ------------------------------------------------------------------ sync_session
-- One call per saved session. Entitlement is checked here (SECURITY DEFINER skips RLS); the
-- sport and team triggers still fire on the insert. An id that's already saved and sealed is
-- NEVER merged: it returns already_saved and writes nothing. An id written by the old app and
-- not yet sealed (grace period only) gets its missing rows added -- inserts only, nothing
-- existing changes -- and is then sealed, so a half-finished old sync completes.
create or replace function public.sync_session(p_session jsonb, p_pitches jsonb default '[]'::jsonb, p_events jsonb default '[]'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
                                 kind, opponent, game_final_inning, game_outs_recorded)
    values (v_id, v_pitcher, v_team, v_logged,
            (p_session ->> 'started_at')::timestamptz, (p_session ->> 'ended_at')::timestamptz,
            coalesce(nullif(p_session ->> 'charting_perspective', ''), 'behind_catcher'),
            coalesce(nullif(p_session ->> 'kind', ''), 'bullpen'),
            nullif(p_session ->> 'opponent', ''),
            (p_session ->> 'game_final_inning')::smallint,
            (p_session ->> 'game_outs_recorded')::smallint);
  end if;

  insert into public.pitches (id, session_id, type, velo, ts, target_row, target_col, actual_row, actual_col,
         accuracy_mode, batter_side, in_accuracy_zone, accuracy_zone_cells, kind, result, in_play_outcome,
         hit_type, fielder, delivery, inning, outs_before, balls_before, strikes_before, at_bat_index, bb_type,
         bb_x, bb_y, fielders, runners_before, batter_to, runner_advances, outs_on_play, runs_scored, sacrifice,
         bb_from_position, time_to_plate)
  select r.id, v_id, r.type, r.velo, coalesce(r.ts, now()), r.target_row, r.target_col,
         coalesce(r.actual_row, 0), coalesce(r.actual_col, 0),
         r.accuracy_mode, r.batter_side, r.in_accuracy_zone, r.accuracy_zone_cells,
         coalesce(r.kind, coalesce(nullif(p_session ->> 'kind', ''), 'bullpen')), r.result, r.in_play_outcome,
         r.hit_type, r.fielder, r.delivery, r.inning, r.outs_before, r.balls_before, r.strikes_before, r.at_bat_index,
         r.bb_type, r.bb_x, r.bb_y, r.fielders, r.runners_before, r.batter_to, r.runner_advances, r.outs_on_play,
         r.runs_scored, r.sacrifice, r.bb_from_position, r.time_to_plate
    from jsonb_populate_recordset(null::public.pitches, coalesce(p_pitches, '[]'::jsonb)) r
   where r.id is not null
  on conflict (id) do nothing;
  get diagnostics v_np = row_count;

  insert into public.game_events (id, session_id, at_bat_index, after_pitch_id, event_type, runners_before,
         runner_advances, outs_on_play, runs_scored, seq, inning_before, balls_before, strikes_before, outs_before)
  select e.id, v_id, e.at_bat_index,
         case when e.after_pitch_id in (select p.id from public.pitches p where p.session_id = v_id) then e.after_pitch_id end,
         e.event_type, e.runners_before, e.runner_advances, e.outs_on_play,
         e.runs_scored, e.seq, e.inning_before, e.balls_before, e.strikes_before, e.outs_before
    from jsonb_populate_recordset(null::public.game_events, coalesce(p_events, '[]'::jsonb)) e
   where e.id is not null
  on conflict (id) do nothing;
  get diagnostics v_ne = row_count;

  update public.sessions set sealed_at = now() where id = v_id;
  return jsonb_build_object('ok', true, 'status', v_status, 'pitches', v_np, 'events', v_ne);
end;
$$;
revoke all on function public.sync_session(jsonb, jsonb, jsonb) from public, anon;
grant execute on function public.sync_session(jsonb, jsonb, jsonb) to authenticated;
