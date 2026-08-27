-- P1-12 — Make account setup server-side, idempotent, and recoverable.
--
-- Adds two server-side layers so every confirmed auth user reliably ends up with a
-- matching public.profiles row (and, for a coach, a public.teams row), regardless of
-- which device/browser they confirm on or whether their signup metadata survived:
--
--   (a) public.handle_new_user()  — AFTER INSERT trigger on auth.users. Creates the
--       profile (+ team for a coach) from raw_user_meta_data captured at signup. It
--       swallows its own errors and always RETURNs NEW: a throwing trigger on
--       auth.users would break signup entirely, which is far worse than the gap it
--       closes. This is the first user-defined trigger on auth.users in this project —
--       a deliberate architectural change, which is why it ships alongside (b).
--
--   (b) public.ensure_account_setup(p_role, p_full_name, p_team_name) — SECURITY
--       DEFINER function the authenticated user calls via RPC on first authenticated
--       load. Idempotent; checks profile and team independently (no short-circuit on
--       "profile exists"), so it also repairs the profile-succeeded/team-failed case.
--       Covers pitchers as well as coaches, and accounts created before the trigger.
--       When the role cannot be determined it does nothing and lets the UI ask —
--       it never guesses a role for a real user.
--
-- The client-side self-heal in bullpen-tracker.html is removed in the same change set;
-- these two layers are the guarantee, not a fallback.
--
-- ---------------------------------------------------------------------------------
-- ROLLBACK (write a new migration with this body if you need to revert — per
-- DEPLOY.md, there is no automatic down-migration):
--
--   drop trigger if exists on_auth_user_created on auth.users;
--   drop function if exists public.handle_new_user();
--   drop function if exists public.ensure_account_setup(text, text, text);
--
-- Dropping these is safe: no other object depends on them, and removing them only
-- returns account setup to the prior client-only behaviour.
-- ---------------------------------------------------------------------------------


-- ============================================================================
-- (a) Trigger: create a coach's profile + team at signup from signup metadata
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
  -- Only a coach signup carries enough metadata to be set up automatically.
  -- Invited pitchers arrive with no metadata (inviteUserByEmail sets none) and are
  -- handled by accept-invite.html / public.ensure_account_setup() instead.
  if v_role = 'coach' and v_full_name is not null then
    insert into public.profiles (id, role, full_name)
    values (new.id, 'coach', v_full_name)
    on conflict (id) do nothing;

    if v_team_name is not null
       and not exists (select 1 from public.teams where coach_id = new.id) then
      insert into public.teams (coach_id, name) values (new.id, v_team_name);
    end if;
  end if;

  return new;
exception when others then
  -- Never let a failure here block signup. Log and move on; ensure_account_setup()
  -- and the recovery UI will pick up whatever didn't get created.
  raise warning 'handle_new_user failed for auth user %: %', new.id, sqlerrm;
  return new;
end;
$$;

alter function public.handle_new_user() owner to postgres;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ============================================================================
-- (b) RPC: idempotently create whatever account rows are missing
-- ============================================================================

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

  -- Serialise concurrent calls for the same user (double page load, retry, a
  -- reconnect landing mid-call) so two callers can't both insert a team.
  perform pg_advisory_xact_lock(hashtext('ensure_account_setup:' || v_uid::text));

  select raw_user_meta_data into v_meta from auth.users where id = v_uid;

  select role into v_profile_role from public.profiles where id = v_uid;
  v_has_profile := found;

  -- ---- Profile ----
  if not v_has_profile then
    -- Explicit args from the recovery UI win; fall back to signup metadata.
    -- Never guess: if neither gives a usable role + name, do nothing here.
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
  if v_profile_role = 'coach' then
    select exists (select 1 from public.teams where coach_id = v_uid) into v_has_team;

    if not v_has_team then
      v_resolved_team := coalesce(nullif(p_team_name, ''), nullif(v_meta ->> 'team_name', ''));
      if v_resolved_team is not null then
        insert into public.teams (coach_id, name) values (v_uid, v_resolved_team);
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

  -- ---- Pitcher ----
  return jsonb_build_object(
    'profile', case when v_profile_created then 'created' else 'exists' end,
    'role',    'pitcher',
    'team',    'not_applicable'
  );
end;
$$;

alter function public.ensure_account_setup(text, text, text) owner to postgres;

revoke all    on function public.ensure_account_setup(text, text, text) from public, anon;
grant  execute on function public.ensure_account_setup(text, text, text) to authenticated;
