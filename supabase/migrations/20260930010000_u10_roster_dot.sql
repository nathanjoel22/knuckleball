-- U10 (3) revised: the roster red dot replaces the coach notices.
--
-- Decisions (Joel, Sept 30 2026):
--  * No notice bar for anyone. When a pitcher gets a new pen or Live Game, a
--    red dot shows by his name for everyone who can see him -- every coach
--    on the team (head and assistants) and the pitcher himself (on his
--    History tab). Each person's dot clears when THAT person has the
--    pitcher's History on screen; nobody else's changes. No time limit.
--  * Any non-deleted session counts, whoever charted it.
--  * Launch: everyone starts as "seen" (rows seeded below at now()), so only
--    sessions saved after this migration light a dot.
--  * coach_notice_seen and get_coach_notices() are dropped with the notices
--    (they held only "this coach saw this notice" markers).
--
-- "Seen" is per (viewer, pitcher), not per team.
--
-- No policy here references teams or pitcher_teams (42P17 landmine).
-- get_roster_latest is SECURITY INVOKER: it reads sessions/pitcher_teams
-- under the caller's own existing RLS, so it can never show more than the
-- caller's History already can -- no new session visibility.
--
-- Rollback (manual; the dropped notice markers are not restored):
--   drop function if exists public.get_roster_latest(uuid);
--   drop table if exists public.roster_seen;
--   then re-run 20260929030000_u10_coach_notices.sql's body.

drop function if exists public.get_coach_notices();
drop table if exists public.coach_notice_seen;

create table public.roster_seen (
  viewer_id  uuid        not null references public.profiles(id) on delete cascade,
  pitcher_id uuid        not null references public.profiles(id) on delete cascade,
  seen_at    timestamptz not null default now(),
  primary key (viewer_id, pitcher_id)
);

comment on table public.roster_seen is
  'U10 (3) revised: when each viewer (coach or the pitcher himself) last had this pitcher''s History on screen. The red dot shows when the pitcher''s latest session ended after seen_at, or there is no row. Own rows only (RLS).';

alter table public.roster_seen enable row level security;

create policy "Viewers read own roster-seen rows"
  on public.roster_seen for select
  using (viewer_id = auth.uid());

create policy "Viewers insert own roster-seen rows"
  on public.roster_seen for insert
  with check (viewer_id = auth.uid());

create policy "Viewers update own roster-seen rows"
  on public.roster_seen for update
  using (viewer_id = auth.uid())
  with check (viewer_id = auth.uid());

revoke all on public.roster_seen from anon;
grant select, insert, update on public.roster_seen to authenticated;

-- Each pitcher's latest saved, non-deleted session on one team, from his
-- join date (same rule the notices used). Caller's own RLS applies.
create or replace function public.get_roster_latest(p_team_id uuid)
returns table (pitcher_id uuid, latest_ended_at timestamptz)
language sql
stable
security invoker
set search_path = ''
as $$
  select s.pitcher_id, max(s.ended_at)
    from public.sessions s
    join public.pitcher_teams pt on pt.team_id = s.team_id and pt.pitcher_id = s.pitcher_id
   where s.team_id = p_team_id
     and s.deleted_at is null
     and s.ended_at is not null
     and s.started_at >= pt.joined_at
   group by s.pitcher_id;
$$;

revoke all on function public.get_roster_latest(uuid) from public, anon;
grant execute on function public.get_roster_latest(uuid) to authenticated;

-- Launch seed: every current viewer/pitcher pair starts as seen now.
insert into public.roster_seen (viewer_id, pitcher_id, seen_at)
select distinct tc.coach_id, pt.pitcher_id, now()
  from public.team_coaches tc
  join public.pitcher_teams pt on pt.team_id = tc.team_id
  join public.profiles cp on cp.id = tc.coach_id
on conflict do nothing;

insert into public.roster_seen (viewer_id, pitcher_id, seen_at)
select distinct pt.pitcher_id, pt.pitcher_id, now()
  from public.pitcher_teams pt
on conflict do nothing;
