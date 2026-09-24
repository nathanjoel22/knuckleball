-- R6 follow-up — fix a real (cosmetic but real) gap caught live during the
-- staging browser pass: a freshly created team's "Rotated" date showed as
-- "—" instead of its creation date.
--
-- public.teams_set_invite_token() (R0, 20260921030000) is a BEFORE INSERT
-- trigger that generates invite_token + invite_token_rotated_at, but only
-- `if new.invite_token is null`. _create_team_with_head (this session's R6
-- migration) explicitly supplied invite_token in its own INSERT, so that
-- trigger's condition was false and invite_token_rotated_at was silently
-- left null -- the token still worked (it's a real, valid, unique token),
-- only the displayed rotation date was missing.
--
-- Fix: stop supplying invite_token ourselves and let the existing trigger
-- generate it (and its rotated_at) exactly as it already does for every
-- other insert path into teams -- one fewer thing to keep in sync, not
-- just a timestamp fix. coach_invite_token has no such trigger (it's new
-- in this same migration set), so it's still set explicitly here, now
-- alongside its own rotated_at.
--
-- ---------------------------------------------------------------------------------
-- ROLLBACK: re-run _create_team_with_head from 20260925000000_r6_coaching_staffs.sql
-- (supplies invite_token itself again, reintroducing the gap this fixes).
-- ---------------------------------------------------------------------------------

create or replace function public._create_team_with_head(p_coach_id uuid, p_name text)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_team_id uuid;
begin
  insert into public.teams (coach_id, name, coach_invite_token, coach_invite_token_rotated_at)
  values (
    p_coach_id, p_name,
    replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''),
    now()
  )
  returning id into v_team_id;

  insert into public.team_coaches (team_id, coach_id, role) values (v_team_id, p_coach_id, 'head');

  return v_team_id;
end;
$$;
