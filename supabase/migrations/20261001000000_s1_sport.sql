-- S1 (Track S, Joel Oct 1 2026): softball -- the sport foundation.
--
-- Every profile, team and session has a sport, 'baseball' or 'softball'.
-- Existing rows are stamped baseball (the ADD COLUMN default), then the
-- defaults are dropped: from here on a row's sport is DERIVED, never taken
-- from the client --
--   profiles: from the signup's intended_sport (signUp metadata; the sport
--             chooser, or a join link's team sport), else baseball;
--   teams:    from the creating coach's profile; never changes;
--   sessions: from the pitcher's profile; never changes;
--   pitcher_teams / team_coaches: refused ('sport_mismatch') when the
--             profile's sport isn't the team's.
-- A profile's sport can't change once it has a session or a team.
--
-- Decisions (Joel, Oct 1): the trigger functions are SECURITY DEFINER and
-- read-only (search_path ''), so a reader's RLS can never hide the team or
-- profile row they need and make them see "no sport". No RLS policy is
-- added, dropped or changed (32 before = 32 after). No policy references
-- teams/pitcher_teams (42P17); triggers may read them.
--
-- profiles.account_id (= id for every profile today) is S3's ownership key,
-- added now so S3 is a policy change, not a data migration. Filled for new
-- profiles by the same trigger.
--
-- The leaderboard returns an empty board for a softball team. The two
-- join-link lookups also return the team's sport, so join pages can theme
-- themselves and sign the new profile up in the team's sport.
--
-- Rollback (manual):
--   drop trigger if exists profiles_s1_sport on public.profiles;
--   drop trigger if exists teams_s1_sport on public.teams;
--   drop trigger if exists sessions_s1_sport on public.sessions;
--   drop trigger if exists pitcher_teams_s1_sport on public.pitcher_teams;
--   drop trigger if exists team_coaches_s1_sport on public.team_coaches;
--   drop function if exists public.s1_profiles_sport(), public.s1_teams_sport(),
--     public.s1_sessions_sport(), public.s1_membership_sport();
--   alter table public.profiles drop column if exists account_id, drop column if exists sport;
--   alter table public.teams drop column if exists sport;
--   alter table public.sessions drop column if exists sport;
--   then re-apply get_team_leaderboard / resolve_team_invite / resolve_coach_invite
--   from supabase/schema/schema.sql as of 20260930020000.

-- ---------- columns ----------
alter table public.profiles add column sport text not null default 'baseball'
  constraint profiles_sport_check check (sport in ('baseball', 'softball'));
alter table public.teams add column sport text not null default 'baseball'
  constraint teams_sport_check check (sport in ('baseball', 'softball'));
alter table public.sessions add column sport text not null default 'baseball'
  constraint sessions_sport_check check (sport in ('baseball', 'softball'));

alter table public.profiles alter column sport drop default;
alter table public.teams alter column sport drop default;
alter table public.sessions alter column sport drop default;

comment on column public.profiles.sport is 'S1: baseball | softball. One sport per profile, ever (S3 adds a second profile, never a second sport). Set at signup from intended_sport; locked once the profile has a session or a team.';
comment on column public.teams.sport is 'S1: the creating coach''s sport; never changes. Members must match (sport_mismatch).';
comment on column public.sessions.sport is 'S1: the pitcher''s sport, set by trigger; never from the client.';

alter table public.profiles add column account_id uuid;
update public.profiles set account_id = id;
alter table public.profiles alter column account_id set not null;
alter table public.profiles add constraint profiles_account_id_fkey
  foreign key (account_id) references auth.users(id) on delete cascade;
create index profiles_account_id_idx on public.profiles(account_id);
comment on column public.profiles.account_id is 'S1 (for S3): the login that owns this profile. = id for every profile until S3 adds child / second-sport profiles.';

-- ---------- triggers ----------
create function public.s1_profiles_sport() returns trigger
language plpgsql security definer set search_path = '' as $$
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
$$;
create trigger profiles_s1_sport before insert or update on public.profiles
  for each row execute function public.s1_profiles_sport();

create function public.s1_teams_sport() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_coach_sport text;
begin
  if tg_op = 'INSERT' then
    select p.sport into v_coach_sport from public.profiles p where p.id = new.coach_id;
    v_coach_sport := coalesce(v_coach_sport, 'baseball');
    if new.sport is null then
      new.sport := v_coach_sport;
    elsif new.sport <> v_coach_sport then
      raise exception 'sport_mismatch'
        using detail = format('A %s coach can''t create a %s team.', v_coach_sport, new.sport);
    end if;
    return new;
  end if;
  if new.sport is distinct from old.sport then
    raise exception 'sport_locked' using detail = 'A team''s sport can''t change.';
  end if;
  return new;
end;
$$;
create trigger teams_s1_sport before insert or update on public.teams
  for each row execute function public.s1_teams_sport();

create function public.s1_sessions_sport() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_pitcher_sport text;
begin
  if tg_op = 'UPDATE' then
    if new.sport is distinct from old.sport then
      raise exception 'sport_locked' using detail = 'A session''s sport can''t change.';
    end if;
    return new;
  end if;
  select p.sport into v_pitcher_sport from public.profiles p where p.id = new.pitcher_id;
  v_pitcher_sport := coalesce(v_pitcher_sport, 'baseball');
  if new.sport is null then
    new.sport := v_pitcher_sport;
  elsif new.sport <> v_pitcher_sport then
    raise exception 'sport_mismatch'
      using detail = format('This pitcher is %s; a %s session can''t be saved for them.', v_pitcher_sport, new.sport);
  end if;
  return new;
end;
$$;
create trigger sessions_s1_sport before insert or update on public.sessions
  for each row execute function public.s1_sessions_sport();

create function public.s1_membership_sport() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_member      uuid;
  v_member_sport text;
  v_team_sport  text;
begin
  if tg_table_name = 'pitcher_teams' then
    v_member := new.pitcher_id;
  else
    v_member := new.coach_id;
  end if;
  select t.sport into v_team_sport from public.teams t where t.id = new.team_id;
  select p.sport into v_member_sport from public.profiles p where p.id = v_member;
  if v_team_sport is distinct from v_member_sport then
    raise exception 'sport_mismatch'
      using detail = format('This is a %s team; this account is %s.', coalesce(v_team_sport, 'unknown'), coalesce(v_member_sport, 'unknown'));
  end if;
  return new;
end;
$$;
create trigger pitcher_teams_s1_sport before insert or update on public.pitcher_teams
  for each row execute function public.s1_membership_sport();
create trigger team_coaches_s1_sport before insert or update on public.team_coaches
  for each row execute function public.s1_membership_sport();

revoke all on function public.s1_profiles_sport(), public.s1_teams_sport(),
  public.s1_sessions_sport(), public.s1_membership_sport() from public, anon, authenticated;

-- ---------- join-link lookups: also return the team's sport ----------
drop function public.resolve_team_invite(text);
create function public.resolve_team_invite(p_token text)
returns table (team_id uuid, team_name text, team_sport text)
language sql security definer set search_path = '' as $$
  select id, name, sport from public.teams where invite_token = p_token;
$$;
revoke all on function public.resolve_team_invite(text) from public;
grant execute on function public.resolve_team_invite(text) to anon, authenticated, service_role;

drop function public.resolve_coach_invite(text);
create function public.resolve_coach_invite(p_token text)
returns table (team_id uuid, team_name text, team_sport text)
language sql security definer set search_path = '' as $$
  select id, name, sport from public.teams where coach_invite_token = p_token;
$$;
revoke all on function public.resolve_coach_invite(text) from public;
grant execute on function public.resolve_coach_invite(text) to anon, authenticated, service_role;

-- ---------- leaderboard: none for softball ----------
CREATE OR REPLACE FUNCTION "public"."get_team_leaderboard"("p_team_id" "uuid", "p_window" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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
$$;
