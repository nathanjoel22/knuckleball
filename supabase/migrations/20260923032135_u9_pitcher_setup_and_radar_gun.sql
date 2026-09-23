-- U9 -- pitcher setup page, coach profile moves to a corner control, radar-gun
-- preference replaces nothing (no per-session checkbox exists to replace --
-- see the precondition report; Joel confirmed the per-pitch skip-by-not-
-- tapping behavior stays exactly as-is, no new checkbox anywhere).
--
-- Three additions, all on public.profiles:
--
-- 1. uses_radar_gun boolean -- the pitcher's own setting, governs whoever
--    charts him (a coach charting Jake sees the strip iff Jake's toggle is
--    on). Loaded the same way pitch_types/throws already are (mapProfile(),
--    the offline snapshot in saveLastKnownContext), but "changing it takes
--    effect next session, never mid-pen" needed one more thing on the
--    client: currentPitcher() is re-derived live on every render, so a
--    toggle flipped from the SAME device's own Profile tab mid-pen would
--    otherwise show/hide the strip immediately, unlike a genuinely
--    per-session-frozen value. The client snapshots it once onto the
--    session/draft object itself at creation (freshActiveSession) and
--    resume (resumeDraft), and reads that snapshot (sessionUsesRadarGun()),
--    never the live pitcher, for the rest of that pen.
--
-- 2. full_name becomes editable -- currently NOT editable by anyone,
--    anywhere (confirmed by grep before writing this: ensure_account_setup
--    only sets it on first INSERT, never UPDATE; the U7 lockdown migration's
--    self-service column grant list never included it). Same shape as
--    that lockdown: self-edit via a direct column grant + a DB check
--    constraint (the one thing a raw grant can't stop a client from doing
--    is submitting blank), coach-edit via a narrow SECURITY DEFINER
--    function mirroring coach_set_throws/coach_set_pitch_types exactly
--    (is_team_coach check, never role/email_verified_at, never a policy).
--
-- 3. setup_dismissed_at timestamptz -- NOT explicitly named in the U9
--    packet, added because acceptance checks 5-7 don't hang together
--    without it: a brand-new pitcher must land on the full setup PAGE
--    once, but an already-existing pitcher with an incomplete profile
--    (there are some on both projects today) must NOT suddenly get
--    redirected to a new full-page interstitial on their next login --
--    they should only ever see the small persistent reminder banner.
--    Backfilling every EXISTING profile to now() on this migration draws
--    that line at "already using the app before U9 shipped." New
--    signups get NULL, so the client shows the full setup page exactly
--    once; completing OR skipping it sets this, and the client never
--    shows the interstitial again regardless of whether the profile is
--    later complete. The ongoing reminder BANNER is separate and derived
--    purely from live data (uniform #, throws, pitch mix all set?), no
--    column needed for it.
--
-- ---------------------------------------------------------------------------------
-- ROLLBACK (no auto-down; write a new migration with this body if you need to
-- revert):
--
--   drop function if exists public.coach_set_full_name(uuid, text);
--   drop function if exists public.coach_set_uses_radar_gun(uuid, boolean);
--   revoke update (full_name, uses_radar_gun, setup_dismissed_at) on public.profiles from authenticated;
--   alter table public.profiles drop constraint if exists profiles_full_name_not_blank;
--   alter table public.profiles drop column if exists uses_radar_gun;
--   alter table public.profiles drop column if exists setup_dismissed_at;
-- ---------------------------------------------------------------------------------

alter table public.profiles
  add column uses_radar_gun boolean not null default false,
  add column setup_dismissed_at timestamptz;

comment on column public.profiles.uses_radar_gun is
  'The PITCHER''s own preference (U9): whether the velocity strip appears at
   all on the charting page, for whoever charts them. Default false -- a
   pitcher who has never said "yes" to a gun should never see a strip.
   Changing it never affects an already-open session -- the client
   snapshots this value onto the session/draft object at creation and
   resume (see sessionUsesRadarGun() in bullpen-tracker.html), never
   re-reading it live mid-pen even from the same device.';
comment on column public.profiles.setup_dismissed_at is
  'When this pitcher completed or explicitly skipped ("Set this up later")
   the post-signup setup page -- NULL means show it once, automatically, on
   next load. Backfilled to now() for every profile that existed before U9
   shipped, so no existing user is suddenly redirected to a page they never
   asked for; they still see the ongoing incomplete-profile reminder banner
   if applicable, which is derived live and does not depend on this column.';

update public.profiles set setup_dismissed_at = now() where setup_dismissed_at is null;

alter table public.profiles
  add constraint profiles_full_name_not_blank check (btrim(full_name) <> '');

-- Self-service: a user may set their OWN full_name, uses_radar_gun, and
-- setup_dismissed_at directly (RLS still restricts this to id = auth.uid()
-- via the existing "Users update own profile" policy; this only adds the
-- columns to what that policy is allowed to touch). setup_dismissed_at
-- needs no validation (a plain timestamp the client sets to now() on
-- finish/skip); the blank-name constraint above is the backstop a raw
-- grant can't otherwise provide for full_name.
grant update (full_name, uses_radar_gun, setup_dismissed_at) on public.profiles to authenticated;

-- Coach-edit: same shape as coach_set_throws/coach_set_pitch_types
-- (20260921070000) -- functions, not a policy, so role/email_verified_at/
-- contact_emails/setup_dismissed_at stay untouched by a coach regardless
-- of which pitcher (setup_dismissed_at is deliberately NOT coach-settable
-- -- it's a per-pitcher "have I personally seen my own setup page" flag,
-- not something a coach acting on their behalf should be able to clear).
create or replace function public.coach_set_full_name(p_pitcher_id uuid, p_name text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not exists (
    select 1 from public.pitcher_teams pt
     where pt.pitcher_id = p_pitcher_id and public.is_team_coach(pt.team_id)
  ) then
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
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not exists (
    select 1 from public.pitcher_teams pt
     where pt.pitcher_id = p_pitcher_id and public.is_team_coach(pt.team_id)
  ) then
    raise exception 'not allowed';
  end if;
  update public.profiles set uses_radar_gun = coalesce(p_enabled, false) where id = p_pitcher_id;
end;
$$;

revoke all on function public.coach_set_full_name(uuid, text) from public, anon;
revoke all on function public.coach_set_uses_radar_gun(uuid, boolean) from public, anon;
grant execute on function public.coach_set_full_name(uuid, text) to authenticated;
grant execute on function public.coach_set_uses_radar_gun(uuid, boolean) to authenticated;
