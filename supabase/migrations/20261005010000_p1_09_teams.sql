-- P1-09 (Joel, Oct 5 2026): rename, archive, restore and delete a team.
-- The rule: a team that has sessions is never destroyed -- it is ARCHIVED (gone from every list,
-- invite links off, no new sessions, history readable, restorable by the head coach). A team with
-- NO sessions can be deleted. All head-coach only; assistants and pitchers refused.
-- Since the teams hotfix (Oct 5) clients can't write teams directly, so every change is a function
-- below. sessions.team_id is ON DELETE RESTRICT, so the database itself also refuses to delete a
-- team with sessions. No policy changes (34 stays 34).
-- delete_team removes the roster rows FIRST, while the team still exists, so the G3 departure
-- trigger can log them; deleting the team then removes those log rows, invites and leaderboard
-- exclusions by cascade. (Deleting the team row first fails: the trigger would log a departure
-- from a team that no longer exists.)
-- Rollback: supabase/rollback/20261005010000_p1_09_teams_down.sql

alter table public.teams
  add column archived_at timestamptz,
  add column archived_by uuid references public.profiles(id) on delete set null;
alter table public.teams
  add constraint teams_name_length check (char_length(btrim(name)) between 2 and 60);
comment on column public.teams.archived_at is 'P1-09: set by archive_team(), cleared by restore_team(). Archived = hidden from lists, invite links off, no new sessions, history readable.';
grant select (archived_at, archived_by) on public.teams to authenticated;

create or replace function public.is_team_archived(p_team_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select t.archived_at is not null from public.teams t where t.id = p_team_id), false);
$$;
revoke all on function public.is_team_archived(uuid) from public, anon;
grant execute on function public.is_team_archived(uuid) to authenticated;

-- ---------------------------------------------------------------- rename (2-60 characters)
create or replace function public.rename_team(p_team_id uuid, p_name text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_team_head(p_team_id) then
    raise exception 'not authorized';
  end if;
  if public.is_team_archived(p_team_id) then
    raise exception 'team_archived' using detail = 'This team is archived. Restore it first.';
  end if;
  if p_name is null or char_length(btrim(p_name)) < 2 or char_length(btrim(p_name)) > 60 then
    raise exception 'team_name_length' using detail = 'A team name is 2 to 60 characters.';
  end if;
  update public.teams set name = btrim(p_name) where id = p_team_id;
end;
$$;

create or replace function public.set_team_level(p_team_id uuid, p_level text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_team_head(p_team_id) then
    raise exception 'not authorized';
  end if;
  if public.is_team_archived(p_team_id) then
    raise exception 'team_archived' using detail = 'This team is archived. Restore it first.';
  end if;
  update public.teams set level = p_level where id = p_team_id;
end;
$$;

-- ---------------------------------------------------------------- archive / restore / delete
create or replace function public.archive_team(p_team_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_team_head(p_team_id) then
    return jsonb_build_object('ok', false, 'error', 'not_authorized');
  end if;
  if public.is_team_archived(p_team_id) then
    return jsonb_build_object('ok', false, 'error', 'already_archived');
  end if;
  update public.teams set archived_at = now(), archived_by = coach_id where id = p_team_id;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.restore_team(p_team_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_team_head(p_team_id) then
    return jsonb_build_object('ok', false, 'error', 'not_authorized');
  end if;
  if not public.is_team_archived(p_team_id) then
    return jsonb_build_object('ok', false, 'error', 'not_archived');
  end if;
  update public.teams set archived_at = null, archived_by = null where id = p_team_id;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.delete_team(p_team_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_n integer;
begin
  if not public.is_team_head(p_team_id) then
    return jsonb_build_object('ok', false, 'error', 'not_authorized');
  end if;
  if public.is_team_archived(p_team_id) then
    return jsonb_build_object('ok', false, 'error', 'team_archived');
  end if;
  -- Every session counts, deleted (tombstoned) ones included: their rows still name this team.
  select count(*) into v_n from public.sessions where team_id = p_team_id;
  if v_n > 0 then
    return jsonb_build_object('ok', false, 'error', 'has_sessions', 'sessions', v_n,
      'message', format('This team has %s session%s and can be archived, not deleted.', v_n, case when v_n = 1 then '' else 's' end));
  end if;
  delete from public.pitcher_teams where team_id = p_team_id;   -- departures logged while the team exists
  delete from public.team_coaches where team_id = p_team_id;
  delete from public.teams where id = p_team_id;                -- departures, invites, exclusions cascade
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.archive_team(uuid) from public, anon;
revoke all on function public.restore_team(uuid) from public, anon;
revoke all on function public.delete_team(uuid) from public, anon;
grant execute on function public.archive_team(uuid) to authenticated;
grant execute on function public.restore_team(uuid) to authenticated;
grant execute on function public.delete_team(uuid) to authenticated;

-- ---------------------------------------------------------------- invite links off while archived
drop function public.resolve_team_invite(text);
create or replace function public.resolve_team_invite(p_token text)
returns table(team_id uuid, team_name text, team_sport text, team_archived boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select id, name, sport, archived_at is not null from public.teams where invite_token = p_token;
$$;
drop function public.resolve_coach_invite(text);
create or replace function public.resolve_coach_invite(p_token text)
returns table(team_id uuid, team_name text, team_sport text, team_archived boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select id, name, sport, archived_at is not null from public.teams where coach_invite_token = p_token;
$$;
revoke all on function public.resolve_team_invite(text) from public;
revoke all on function public.resolve_coach_invite(text) from public;
grant execute on function public.resolve_team_invite(text) to anon, authenticated;
grant execute on function public.resolve_coach_invite(text) to anon, authenticated;

-- ---------------------------------------------------------------- existing functions, archived check added
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

  if public.is_team_archived(p_team_id) then
    raise exception 'team_archived' using detail = 'This team is archived. Restore it first.';
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

  if public.is_team_archived(p_team_id) then
    raise exception 'team_archived' using detail = 'This team is archived. Restore it first.';
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

  if public.is_team_archived(p_team_id) then
    raise exception 'team_archived' using detail = 'This team is archived. Restore it first.';
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
  -- P1-09: an archived team takes no new sessions (also inside sync_session).
  if public.is_team_archived(new.team_id) then
    raise exception 'team_archived' using errcode = 'check_violation', detail = 'This team is archived; it can''t take new sessions.';
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
  if public.is_team_archived(v_team_id) then
    return jsonb_build_object('error', 'team_archived');   -- P1-09
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
  if public.is_team_archived(v_team_id) then
    return jsonb_build_object('error', 'team_archived');   -- P1-09
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
