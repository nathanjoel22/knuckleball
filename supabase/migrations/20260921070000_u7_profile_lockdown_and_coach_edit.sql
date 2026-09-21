-- U7 Phase A: throws, profile write lockdown, coach editing of pitch mix / throws.
--
-- 1. profiles.throws ('L' | 'R', nullable, informational only).
--
-- 2. Lock down direct client writes to profiles. Before this, the "Users update
--    own profile" policy (USING id = auth.uid(), no WITH CHECK) combined with a
--    table-wide UPDATE grant let any signed-in user change ANY column of their
--    own row -- including role and email_verified_at (which would skip the
--    email-verification gate on report sending). Verification itself is
--    unaffected: it goes through verify_email() / generate_email_verify_token(),
--    which are SECURITY DEFINER and so don't depend on this grant. The only
--    client writes to profiles are pitch_types and contact_emails (audited in
--    bullpen-tracker.html); throws is added for the new Profile page. Columns
--    added later get no client write access unless granted here.
--
-- 3. Coach editing goes through two narrow SECURITY DEFINER functions, not an
--    RLS policy: a policy limits rows, not columns, so it would also expose
--    role / email_verified_at / contact_emails to coaches. A coach may only edit
--    a pitcher who is on one of the coach's own teams (public.is_team_coach,
--    per CLAUDE.md landmine 1). A per-team uniform number is already covered by
--    set_uniform_number(). Coaches never touch email or password (those live in
--    the auth system, not profiles).
--
-- ---------------------------------------------------------------------------------
-- ROLLBACK (no automatic down-migration: to revert, write a NEW migration with
-- this body and deploy it staging-first, per DEPLOY.md):
--
--   drop function if exists public.coach_set_pitch_types(uuid, text[]);
--   drop function if exists public.coach_set_throws(uuid, text);
--   grant update on public.profiles to authenticated, anon;   -- reopens the lockdown
--   alter table public.profiles drop column if exists throws; -- deletes any throws data entered since
--
-- Reverting the grant reopens the hole described in (2); prefer fixing forward.
-- ---------------------------------------------------------------------------------

alter table public.profiles
  add column throws text
  constraint profiles_throws_check check (throws in ('L', 'R'));

revoke update on public.profiles from authenticated, anon;
grant update (pitch_types, contact_emails, throws) on public.profiles to authenticated;

create or replace function public.coach_set_pitch_types(p_pitcher_id uuid, p_types text[])
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
  if p_types is null or cardinality(p_types) > 20 then
    raise exception 'invalid pitch list';
  end if;
  update public.profiles set pitch_types = p_types where id = p_pitcher_id;
end;
$$;

create or replace function public.coach_set_throws(p_pitcher_id uuid, p_throws text)
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
  -- profiles_throws_check rejects anything other than 'L', 'R' or null.
  update public.profiles set throws = p_throws where id = p_pitcher_id;
end;
$$;

-- This project auto-grants execute on new functions to anon (see the note in
-- 20260919025421); revoke from both, grant only to signed-in users.
revoke all on function public.coach_set_pitch_types(uuid, text[]) from public, anon;
revoke all on function public.coach_set_throws(uuid, text) from public, anon;
grant execute on function public.coach_set_pitch_types(uuid, text[]) to authenticated;
grant execute on function public.coach_set_throws(uuid, text) to authenticated;
