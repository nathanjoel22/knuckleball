-- SR1 Stage D (Joel, Nov 19 2026; plans/sr1-session-reports.md Stage D, decisions in plans/sr1d-preconditions.md):
-- workload, rest and team settings.
--
--  (1) A Pitch Smart age group: teams.pitch_smart_age (a team's head coach sets it, next to Level of play) and
--      profiles.pitch_smart_age (a pitcher's own, for Independent games). The seven groups of MLB / USA Baseball's
--      Pitch Smart. Baseball only: Pitch Smart has no softball table.
--  (2) teams.level_confirmed_at: null until the head coach chooses or confirms Level of play (set_team_level now
--      stamps it). The app asks once while it is null (decision 15). No backfill: every team is asked once.
--  (3) set_team_age_group(team, age): head coach only, not archived, baseball only.
--  (4) sr1_session_age(session): the age group a game's rest card uses -- its team's, or for an Independent game the
--      pitcher's own; null = not set (no guessing from the level). SECURITY DEFINER for the same reason as
--      sr1_session_level (a guardian or a teen's own sign-in can't read the teams row), with the same check.
--  (5) session_workload(session): SECURITY INVOKER, so it counts what the caller can read, like pitcher_workload.
--      The pitches in the 7 days up to the session (bullpens and games, this one included, nothing after it), each
--      session's count as pitcher_workload counts it, plus the level and the age group.
-- No policy is added or changed: public stays 32, storage 12.
-- Rollback: supabase/rollback/20261125000000_sr1d_workload_down.sql. Test: supabase/tests/sr1d_workload.sql.

-- (1) and (2)
alter table public.teams add column pitch_smart_age text,
  add constraint teams_pitch_smart_age_check check (pitch_smart_age is null
    or (pitch_smart_age in ('7-8', '9-10', '11-12', '13-14', '15-16', '17-18', '19-22') and sport = 'baseball'));
alter table public.teams add column level_confirmed_at timestamptz;
grant select (pitch_smart_age, level_confirmed_at) on public.teams to authenticated;
alter table public.profiles add column pitch_smart_age text,
  add constraint profiles_pitch_smart_age_check check (pitch_smart_age is null
    or pitch_smart_age in ('7-8', '9-10', '11-12', '13-14', '15-16', '17-18', '19-22'));
grant select (pitch_smart_age), update (pitch_smart_age) on public.profiles to authenticated;

-- (2) choosing the level confirms it
create or replace function public.set_team_level(p_team_id uuid, p_level text)
 returns void
 language plpgsql
 security definer
 set search_path to ''
as $function$
begin
  if not public.is_team_head(p_team_id) then
    raise exception 'not authorized';
  end if;
  if public.is_team_archived(p_team_id) then
    raise exception 'team_archived' using detail = 'This team is archived. Restore it first.';
  end if;
  update public.teams set level = p_level, level_confirmed_at = now() where id = p_team_id;   -- SR1 D: chosen = confirmed
end;
$function$;

-- (3)
create or replace function public.set_team_age_group(p_team_id uuid, p_age text)
 returns void
 language plpgsql
 security definer
 set search_path to ''
as $function$
begin
  if not public.is_team_head(p_team_id) then
    raise exception 'not authorized';
  end if;
  if public.is_team_archived(p_team_id) then
    raise exception 'team_archived' using detail = 'This team is archived. Restore it first.';
  end if;
  if (select sport from public.teams where id = p_team_id) <> 'baseball' and p_age is not null then
    raise exception 'baseball_only' using detail = 'Pitch Smart age groups are for baseball.';
  end if;
  update public.teams set pitch_smart_age = p_age where id = p_team_id;
end;
$function$;
revoke all on function public.set_team_age_group(uuid, text) from public, anon;
grant execute on function public.set_team_age_group(uuid, text) to authenticated;

-- (4)
create or replace function public.sr1_session_age(p_session uuid)
returns text
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  s record;
  v_age text;
begin
  select x.pitcher_id, x.team_id, x.started_at into s from public.sessions x where x.id = p_session;
  if not found or s.pitcher_id is null then return null; end if;
  if not (public.can_chart_for(s.pitcher_id) or public.coach_sees_pitcher(s.team_id, s.pitcher_id)
          or public.is_linked_to(s.pitcher_id) or public.is_current_coach_of_pitcher(s.pitcher_id, s.started_at)) then
    return null;
  end if;
  if s.team_id is not null then
    select t.pitch_smart_age into v_age from public.teams t where t.id = s.team_id;
  else
    select p.pitch_smart_age into v_age from public.profiles p where p.id = s.pitcher_id;
  end if;
  return v_age;
end;
$function$;
revoke all on function public.sr1_session_age(uuid) from public, anon;
grant execute on function public.sr1_session_age(uuid) to authenticated;

-- (5)
create or replace function public.session_workload(p_session uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path to ''
as $function$
declare
  s record;
  v_parts jsonb;
begin
  select x.id, x.pitcher_id, x.kind, x.sport, x.started_at, x.ended_at into s
    from public.sessions x where x.id = p_session and x.deleted_at is null and x.ended_at is not null;
  if not found or s.pitcher_id is null then
    return jsonb_build_object('error', 'not_found');
  end if;
  -- each session counted as pitcher_workload counts it: its stats row's pitch count, else its pitches + adjustment
  select coalesce(jsonb_agg(jsonb_build_object('session', w.id, 'kind', w.kind, 'started_at', w.started_at, 'pitches', w.n,
                                               'this', w.id = s.id) order by w.started_at), '[]'::jsonb)
    into v_parts
    from (select x.id, x.kind, x.started_at,
                 coalesce((select st.pitch_count from public.session_stats st where st.session_id = x.id),
                          greatest(0, (select count(*) from public.pitches p where p.session_id = x.id) + x.pitch_count_adjust))::int as n
            from public.sessions x
           where x.pitcher_id = s.pitcher_id and x.deleted_at is null and x.ended_at is not null
             and x.started_at > s.ended_at - interval '7 days' and x.started_at <= s.started_at) w;
  return jsonb_build_object(
    'session', s.id, 'kind', s.kind, 'sport', s.sport,
    'level', public.sr1_session_level(p_session), 'age_group', public.sr1_session_age(p_session),
    'from', s.ended_at - interval '7 days', 'to', s.ended_at,
    'seven_day', (select coalesce(sum((e ->> 'pitches')::int), 0) from jsonb_array_elements(v_parts) e),
    'parts', v_parts);
end;
$function$;
revoke all on function public.session_workload(uuid) from public, anon;
grant execute on function public.session_workload(uuid) to authenticated;
