-- Down migration for 20261005010000_p1_09_teams.sql: previous bodies verbatim from schema.sql.
drop function if exists public.archive_team(uuid);
drop function if exists public.restore_team(uuid);
drop function if exists public.delete_team(uuid);
drop function public.resolve_team_invite(text);
CREATE OR REPLACE FUNCTION "public"."resolve_team_invite"("p_token" "text") RETURNS TABLE("team_id" "uuid", "team_name" "text", "team_sport" "text")
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select id, name, sport from public.teams where invite_token = p_token;
$$;

drop function public.resolve_coach_invite(text);
CREATE OR REPLACE FUNCTION "public"."resolve_coach_invite"("p_token" "text") RETURNS TABLE("team_id" "uuid", "team_name" "text", "team_sport" "text")
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select id, name, sport from public.teams where coach_invite_token = p_token;
$$;

revoke all on function public.resolve_team_invite(text) from public; grant execute on function public.resolve_team_invite(text) to anon, authenticated;
revoke all on function public.resolve_coach_invite(text) from public; grant execute on function public.resolve_coach_invite(text) to anon, authenticated;
CREATE OR REPLACE FUNCTION "public"."rename_team"("p_team_id" "uuid", "p_name" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.is_team_head(p_team_id) then
    raise exception 'not authorized';
  end if;
  if p_name is null or btrim(p_name) = '' then
    raise exception 'team name cannot be blank';
  end if;
  update public.teams set name = btrim(p_name) where id = p_team_id;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."set_team_level"("p_team_id" "uuid", "p_level" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.is_team_head(p_team_id) then
    raise exception 'not authorized';
  end if;
  -- teams_level_check ties the level to the team's sport and refuses anything else.
  update public.teams set level = p_level where id = p_team_id;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."rotate_team_invite"("p_team_id" "uuid") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_new_token text;
begin
  if not public.is_team_head(p_team_id) then
    raise exception 'not authorized';
  end if;

  v_new_token := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
  update public.teams
  set invite_token = v_new_token, invite_token_rotated_at = now()
  where id = p_team_id;

  return v_new_token;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."rotate_coach_invite"("p_team_id" "uuid") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_new_token text;
begin
  if not public.is_team_head(p_team_id) then
    raise exception 'not authorized';
  end if;

  v_new_token := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
  update public.teams
  set coach_invite_token = v_new_token, coach_invite_token_rotated_at = now()
  where id = p_team_id;

  return v_new_token;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."get_team_invite_links"("p_team_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.is_team_head(p_team_id) then
    raise exception 'not authorized';
  end if;

  return (
    select jsonb_build_object(
      'invite_token', invite_token,
      'invite_token_rotated_at', invite_token_rotated_at,
      'coach_invite_token', coach_invite_token,
      'coach_invite_token_rotated_at', coach_invite_token_rotated_at
    )
    from public.teams where id = p_team_id
  );
end;
$$;

CREATE OR REPLACE FUNCTION "public"."sessions_g3_team_check"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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

CREATE OR REPLACE FUNCTION "public"."join_team_via_invite"("p_token" "text", "p_profile" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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

  insert into public.pitcher_teams (pitcher_id, team_id)
  values (v_prof, v_team_id)
  on conflict (pitcher_id, team_id) do nothing;

  return jsonb_build_object('ok', true, 'team_id', v_team_id, 'team_name', v_team_name, 'profile_id', v_prof);
end;
$$;

CREATE OR REPLACE FUNCTION "public"."join_team_as_coach"("p_token" "text", "p_profile" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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

  insert into public.team_coaches (team_id, coach_id, role, invited_by)
  values (v_team_id, v_prof, 'assistant', v_head_id)
  on conflict (team_id, coach_id) do nothing;

  return jsonb_build_object('ok', true, 'team_id', v_team_id, 'team_name', v_team_name, 'profile_id', v_prof);
end;
$$;

CREATE OR REPLACE FUNCTION "public"."get_team_leaderboard"("p_team_id" "uuid", "p_window" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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
$$;

drop function if exists public.is_team_archived(uuid);
alter table public.teams drop constraint if exists teams_name_length;
alter table public.teams drop column if exists archived_by, drop column if exists archived_at;
