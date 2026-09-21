-- Fix coach signup: teams.invite_token became NOT NULL (20260919025421) but the
-- team inserts in handle_new_user() and ensure_account_setup() (20260827161717)
-- never set it. The insert failed, handle_new_user()'s exception block rolled back
-- the profile insert too and swallowed the error, and ensure_account_setup() failed
-- the same way -- so new coaches ended up with no profile ("Could not load your
-- account profile").
--
-- Fix at the table rather than in each caller: a BEFORE INSERT trigger fills in the
-- token (same expression the r0 migration uses) whenever an insert omits it, so
-- every current and future insert path is covered. An explicitly supplied token is
-- left alone.
--
-- ---------------------------------------------------------------------------------
-- ROLLBACK (write a new migration with this body if you need to revert):
--
--   drop trigger if exists teams_set_invite_token on public.teams;
--   drop function if exists public.teams_set_invite_token();
-- ---------------------------------------------------------------------------------

create or replace function public.teams_set_invite_token()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.invite_token is null then
    new.invite_token := replace(gen_random_uuid()::text, '-', '')
                     || replace(gen_random_uuid()::text, '-', '');
    new.invite_token_rotated_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists teams_set_invite_token on public.teams;
create trigger teams_set_invite_token
  before insert on public.teams
  for each row execute function public.teams_set_invite_token();
