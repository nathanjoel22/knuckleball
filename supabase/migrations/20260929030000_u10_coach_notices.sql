-- U10 (3): coach notices -- "Jack Croft logged a Bullpen · Tue Sept 29, 4:12 PM".
--
-- Decisions (Joel, Sept 29 2026):
--  * A notice goes to every coach on the team (head or assistant) EXCEPT the
--    account that pressed "End session & save" (sessions.logged_by). If the
--    player charted it himself, every coach sees it.
--  * Sessions of either kind, filed to a team the coach is on, finalized
--    (ended_at) in the last 7 days, not deleted.
--  * Seen rule: shown on the coach's first screen after sign-in / app open,
--    and marked seen for THAT coach at that moment (each coach has his own
--    seen state). Gone at the next sign-in / app open.
--  * Follows the roster & visibility model: only sessions by a pitcher
--    CURRENTLY on that team, thrown on or after his join date. Notices carry
--    only player name, kind and time -- never session detail.
--
-- No policy here references teams or pitcher_teams (42P17 landmine); the
-- one cross-table check (is this caller a coach of the session's team) goes
-- through the existing is_team_coach helper, inside a SECURITY DEFINER
-- function -- never inside a policy.
--
-- Rollback (manual):
--   drop function if exists public.get_coach_notices();
--   drop table if exists public.coach_notice_seen;

create table public.coach_notice_seen (
  coach_id   uuid        not null references public.profiles(id) on delete cascade,
  session_id uuid        not null references public.sessions(id) on delete cascade,
  seen_at    timestamptz not null default now(),
  primary key (coach_id, session_id)
);

comment on table public.coach_notice_seen is
  'U10 (3): which session notices each coach has already been shown. One row per (coach, session); written by the client the moment the notices render. Own rows only (RLS).';

alter table public.coach_notice_seen enable row level security;

-- A coach reads and inserts only his own rows. No update or delete policy:
-- a notice, once seen, stays seen (session deletion cascades the row away).
create policy "Coaches read own notice-seen rows"
  on public.coach_notice_seen for select
  using (coach_id = auth.uid());

create policy "Coaches insert own notice-seen rows"
  on public.coach_notice_seen for insert
  with check (coach_id = auth.uid());

revoke all on public.coach_notice_seen from anon;
grant select, insert on public.coach_notice_seen to authenticated;

-- The notice list for the calling coach: player name, kind, finalized time
-- -- nothing else leaves the database. Unseen only.
create or replace function public.get_coach_notices()
returns table (session_id uuid, player_name text, kind text, ended_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select s.id, pr.full_name, s.kind, s.ended_at
    from public.sessions s
    join public.pitcher_teams pt on pt.team_id = s.team_id and pt.pitcher_id = s.pitcher_id
    join public.profiles pr on pr.id = s.pitcher_id
   where public.is_team_coach(s.team_id)
     and s.ended_at > now() - interval '7 days'
     and s.deleted_at is null
     and s.logged_by is distinct from auth.uid()
     and s.started_at >= pt.joined_at
     and not exists (
       select 1 from public.coach_notice_seen n
        where n.coach_id = auth.uid() and n.session_id = s.id
     )
   order by s.ended_at desc;
$$;

revoke all on function public.get_coach_notices() from public, anon;
grant execute on function public.get_coach_notices() to authenticated;
