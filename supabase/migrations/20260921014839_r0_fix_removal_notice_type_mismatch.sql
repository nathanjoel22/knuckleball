-- R0 follow-up — fix a real type mismatch in get_removal_notice_info,
-- caught live during the staging walkthrough.
--
-- auth.users.email is character varying, not text -- confirmed via
-- information_schema.columns. get_removal_notice_info declares
-- `returns table(email text, team_name text)` and uses plpgsql's RETURN
-- QUERY, which -- unlike a plain LANGUAGE SQL function's more permissive
-- implicit return coercion -- enforces an EXACT type match between the
-- query's output and the declared return type. That mismatch made every
-- call fail with "structure of query does not match function result
-- type", 403'd by send-removal-notice's own error handling (so no email
-- ever silently failed to send -- it correctly never sent, and the
-- function correctly never claimed success).
--
-- Checked the other functions in this migration series for the same
-- latent bug before writing this: my_verification_status and
-- get_roster_verification also select auth.users.email into a declared
-- text column, but both are LANGUAGE SQL (no RETURN QUERY), and both
-- have already been proven working repeatedly during this walkthrough
-- (the Unverified badges, the verify banner) -- confirming the coercion
-- difference is real, not just theoretical, and this fix is isolated to
-- the one function that actually needed it.

create or replace function public.get_removal_notice_info(p_pitcher_id uuid, p_team_id uuid)
returns table(email text, team_name text)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_team_coach(p_team_id) then
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

-- Grants unchanged (still revoked from public/anon, authenticated-only) --
-- CREATE OR REPLACE doesn't reset a function's ACL.

-- ---------------------------------------------------------------------------------
-- ROLLBACK (no auto-down; write a new migration with this body if you need to
-- revert) -- restores the unqualified select, which will fail with the
-- type-mismatch error again on every call:
--
--   create or replace function public.get_removal_notice_info(p_pitcher_id uuid, p_team_id uuid)
--   returns table(email text, team_name text)
--   language plpgsql security definer set search_path = ''
--   as $$
--   begin
--     if not public.is_team_coach(p_team_id) then
--       raise exception 'not authorized';
--     end if;
--     if not exists (select 1 from public.pitcher_teams where pitcher_id = p_pitcher_id and team_id = p_team_id) then
--       raise exception 'pitcher is not a member of this team';
--     end if;
--     return query select u.email, t.name from auth.users u, public.teams t where u.id = p_pitcher_id and t.id = p_team_id;
--   end;
--   $$;
-- ---------------------------------------------------------------------------------
