-- ============================================================
-- Knuckleball database schema
-- Run this once in Supabase → SQL Editor → New query → Run
-- ============================================================

-- ---------- TABLES (created first, so policies below can reference any of them) ----------

-- One row per user (coach or pitcher), linked 1:1 to Supabase Auth's
-- built-in auth.users table.
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('coach','pitcher')),
  full_name text not null,
  pitch_types text[] not null default '{}',
  created_at timestamptz not null default now()
);

-- One coach per team for now.
create table public.teams (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now()
);

-- Membership join table. A pitcher can belong to several teams.
create table public.pitcher_teams (
  pitcher_id uuid not null references auth.users(id) on delete cascade,
  team_id uuid not null references public.teams(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (pitcher_id, team_id)
);

-- Created by the invite-pitcher Edge Function when a coach invites someone.
create table public.invites (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  email text not null,
  invited_by uuid not null references auth.users(id),
  status text not null default 'pending' check (status in ('pending','accepted')),
  created_at timestamptz not null default now()
);

-- A bullpen session, scoped to the team it was logged under.
create table public.sessions (
  id uuid primary key default gen_random_uuid(),
  pitcher_id uuid not null references auth.users(id) on delete cascade,
  team_id uuid not null references public.teams(id) on delete cascade,
  started_at timestamptz not null,
  ended_at timestamptz,
  created_at timestamptz not null default now()
);

-- Individual pitches within a session.
create table public.pitches (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  type text not null,
  velo integer,
  row_idx integer not null,
  col_idx integer not null,
  ts timestamptz not null default now()
);

-- ---------- ROW LEVEL SECURITY ----------

alter table public.profiles enable row level security;
alter table public.teams enable row level security;
alter table public.pitcher_teams enable row level security;
alter table public.invites enable row level security;
alter table public.sessions enable row level security;
alter table public.pitches enable row level security;

-- ---------- POLICIES: profiles ----------

create policy "Users view own profile"
  on public.profiles for select
  using (id = auth.uid());

create policy "Users update own profile"
  on public.profiles for update
  using (id = auth.uid());

create policy "Users insert own profile"
  on public.profiles for insert
  with check (id = auth.uid());

create policy "Coaches view their pitchers' profiles"
  on public.profiles for select
  using (
    exists (
      select 1 from public.pitcher_teams pt
      join public.teams t on t.id = pt.team_id
      where pt.pitcher_id = public.profiles.id
        and t.coach_id = auth.uid()
    )
  );

-- ---------- POLICIES: teams ----------

create policy "Coaches manage own teams"
  on public.teams for all
  using (coach_id = auth.uid())
  with check (coach_id = auth.uid());

create policy "Pitchers view teams they belong to"
  on public.teams for select
  using (
    exists (
      select 1 from public.pitcher_teams pt
      where pt.team_id = teams.id and pt.pitcher_id = auth.uid()
    )
  );

-- ---------- POLICIES: pitcher_teams ----------

create policy "Pitchers view own memberships"
  on public.pitcher_teams for select
  using (pitcher_id = auth.uid());

create policy "Coaches view memberships for their teams"
  on public.pitcher_teams for select
  using (exists (select 1 from public.teams t where t.id = team_id and t.coach_id = auth.uid()));

create policy "Pitchers accept invite by inserting own membership"
  on public.pitcher_teams for insert
  with check (pitcher_id = auth.uid());

create policy "Coaches remove pitchers from their team"
  on public.pitcher_teams for delete
  using (exists (select 1 from public.teams t where t.id = team_id and t.coach_id = auth.uid()));

-- ---------- POLICIES: invites ----------

create policy "Coaches manage own team invites"
  on public.invites for all
  using (exists (select 1 from public.teams t where t.id = team_id and t.coach_id = auth.uid()))
  with check (exists (select 1 from public.teams t where t.id = team_id and t.coach_id = auth.uid()));

create policy "Invited person views invite addressed to their email"
  on public.invites for select
  using (email = auth.jwt() ->> 'email');

create policy "Invited person marks their invite accepted"
  on public.invites for update
  using (email = auth.jwt() ->> 'email')
  with check (email = auth.jwt() ->> 'email');

-- ---------- POLICIES: sessions ----------

create policy "Pitchers manage own sessions"
  on public.sessions for all
  using (pitcher_id = auth.uid())
  with check (pitcher_id = auth.uid());

create policy "Coaches view sessions logged under their team"
  on public.sessions for select
  using (exists (select 1 from public.teams t where t.id = team_id and t.coach_id = auth.uid()));

-- ---------- POLICIES: pitches ----------

create policy "Pitchers manage pitches in own sessions"
  on public.pitches for all
  using (exists (select 1 from public.sessions s where s.id = session_id and s.pitcher_id = auth.uid()))
  with check (exists (select 1 from public.sessions s where s.id = session_id and s.pitcher_id = auth.uid()));

create policy "Coaches view pitches for their team's sessions"
  on public.pitches for select
  using (
    exists (
      select 1 from public.sessions s
      join public.teams t on t.id = s.team_id
      where s.id = session_id and t.coach_id = auth.uid()
    )
  );
