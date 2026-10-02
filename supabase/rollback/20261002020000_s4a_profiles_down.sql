-- DOWN migration for 20261002020000_s4a_profiles.sql -- restores production as of Oct 2 2026

-- (definitions copied verbatim from production before S4A was applied).

-- WARNING: profiles that aren't a login's primary profile (second-sport profiles) can't exist

-- once profiles.id references auth.users again; they -- and, by cascade, their sessions/memberships --

-- are deleted below. Export them first if any exist.

begin;

delete from public.profiles where id <> account_id;

drop function if exists public.add_sport_profile(text);

drop function if exists public.create_team(text, uuid);

drop function if exists public.get_unopened_sessions(uuid, uuid);

drop function if exists public.join_team_as_coach(text, uuid);

drop function if exists public.join_team_via_invite(text, uuid);

drop function if exists public.set_my_uniform_number(uuid, smallint, uuid);

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

CREATE OR REPLACE FUNCTION public.is_team_coach(check_team_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from public.team_coaches tc where tc.team_id = check_team_id and tc.coach_id = auth.uid()
  );
$function$;

CREATE OR REPLACE FUNCTION public.is_team_head(check_team_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from public.teams t where t.id = check_team_id and t.coach_id = auth.uid()
  );
$function$;

CREATE OR REPLACE FUNCTION public.is_team_member(check_team_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from public.pitcher_teams pt where pt.team_id = check_team_id and pt.pitcher_id = auth.uid()
  );
$function$;

CREATE OR REPLACE FUNCTION public.is_coach_of_session(p_session_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (
    select 1
      from public.sessions s
      join public.team_coaches tc on tc.team_id = s.team_id and tc.coach_id = auth.uid()
      join public.pitcher_teams pt on pt.team_id = s.team_id and pt.pitcher_id = s.pitcher_id
     where s.id = p_session_id
       and s.started_at >= pt.joined_at
  );
$function$;

CREATE OR REPLACE FUNCTION public.is_coach_of_session_team(p_session_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (
    select 1 from public.sessions s
      join public.team_coaches tc on tc.team_id = s.team_id and tc.coach_id = auth.uid()
     where s.id = p_session_id
  );
$function$;

CREATE OR REPLACE FUNCTION public.create_team(p_name text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;
  if p_name is null or btrim(p_name) = '' then
    raise exception 'team name cannot be blank';
  end if;
  return public._create_team_with_head(v_uid, btrim(p_name));
end;
$function$;

CREATE OR REPLACE FUNCTION public.delete_session(p_session_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid         uuid := auth.uid();
  v_pitcher     uuid;
  v_team        uuid;
  v_role        text;
  v_count       integer;
  v_event_count integer;
  v_name        text;
  v_report      text;
begin
  if v_uid is null then
    return jsonb_build_object('error', 'not authenticated');
  end if;

  select pitcher_id, team_id, report_path into v_pitcher, v_team, v_report
  from public.sessions
  where id = p_session_id and deleted_at is null;
  if not found then
    return jsonb_build_object('error', 'session not found or already deleted');
  end if;

  if v_pitcher = v_uid then
    v_role := 'pitcher';
  elsif public.is_team_head(v_team) then
    v_role := 'coach';
  else
    return jsonb_build_object('error', 'not entitled to delete this session');
  end if;

  select full_name into v_name from public.profiles where id = v_uid;

  select count(*) into v_count from public.pitches where session_id = p_session_id;
  select count(*) into v_event_count from public.game_events where session_id = p_session_id;

  update public.sessions
     set deleted_at      = now(),
         deleted_by      = v_uid,
         deleted_by_role = v_role,
         deleted_by_name = v_name,
         pitch_count     = v_count
   where id = p_session_id;

  delete from public.game_events where session_id = p_session_id;
  delete from public.pitches where session_id = p_session_id;

  return jsonb_build_object('ok', true, 'report_path', v_report, 'event_count', v_event_count);
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_removal_notice_info(p_pitcher_id uuid, p_team_id uuid)
 RETURNS TABLE(email text, team_name text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if not public.is_team_head(p_team_id) then
    raise exception 'not authorized';
  end if;

  if not exists (
    select 1 from public.pitcher_teams
    where pitcher_id = p_pitcher_id and team_id = p_team_id
  ) then
    raise exception 'pitcher is not a member of this team';
  end if;

  return query
    select u.email::text, t.name
    from auth.users u, public.teams t
    where u.id = p_pitcher_id and t.id = p_team_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_roster_verification(p_team_id uuid)
 RETURNS TABLE(pitcher_id uuid, email text, email_confirmed boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select u.id, u.email, pr.email_verified_at is not null
  from public.pitcher_teams pt
  join auth.users u on u.id = pt.pitcher_id
  join public.profiles pr on pr.id = pt.pitcher_id
  where pt.team_id = p_team_id
    and public.is_team_coach(p_team_id);
$function$;

CREATE OR REPLACE FUNCTION public.get_team_leaderboard(p_team_id uuid, p_window text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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

  -- S1 (Joel, Oct 1): softball has no leaderboard, ever. An empty board
  -- even if a stale client asks; the tab itself is hidden for softball.
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
           (p.target_row = p.actual_row and p.target_col = p.actual_col)   as is_exact,
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
$function$;

CREATE OR REPLACE FUNCTION public.get_unopened_sessions(p_team_id uuid)
 RETURNS TABLE(session_id uuid, pitcher_id uuid)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select s.id, s.pitcher_id
    from public.sessions s
    join public.pitcher_teams pt on pt.team_id = s.team_id and pt.pitcher_id = s.pitcher_id
   where s.team_id = p_team_id
     and s.deleted_at is null
     and s.ended_at is not null
     and s.started_at >= pt.joined_at
     and s.ended_at > public.session_dots_since()
     and s.ended_at > coalesce(
           (select tc.joined_at from public.team_coaches tc
             where tc.team_id = p_team_id and tc.coach_id = auth.uid()),
           '-infinity'::timestamptz)
     and not exists (
       select 1 from public.session_opened o
        where o.viewer_id = auth.uid() and o.session_id = s.id
     );
$function$;

CREATE OR REPLACE FUNCTION public.hand_off_team_head(p_team_id uuid, p_new_head_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_team_head(p_team_id) then
    raise exception 'not authorized';
  end if;
  if not exists (
    select 1 from public.team_coaches
     where team_id = p_team_id and coach_id = p_new_head_id and role = 'assistant'
  ) then
    raise exception 'target must be an existing assistant on this team';
  end if;

  update public.team_coaches set role = 'assistant' where team_id = p_team_id and coach_id = v_uid;
  update public.team_coaches set role = 'head'      where team_id = p_team_id and coach_id = p_new_head_id;
  update public.teams set coach_id = p_new_head_id where id = p_team_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.is_pitcher_report_eligible(p_pitcher_id uuid)
 RETURNS boolean
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select
    coalesce((select email_verified_at is not null from public.profiles where id = p_pitcher_id), false)
    and exists (select 1 from public.pitcher_teams where pitcher_id = p_pitcher_id);
$function$;

CREATE OR REPLACE FUNCTION public.join_team_as_coach(p_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := auth.uid();
  v_role text;
  v_team_id uuid;
  v_team_name text;
  v_head_id uuid;
begin
  if v_uid is null then
    return jsonb_build_object('error', 'not_authenticated');
  end if;

  select role into v_role from public.profiles where id = v_uid;
  if v_role = 'pitcher' then
    return jsonb_build_object('error', 'pitcher_cannot_join');
  end if;

  select id, name, coach_id into v_team_id, v_team_name, v_head_id
    from public.teams where coach_invite_token = p_token;
  if v_team_id is null then
    return jsonb_build_object('error', 'invalid_token');
  end if;

  -- Idempotent, same as join_team_via_invite: opening the link twice is a
  -- no-op, never a second row (and never demotes an existing head/assistant
  -- row already there).
  insert into public.team_coaches (team_id, coach_id, role, invited_by)
  values (v_team_id, v_uid, 'assistant', v_head_id)
  on conflict (team_id, coach_id) do nothing;

  return jsonb_build_object('ok', true, 'team_id', v_team_id, 'team_name', v_team_name);
end;
$function$;

CREATE OR REPLACE FUNCTION public.join_team_via_invite(p_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := auth.uid();
  v_team_id uuid;
  v_team_name text;
  v_role text;
begin
  if v_uid is null then
    return jsonb_build_object('error', 'not_authenticated');
  end if;

  select role into v_role from public.profiles where id = v_uid;
  if v_role = 'coach' then
    return jsonb_build_object('error', 'coach_cannot_join');
  end if;

  select id, name into v_team_id, v_team_name from public.teams where invite_token = p_token;
  if v_team_id is null then
    return jsonb_build_object('error', 'invalid_token');
  end if;

  insert into public.pitcher_teams (pitcher_id, team_id)
  values (v_uid, v_team_id)
  on conflict (pitcher_id, team_id) do nothing;

  return jsonb_build_object('ok', true, 'team_id', v_team_id, 'team_name', v_team_name);
end;
$function$;

CREATE OR REPLACE FUNCTION public.set_my_uniform_number(p_team_id uuid, p_number smallint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  update public.pitcher_teams
     set uniform_number = p_number
   where pitcher_id = auth.uid()
     and team_id = p_team_id;

  if not found then
    raise exception 'not a member of that team';
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.set_uniform_number(p_team_id uuid, p_pitcher_id uuid, p_number smallint, p_expected smallint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid     uuid := auth.uid();
  v_current smallint;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if p_number is not null and (p_number < 0 or p_number > 99) then
    raise exception 'uniform number must be between 0 and 99';
  end if;

  if not (v_uid = p_pitcher_id or public.is_team_head(p_team_id)) then
    raise exception 'not allowed';
  end if;

  select uniform_number into v_current from public.pitcher_teams
   where team_id = p_team_id and pitcher_id = p_pitcher_id;
  if not found then
    raise exception 'pitcher is not a member of this team';
  end if;
  if v_current is distinct from p_expected then
    return jsonb_build_object('error', 'conflict', 'current', v_current);
  end if;

  if p_number is not null and exists (
    select 1 from public.pitcher_teams
     where team_id = p_team_id and pitcher_id <> p_pitcher_id and uniform_number = p_number
  ) then
    return jsonb_build_object('error', 'taken');
  end if;

  update public.pitcher_teams set uniform_number = p_number
   where team_id = p_team_id and pitcher_id = p_pitcher_id;

  return jsonb_build_object('ok', true);
end;
$function$;

drop policy "Pitcher or their coach manages zones" on public.accuracy_zones;
create policy "Pitcher or their coach manages zones" on public.accuracy_zones for all
  using (((pitcher_id = auth.uid()) OR is_coach_of_pitcher(pitcher_id)))
  with check (((pitcher_id = auth.uid()) OR is_coach_of_pitcher(pitcher_id)));

drop policy "Pitchers manage events in own sessions" on public.game_events;
create policy "Pitchers manage events in own sessions" on public.game_events for all
  using ((EXISTS ( SELECT 1
   FROM sessions s
  WHERE ((s.id = game_events.session_id) AND (s.pitcher_id = auth.uid())))))
  with check ((EXISTS ( SELECT 1
   FROM sessions s
  WHERE ((s.id = game_events.session_id) AND (s.pitcher_id = auth.uid())))));

drop policy "Coaches manage own team invites" on public.invites;
create policy "Coaches manage own team invites" on public.invites for all
  using ((EXISTS ( SELECT 1
   FROM teams t
  WHERE ((t.id = invites.team_id) AND (t.coach_id = auth.uid())))))
  with check ((EXISTS ( SELECT 1
   FROM teams t
  WHERE ((t.id = invites.team_id) AND (t.coach_id = auth.uid())))));

drop policy "Pitchers accept invite by inserting own membership" on public.pitcher_teams;
create policy "Pitchers accept invite by inserting own membership" on public.pitcher_teams for insert
  with check ((pitcher_id = auth.uid()));

drop policy "Pitchers view own memberships" on public.pitcher_teams;
create policy "Pitchers view own memberships" on public.pitcher_teams for select
  using ((pitcher_id = auth.uid()));

drop policy "Pitchers manage pitches in own sessions" on public.pitches;
create policy "Pitchers manage pitches in own sessions" on public.pitches for all
  using ((EXISTS ( SELECT 1
   FROM sessions s
  WHERE ((s.id = pitches.session_id) AND (s.pitcher_id = auth.uid())))))
  with check ((EXISTS ( SELECT 1
   FROM sessions s
  WHERE ((s.id = pitches.session_id) AND (s.pitcher_id = auth.uid())))));

drop policy "Users update own profile" on public.profiles;
create policy "Users update own profile" on public.profiles for update
  using ((id = auth.uid()));

drop policy "Users view own profile" on public.profiles;
create policy "Users view own profile" on public.profiles for select
  using ((id = auth.uid()));

drop policy "Viewers insert own roster-seen rows" on public.roster_seen;
create policy "Viewers insert own roster-seen rows" on public.roster_seen for insert
  with check ((viewer_id = auth.uid()));

drop policy "Viewers read own roster-seen rows" on public.roster_seen;
create policy "Viewers read own roster-seen rows" on public.roster_seen for select
  using ((viewer_id = auth.uid()));

drop policy "Viewers update own roster-seen rows" on public.roster_seen;
create policy "Viewers update own roster-seen rows" on public.roster_seen for update
  using ((viewer_id = auth.uid()))
  with check ((viewer_id = auth.uid()));

drop policy "Authors delete their own notes" on public.session_notes;
create policy "Authors delete their own notes" on public.session_notes for delete
  using ((author_id = auth.uid()));

drop policy "Coaches add notes to their pitchers' sessions" on public.session_notes;
create policy "Coaches add notes to their pitchers' sessions" on public.session_notes for insert
  with check (((author_id = auth.uid()) AND is_coach_of_session(session_id)));

drop policy "Notes readable by author, pitcher and his team's coaches" on public.session_notes;
create policy "Notes readable by author, pitcher and his team's coaches" on public.session_notes for select
  using (((author_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM sessions s
  WHERE ((s.id = session_notes.session_id) AND (s.pitcher_id = auth.uid())))) OR is_coach_of_session_team(session_id)));

drop policy "Viewers insert own session-opened rows" on public.session_opened;
create policy "Viewers insert own session-opened rows" on public.session_opened for insert
  with check ((viewer_id = auth.uid()));

drop policy "Viewers read own session-opened rows" on public.session_opened;
create policy "Viewers read own session-opened rows" on public.session_opened for select
  using ((viewer_id = auth.uid()));

drop policy "Pitchers manage own sessions" on public.sessions;
create policy "Pitchers manage own sessions" on public.sessions for all
  using ((pitcher_id = auth.uid()))
  with check ((pitcher_id = auth.uid()));

drop policy "Headshots: player and his coaches can read" on storage.objects;
create policy "Headshots: player and his coaches can read" on storage.objects for select using ((bucket_id = 'headshots'::text) AND ((name = ((auth.uid())::text || '.jpg'::text)) OR public.can_view_headshot(name)));
drop policy "Headshots: player removes his own" on storage.objects;
create policy "Headshots: player removes his own" on storage.objects for delete using ((bucket_id = 'headshots'::text) AND (name = ((auth.uid())::text || '.jpg'::text)));
drop policy "Headshots: player replaces his own" on storage.objects;
create policy "Headshots: player replaces his own" on storage.objects for update using ((bucket_id = 'headshots'::text) AND (name = ((auth.uid())::text || '.jpg'::text))) with check ((bucket_id = 'headshots'::text) AND (name = ((auth.uid())::text || '.jpg'::text)));
drop policy "Headshots: player uploads his own" on storage.objects;
create policy "Headshots: player uploads his own" on storage.objects for insert with check ((bucket_id = 'headshots'::text) AND (name = ((auth.uid())::text || '.jpg'::text)));
drop function if exists public.is_my_headshot(text);
drop function if exists public.my_single_profile();
drop function if exists public.is_my_profile(uuid);
drop trigger if exists profiles_s4_cap on public.profiles;
drop function if exists public.profiles_s4_cap();
drop index if exists public.profiles_one_per_sport_role;
alter table public.profiles drop constraint profiles_sport_check;
alter table public.profiles add constraint profiles_sport_check CHECK ((sport = ANY (ARRAY['baseball'::text, 'softball'::text])));
alter table public.profiles alter column sport set not null;
alter table public.profiles drop constraint profiles_role_check;
alter table public.profiles add constraint profiles_role_check CHECK ((role = ANY (ARRAY['coach'::text, 'pitcher'::text])));
alter table public.profiles drop column is_primary, drop column managed_by;
alter table public.invites drop constraint invites_invited_by_fkey, add constraint invites_invited_by_fkey foreign key (invited_by) references auth.users(id);
alter table public.teams drop constraint teams_coach_id_fkey, add constraint teams_coach_id_fkey foreign key (coach_id) references auth.users(id) on delete cascade;
alter table public.sessions
  drop constraint sessions_deleted_by_fkey, add constraint sessions_deleted_by_fkey foreign key (deleted_by) references auth.users(id),
  drop constraint sessions_logged_by_fkey, add constraint sessions_logged_by_fkey foreign key (logged_by) references auth.users(id),
  drop constraint sessions_pitcher_id_fkey, add constraint sessions_pitcher_id_fkey foreign key (pitcher_id) references auth.users(id) on delete cascade;
alter table public.profiles add constraint profiles_id_fkey foreign key (id) references auth.users(id) on delete cascade;
commit;

-- Re-grant the restored functions that the up migration had dropped and recreated.
grant execute on function public.create_team(text) to authenticated;
grant execute on function public.get_unopened_sessions(uuid) to authenticated;
grant execute on function public.join_team_as_coach(text) to authenticated;
grant execute on function public.join_team_via_invite(text) to authenticated;
grant execute on function public.set_my_uniform_number(uuid, smallint) to authenticated;
