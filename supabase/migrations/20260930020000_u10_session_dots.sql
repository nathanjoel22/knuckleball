-- U10 (3) revised again: red dots on individual sessions in History.
--
-- Decisions (Joel, Sept 30 2026):
--  * Every viewer -- each coach on the team and the pitcher himself -- sees
--    a red dot on each session in that pitcher's History until THAT viewer
--    taps it open. Opening is permanent and per viewer (session_opened).
--  * Whoever saved the session gets the dot too.
--  * Only sessions saved after this goes live, and (for a coach) after he
--    joined the team, and (for everyone) thrown after the pitcher joined
--    the team -- nobody gets dots on old history.
--  * The roster-name / History-tab dot stays as in 20260930010000
--    (roster_seen): it clears when the viewer opens that pitcher's History.
--
-- No policy here references teams or pitcher_teams (42P17 landmine).
-- get_unopened_sessions is SECURITY INVOKER: sessions, pitcher_teams and
-- team_coaches are read under the caller's own existing RLS, so it can
-- never list a session the caller's History couldn't show.
--
-- Rollback (manual):
--   drop function if exists public.get_unopened_sessions(uuid);
--   drop function if exists public.session_dots_since();
--   drop table if exists public.session_opened;

create table public.session_opened (
  viewer_id  uuid        not null references public.profiles(id) on delete cascade,
  session_id uuid        not null references public.sessions(id) on delete cascade,
  opened_at  timestamptz not null default now(),
  primary key (viewer_id, session_id)
);

comment on table public.session_opened is
  'U10 (3): which sessions each viewer (coach or the pitcher himself) has tapped open in History. A session saved after launch with no row here for the viewer shows a red dot. Own rows only (RLS).';

alter table public.session_opened enable row level security;

create policy "Viewers read own session-opened rows"
  on public.session_opened for select
  using (viewer_id = auth.uid());

create policy "Viewers insert own session-opened rows"
  on public.session_opened for insert
  with check (viewer_id = auth.uid());

revoke all on public.session_opened from anon;
grant select, insert on public.session_opened to authenticated;

-- The launch moment, frozen into a function at migration time: sessions
-- that ended before it never get a dot.
do $do$
begin
  execute format(
    'create or replace function public.session_dots_since() returns timestamptz
       language sql immutable set search_path = '''' as $f$ select %L::timestamptz $f$',
    now());
end
$do$;

grant execute on function public.session_dots_since() to authenticated;

-- The caller's unopened sessions on one team (every pitcher whose History
-- he can see there). Caller's own RLS applies throughout.
create or replace function public.get_unopened_sessions(p_team_id uuid)
returns table (session_id uuid, pitcher_id uuid)
language sql
stable
security invoker
set search_path = ''
as $$
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
$$;

revoke all on function public.get_unopened_sessions(uuid) from public, anon;
grant execute on function public.get_unopened_sessions(uuid) to authenticated;
