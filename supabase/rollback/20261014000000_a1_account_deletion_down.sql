-- Down for 20261014000000_a1_account_deletion. Executed purges are NOT reversible (tombstoned sessions keep a NULL
-- pitcher and can't regain NOT NULL while they exist -- this down leaves pitcher_id / logged_by nullable if any such
-- rows remain, and says so).
drop function if exists public.a1_due_deletions();
drop function if exists public.a1_purge_profile(uuid);
drop function if exists public.cancel_account_deletion(uuid);
drop function if exists public.request_account_deletion(text, uuid);
drop function if exists public.account_deletion_status(uuid);
drop function if exists public.a1_headed_teams(uuid);
drop table if exists public.account_deletion_log;
delete from public.rate_limit_config where key in ('account_deletion_day', 'account_export_day');
alter table public.profiles drop column if exists deletion_due_at;
alter table public.profiles drop column if exists deletion_requested_at;
-- the H1 lock without the A1 exception
create or replace function public.sessions_h1_lock()
returns trigger language plpgsql set search_path to '' as $function$
begin
  if old.ended_at is null then return new; end if;
  if new.ended_at is distinct from old.ended_at then
    raise exception 'session_saved_locked' using detail = 'A saved session can''t be un-saved or re-timed.';
  end if;
  if (new.id, new.pitcher_id, new.team_id, new.logged_by, new.started_at, new.created_at, new.kind, new.sport,
      new.charting_perspective, new.opponent, new.game_final_inning, new.game_outs_recorded)
     is distinct from
     (old.id, old.pitcher_id, old.team_id, old.logged_by, old.started_at, old.created_at, old.kind, old.sport,
      old.charting_perspective, old.opponent, old.game_final_inning, old.game_outs_recorded) then
    raise exception 'session_saved_locked' using detail = 'Who and what a saved session belongs to can''t change.';
  end if;
  if old.sealed_at is not null and new.sealed_at is distinct from old.sealed_at then
    raise exception 'session_saved_locked' using detail = 'A sealed session stays sealed.';
  end if;
  if current_user in ('authenticated', 'anon', 'service_role')
     and (new.deleted_at, new.deleted_by, new.deleted_by_role, new.deleted_by_name, new.pitch_count)
         is distinct from (old.deleted_at, old.deleted_by, old.deleted_by_role, old.deleted_by_name, old.pitch_count) then
    raise exception 'session_saved_locked' using detail = 'Only delete_session() can delete a session.';
  end if;
  return new;
end; $function$;
alter table public.sessions drop constraint if exists sessions_deletion_check;
alter table public.sessions add constraint sessions_deletion_check check (
  deleted_at is null or (deleted_by is not null and deleted_by_role in ('pitcher', 'coach') and pitch_count is not null and pitch_count >= 0)
) not valid;   -- NOT VALID: purged tombstones ('deleted_account') may remain
alter table public.sessions drop constraint if exists sessions_pitcher_unless_tombstone;
do $$ begin
  if not exists (select 1 from public.sessions where pitcher_id is null) then
    alter table public.sessions alter column pitcher_id set not null;
  else raise notice 'A1 down: tombstones with no pitcher remain; pitcher_id stays nullable'; end if;
  if not exists (select 1 from public.sessions where logged_by is null) then
    alter table public.sessions alter column logged_by set not null;
  else raise notice 'A1 down: sessions with a former coach remain; logged_by stays nullable'; end if;
end $$;
