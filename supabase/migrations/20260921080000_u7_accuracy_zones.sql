-- U7 Phase B: per-pitch accuracy zones.
--
-- A pitcher can turn on "relative accuracy" and paint, for each pitch type and
-- separately vs RHB and vs LHB, the set of cells that count as accurate. Zones are
-- stored in CATCHER FRAME like every other coordinate, as 'row-col' strings, and
-- zone NUMBERS are never stored (D8): each set is simply the physical cells that
-- count against that hitter, so nothing is mirrored per batter side.
--
-- Scoring is frozen onto each pitch at tap 2 (pitches.in_accuracy_zone plus a copy of
-- the cells that counted), so repainting a zone later never changes a saved session
-- and reports read the stored result instead of recomputing it.
--
-- pitches.accuracy_mode is deliberately NOT touched: new pitches leave it NULL and
-- the check constraint keeps its five existing values. Older cached clients and the
-- deployed report function then treat a new pitch as exact-hit only (their `default`
-- branch) instead of tripping on an unknown mode.
--
-- Access: the pitcher manages their own rows; a coach manages the rows of any pitcher
-- on one of their teams. The coach test goes through a SECURITY DEFINER helper that
-- wraps public.is_team_coach, so no policy here reads pitcher_teams directly and
-- there is no teams <-> pitcher_teams recursion (CLAUDE.md landmine 1). No anon access.
-- updated_at / updated_by are set by a trigger from auth.uid(), never trusted from
-- the client, so a coach's edits are attributable.
--
-- ---------------------------------------------------------------------------------
-- ROLLBACK (no automatic down-migration: write a NEW migration with this body and
-- deploy it staging-first, per DEPLOY.md):
--
--   drop table if exists public.accuracy_zones;
--   drop function if exists public.accuracy_zones_stamp();
--   drop function if exists public.coach_set_relative_accuracy(uuid, boolean);
--   drop function if exists public.is_coach_of_pitcher(uuid);
--   alter table public.pitches
--     drop column if exists in_accuracy_zone,
--     drop column if exists accuracy_zone_cells;
--   revoke update (relative_accuracy_enabled) on public.profiles from authenticated;
--   alter table public.profiles drop column if exists relative_accuracy_enabled;
--
-- Dropping the pitches columns deletes the stored zone results for every pitch
-- charted since this shipped; those cannot be recomputed. Prefer fixing forward.
-- ---------------------------------------------------------------------------------

-- 1. The pitcher's relative-accuracy switch. A pitcher toggles their own (column grant
--    on top of the U7 Phase A lockdown); a coach goes through the function below.
alter table public.profiles
  add column relative_accuracy_enabled boolean not null default false;

grant update (relative_accuracy_enabled) on public.profiles to authenticated;

-- 2. Helper: is the caller a coach of a team this pitcher is on?
create or replace function public.is_coach_of_pitcher(p_pitcher_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.pitcher_teams pt
     where pt.pitcher_id = p_pitcher_id and public.is_team_coach(pt.team_id)
  );
$$;

revoke all on function public.is_coach_of_pitcher(uuid) from public, anon;
grant execute on function public.is_coach_of_pitcher(uuid) to authenticated;

create or replace function public.coach_set_relative_accuracy(p_pitcher_id uuid, p_enabled boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_coach_of_pitcher(p_pitcher_id) then
    raise exception 'not allowed';
  end if;
  if p_enabled is null then
    raise exception 'invalid value';
  end if;
  update public.profiles set relative_accuracy_enabled = p_enabled where id = p_pitcher_id;
end;
$$;

revoke all on function public.coach_set_relative_accuracy(uuid, boolean) from public, anon;
grant execute on function public.coach_set_relative_accuracy(uuid, boolean) to authenticated;

-- 3. The zones themselves. Foreign keys are real (CLAUDE.md landmine 2).
create table public.accuracy_zones (
  pitcher_id  uuid        not null references public.profiles(id) on delete cascade,
  pitch_type  text        not null,
  batter_side text        not null check (batter_side in ('R', 'L')),
  cells       text[]      not null check (cardinality(cells) <= 49),
  updated_at  timestamptz not null default now(),
  updated_by  uuid        references public.profiles(id) on delete set null,
  primary key (pitcher_id, pitch_type, batter_side)
);

alter table public.accuracy_zones enable row level security;

revoke all on table public.accuracy_zones from anon, public;
grant select, insert, update, delete on table public.accuracy_zones to authenticated;

create policy "Pitcher or their coach manages zones"
  on public.accuracy_zones
  for all
  to authenticated
  using      (pitcher_id = auth.uid() or public.is_coach_of_pitcher(pitcher_id))
  with check (pitcher_id = auth.uid() or public.is_coach_of_pitcher(pitcher_id));

create or replace function public.accuracy_zones_stamp()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end;
$$;

create trigger accuracy_zones_stamp
  before insert or update on public.accuracy_zones
  for each row execute function public.accuracy_zones_stamp();

-- 4. Stored per-pitch result. NULL in_accuracy_zone = relative accuracy was off, or no
--    zone existed for that pitch type and batter side. Existing rows are untouched.
alter table public.pitches
  add column in_accuracy_zone boolean,
  add column accuracy_zone_cells text[];
