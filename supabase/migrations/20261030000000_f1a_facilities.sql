-- F1-A: training facilities -- organizations, the Facility Manager as head of both facility teams, per-coach groups,
-- narrowed R4 inside a facility, no leaderboard and no notes on facility teams.
-- Packet: plans/f1-training-facilities.md (v2); decisions: plans/f1a-preconditions.md (Joel, Oct 29 2026).
-- Rollback: supabase/rollback/20261030000000_f1a_facilities_down.sql. Tests: supabase/tests/f1a_rls_matrix.sql (every
-- login, before = after for kind='team') and supabase/tests/f1a_acceptance.sql.
--
-- No policy reads teams or pitcher_teams for a team check (42P17): every new check is a SECURITY DEFINER helper.

-- ---------------------------------------------------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------------------------------------------------

create table public.organizations (
  id            uuid primary key default gen_random_uuid(),
  name          text not null constraint organizations_name_length check (char_length(btrim(name)) between 2 and 60),
  manager_login uuid not null references auth.users(id),
  created_at    timestamptz not null default now()
);
alter table public.organizations enable row level security;
-- No client policies or grants: read through my_facility() and is_facility_login().

alter table public.teams
  add column org_id uuid references public.organizations(id) on delete restrict,
  add column kind text not null default 'team' constraint teams_kind_check check (kind in ('team', 'facility'));
alter table public.teams add constraint teams_facility_has_org check ((kind = 'facility') = (org_id is not null));
grant select (org_id, kind) on public.teams to anon, authenticated;   -- same as the team's other readable columns

-- One group per coach per facility team, made when the coach joins it (trigger below). join_token is F1-B's QR code:
-- never granted to clients.
create table public.coach_groups (
  id         uuid primary key default gen_random_uuid(),
  team_id    uuid not null references public.teams(id) on delete cascade,
  coach_id   uuid not null references public.profiles(id) on delete cascade,
  join_token text not null unique default (replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '')),
  created_at timestamptz not null default now(),
  unique (team_id, coach_id)
);
alter table public.coach_groups enable row level security;
grant select (id, team_id, coach_id, created_at) on public.coach_groups to authenticated;

-- A pitcher may be in several groups on a side (one membership, two coaches).
create table public.coach_group_members (
  group_id    uuid not null references public.coach_groups(id) on delete cascade,
  pitcher_id  uuid not null references public.profiles(id) on delete cascade,
  added_by    uuid references public.profiles(id) on delete set null,
  added_at    timestamptz not null default now(),
  flagged_new boolean not null default true,
  primary key (group_id, pitcher_id)
);
create index coach_group_members_pitcher on public.coach_group_members (pitcher_id);
alter table public.coach_group_members enable row level security;
grant select (group_id, pitcher_id, added_at, flagged_new) on public.coach_group_members to authenticated;

-- One-time signup links. Written only by Joel (SQL / service role); no client access at all.
create table public.facility_invites (
  token          text primary key default (replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '')),
  facility_name  text not null constraint facility_invites_name_length check (char_length(btrim(facility_name)) between 2 and 60),
  manager_email  text not null,
  baseball_level text not null constraint facility_invites_bb_level check (baseball_level in ('little_league', 'high_school', 'college')),
  softball_level text not null constraint facility_invites_sb_level check (softball_level in ('little_league', 'high_school_up')),
  expires_at     timestamptz not null default now() + interval '14 days',
  used_at        timestamptz,
  used_by        uuid references auth.users(id) on delete set null,
  org_id         uuid references public.organizations(id) on delete set null,
  created_at     timestamptz not null default now()
);
alter table public.facility_invites enable row level security;
revoke all on public.facility_invites from anon, authenticated;
revoke all on public.organizations from anon, authenticated;
revoke all on public.coach_groups from anon;
revoke all on public.coach_group_members from anon;
revoke insert, update, delete on public.coach_groups from authenticated;
revoke insert, update, delete on public.coach_group_members from authenticated;

-- ---------------------------------------------------------------------------------------------------------------
-- 2. Helpers (SECURITY DEFINER, so no policy reads teams / pitcher_teams itself)
-- ---------------------------------------------------------------------------------------------------------------

create function public.is_facility_team(p_team uuid) returns boolean
  language sql stable security definer set search_path to '' as $$
  select coalesce((select t.kind = 'facility' from public.teams t where t.id = p_team), false);
$$;

-- The manager = the head of a team that belongs to an organization.
create function public.is_org_manager(p_team uuid) returns boolean
  language sql stable security definer set search_path to '' as $$
  select public.is_team_head(p_team) and coalesce((select t.org_id is not null from public.teams t where t.id = p_team), false);
$$;

-- The caller coaches a group on this team that has this pitcher in it.
create function public.is_group_coach(p_pitcher uuid, p_team uuid) returns boolean
  language sql stable security definer set search_path to '' as $$
  select exists (
    select 1 from public.coach_group_members m
      join public.coach_groups g on g.id = m.group_id
      join public.profiles pr on pr.id = g.coach_id and pr.account_id = auth.uid()
     where m.pitcher_id = p_pitcher and g.team_id = p_team
  );
$$;

-- R4's coach check, narrowed inside a facility: the caller coaches this team, and either it's an ordinary team (then
-- this is exactly is_team_coach), or the caller is its head (the manager), or the pitcher is in the caller's group.
create function public.coach_sees_pitcher(p_team uuid, p_pitcher uuid) returns boolean
  language sql stable security definer set search_path to '' as $$
  select exists (
    select 1 from public.team_coaches tc
      join public.profiles pr on pr.id = tc.coach_id and pr.account_id = auth.uid()
      join public.teams t on t.id = tc.team_id
     where tc.team_id = p_team
       and (t.kind = 'team'
            or tc.coach_id = t.coach_id
            or exists (select 1 from public.coach_groups g join public.coach_group_members m on m.group_id = g.id
                        where g.team_id = p_team and g.coach_id = tc.coach_id and m.pitcher_id = p_pitcher))
  );
$$;

-- A login that manages an organization (the facility sign-in card, decision A).
create function public.is_facility_login() returns boolean
  language sql stable security definer set search_path to '' as $$
  select exists (select 1 from public.organizations o where o.manager_login = auth.uid());
$$;

-- Can the caller see this group member row: the side's manager, or a coach who sees the pitcher (their own group).
create function public.can_see_group_member(p_group uuid, p_pitcher uuid) returns boolean
  language sql stable security definer set search_path to '' as $$
  select coalesce((select public.coach_sees_pitcher(g.team_id, p_pitcher) from public.coach_groups g where g.id = p_group), false);
$$;

-- Like is_team_coach, these stay callable by every role: the read rules call them as the caller.

-- ---------------------------------------------------------------------------------------------------------------
-- 3. Read rules for the new tables (+2 policies: 30 -> 32)
-- ---------------------------------------------------------------------------------------------------------------

create policy "Coach groups: read by the side's coaches" on public.coach_groups for select
  using (public.is_team_coach(team_id));
create policy "Group members: read by the manager and the pitcher's own coach" on public.coach_group_members for select
  using (public.can_see_group_member(group_id, pitcher_id));

-- ---------------------------------------------------------------------------------------------------------------
-- 4. Narrowed R4 (Joel, Oct 29, decision D): on a facility team an assistant sees, charts and reports only their
--    group's pitchers. Every change is is_team_coach(team) -> coach_sees_pitcher(team, pitcher), which is exactly
--    is_team_coach on a kind='team' team. Functions: the live definitions with only the marked lines changed.
-- ---------------------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.can_view_headshot(p_object_name text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (
    select 1 from public.pitcher_teams pt
     where pt.pitcher_id::text || '.jpg' = p_object_name
       and public.coach_sees_pitcher(pt.team_id, pt.pitcher_id)   -- F1-A
  );
$function$;

CREATE OR REPLACE FUNCTION public.get_roster_closing(p_team_id uuid)
 RETURNS TABLE(pitcher_id uuid, closing_on timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select pt.pitcher_id, coalesce(pr.deletion_due_at, acct.deletion_due_at)
  from public.pitcher_teams pt
  join public.profiles pr on pr.id = pt.pitcher_id
  join public.profiles acct on acct.id = pr.account_id
  where pt.team_id = p_team_id
    and public.coach_sees_pitcher(p_team_id, pt.pitcher_id)   -- F1-A
    and coalesce(pr.deletion_due_at, acct.deletion_due_at) is not null;
$function$;

CREATE OR REPLACE FUNCTION public.get_roster_verification(p_team_id uuid)
 RETURNS TABLE(pitcher_id uuid, email text, email_confirmed boolean, guardian_pending boolean, age_answered boolean, managed boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select pt.pitcher_id, u.email, acct.email_verified_at is not null,
         (acct.age_attestation = 'minor_13_17' and acct.guardian_consented_at is null),
         acct.age_attestation is not null,
         pr.managed_by is not null
  from public.pitcher_teams pt
  join public.profiles pr on pr.id = pt.pitcher_id
  join auth.users u on u.id = pr.account_id
  join public.profiles acct on acct.id = pr.account_id
  where pt.team_id = p_team_id
    and public.coach_sees_pitcher(p_team_id, pt.pitcher_id);   -- F1-A
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

CREATE OR REPLACE FUNCTION public.is_coach_of_pitcher(p_pitcher_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (
    select 1 from public.pitcher_teams pt
     where pt.pitcher_id = p_pitcher_id and public.coach_sees_pitcher(pt.team_id, pt.pitcher_id)   -- F1-A
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
      join public.team_coaches tc on tc.team_id = s.team_id
      join public.profiles cp on cp.id = tc.coach_id and cp.account_id = auth.uid()
      join public.pitcher_teams pt on pt.team_id = s.team_id and pt.pitcher_id = s.pitcher_id
     where s.id = p_session_id
       and s.started_at >= pt.joined_at
       and not public.is_facility_team(s.team_id)   -- F1-A: no notes in a facility (Chat replaces them)
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
      join public.team_coaches tc on tc.team_id = s.team_id
      join public.profiles cp on cp.id = tc.coach_id and cp.account_id = auth.uid()
     where s.id = p_session_id
       and public.coach_sees_pitcher(s.team_id, s.pitcher_id)   -- F1-A
  );
$function$;

CREATE OR REPLACE FUNCTION public.is_current_coach_of_pitcher(p_pitcher uuid, p_at timestamp with time zone)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  -- The caller coaches a non-archived team the pitcher is on now, and joined it at or before p_at.
  select exists (
    select 1 from public.pitcher_teams pt
     where pt.pitcher_id = p_pitcher
       and pt.joined_at <= p_at
       and public.coach_sees_pitcher(pt.team_id, pt.pitcher_id)   -- F1-A: a facility assistant only for their group
       and not public.is_team_archived(pt.team_id)
  );
$function$;

CREATE OR REPLACE FUNCTION public.pitcher_session_teams(p_pitcher uuid)
 RETURNS TABLE(team_id uuid, team_name text, team_archived boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select distinct t.id, t.name, t.archived_at is not null
    from public.sessions s join public.teams t on t.id = s.team_id
   where s.pitcher_id = p_pitcher
     and (public.is_my_profile(s.pitcher_id) or public.coach_sees_pitcher(s.team_id, s.pitcher_id)
          or public.is_current_coach_of_pitcher(s.pitcher_id, s.started_at));
$function$;

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

drop policy "Sessions: read by the pitcher, the recording team's coaches and" on public.sessions;
create policy "Sessions: read by the pitcher, the recording team's coaches and" on public.sessions for select
  using ((is_my_profile(pitcher_id) OR coach_sees_pitcher(team_id, pitcher_id) OR is_current_coach_of_pitcher(pitcher_id, started_at)));

drop policy "Sessions: report link written by the pitcher and the team's coa" on public.sessions;
create policy "Sessions: report link written by the pitcher and the team's coa" on public.sessions for update
  using ((is_my_profile(pitcher_id) OR coach_sees_pitcher(team_id, pitcher_id)))
  with check ((is_my_profile(pitcher_id) OR coach_sees_pitcher(team_id, pitcher_id)));

drop policy "Pitches: read by the pitcher, the recording team's coaches and " on public.pitches;
create policy "Pitches: read by the pitcher, the recording team's coaches and " on public.pitches for select
  using ((EXISTS ( SELECT 1
   FROM sessions s
  WHERE ((s.id = pitches.session_id) AND (is_my_profile(s.pitcher_id) OR coach_sees_pitcher(s.team_id, s.pitcher_id) OR is_current_coach_of_pitcher(s.pitcher_id, s.started_at))))));

drop policy "Game events: read by the pitcher, the recording team's coaches " on public.game_events;
create policy "Game events: read by the pitcher, the recording team's coaches " on public.game_events for select
  using ((EXISTS ( SELECT 1
   FROM sessions s
  WHERE ((s.id = game_events.session_id) AND (is_my_profile(s.pitcher_id) OR coach_sees_pitcher(s.team_id, s.pitcher_id) OR is_current_coach_of_pitcher(s.pitcher_id, s.started_at))))));

drop policy "Session stats: read where the session's pitches are read" on public.session_stats;
create policy "Session stats: read where the session's pitches are read" on public.session_stats for select
  using ((EXISTS ( SELECT 1
   FROM sessions s
  WHERE ((s.id = session_stats.session_id) AND (is_my_profile(s.pitcher_id) OR coach_sees_pitcher(s.team_id, s.pitcher_id) OR is_current_coach_of_pitcher(s.pitcher_id, s.started_at))))));

drop policy "Coaches view memberships for their teams" on public.pitcher_teams;
create policy "Coaches view memberships for their teams" on public.pitcher_teams for select
  using (coach_sees_pitcher(team_id, pitcher_id));

drop policy "Coaches view their pitchers' profiles" on public.profiles;
create policy "Coaches view their pitchers' profiles" on public.profiles for select
  using ((EXISTS ( SELECT 1
   FROM pitcher_teams pt
  WHERE ((pt.pitcher_id = profiles.id) AND coach_sees_pitcher(pt.team_id, pt.pitcher_id)))));


-- ---------------------------------------------------------------------------------------------------------------
-- 5. Groups follow the staff and the roster
-- ---------------------------------------------------------------------------------------------------------------

-- A coach who joins a facility team (the manager included, as head) gets their group.
create function public.f1a_coach_group_on_join() returns trigger
  language plpgsql security definer set search_path to '' as $$
begin
  if public.is_facility_team(new.team_id) then
    insert into public.coach_groups (team_id, coach_id) values (new.team_id, new.coach_id)
      on conflict (team_id, coach_id) do nothing;
  end if;
  return new;
end;
$$;
create trigger team_coaches_f1a_group after insert on public.team_coaches
  for each row execute function public.f1a_coach_group_on_join();

-- A coach removed from the side loses the group; its pitchers stay on the side, in no group (the manager re-assigns).
create function public.f1a_coach_group_on_leave() returns trigger
  language plpgsql security definer set search_path to '' as $$
begin
  delete from public.coach_groups where team_id = old.team_id and coach_id = old.coach_id;
  return old;
end;
$$;
create trigger team_coaches_f1a_group_leave after delete on public.team_coaches
  for each row execute function public.f1a_coach_group_on_leave();

-- A pitcher who leaves the side leaves every group on it.
create function public.f1a_group_members_on_leave() returns trigger
  language plpgsql security definer set search_path to '' as $$
begin
  delete from public.coach_group_members m using public.coach_groups g
   where g.id = m.group_id and g.team_id = old.team_id and m.pitcher_id = old.pitcher_id;
  return old;
end;
$$;
create trigger pitcher_teams_f1a_groups after delete on public.pitcher_teams
  for each row execute function public.f1a_group_members_on_leave();
revoke execute on function public.f1a_coach_group_on_join(), public.f1a_coach_group_on_leave(), public.f1a_group_members_on_leave()
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------------------------------------------
-- 6. The signup link and create_facility (decision B: always both sides)
-- ---------------------------------------------------------------------------------------------------------------

-- What facility-signup.html shows before an account exists. The token is the secret; nothing else is revealed.
create function public.facility_invite_info(p_token text) returns jsonb
  language plpgsql stable security definer set search_path to '' as $$
declare v public.facility_invites%rowtype;
begin
  select * into v from public.facility_invites where token = p_token;
  if not found then return jsonb_build_object('status', 'not_found'); end if;
  if v.used_at is not null then
    return jsonb_build_object('status', case when v.used_by = auth.uid() then 'done' else 'used' end);
  end if;
  if v.expires_at < now() then return jsonb_build_object('status', 'expired'); end if;
  return jsonb_build_object('status', 'ok', 'facility_name', v.facility_name, 'manager_email', v.manager_email);
end;
$$;
grant execute on function public.facility_invite_info(text) to anon, authenticated;

-- Consumes the link once for the signed-in caller (a new coach login whose address is the link's): the organization,
-- a baseball and a softball coach profile on the login, both teams (kind 'facility', the caller as head on both) and
-- their groups. Run again by the same login it returns the same organization.
create function public.create_facility(p_token text) returns jsonb
  language plpgsql security definer set search_path to '' as $$
declare
  v_uid uuid := auth.uid();
  v public.facility_invites%rowtype;
  v_email text; v_prim public.profiles%rowtype; v_bb uuid; v_sb uuid; v_org uuid; v_team uuid; v_name text;
begin
  if v_uid is null then return jsonb_build_object('ok', false, 'error', 'not_authenticated'); end if;
  select * into v from public.facility_invites where token = p_token for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if v.used_at is not null then
    if v.used_by = v_uid then return jsonb_build_object('ok', true, 'status', 'already_created', 'org_id', v.org_id); end if;
    return jsonb_build_object('ok', false, 'error', 'used');
  end if;
  if v.expires_at < now() then return jsonb_build_object('ok', false, 'error', 'expired'); end if;
  select lower(u.email) into v_email from auth.users u where u.id = v_uid;
  if v_email is distinct from lower(btrim(v.manager_email)) then return jsonb_build_object('ok', false, 'error', 'wrong_email'); end if;
  if exists (select 1 from public.organizations o where o.manager_login = v_uid) then
    return jsonb_build_object('ok', false, 'error', 'already_manager');
  end if;
  -- A fresh login only: none of its profiles is on a team or staff yet.
  if exists (select 1 from public.team_coaches tc join public.profiles pr on pr.id = tc.coach_id where pr.account_id = v_uid)
     or exists (select 1 from public.pitcher_teams pt join public.profiles pr on pr.id = pt.pitcher_id where pr.account_id = v_uid) then
    return jsonb_build_object('ok', false, 'error', 'login_in_use');
  end if;
  select * into v_prim from public.profiles where id = v_uid;
  if not found then
    v_name := nullif(btrim((select u.raw_user_meta_data ->> 'full_name' from auth.users u where u.id = v_uid)), '');
    if v_name is null then return jsonb_build_object('ok', false, 'error', 'name_required'); end if;
    insert into public.profiles (id, role, full_name, sport) values (v_uid, 'coach', v_name, 'baseball');
    select * into v_prim from public.profiles where id = v_uid;
  end if;
  if v_prim.role <> 'coach' then return jsonb_build_object('ok', false, 'error', 'not_a_coach_login'); end if;
  select id into v_bb from public.profiles where account_id = v_uid and role = 'coach' and managed_by is null and sport = 'baseball' limit 1;
  select id into v_sb from public.profiles where account_id = v_uid and role = 'coach' and managed_by is null and sport = 'softball' limit 1;
  if v_bb is null then
    v_bb := gen_random_uuid();
    insert into public.profiles (id, account_id, role, full_name, sport) values (v_bb, v_uid, 'coach', v_prim.full_name, 'baseball');
  end if;
  if v_sb is null then
    v_sb := gen_random_uuid();
    insert into public.profiles (id, account_id, role, full_name, sport) values (v_sb, v_uid, 'coach', v_prim.full_name, 'softball');
  end if;

  insert into public.organizations (name, manager_login) values (btrim(v.facility_name), v_uid) returning id into v_org;
  -- Both sides, as _create_team_with_head does (the invite token comes from the existing trigger), plus org and kind.
  insert into public.teams (coach_id, name, coach_invite_token, coach_invite_token_rotated_at, org_id, kind, level)
    values (v_bb, btrim(v.facility_name), replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''), now(),
            v_org, 'facility', v.baseball_level) returning id into v_team;
  insert into public.team_coaches (team_id, coach_id, role) values (v_team, v_bb, 'head');
  insert into public.teams (coach_id, name, coach_invite_token, coach_invite_token_rotated_at, org_id, kind, level)
    values (v_sb, btrim(v.facility_name), replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''), now(),
            v_org, 'facility', v.softball_level) returning id into v_team;
  insert into public.team_coaches (team_id, coach_id, role) values (v_team, v_sb, 'head');

  update public.facility_invites set used_at = now(), used_by = v_uid, org_id = v_org where token = p_token;
  return jsonb_build_object('ok', true, 'status', 'created', 'org_id', v_org);
end;
$$;
revoke execute on function public.create_facility(text) from public, anon;

-- The caller's facility (the manager) or null: name and both teams.
create function public.my_facility() returns jsonb
  language sql stable security definer set search_path to '' as $$
  select jsonb_build_object('org_id', o.id, 'name', o.name,
           'teams', (select jsonb_agg(jsonb_build_object('id', t.id, 'sport', t.sport) order by t.sport) from public.teams t where t.org_id = o.id))
    from public.organizations o where o.manager_login = auth.uid() limit 1;
$$;
revoke execute on function public.my_facility() from public, anon;

-- Decision C: hand the facility to a coach who is already on both sides, in one step. The R6 handoff runs on each team
-- (the old manager stays as an assistant, with their group); the organization's manager_login moves with it.
create function public.handoff_facility(p_new_manager uuid) returns jsonb
  language plpgsql security definer set search_path to '' as $$
declare v_uid uuid := auth.uid(); v_org uuid; v_new_login uuid; t record; v_prof uuid;
begin
  if v_uid is null then return jsonb_build_object('ok', false, 'error', 'not_authenticated'); end if;
  select o.id into v_org from public.organizations o where o.manager_login = v_uid limit 1 for update;
  if v_org is null then return jsonb_build_object('ok', false, 'error', 'not_manager'); end if;
  select pr.account_id into v_new_login from public.profiles pr where pr.id = p_new_manager;
  if v_new_login is null or v_new_login = v_uid then return jsonb_build_object('ok', false, 'error', 'invalid_new_manager'); end if;
  if exists (select 1 from public.organizations o where o.manager_login = v_new_login) then
    return jsonb_build_object('ok', false, 'error', 'already_manager');
  end if;
  for t in select id from public.teams where org_id = v_org order by sport loop
    select tc.coach_id into v_prof from public.team_coaches tc join public.profiles pr on pr.id = tc.coach_id
     where tc.team_id = t.id and tc.role = 'assistant' and pr.account_id = v_new_login limit 1;
    if v_prof is null then return jsonb_build_object('ok', false, 'error', 'not_on_both_sides'); end if;
  end loop;
  for t in select id from public.teams where org_id = v_org order by sport loop
    select tc.coach_id into v_prof from public.team_coaches tc join public.profiles pr on pr.id = tc.coach_id
     where tc.team_id = t.id and tc.role = 'assistant' and pr.account_id = v_new_login limit 1;
    perform public.hand_off_team_head(t.id, v_prof);
  end loop;
  update public.organizations set manager_login = v_new_login where id = v_org;
  return jsonb_build_object('ok', true);
end;
$$;
revoke execute on function public.handoff_facility(uuid) from public, anon;

-- ---------------------------------------------------------------------------------------------------------------
-- 7. Group actions. The manager: any group on their side. A coach: their own group only (move is the manager's).
-- ---------------------------------------------------------------------------------------------------------------

-- The caller's coach profile on a team (the manager's or the group coach's), for added_by; null when not on its staff.
create function public.f1a_my_coach_profile(p_team uuid) returns uuid
  language sql stable security definer set search_path to '' as $$
  select tc.coach_id from public.team_coaches tc join public.profiles pr on pr.id = tc.coach_id
   where tc.team_id = p_team and pr.account_id = auth.uid() limit 1;
$$;
revoke execute on function public.f1a_my_coach_profile(uuid) from public, anon, authenticated;

create function public.f1a_may_edit_group(p_group uuid) returns boolean
  language sql stable security definer set search_path to '' as $$
  select coalesce((select public.is_org_manager(g.team_id) or public.is_my_profile(g.coach_id)
                     from public.coach_groups g where g.id = p_group), false);
$$;
revoke execute on function public.f1a_may_edit_group(uuid) from public, anon, authenticated;

create function public.add_to_group(p_group uuid, p_pitcher uuid) returns jsonb
  language plpgsql security definer set search_path to '' as $$
declare v_team uuid;
begin
  select team_id into v_team from public.coach_groups where id = p_group;
  if v_team is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if not public.f1a_may_edit_group(p_group) then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  if public.is_team_archived(v_team) then return jsonb_build_object('ok', false, 'error', 'team_archived'); end if;
  if not exists (select 1 from public.pitcher_teams where team_id = v_team and pitcher_id = p_pitcher) then
    return jsonb_build_object('ok', false, 'error', 'not_on_side');
  end if;
  insert into public.coach_group_members (group_id, pitcher_id, added_by, flagged_new)
    values (p_group, p_pitcher, public.f1a_my_coach_profile(v_team), false)
    on conflict (group_id, pitcher_id) do nothing;
  return jsonb_build_object('ok', true);
end;
$$;

-- Removing a pitcher from their last group on a side takes them off the side (the departure is logged as for any
-- removal). Returns left_side true then.
create function public.remove_from_group(p_group uuid, p_pitcher uuid) returns jsonb
  language plpgsql security definer set search_path to '' as $$
declare v_team uuid; v_left boolean := false;
begin
  select team_id into v_team from public.coach_groups where id = p_group;
  if v_team is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if not public.f1a_may_edit_group(p_group) then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  delete from public.coach_group_members where group_id = p_group and pitcher_id = p_pitcher;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_in_group'); end if;
  if not exists (select 1 from public.coach_group_members m join public.coach_groups g on g.id = m.group_id
                  where g.team_id = v_team and m.pitcher_id = p_pitcher) then
    delete from public.pitcher_teams where team_id = v_team and pitcher_id = p_pitcher;
    v_left := found;
  end if;
  return jsonb_build_object('ok', true, 'left_side', v_left);
end;
$$;

create function public.move_between_groups(p_pitcher uuid, p_from uuid, p_to uuid) returns jsonb
  language plpgsql security definer set search_path to '' as $$
declare v_team uuid; v_to_team uuid;
begin
  select team_id into v_team from public.coach_groups where id = p_from;
  select team_id into v_to_team from public.coach_groups where id = p_to;
  if v_team is null or v_to_team is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if v_team <> v_to_team then return jsonb_build_object('ok', false, 'error', 'other_side'); end if;
  if not public.is_org_manager(v_team) then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  delete from public.coach_group_members where group_id = p_from and pitcher_id = p_pitcher;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_in_group'); end if;
  insert into public.coach_group_members (group_id, pitcher_id, added_by, flagged_new)
    values (p_to, p_pitcher, public.f1a_my_coach_profile(v_team), false)
    on conflict (group_id, pitcher_id) do nothing;
  return jsonb_build_object('ok', true);
end;
$$;

create function public.clear_new_flag(p_group uuid, p_pitcher uuid) returns jsonb
  language plpgsql security definer set search_path to '' as $$
begin
  if not public.f1a_may_edit_group(p_group) then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  update public.coach_group_members set flagged_new = false where group_id = p_group and pitcher_id = p_pitcher;
  return jsonb_build_object('ok', true);
end;
$$;
revoke execute on function public.add_to_group(uuid, uuid), public.remove_from_group(uuid, uuid),
  public.move_between_groups(uuid, uuid, uuid), public.clear_new_flag(uuid, uuid) from public, anon;
