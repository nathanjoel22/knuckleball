-- F2 Stage 3 (Joel, Nov 20 2026; plans/f2-facility-assignments-birthdays-camps.md, decisions in plans/f2-preconditions.md):
-- birthdays for pitchers, and a silent move to the next level of play every September 1.
--
-- This reverses P1-10 / S4's "no date of birth, ever" at Joel's request (the packet). STAGING ONLY until Joel approves
-- the privacy / terms / consent wording (DRAFT in the PR).
--
-- Who sees a birthday: the pitcher's own login and their parents (the parent who created the player, a linked guardian,
-- the player's own child sign-in). Never coaches, facility managers or other pitchers. So it is NOT a profiles column
-- (the profiles read rule lets coaches read rostered pitchers' rows, and column grants can't tell rows apart): it lives
-- in profile_birthdays, with no client grant and no policy, read and written only through the functions below.
-- A player sitting on a COACH's login (a coach-added player with no email of their own): the coach may enter it, or
-- "I don't know", but never read it back. Policies stay 32 / 12.

create table public.profile_birthdays (
  profile_id uuid primary key references public.profiles(id) on delete cascade,   -- A1: goes with the profile
  birth_date date,                                       -- null only with unknown = true
  unknown    boolean not null default false,             -- a coach-added player: "I don't know"
  set_by     uuid references auth.users(id) on delete set null,
  set_at     timestamptz not null default now(),
  check ((birth_date is not null) <> unknown),
  check (birth_date is null or birth_date between date '1900-01-01' and date '2100-01-01')
);
alter table public.profile_birthdays enable row level security;
revoke all on public.profile_birthdays from public, anon, authenticated;

-- A birthday that disagrees with the age a login gave at sign-up is NOT saved (Joel decides the handling before
-- production): the case is listed here for the operator. No date is stored, only the two brackets.
create table public.birthday_contradictions (
  id         uuid primary key default gen_random_uuid(),
  profile_id uuid references public.profiles(id) on delete cascade,
  attested   text,
  by_date    text,
  at         timestamptz not null default now()
);
alter table public.birthday_contradictions enable row level security;
revoke all on public.birthday_contradictions from public, anon, authenticated;

-- The September 1 job's record (operator only): who, from, to, when. No birthday in it.
create table public.level_switch_log (
  id          uuid primary key default gen_random_uuid(),
  profile_id  uuid references public.profiles(id) on delete cascade,
  sport       text,
  from_level  text,
  to_level    text,
  switched_at timestamptz not null default now()
);
alter table public.level_switch_log enable row level security;
revoke all on public.level_switch_log from public, anon, authenticated;

-- 'read' (may read and write), 'write' (may write only: a player on a coach's login), or null.
create or replace function public.f2_bday_access(p_profile uuid)
 returns text language sql stable security definer set search_path to '' as $$
  select case
    when p.role <> 'pitcher' then null
    -- the pitcher's own login (not a created player)
    when p.account_id = auth.uid() and p.managed_by is null then 'read'
    -- a player this login created: a parent reads; a coach (a coach-added player) only writes
    when p.account_id = auth.uid() and p.managed_by is not null then
      case when (select m.role from public.profiles m where m.id = p.managed_by) = 'coach' then 'write' else 'read' end
    -- a linked second parent, or the player's own (13-17) sign-in
    when exists (select 1 from public.player_links l where l.player_id = p.id and l.login = auth.uid() and l.role in ('guardian', 'child')) then 'read'
  end
  from public.profiles p where p.id = p_profile
$$;
revoke all on function public.f2_bday_access(uuid) from public, anon, authenticated;

-- Every pitcher profile this login answers for, with its birthday where it may read it.
create or replace function public.my_birthdays()
 returns jsonb language sql stable security definer set search_path to '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'profile_id', p.id, 'name', p.full_name, 'sport', p.sport, 'access', a.acc,
           'answered', b.profile_id is not null,
           'birth_date', case when a.acc = 'read' then b.birth_date end,
           'unknown', case when a.acc = 'read' then b.unknown end) order by p.full_name), '[]'::jsonb)
    from public.profiles p
    cross join lateral (select public.f2_bday_access(p.id) acc) a
    left join public.profile_birthdays b on b.profile_id = p.id
   where a.acc is not null
     and (p.account_id = auth.uid() or exists (select 1 from public.player_links l where l.player_id = p.id and l.login = auth.uid()))
$$;
revoke all on function public.my_birthdays() from public, anon;
grant execute on function public.my_birthdays() to authenticated;

-- Whole years on a day.
create or replace function public.f2_age_on(p_birth date, p_on date)
 returns int language sql immutable set search_path to '' as $$
  select extract(year from age(p_on, p_birth))::int
$$;

-- Set a birthday (or, for a coach-added player only, "I don't know").
create or replace function public.set_birthday(p_profile uuid, p_date date, p_unknown boolean default false)
 returns jsonb language plpgsql volatile security definer set search_path to '' as $$
declare
  acc text := public.f2_bday_access(p_profile);
  p public.profiles%rowtype;
  prim public.profiles%rowtype;
  age int;
  by_date text;
begin
  if acc is null then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  if coalesce(p_unknown, false) then
    if acc <> 'write' then return jsonb_build_object('ok', false, 'error', 'date_required'); end if;
    insert into public.profile_birthdays (profile_id, birth_date, unknown, set_by) values (p_profile, null, true, auth.uid())
      on conflict (profile_id) do update set birth_date = null, unknown = true, set_by = auth.uid(), set_at = now();
    return jsonb_build_object('ok', true);
  end if;
  if p_date is null or p_date > (now() at time zone 'America/New_York')::date or p_date < date '1900-01-01' then
    return jsonb_build_object('ok', false, 'error', 'date_invalid');
  end if;
  age := public.f2_age_on(p_date, (now() at time zone 'America/New_York')::date);
  if age > 100 then return jsonb_build_object('ok', false, 'error', 'date_invalid'); end if;
  by_date := case when age >= 18 then 'adult' when age >= 13 then 'minor_13_17' else 'under_13' end;
  -- The pitcher's own sign-up gave an age (P1-10, on the login's primary profile). A date that contradicts it is not
  -- saved: under 13 on a self-signed-up login, or under 18 on a login that said 18 or older. (13-17 then 18 now is
  -- just time passing.) Created players and child sign-ins are checked by how they were made, not here.
  select * into p from public.profiles where id = p_profile;
  if p.managed_by is null and p.account_id is not null then
    select * into prim from public.profiles where id = p.account_id;
    if prim.age_attestation is null then
      return jsonb_build_object('ok', false, 'error', 'answer_age_first');
    end if;
    if (prim.age_attestation = 'adult' and by_date <> 'adult') or (prim.age_attestation = 'minor_13_17' and by_date = 'under_13') then
      insert into public.birthday_contradictions (profile_id, attested, by_date) values (p_profile, prim.age_attestation, by_date);
      return jsonb_build_object('ok', false, 'error', 'contradiction');
    end if;
  end if;
  insert into public.profile_birthdays (profile_id, birth_date, unknown, set_by) values (p_profile, p_date, false, auth.uid())
    on conflict (profile_id) do update set birth_date = excluded.birth_date, unknown = false, set_by = auth.uid(), set_at = now();
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.set_birthday(uuid, date, boolean) from public, anon;
grant execute on function public.set_birthday(uuid, date, boolean) to authenticated;

-- The level a birthday gives on a September 1 (Joel, Nov 20 2026): 12 or under Little League; 13-17 High school, so a
-- senior who turns 18 during the school year stays High school; 18 or over on that September 1 is College. Softball:
-- 12 or under Little League, then High school & up.
create or replace function public.f2_level_for(p_sport text, p_age int)
 returns text language sql immutable set search_path to '' as $$
  select case
    when p_age <= 12 then 'little_league'
    when p_sport = 'softball' then 'high_school_up'
    when p_age <= 17 then 'high_school'
    else 'college' end
$$;
create or replace function public.f2_level_rank(p_level text)
 returns int language sql immutable set search_path to '' as $$
  select case p_level when 'little_league' then 1 when 'high_school' then 2 when 'high_school_up' then 2 when 'college' then 3 else 0 end
$$;

-- The September 1 move: every pitcher with a birthday goes UP to the level their age on that September 1 gives; never
-- down, so a level set higher by hand is kept. Only profiles.level (the pitcher's own level) changes: no session, report,
-- stats row or baseline is touched; team games keep the team's level. Silent: no email, no notice; one log row each.
create or replace function public.f2_level_switch(p_on date default null)
 returns integer language plpgsql volatile security definer set search_path to '' as $$
declare
  d date := coalesce(p_on, (now() at time zone 'America/New_York')::date);
  sep1 date;
  n int := 0;
  r record;
begin
  sep1 := make_date(extract(year from d)::int - case when extract(month from d) < 9 then 1 else 0 end, 9, 1);   -- the latest Sept 1
  for r in
    select p.id, p.sport, p.level, public.f2_level_for(p.sport, public.f2_age_on(b.birth_date, sep1)) as want
      from public.profiles p join public.profile_birthdays b on b.profile_id = p.id
     where p.role = 'pitcher' and b.birth_date is not null and p.sport in ('baseball', 'softball')
  loop
    if public.f2_level_rank(r.want) > public.f2_level_rank(r.level) then
      update public.profiles set level = r.want where id = r.id;
      insert into public.level_switch_log (profile_id, sport, from_level, to_level) values (r.id, r.sport, r.level, r.want);
      n := n + 1;
    end if;
  end loop;
  return n;
end;
$$;
revoke all on function public.f2_level_switch(date) from public, anon, authenticated;

-- Every September 1, 09:53 UTC (about 5 am Eastern), as the chat-clear job runs.
select cron.schedule('f2-level-switch', '53 9 1 9 *', $$select public.f2_level_switch()$$);
