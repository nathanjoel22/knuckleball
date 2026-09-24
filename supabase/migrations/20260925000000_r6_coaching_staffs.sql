-- R6 — Coaching staffs: assistant coaches, multi-team coaches, team admin
-- moves into the coach profile.
--
-- A team can have more than one coach (one HEAD, any number of ASSISTANTS),
-- and a coach can hold a role on more than one team. Today `is_team_coach`
-- IS "is head" (teams.coach_id = auth.uid(), one coach per team by
-- construction) -- this migration turns that into a real membership table
-- and makes `is_team_coach` mean "any coach on this team" while introducing
-- `is_team_head` for what `is_team_coach` used to mean. See the precondition
-- report (this session) for the full classification of every existing
-- caller into "broadens for free" vs "must move to is_team_head".
--
-- ---------------------------------------------------------------------------------
-- ROLLBACK (no auto-down; write a new migration with this body if you need to
-- revert). Reverting after any assistant relationship or coach-invite exists
-- destroys that data permanently (there is no second copy of "who is an
-- assistant where") -- take the pre-deploy backup seriously.
--
--   -- Functions added by this migration:
--   drop function if exists public.join_team_as_coach(text);
--   drop function if exists public.resolve_coach_invite(text);
--   drop function if exists public.rotate_coach_invite(uuid);
--   drop function if exists public.remove_coach(uuid, uuid);
--   drop function if exists public.rename_team(uuid, text);
--   drop function if exists public.hand_off_team_head(uuid, uuid);
--   drop function if exists public.create_team(text);
--   drop function if exists public.get_team_invite_links(uuid);
--   drop function if exists public.is_head_of_pitcher(uuid);
--   drop function if exists public._create_team_with_head(uuid, text);
--   drop function if exists public.is_team_head(uuid);
--
--   -- Restore is_team_coach to the pre-R6 definition (teams.coach_id only):
--   create or replace function public.is_team_coach(check_team_id uuid)
--   returns boolean language sql stable security definer set search_path = 'public'
--   as $$ select exists (select 1 from public.teams t where t.id = check_team_id and t.coach_id = auth.uid()); $$;
--
--   -- Restore every function/policy this migration moved to is_team_head
--   -- back to is_team_coach (they're the same helper again once the above
--   -- runs, so no further change needed there) EXCEPT the four that were
--   -- rewritten from an inline teams.coach_id join to is_team_coach()
--   -- (sessions x2, pitches x2) -- those stay correct as-is since
--   -- is_team_coach is restored to head-only above.
--
--   drop table if exists public.team_coaches;
--   revoke select (invite_token, invite_token_rotated_at, coach_invite_token,
--     coach_invite_token_rotated_at) on public.teams from authenticated, anon; -- re-run as GRANT to undo
--   grant select (invite_token, invite_token_rotated_at, coach_invite_token,
--     coach_invite_token_rotated_at) on public.teams to authenticated, anon;
--   alter table public.teams drop column if exists coach_invite_token, drop column if exists coach_invite_token_rotated_at;
--   drop policy if exists "Coaches view teams they belong to as staff" on public.teams;
-- ---------------------------------------------------------------------------------

-- ============================================================================
-- (1) team_coaches — the membership table. teams.coach_id stays and always
-- equals the head's id (kept in sync by hand_off_team_head and
-- _create_team_with_head below, the ONLY two places a head is ever set) so
-- nothing that reads teams.coach_id today breaks by surprise; this
-- migration explicitly re-points every caller that actually meant "head".
-- ============================================================================

create table public.team_coaches (
  team_id    uuid not null references public.teams(id) on delete cascade,
  coach_id   uuid not null references public.profiles(id) on delete cascade,
  role       text not null check (role in ('head', 'assistant')),
  joined_at  timestamptz not null default now(),
  invited_by uuid references public.profiles(id),
  primary key (team_id, coach_id)
);

comment on table public.team_coaches is
  'R6: a coach''s relationship to a team is a membership with a role, not a
   property of the account -- one coach account can be head of one team and
   assistant on another. Exactly one head row per team (partial unique index
   below). Writes only ever happen through the SECURITY DEFINER functions in
   this migration (create_team, join_team_as_coach, hand_off_team_head,
   remove_coach) -- there is deliberately no INSERT/UPDATE/DELETE policy, so
   a direct client write is refused by RLS regardless of role.';

-- Exactly one head per team.
create unique index team_coaches_one_head_per_team on public.team_coaches (team_id) where role = 'head';

-- Backfill: one head row per existing team, straight from teams.coach_id.
insert into public.team_coaches (team_id, coach_id, role)
select id, coach_id, 'head' from public.teams
on conflict do nothing;

alter table public.team_coaches enable row level security;

-- Read-only for clients: a coach sees every coach on a team he is on
-- (needed for the read-only "coaches list" both roles see, and for
-- is_team_coach itself, defined below, to work at all).
create policy "Coaches view their teams' coaching staff" on public.team_coaches
  for select using (public.is_team_coach(team_id));

revoke all on table public.team_coaches from anon;
grant select on table public.team_coaches to authenticated;

-- ============================================================================
-- (2) Coach invite token — mirrors teams.invite_token (R0) exactly.
-- ============================================================================

alter table public.teams
  add column coach_invite_token text,
  add column coach_invite_token_rotated_at timestamptz;

comment on column public.teams.coach_invite_token is
  'R6: same shape/trust model as invite_token (R0) -- CSPRNG, the token IS
   the credential, rotating invalidates the old link instantly. A separate
   token (not the pitcher one) because resolving it must reject a pitcher
   and land the visitor on the coach signup/accept path instead.';

update public.teams
set coach_invite_token = replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''),
    coach_invite_token_rotated_at = now()
where coach_invite_token is null;

alter table public.teams alter column coach_invite_token set not null;
alter table public.teams add constraint teams_coach_invite_token_key unique (coach_invite_token);

-- Both invite tokens are readable today only because whoever passes "coach
-- of this team" RLS could read the whole row (fine when there was only ever
-- one coach). Now that assistants also pass that check, and the decision
-- table says assistants get neither invite link, restrict the four
-- token/rotated-at columns at the column-privilege level (composes with RLS
-- -- a role needs both to read a cell) and serve them only through
-- get_team_invite_links() below, which checks is_team_head itself. This
-- table already has a blanket `grant all ... to authenticated, anon` from
-- the baseline (RLS is the real boundary here, per CLAUDE.md) -- this is a
-- real hole punched in that grant, not a new pattern.
revoke select (invite_token, invite_token_rotated_at, coach_invite_token, coach_invite_token_rotated_at)
  on public.teams from authenticated, anon;

-- ============================================================================
-- (3) THE HELPERS.
-- ============================================================================

-- is_team_head: what is_team_coach used to mean. Same body, new name --
-- every admin-only caller below moves to this one explicitly rather than
-- relying on is_team_coach to keep meaning what it used to.
create or replace function public.is_team_head(check_team_id uuid)
returns boolean
language sql stable security definer
set search_path = 'public'
as $$
  select exists (
    select 1 from public.teams t where t.id = check_team_id and t.coach_id = auth.uid()
  );
$$;

alter function public.is_team_head(uuid) owner to postgres;
revoke all on function public.is_team_head(uuid) from public, anon;
grant execute on function public.is_team_head(uuid) to authenticated;

-- is_team_coach: broadened to "any row in team_coaches for this team" --
-- every existing "coach may see/chart" caller that already goes through
-- this function gains assistants for free. Same signature, same STABLE
-- SECURITY DEFINER shape, so nothing calling it needs to change.
create or replace function public.is_team_coach(check_team_id uuid)
returns boolean
language sql stable security definer
set search_path = 'public'
as $$
  select exists (
    select 1 from public.team_coaches tc where tc.team_id = check_team_id and tc.coach_id = auth.uid()
  );
$$;

-- is_head_of_pitcher: the head-only counterpart to the existing
-- is_coach_of_pitcher (U7, unchanged -- it still means "any coach of a team
-- this pitcher is on" and is correct as-is for VIEWING). Every function that
-- EDITS a pitcher's profile moves to this one instead (decision table:
-- assistants cannot edit pitcher profiles).
create or replace function public.is_head_of_pitcher(p_pitcher_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.pitcher_teams pt
     where pt.pitcher_id = p_pitcher_id and public.is_team_head(pt.team_id)
  );
$$;

revoke all on function public.is_head_of_pitcher(uuid) from public, anon;
grant execute on function public.is_head_of_pitcher(uuid) to authenticated;

-- _create_team_with_head: the ONLY place a team row and its head row are
-- created together. Takes an explicit coach id (never auth.uid() internally)
-- because handle_new_user() runs as an AFTER INSERT trigger on auth.users,
-- where auth.uid() does not resolve to the new row. Every team-creation path
-- (coach signup, ensure_account_setup's recovery branch, the new "Create a
-- team" button) goes through this so a team can never exist without exactly
-- one head row -- the invariant loadTeams() below now depends on.
create or replace function public._create_team_with_head(p_coach_id uuid, p_name text)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_team_id uuid;
begin
  insert into public.teams (coach_id, name, invite_token, coach_invite_token)
  values (
    p_coach_id, p_name,
    replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''),
    replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '')
  )
  returning id into v_team_id;

  insert into public.team_coaches (team_id, coach_id, role) values (v_team_id, p_coach_id, 'head');

  return v_team_id;
end;
$$;

alter function public._create_team_with_head(uuid, text) owner to postgres;
-- Never exposed directly -- only ever called from other SECURITY DEFINER
-- functions below, which run as the owner (postgres) and so don't need a
-- grant here regardless.
revoke all on function public._create_team_with_head(uuid, text) from public, anon, authenticated;

-- ============================================================================
-- (4) Existing team-creation paths now go through _create_team_with_head,
-- so a team never exists without a matching team_coaches head row -- the
-- exact invariant loadTeams() (client) will depend on once it reads
-- team_coaches instead of teams.coach_id.
-- ============================================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role      text := nullif(new.raw_user_meta_data ->> 'intended_role', '');
  v_full_name text := nullif(new.raw_user_meta_data ->> 'full_name', '');
  v_team_name text := nullif(new.raw_user_meta_data ->> 'team_name', '');
begin
  if v_role = 'coach' and v_full_name is not null then
    insert into public.profiles (id, role, full_name)
    values (new.id, 'coach', v_full_name)
    on conflict (id) do nothing;

    -- R6: a coach-invite-link signup deliberately omits team_name (it's
    -- joining an existing team as assistant via join_team_as_coach, not
    -- creating one) -- this branch is unchanged, still skips team creation
    -- whenever team_name is absent, which is exactly what that path needs.
    if v_team_name is not null
       and not exists (select 1 from public.teams where coach_id = new.id) then
      perform public._create_team_with_head(new.id, v_team_name);
    end if;
  end if;

  return new;
exception when others then
  raise warning 'handle_new_user failed for auth user %: %', new.id, sqlerrm;
  return new;
end;
$$;

create or replace function public.ensure_account_setup(
  p_role      text default null,
  p_full_name text default null,
  p_team_name text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid             uuid := auth.uid();
  v_meta            jsonb;
  v_profile_role    text;
  v_resolved_role   text;
  v_resolved_name   text;
  v_resolved_team   text;
  v_has_profile     boolean;
  v_has_team        boolean;
  v_profile_created boolean := false;
  v_team_created    boolean := false;
begin
  if v_uid is null then
    return jsonb_build_object('error', 'not authenticated');
  end if;

  perform pg_advisory_xact_lock(hashtext('ensure_account_setup:' || v_uid::text));

  select raw_user_meta_data into v_meta from auth.users where id = v_uid;

  select role into v_profile_role from public.profiles where id = v_uid;
  v_has_profile := found;

  if not v_has_profile then
    v_resolved_role := coalesce(nullif(p_role, ''), nullif(v_meta ->> 'intended_role', ''));
    v_resolved_name := coalesce(nullif(p_full_name, ''), nullif(v_meta ->> 'full_name', ''));

    if v_resolved_role in ('coach', 'pitcher') and v_resolved_name is not null then
      insert into public.profiles (id, role, full_name)
      values (v_uid, v_resolved_role, v_resolved_name)
      on conflict (id) do nothing;

      select role into v_profile_role from public.profiles where id = v_uid;
      v_has_profile := found;
      v_profile_created := v_has_profile;
    end if;
  end if;

  if not v_has_profile then
    return jsonb_build_object(
      'profile',    'missing',
      'role',       null,
      'needs_role', true
    );
  end if;

  -- ---- Team (coach only) ----
  -- needs_team here still means "no team you HEAD" -- unchanged on purpose.
  -- This branch is what the explicit "create a team" recovery form
  -- (renderAccountSetupScreen / submitAccountSetup) drives: someone
  -- filling that in wants to become a NEW team's head regardless of
  -- whatever else they're already an assistant on, so "you already have
  -- team access" must never short-circuit it. The routing question this
  -- migration actually fixes -- whether an assistant-only coach even
  -- REACHES this recovery screen on a normal load -- is answered by
  -- loadTeams() (client) reading team_coaches instead of teams.coach_id,
  -- not by changing this function's own notion of needs_team.
  if v_profile_role = 'coach' then
    select exists (select 1 from public.teams where coach_id = v_uid) into v_has_team;

    if not v_has_team then
      v_resolved_team := coalesce(nullif(p_team_name, ''), nullif(v_meta ->> 'team_name', ''));
      if v_resolved_team is not null then
        perform public._create_team_with_head(v_uid, v_resolved_team);
        v_has_team     := true;
        v_team_created := true;
      end if;
    end if;

    return jsonb_build_object(
      'profile',    case when v_profile_created then 'created' else 'exists' end,
      'role',       'coach',
      'team',       case when v_team_created then 'created'
                         when v_has_team     then 'exists'
                         else 'missing' end,
      'needs_team', not v_has_team
    );
  end if;

  return jsonb_build_object(
    'profile', case when v_profile_created then 'created' else 'exists' end,
    'role',    'pitcher',
    'team',    'not_applicable'
  );
end;
$$;

-- ============================================================================
-- (5) COACH INVITE LINK — mirrors resolve_team_invite / join_team_via_invite
-- / rotate_team_invite (R0) exactly, role check inverted.
-- ============================================================================

create or replace function public.resolve_coach_invite(p_token text)
returns table(team_id uuid, team_name text)
language sql
security definer
set search_path = ''
as $$
  select id, name from public.teams where coach_invite_token = p_token;
$$;

revoke all on function public.resolve_coach_invite(text) from public;
grant execute on function public.resolve_coach_invite(text) to anon, authenticated;

create or replace function public.join_team_as_coach(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_role text;
  v_team_id uuid;
  v_team_name text;
  v_head_id uuid;
begin
  if v_uid is null then
    return jsonb_build_object('error', 'not_authenticated');
  end if;

  select role into v_role from public.profiles where id = v_uid;
  if v_role = 'pitcher' then
    return jsonb_build_object('error', 'pitcher_cannot_join');
  end if;

  select id, name, coach_id into v_team_id, v_team_name, v_head_id
    from public.teams where coach_invite_token = p_token;
  if v_team_id is null then
    return jsonb_build_object('error', 'invalid_token');
  end if;

  -- Idempotent, same as join_team_via_invite: opening the link twice is a
  -- no-op, never a second row (and never demotes an existing head/assistant
  -- row already there).
  insert into public.team_coaches (team_id, coach_id, role, invited_by)
  values (v_team_id, v_uid, 'assistant', v_head_id)
  on conflict (team_id, coach_id) do nothing;

  return jsonb_build_object('ok', true, 'team_id', v_team_id, 'team_name', v_team_name);
end;
$$;

revoke all on function public.join_team_as_coach(text) from public, anon;
grant execute on function public.join_team_as_coach(text) to authenticated;

create or replace function public.rotate_coach_invite(p_team_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_new_token text;
begin
  if not public.is_team_head(p_team_id) then
    raise exception 'not authorized';
  end if;

  v_new_token := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
  update public.teams
  set coach_invite_token = v_new_token, coach_invite_token_rotated_at = now()
  where id = p_team_id;

  return v_new_token;
end;
$$;

revoke all on function public.rotate_coach_invite(uuid) from public, anon;
grant execute on function public.rotate_coach_invite(uuid) to authenticated;

-- Head-only accessor for BOTH invite links, now that the raw columns are
-- unreadable directly (see the column revoke above). The admin section
-- calls this once for the active team; assistants never call it (the UI
-- never shows the links section to them), and if one did, is_team_head
-- refuses it server-side same as every other admin action here.
create or replace function public.get_team_invite_links(p_team_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_team_head(p_team_id) then
    raise exception 'not authorized';
  end if;

  return (
    select jsonb_build_object(
      'invite_token', invite_token,
      'invite_token_rotated_at', invite_token_rotated_at,
      'coach_invite_token', coach_invite_token,
      'coach_invite_token_rotated_at', coach_invite_token_rotated_at
    )
    from public.teams where id = p_team_id
  );
end;
$$;

revoke all on function public.get_team_invite_links(uuid) from public, anon;
grant execute on function public.get_team_invite_links(uuid) to authenticated;

-- ============================================================================
-- (6) TEAM ADMIN — create / rename / remove-coach / hand-off. All head-only
-- except create_team (any coach may start a new one and becomes its head).
-- Delete-team is deliberately NOT built here (packet: "leave the control
-- absent rather than half-built" -- P1-09 doesn't exist yet).
-- ============================================================================

create or replace function public.create_team(p_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;
  if p_name is null or btrim(p_name) = '' then
    raise exception 'team name cannot be blank';
  end if;
  return public._create_team_with_head(v_uid, btrim(p_name));
end;
$$;

revoke all on function public.create_team(text) from public, anon;
grant execute on function public.create_team(text) to authenticated;

create or replace function public.rename_team(p_team_id uuid, p_name text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_team_head(p_team_id) then
    raise exception 'not authorized';
  end if;
  if p_name is null or btrim(p_name) = '' then
    raise exception 'team name cannot be blank';
  end if;
  update public.teams set name = btrim(p_name) where id = p_team_id;
end;
$$;

revoke all on function public.rename_team(uuid, text) from public, anon;
grant execute on function public.rename_team(uuid, text) to authenticated;

-- Ends an assistant's membership and nothing else (decision item 4): his
-- account, his other teams, and pens he charted for THIS team all stay --
-- pens belong to pitchers (D3), never to the coach who charted them, and
-- this function never touches sessions/pitches/profiles at all.
create or replace function public.remove_coach(p_team_id uuid, p_coach_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_team_head(p_team_id) then
    raise exception 'not authorized';
  end if;
  if p_coach_id = (select coach_id from public.teams where id = p_team_id) then
    raise exception 'cannot remove the head coach -- hand off the head role first';
  end if;
  delete from public.team_coaches
   where team_id = p_team_id and coach_id = p_coach_id and role = 'assistant';
end;
$$;

revoke all on function public.remove_coach(uuid, uuid) from public, anon;
grant execute on function public.remove_coach(uuid, uuid) to authenticated;

-- The only way a team's head changes (decision item 1). Updates
-- team_coaches AND teams.coach_id together so they can never drift --
-- there is no trigger keeping them in sync; this function (plus
-- _create_team_with_head, which sets both at creation) is the entire
-- guarantee. Momentarily zero head rows exist between the two team_coaches
-- updates below, never two -- the partial unique index only ever rejects a
-- second 'head' row, so this ordering is safe inside one transaction.
create or replace function public.hand_off_team_head(p_team_id uuid, p_new_head_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
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

  update public.team_coaches set role = 'assistant' where team_id = p_team_id and coach_id = v_uid;
  update public.team_coaches set role = 'head'      where team_id = p_team_id and coach_id = p_new_head_id;
  update public.teams set coach_id = p_new_head_id where id = p_team_id;
end;
$$;

revoke all on function public.hand_off_team_head(uuid, uuid) from public, anon;
grant execute on function public.hand_off_team_head(uuid, uuid) to authenticated;

-- ============================================================================
-- (7) RECLASSIFY existing functions: every "coach may EDIT a pitcher's
-- profile" caller moves from is_team_coach (broadening under it) to
-- is_head_of_pitcher / is_team_head (decision table: assistants cannot edit
-- pitcher profiles, remove pitchers, regenerate links, or delete sessions).
-- ============================================================================

create or replace function public.coach_set_pitch_types(p_pitcher_id uuid, p_types text[])
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_head_of_pitcher(p_pitcher_id) then
    raise exception 'not allowed';
  end if;
  if p_types is null or cardinality(p_types) > 20 then
    raise exception 'invalid pitch list';
  end if;
  update public.profiles set pitch_types = p_types where id = p_pitcher_id;
end;
$$;

create or replace function public.coach_set_throws(p_pitcher_id uuid, p_throws text)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_head_of_pitcher(p_pitcher_id) then
    raise exception 'not allowed';
  end if;
  update public.profiles set throws = p_throws where id = p_pitcher_id;
end;
$$;

create or replace function public.coach_set_full_name(p_pitcher_id uuid, p_name text)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_head_of_pitcher(p_pitcher_id) then
    raise exception 'not allowed';
  end if;
  if p_name is null or btrim(p_name) = '' then
    raise exception 'name cannot be blank';
  end if;
  update public.profiles set full_name = btrim(p_name) where id = p_pitcher_id;
end;
$$;

create or replace function public.coach_set_uses_radar_gun(p_pitcher_id uuid, p_enabled boolean)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_head_of_pitcher(p_pitcher_id) then
    raise exception 'not allowed';
  end if;
  update public.profiles set uses_radar_gun = coalesce(p_enabled, false) where id = p_pitcher_id;
end;
$$;

create or replace function public.coach_set_relative_accuracy(p_pitcher_id uuid, p_enabled boolean)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_head_of_pitcher(p_pitcher_id) then
    raise exception 'not allowed';
  end if;
  if p_enabled is null then
    raise exception 'invalid value';
  end if;
  update public.profiles set relative_accuracy_enabled = p_enabled where id = p_pitcher_id;
end;
$$;

create or replace function public.set_uniform_number(
  p_team_id    uuid,
  p_pitcher_id uuid,
  p_number     smallint,
  p_expected   smallint
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_current smallint;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if p_number is not null and (p_number < 0 or p_number > 99) then
    raise exception 'uniform number must be between 0 and 99';
  end if;

  if not (v_uid = p_pitcher_id or public.is_team_head(p_team_id)) then
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

create or replace function public.rotate_team_invite(p_team_id uuid)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  v_new_token text;
begin
  if not public.is_team_head(p_team_id) then
    raise exception 'not authorized';
  end if;

  v_new_token := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
  update public.teams
  set invite_token = v_new_token, invite_token_rotated_at = now()
  where id = p_team_id;

  return v_new_token;
end;
$$;

create or replace function public.get_removal_notice_info(p_pitcher_id uuid, p_team_id uuid)
returns table(email text, team_name text)
language plpgsql security definer set search_path = ''
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
    from auth.users u, public.teams t
    where u.id = p_pitcher_id and t.id = p_team_id;
end;
$$;

-- delete_session's coach branch: assistants cannot delete team sessions
-- (confirmed by Joel) -- narrows from "any team coach" to head-only.
create or replace function public.delete_session(p_session_id uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid     uuid := auth.uid();
  v_pitcher uuid;
  v_team    uuid;
  v_role    text;
  v_count   integer;
begin
  if v_uid is null then
    return jsonb_build_object('error', 'not authenticated');
  end if;

  select pitcher_id, team_id into v_pitcher, v_team
  from public.sessions
  where id = p_session_id and deleted_at is null;
  if not found then
    return jsonb_build_object('error', 'session not found or already deleted');
  end if;

  if v_pitcher = v_uid then
    v_role := 'pitcher';
  elsif public.is_team_head(v_team) then
    v_role := 'coach';
  else
    return jsonb_build_object('error', 'not entitled to delete this session');
  end if;

  select count(*) into v_count from public.pitches where session_id = p_session_id;

  update public.sessions
     set deleted_at      = now(),
         deleted_by      = v_uid,
         deleted_by_role = v_role,
         pitch_count     = v_count
   where id = p_session_id;

  return jsonb_build_object('ok', true);
end;
$$;

-- ============================================================================
-- (8) RECLASSIFY RLS policies.
-- ============================================================================

-- teams: the existing ALL policy narrows to head-only (rename/delete-if-
-- ever-built are head actions; writes to this table are otherwise only ever
-- done through the SECURITY DEFINER functions above, which bypass RLS
-- entirely as the table owner). A NEW, separate SELECT policy gives every
-- coach on the team read access to the row (name, id -- NOT the token
-- columns, which are column-revoked above regardless of row access).
drop policy if exists "Coaches manage own teams" on public.teams;
create policy "Coaches manage own teams" on public.teams
  for all using (public.is_team_head(id)) with check (public.is_team_head(id));

create policy "Coaches view teams they belong to as staff" on public.teams
  for select using (public.is_team_coach(id));

-- pitcher_teams: viewing the roster stays any-coach; removing a pitcher
-- narrows to head-only.
drop policy if exists "Coaches remove pitchers from their team" on public.pitcher_teams;
create policy "Coaches remove pitchers from their team" on public.pitcher_teams
  for delete using (public.is_team_head(team_id));

-- sessions: these two policies bypassed is_team_coach entirely (inline
-- teams.coach_id join) -- today that's identical to head-only; rewriting
-- them to call is_team_coach(team_id) directly (sessions already carries
-- team_id, no join needed) is what actually lets assistants chart/view.
drop policy if exists "Coaches manage sessions for their team" on public.sessions;
create policy "Coaches manage sessions for their team" on public.sessions
  for all using (public.is_team_coach(team_id)) with check (public.is_team_coach(team_id));

drop policy if exists "Coaches view sessions logged under their team" on public.sessions;
create policy "Coaches view sessions logged under their team" on public.sessions
  for select using (public.is_team_coach(team_id));

-- pitches: same story, via a join to sessions for team_id (pitches has no
-- team_id column of its own).
drop policy if exists "Coaches manage pitches for their team's sessions" on public.pitches;
create policy "Coaches manage pitches for their team's sessions" on public.pitches
  for all using (
    exists (select 1 from public.sessions s where s.id = pitches.session_id and public.is_team_coach(s.team_id))
  ) with check (
    exists (select 1 from public.sessions s where s.id = pitches.session_id and public.is_team_coach(s.team_id))
  );

drop policy if exists "Coaches view pitches for their team's sessions" on public.pitches;
create policy "Coaches view pitches for their team's sessions" on public.pitches
  for select using (
    exists (select 1 from public.sessions s where s.id = pitches.session_id and public.is_team_coach(s.team_id))
  );

-- leaderboard_exclusions: the "exclude a reading" control is head-only
-- (packet, approach g) -- narrows from is_team_coach.
drop policy if exists "Coach manages leaderboard exclusions for own team" on public.leaderboard_exclusions;
create policy "Coach manages leaderboard exclusions for own team" on public.leaderboard_exclusions
  for all using (public.is_team_head(team_id)) with check (public.is_team_head(team_id));

-- invites / "Coaches manage own team invites": left untouched. Confirmed
-- (precondition report, finding E) this table and accept-invite.html /
-- invite-pitcher are vestigial -- superseded by R0's link-based pitcher
-- invite and, as of this migration, the link-based coach invite above.
-- Nothing in bullpen-tracker.html references either.

-- get_team_leaderboard: NOT changed here. It already calls
-- is_team_coach(p_team_id) for view access (any coach may see the board),
-- which is correct as written -- the head-only line is drawn at
-- leaderboard_exclusions above, a separate table.
