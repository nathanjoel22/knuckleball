-- S4 Stage A (Joel, Oct 2 2026): one login, many profiles.
--
-- A login (auth user) owns one or more profiles (profiles.account_id). Its
-- PRIMARY profile has id = account_id, as every profile does today; a login
-- can add a second-sport profile of itself (Stage A) and, in Stage B,
-- players it manages (managed_by). Every policy and function that compared
-- auth.uid() to a profile id now asks "does the caller's login own this
-- profile?" via is_my_profile(). Team helpers ask "does the caller own a
-- coach/pitcher profile on this team?". Account-level facts (email,
-- email_verified_at) stay on the primary profile and are read through
-- account_id.
--
-- For every EXISTING login (exactly one profile each, id = account_id) the
-- results are unchanged -- proven by supabase/tests/s4_rls_matrix.sql run
-- before and after on staging.
--
-- Functions that act as the caller take an optional profile id. When it is
-- omitted they use the login's ONLY profile (my_single_profile()); a login
-- with several profiles must say which one ('profile_required'). Nothing
-- falls back to auth.uid() as a profile id.
--
-- Joel's calls (Oct 2): sessions.pitcher_id / logged_by / deleted_by,
-- teams.coach_id and invites.invited_by now reference profiles, not logins;
-- the 4 headshot storage policies are rewritten the same way; the invites
-- table's policies are rewritten like the rest.
--
-- No policy references teams and pitcher_teams directly (42P17). Policy
-- count: 35 public + 4 storage before and after (rewritten, not added).
--
-- Rollback: supabase/rollback/20261002020000_s4a_profiles_down.sql
-- (written before deploy; restores every object verbatim from production).

-- =====================================================================
-- 1. Schema
-- =====================================================================

-- Profiles no longer need their own login; the login is account_id.
alter table public.profiles drop constraint profiles_id_fkey;

-- Columns that pointed at logins now point at profiles. Every existing
-- value already has a matching profile (checked: 0 orphans, both projects).
alter table public.sessions
  drop constraint sessions_pitcher_id_fkey,
  add constraint sessions_pitcher_id_fkey foreign key (pitcher_id) references public.profiles(id) on delete cascade,
  drop constraint sessions_logged_by_fkey,
  add constraint sessions_logged_by_fkey foreign key (logged_by) references public.profiles(id),
  drop constraint sessions_deleted_by_fkey,
  add constraint sessions_deleted_by_fkey foreign key (deleted_by) references public.profiles(id);
alter table public.teams
  drop constraint teams_coach_id_fkey,
  add constraint teams_coach_id_fkey foreign key (coach_id) references public.profiles(id) on delete cascade;
alter table public.invites
  drop constraint invites_invited_by_fkey,
  add constraint invites_invited_by_fkey foreign key (invited_by) references public.profiles(id);

alter table public.profiles
  add column managed_by uuid references public.profiles(id) on delete cascade,
  add column is_primary boolean generated always as (id = account_id) stored;
comment on column public.profiles.managed_by is 'S4: set on a player profile created by a parent (Stage B); null for a login''s own profiles.';
comment on column public.profiles.is_primary is 'S4: true for the login''s own first profile (id = account_id), which holds email verification and, in Stage B, attestation.';

alter table public.profiles drop constraint profiles_role_check;
alter table public.profiles add constraint profiles_role_check check (role in ('coach', 'pitcher', 'parent'));
alter table public.profiles alter column sport drop not null;
alter table public.profiles drop constraint profiles_sport_check;
alter table public.profiles add constraint profiles_sport_check check (
  (role = 'parent' and sport is null) or (role <> 'parent' and sport in ('baseball', 'softball'))
);

-- One of each (sport, role) per login for its own profiles; managed players
-- are exempt (a parent can have two baseball players).
create unique index profiles_one_per_sport_role on public.profiles (account_id, sport, role) where managed_by is null;

-- Abuse guard: at most 10 profiles per login.
create or replace function public.profiles_s4_cap()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select count(*) from public.profiles p where p.account_id = coalesce(new.account_id, new.id)) >= 10 then
    raise exception 'profile_limit' using detail = 'A login can hold at most 10 profiles.';
  end if;
  return new;
end;
$$;
create trigger profiles_s4_cap before insert on public.profiles
  for each row execute function public.profiles_s4_cap();
revoke all on function public.profiles_s4_cap() from public, anon, authenticated;

-- S1's profile trigger: a parent profile has no sport.
create or replace function public.s1_profiles_sport()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

-- =====================================================================
-- 2. Ownership helpers
-- =====================================================================

-- Does the caller's login own profile p?
create or replace function public.is_my_profile(p uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.profiles pr where pr.id = p and pr.account_id = auth.uid());
$$;
revoke all on function public.is_my_profile(uuid) from public;
grant execute on function public.is_my_profile(uuid) to anon, authenticated;

-- The caller's login's only profile, or null when it has none or several.
-- Used ONLY as the default when a function isn't told which profile.
create or replace function public.my_single_profile()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select case when count(*) = 1 then (array_agg(pr.id))[1] end
    from public.profiles pr where pr.account_id = auth.uid();
$$;
revoke all on function public.my_single_profile() from public, anon;
grant execute on function public.my_single_profile() to authenticated;

-- Headshots are named <profile id>.jpg.
create or replace function public.is_my_headshot(p_object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.profiles pr where pr.id::text || '.jpg' = p_object_name and pr.account_id = auth.uid());
$$;
revoke all on function public.is_my_headshot(text) from public;
grant execute on function public.is_my_headshot(text) to anon, authenticated;

-- Team helpers: "the caller owns a profile in that row".
create or replace function public.is_team_coach(check_team_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.team_coaches tc join public.profiles pr on pr.id = tc.coach_id
     where tc.team_id = check_team_id and pr.account_id = auth.uid()
  );
$$;

create or replace function public.is_team_head(check_team_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.teams t join public.profiles pr on pr.id = t.coach_id
     where t.id = check_team_id and pr.account_id = auth.uid()
  );
$$;

create or replace function public.is_team_member(check_team_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.pitcher_teams pt join public.profiles pr on pr.id = pt.pitcher_id
     where pt.team_id = check_team_id and pr.account_id = auth.uid()
  );
$$;

create or replace function public.is_coach_of_session(p_session_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.sessions s
      join public.team_coaches tc on tc.team_id = s.team_id
      join public.profiles cp on cp.id = tc.coach_id and cp.account_id = auth.uid()
      join public.pitcher_teams pt on pt.team_id = s.team_id and pt.pitcher_id = s.pitcher_id
     where s.id = p_session_id
       and s.started_at >= pt.joined_at
  );
$$;

create or replace function public.is_coach_of_session_team(p_session_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.sessions s
      join public.team_coaches tc on tc.team_id = s.team_id
      join public.profiles cp on cp.id = tc.coach_id and cp.account_id = auth.uid()
     where s.id = p_session_id
  );
$$;

-- =====================================================================
-- 3. Policies (same names, same commands; auth.uid() -> ownership)
-- =====================================================================

drop policy "Pitcher or their coach manages zones" on public.accuracy_zones;
create policy "Pitcher or their coach manages zones" on public.accuracy_zones for all
  using (public.is_my_profile(pitcher_id) or public.is_coach_of_pitcher(pitcher_id))
  with check (public.is_my_profile(pitcher_id) or public.is_coach_of_pitcher(pitcher_id));

drop policy "Pitchers manage events in own sessions" on public.game_events;
create policy "Pitchers manage events in own sessions" on public.game_events for all
  using (exists (select 1 from public.sessions s where s.id = game_events.session_id and public.is_my_profile(s.pitcher_id)))
  with check (exists (select 1 from public.sessions s where s.id = game_events.session_id and public.is_my_profile(s.pitcher_id)));

drop policy "Coaches manage own team invites" on public.invites;
create policy "Coaches manage own team invites" on public.invites for all
  using (exists (select 1 from public.teams t where t.id = invites.team_id and public.is_my_profile(t.coach_id)))
  with check (exists (select 1 from public.teams t where t.id = invites.team_id and public.is_my_profile(t.coach_id)));

drop policy "Pitchers accept invite by inserting own membership" on public.pitcher_teams;
create policy "Pitchers accept invite by inserting own membership" on public.pitcher_teams for insert
  with check (public.is_my_profile(pitcher_id));

drop policy "Pitchers view own memberships" on public.pitcher_teams;
create policy "Pitchers view own memberships" on public.pitcher_teams for select
  using (public.is_my_profile(pitcher_id));

drop policy "Pitchers manage pitches in own sessions" on public.pitches;
create policy "Pitchers manage pitches in own sessions" on public.pitches for all
  using (exists (select 1 from public.sessions s where s.id = pitches.session_id and public.is_my_profile(s.pitcher_id)))
  with check (exists (select 1 from public.sessions s where s.id = pitches.session_id and public.is_my_profile(s.pitcher_id)));

-- profiles: the login sees and updates every profile it owns. Inserting by
-- the client stays limited to the login's primary profile (other profiles
-- are created only by SECURITY DEFINER functions).
drop policy "Users update own profile" on public.profiles;
create policy "Users update own profile" on public.profiles for update
  using (account_id = auth.uid());
drop policy "Users view own profile" on public.profiles;
create policy "Users view own profile" on public.profiles for select
  using (account_id = auth.uid());
-- "Users insert own profile" (check id = auth.uid()) is unchanged on purpose.

drop policy "Viewers insert own roster-seen rows" on public.roster_seen;
create policy "Viewers insert own roster-seen rows" on public.roster_seen for insert
  with check (public.is_my_profile(viewer_id));
drop policy "Viewers read own roster-seen rows" on public.roster_seen;
create policy "Viewers read own roster-seen rows" on public.roster_seen for select
  using (public.is_my_profile(viewer_id));
drop policy "Viewers update own roster-seen rows" on public.roster_seen;
create policy "Viewers update own roster-seen rows" on public.roster_seen for update
  using (public.is_my_profile(viewer_id)) with check (public.is_my_profile(viewer_id));

drop policy "Authors delete their own notes" on public.session_notes;
create policy "Authors delete their own notes" on public.session_notes for delete
  using (public.is_my_profile(author_id));
drop policy "Coaches add notes to their pitchers' sessions" on public.session_notes;
create policy "Coaches add notes to their pitchers' sessions" on public.session_notes for insert
  with check (public.is_my_profile(author_id) and public.is_coach_of_session(session_id));
drop policy "Notes readable by author, pitcher and his team's coaches" on public.session_notes;
create policy "Notes readable by author, pitcher and his team's coaches" on public.session_notes for select
  using (
    public.is_my_profile(author_id)
    or exists (select 1 from public.sessions s where s.id = session_notes.session_id and public.is_my_profile(s.pitcher_id))
    or public.is_coach_of_session_team(session_id)
  );

drop policy "Viewers insert own session-opened rows" on public.session_opened;
create policy "Viewers insert own session-opened rows" on public.session_opened for insert
  with check (public.is_my_profile(viewer_id));
drop policy "Viewers read own session-opened rows" on public.session_opened;
create policy "Viewers read own session-opened rows" on public.session_opened for select
  using (public.is_my_profile(viewer_id));

drop policy "Pitchers manage own sessions" on public.sessions;
create policy "Pitchers manage own sessions" on public.sessions for all
  using (public.is_my_profile(pitcher_id)) with check (public.is_my_profile(pitcher_id));

-- Headshots (storage).
drop policy "Headshots: player and his coaches can read" on storage.objects;
create policy "Headshots: player and his coaches can read" on storage.objects for select
  using (bucket_id = 'headshots' and (public.is_my_headshot(name) or public.can_view_headshot(name)));
drop policy "Headshots: player removes his own" on storage.objects;
create policy "Headshots: player removes his own" on storage.objects for delete
  using (bucket_id = 'headshots' and public.is_my_headshot(name));
drop policy "Headshots: player replaces his own" on storage.objects;
create policy "Headshots: player replaces his own" on storage.objects for update
  using (bucket_id = 'headshots' and public.is_my_headshot(name))
  with check (bucket_id = 'headshots' and public.is_my_headshot(name));
drop policy "Headshots: player uploads his own" on storage.objects;
create policy "Headshots: player uploads his own" on storage.objects for insert
  with check (bucket_id = 'headshots' and public.is_my_headshot(name));

-- =====================================================================
-- 4. Functions that act as the caller
-- =====================================================================

-- create_team: the team's head is the caller's profile (the one given, or
-- the login's only profile).
drop function public.create_team(text);
create or replace function public.create_team(p_name text, p_profile uuid default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_coach uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if p_profile is not null then
    if not public.is_my_profile(p_profile) then raise exception 'not_your_profile'; end if;
    v_coach := p_profile;
  else
    v_coach := public.my_single_profile();
    if v_coach is null then raise exception 'profile_required'; end if;
  end if;
  if p_name is null or btrim(p_name) = '' then
    raise exception 'team name cannot be blank';
  end if;
  return public._create_team_with_head(v_coach, btrim(p_name));
end;
$$;
revoke all on function public.create_team(text, uuid) from public, anon;
grant execute on function public.create_team(text, uuid) to authenticated;

-- delete_session: the deleter is the owned pitcher profile, or the team's
-- head (its coach profile).
create or replace function public.delete_session(p_session_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pitcher     uuid;
  v_team        uuid;
  v_role        text;
  v_by          uuid;
  v_count       integer;
  v_event_count integer;
  v_name        text;
  v_report      text;
begin
  if auth.uid() is null then
    return jsonb_build_object('error', 'not authenticated');
  end if;

  select pitcher_id, team_id, report_path into v_pitcher, v_team, v_report
  from public.sessions
  where id = p_session_id and deleted_at is null;
  if not found then
    return jsonb_build_object('error', 'session not found or already deleted');
  end if;

  if public.is_my_profile(v_pitcher) then
    v_role := 'pitcher';
    v_by := v_pitcher;
  elsif public.is_team_head(v_team) then
    v_role := 'coach';
    v_by := (select t.coach_id from public.teams t where t.id = v_team);
  else
    return jsonb_build_object('error', 'not entitled to delete this session');
  end if;

  select full_name into v_name from public.profiles where id = v_by;

  select count(*) into v_count from public.pitches where session_id = p_session_id;
  select count(*) into v_event_count from public.game_events where session_id = p_session_id;

  update public.sessions
     set deleted_at      = now(),
         deleted_by      = v_by,
         deleted_by_role = v_role,
         deleted_by_name = v_name,
         pitch_count     = v_count
   where id = p_session_id;

  delete from public.game_events where session_id = p_session_id;
  delete from public.pitches where session_id = p_session_id;

  return jsonb_build_object('ok', true, 'report_path', v_report, 'event_count', v_event_count);
end;
$$;

-- Removal notice: the pitcher's LOGIN email.
create or replace function public.get_removal_notice_info(p_pitcher_id uuid, p_team_id uuid)
returns table(email text, team_name text)
language plpgsql
security definer
set search_path = ''
as $$
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
    from public.profiles pr
    join auth.users u on u.id = pr.account_id
    cross join public.teams t
    where pr.id = p_pitcher_id and t.id = p_team_id;
end;
$$;

-- Roster verification: each pitcher's LOGIN email and its verification
-- (held on the login's primary profile).
create or replace function public.get_roster_verification(p_team_id uuid)
returns table(pitcher_id uuid, email text, email_confirmed boolean)
language sql
security definer
set search_path = ''
as $$
  select pt.pitcher_id, u.email, acct.email_verified_at is not null
  from public.pitcher_teams pt
  join public.profiles pr on pr.id = pt.pitcher_id
  join auth.users u on u.id = pr.account_id
  join public.profiles acct on acct.id = pr.account_id
  where pt.team_id = p_team_id
    and public.is_team_coach(p_team_id);
$$;

-- Leaderboard: "is_me" = a profile the caller owns.
create or replace function public.get_team_leaderboard(p_team_id uuid, p_window text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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

-- Session dots: the viewer is a profile the caller owns (the one given, or
-- the login's only profile).
drop function public.get_unopened_sessions(uuid);
create or replace function public.get_unopened_sessions(p_team_id uuid, p_viewer uuid default null)
returns table (session_id uuid, pitcher_id uuid)
language sql
stable
security invoker
set search_path = ''
as $$
  with v as (
    select case when p_viewer is not null then (case when public.is_my_profile(p_viewer) then p_viewer end)
                else public.my_single_profile() end as viewer
  )
  select s.id, s.pitcher_id
    from v, public.sessions s
    join public.pitcher_teams pt on pt.team_id = s.team_id and pt.pitcher_id = s.pitcher_id
   where v.viewer is not null
     and s.team_id = p_team_id
     and s.deleted_at is null
     and s.ended_at is not null
     and s.started_at >= pt.joined_at
     and s.ended_at > public.session_dots_since()
     and s.ended_at > coalesce(
           (select tc.joined_at from public.team_coaches tc
             where tc.team_id = p_team_id and tc.coach_id = v.viewer),
           '-infinity'::timestamptz)
     and not exists (
       select 1 from public.session_opened o
        where o.viewer_id = v.viewer and o.session_id = s.id
     );
$$;
revoke all on function public.get_unopened_sessions(uuid, uuid) from public, anon;
grant execute on function public.get_unopened_sessions(uuid, uuid) to authenticated;

-- Hand-off: the outgoing head is the team's current head profile.
create or replace function public.hand_off_team_head(p_team_id uuid, p_new_head_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old uuid;
begin
  if auth.uid() is null then
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

  v_old := (select t.coach_id from public.teams t where t.id = p_team_id);
  update public.team_coaches set role = 'assistant' where team_id = p_team_id and coach_id = v_old;
  update public.team_coaches set role = 'head'      where team_id = p_team_id and coach_id = p_new_head_id;
  update public.teams set coach_id = p_new_head_id where id = p_team_id;
end;
$$;

-- Report gate (A4, recorded as an amendment): verification is the
-- profile's LOGIN's (its primary profile's email_verified_at).
create or replace function public.is_pitcher_report_eligible(p_pitcher_id uuid)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select
    coalesce((select acct.email_verified_at is not null
                from public.profiles pr join public.profiles acct on acct.id = pr.account_id
               where pr.id = p_pitcher_id), false)
    and exists (select 1 from public.pitcher_teams where pitcher_id = p_pitcher_id);
$$;

-- Joining: the joining profile is the one given (must be owned), else the
-- login's own profile of the team's sport and the link's role, else the
-- login's only profile (so the old errors still read the same).
drop function public.join_team_as_coach(text);
create or replace function public.join_team_as_coach(p_token text, p_profile uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_prof uuid;
  v_role text;
  v_team_id uuid;
  v_team_name text;
  v_team_sport text;
  v_head_id uuid;
begin
  if auth.uid() is null then
    return jsonb_build_object('error', 'not_authenticated');
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
revoke all on function public.join_team_as_coach(text, uuid) from public, anon;
grant execute on function public.join_team_as_coach(text, uuid) to authenticated;

drop function public.join_team_via_invite(text);
create or replace function public.join_team_via_invite(p_token text, p_profile uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_prof uuid;
  v_team_id uuid;
  v_team_name text;
  v_team_sport text;
  v_role text;
begin
  if auth.uid() is null then
    return jsonb_build_object('error', 'not_authenticated');
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
revoke all on function public.join_team_via_invite(text, uuid) from public, anon;
grant execute on function public.join_team_via_invite(text, uuid) to authenticated;

-- A pitcher's own uniform number: the profile given, or the login's
-- profile that's on that team.
drop function public.set_my_uniform_number(uuid, smallint);
create or replace function public.set_my_uniform_number(p_team_id uuid, p_number smallint, p_profile uuid default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_prof uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if p_profile is not null then
    if not public.is_my_profile(p_profile) then raise exception 'not_your_profile'; end if;
    v_prof := p_profile;
  else
    select case when count(*) = 1 then (array_agg(pt.pitcher_id))[1] end into v_prof
      from public.pitcher_teams pt join public.profiles pr on pr.id = pt.pitcher_id
     where pt.team_id = p_team_id and pr.account_id = auth.uid();
  end if;

  update public.pitcher_teams
     set uniform_number = p_number
   where pitcher_id = v_prof
     and team_id = p_team_id;

  if not found then
    raise exception 'not a member of that team';
  end if;
end;
$$;
revoke all on function public.set_my_uniform_number(uuid, smallint, uuid) from public, anon;
grant execute on function public.set_my_uniform_number(uuid, smallint, uuid) to authenticated;

create or replace function public.set_uniform_number(p_team_id uuid, p_pitcher_id uuid, p_number smallint, p_expected smallint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current smallint;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if p_number is not null and (p_number < 0 or p_number > 99) then
    raise exception 'uniform number must be between 0 and 99';
  end if;

  if not (public.is_my_profile(p_pitcher_id) or public.is_team_head(p_team_id)) then
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
$$;

-- =====================================================================
-- 5. Add a sport (A7): a second profile of the same person, same role,
--    the other sport, under the same login. No team is created.
-- =====================================================================
create or replace function public.add_sport_profile(p_sport text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_primary public.profiles%rowtype;
  v_new uuid := gen_random_uuid();
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if p_sport not in ('baseball', 'softball') then
    raise exception 'invalid sport';
  end if;
  select * into v_primary from public.profiles where id = auth.uid();
  if not found or v_primary.role not in ('coach', 'pitcher') then
    raise exception 'no_profile_to_copy';
  end if;
  if exists (select 1 from public.profiles where account_id = auth.uid() and managed_by is null
              and role = v_primary.role and sport = p_sport) then
    raise exception 'already_have_sport';
  end if;
  insert into public.profiles (id, account_id, role, full_name, sport, throws, uses_radar_gun)
  values (v_new, auth.uid(), v_primary.role, v_primary.full_name, p_sport, v_primary.throws, v_primary.uses_radar_gun);
  return v_new;
end;
$$;
revoke all on function public.add_sport_profile(text) from public, anon;
grant execute on function public.add_sport_profile(text) to authenticated;
