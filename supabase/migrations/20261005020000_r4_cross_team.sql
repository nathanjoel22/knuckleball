-- R4 (Joel, Oct 5 2026): cross-team visibility. Coaches of every NON-archived team a pitcher is
-- currently on can READ his sessions -- pitches, events and notes -- for sessions he charted
-- since he joined their team (Joel: "since he joined"), whichever team they were charted for.
-- Only the recording team (sessions.team_id) acts on them: notes (already recording-team only,
-- S3 is_coach_of_session), reports (send-session-report now checks it explicitly), the report
-- link (UPDATE rule unchanged), deleting (delete_session unchanged). The pitcher sees all of his
-- own. Sports never mix: a softball profile is a separate pitcher_id (S4).
-- Policies: 34 -> 34 (four SELECT rules edited, none added). No rule references teams and
-- pitcher_teams directly (42P17): the new helper is SECURITY DEFINER.
-- Supersedes the never-built "summary line" roster decision in CLAUDE.md.
-- Rollback: supabase/rollback/20261005020000_r4_cross_team_down.sql

create or replace function public.is_current_coach_of_pitcher(p_pitcher uuid, p_at timestamptz)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  -- The caller coaches a non-archived team the pitcher is on now, and joined it at or before p_at.
  select exists (
    select 1 from public.pitcher_teams pt
     where pt.pitcher_id = p_pitcher
       and pt.joined_at <= p_at
       and public.is_team_coach(pt.team_id)
       and not public.is_team_archived(pt.team_id)
  );
$$;
-- Used inside read rules, so (like is_team_coach / is_my_profile) anon must be able to evaluate
-- it; for anon it is always false.
revoke all on function public.is_current_coach_of_pitcher(uuid, timestamptz) from public;
grant execute on function public.is_current_coach_of_pitcher(uuid, timestamptz) to anon, authenticated;

-- ------------------------------------------------------------------ the four read rules
drop policy "Sessions: read by the pitcher and the team's coaches" on public.sessions;
create policy "Sessions: read by the pitcher, the recording team's coaches and his current teams' coaches" on public.sessions
  for select using (public.is_my_profile(pitcher_id) or public.is_team_coach(team_id)
                    or public.is_current_coach_of_pitcher(pitcher_id, started_at));

drop policy "Pitches: read by the pitcher and the team's coaches" on public.pitches;
create policy "Pitches: read by the pitcher, the recording team's coaches and his current teams' coaches" on public.pitches
  for select using (exists (select 1 from public.sessions s where s.id = pitches.session_id
                            and (public.is_my_profile(s.pitcher_id) or public.is_team_coach(s.team_id)
                                 or public.is_current_coach_of_pitcher(s.pitcher_id, s.started_at))));

drop policy "Game events: read by the pitcher and the team's coaches" on public.game_events;
create policy "Game events: read by the pitcher, the recording team's coaches and his current teams' coaches" on public.game_events
  for select using (exists (select 1 from public.sessions s where s.id = game_events.session_id
                            and (public.is_my_profile(s.pitcher_id) or public.is_team_coach(s.team_id)
                                 or public.is_current_coach_of_pitcher(s.pitcher_id, s.started_at))));

drop policy "Notes readable by author, pitcher and his team's coaches" on public.session_notes;
create policy "Notes readable by author, pitcher, the recording team's coaches and his current teams' coaches" on public.session_notes
  for select using (public.is_my_profile(author_id)
                    or exists (select 1 from public.sessions s where s.id = session_notes.session_id and public.is_my_profile(s.pitcher_id))
                    or public.is_coach_of_session_team(session_id)
                    or exists (select 1 from public.sessions s where s.id = session_notes.session_id
                               and public.is_current_coach_of_pitcher(s.pitcher_id, s.started_at)));

-- ------------------------------------------------------------------ team chips
-- Names of the teams a pitcher's VISIBLE sessions were charted for (a coach can't read other
-- teams' rows directly). Team names aren't secret (join pages show them to anyone with a link).
create or replace function public.pitcher_session_teams(p_pitcher uuid)
returns table(team_id uuid, team_name text, team_archived boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select distinct t.id, t.name, t.archived_at is not null
    from public.sessions s join public.teams t on t.id = s.team_id
   where s.pitcher_id = p_pitcher
     and (public.is_my_profile(s.pitcher_id) or public.is_team_coach(s.team_id)
          or public.is_current_coach_of_pitcher(s.pitcher_id, s.started_at));
$$;
revoke all on function public.pitcher_session_teams(uuid) from public, anon;
grant execute on function public.pitcher_session_teams(uuid) to authenticated;

-- ------------------------------------------------------------------ workload (pitch counts)
-- SECURITY INVOKER: counts exactly the sessions the caller can read (so a coach's numbers start
-- when the pitcher joined his team). Deleted sessions never count. Games separable.
create or replace function public.pitcher_workload(p_profiles uuid[])
returns table(pitcher_id uuid, last_at timestamptz, last_kind text, last_pitches integer,
              d7_bullpen integer, d7_game integer, d30_bullpen integer, d30_game integer)
language sql
stable
set search_path = ''
as $$
  with ss as (
    select s.id, s.pitcher_id, s.kind, s.started_at,
           (select count(*) from public.pitches p where p.session_id = s.id)::int as n
      from public.sessions s
     where s.pitcher_id = any(p_profiles) and s.deleted_at is null and s.ended_at is not null
  ), last as (
    select distinct on (ss.pitcher_id) ss.pitcher_id, ss.started_at, ss.kind, ss.n
      from ss order by ss.pitcher_id, ss.started_at desc
  )
  select pid, l.started_at, l.kind, l.n,
         coalesce(sum(ss.n) filter (where ss.kind = 'bullpen' and ss.started_at > now() - interval '7 days'), 0)::int,
         coalesce(sum(ss.n) filter (where ss.kind = 'game'    and ss.started_at > now() - interval '7 days'), 0)::int,
         coalesce(sum(ss.n) filter (where ss.kind = 'bullpen' and ss.started_at > now() - interval '30 days'), 0)::int,
         coalesce(sum(ss.n) filter (where ss.kind = 'game'    and ss.started_at > now() - interval '30 days'), 0)::int
    from unnest(p_profiles) pid
    left join last l on l.pitcher_id = pid
    left join ss on ss.pitcher_id = pid
   group by pid, l.started_at, l.kind, l.n;
$$;
revoke all on function public.pitcher_workload(uuid[]) from public, anon;
grant execute on function public.pitcher_workload(uuid[]) to authenticated;

-- ------------------------------------------------------------------ dots follow visibility
-- Both run as the caller (RLS applies). A team's dots now include the pitcher's sessions for his
-- other teams since he joined this one -- unless this team is archived (then only its own).
create or replace function public.get_roster_latest(p_team_id uuid)
returns table(pitcher_id uuid, latest_ended_at timestamptz)
language sql
stable
set search_path = ''
as $$
  select s.pitcher_id, max(s.ended_at)
    from public.sessions s
    join public.pitcher_teams pt on pt.team_id = p_team_id and pt.pitcher_id = s.pitcher_id
   where (s.team_id = p_team_id or not public.is_team_archived(p_team_id))
     and s.deleted_at is null
     and s.ended_at is not null
     and s.started_at >= pt.joined_at
   group by s.pitcher_id;
$$;

create or replace function public.get_unopened_sessions(p_team_id uuid, p_viewer uuid default null::uuid)
returns table(session_id uuid, pitcher_id uuid)
language sql
stable
set search_path = ''
as $$
  with v as (
    select case when p_viewer is not null then (case when public.is_my_profile(p_viewer) then p_viewer end)
                else public.my_single_profile() end as viewer
  )
  select s.id, s.pitcher_id
    from v, public.sessions s
    join public.pitcher_teams pt on pt.team_id = p_team_id and pt.pitcher_id = s.pitcher_id
   where v.viewer is not null
     and (s.team_id = p_team_id or not public.is_team_archived(p_team_id))
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
