-- A1 (Joel, Oct 14 2026): delete my account in the app, with a 7-day grace; plans/a1-account-deletion-export.md,
-- decisions in plans/a1-preconditions.md ("Joel's answers").
--
--  * A login (or a parent-created player) is MARKED for deletion; 7 days later the delete-account function's
--    scheduled run purges it. Signing in during the grace can restore it.
--  * The pitcher's own sessions become TOMBSTONES: a record that the session happened (date, pitch count,
--    "deleted account"), never openable again -- pitches, events, notes and the report file all go, and the row
--    no longer names a pitcher (pitcher_id NULL).
--  * A deleted coach's charted sessions stay with the pitcher who threw them (and stay visible to that team);
--    "charted by" becomes a former coach (logged_by NULL).
--  * Notes the person wrote are deleted (Apple: content shared with others goes too).
--  * A head coach can't be deleted while still the head of any team (archived included).
--
-- No new RLS policy: the new columns are NOT granted to clients (column grants, Oct 2), and every entry point is a
-- SECURITY DEFINER function with its own check. a1_purge_profile() is executable by service_role only.
-- Rollback: supabase/rollback/20261014000000_a1_account_deletion_down.sql

-- ---------- 1. the deletion mark (on the profile: the primary profile = the whole login; a player = that player) ----------
alter table public.profiles add column if not exists deletion_requested_at timestamptz;
alter table public.profiles add column if not exists deletion_due_at       timestamptz;
comment on column public.profiles.deletion_requested_at is 'A1: when deletion was requested. On the primary profile it covers the whole login. Never client-readable.';
comment on column public.profiles.deletion_due_at is 'A1: when the scheduled run purges it (requested + 7 days).';

-- ---------- 2. tombstones without a pitcher; sessions without a charter ----------
alter table public.sessions alter column pitcher_id drop not null;
alter table public.sessions alter column logged_by  drop not null;
alter table public.sessions add constraint sessions_pitcher_unless_tombstone
  check (pitcher_id is not null or deleted_at is not null);
alter table public.sessions drop constraint sessions_deletion_check;
alter table public.sessions add constraint sessions_deletion_check check (
  deleted_at is null
  or (deleted_by is not null and deleted_by_role in ('pitcher', 'coach') and pitch_count is not null and pitch_count >= 0)
  or (deleted_by_role = 'deleted_account' and deleted_by_name is null and pitch_count is not null and pitch_count >= 0)
);

-- ---------- 3. the H1 lock: one exception, for the server's own deletion function only ----------
-- A saved session's pitcher / charter may be CLEARED (set to NULL) -- never changed to someone else -- and only by
-- a function running as its owner (not by the app, a crafted request or the service role directly). The rest of the
-- lock is unchanged.
create or replace function public.sessions_h1_lock()
returns trigger
language plpgsql
set search_path to ''
as $function$
declare
  v_api boolean := current_user in ('authenticated', 'anon', 'service_role');
  v_pitcher uuid := new.pitcher_id;
  v_logged  uuid := new.logged_by;
begin
  if old.ended_at is null then
    return new;   -- a legacy unsaved row (none on production): finishes through the old path
  end if;
  if new.ended_at is distinct from old.ended_at then
    raise exception 'session_saved_locked' using detail = 'A saved session can''t be un-saved or re-timed.';
  end if;
  -- A1: the account-deletion function may clear these two (to NULL only).
  if not v_api then
    if new.pitcher_id is null then v_pitcher := old.pitcher_id; end if;
    if new.logged_by  is null then v_logged  := old.logged_by;  end if;
  end if;
  if (new.id, v_pitcher, new.team_id, v_logged, new.started_at, new.created_at, new.kind, new.sport,
      new.charting_perspective, new.opponent, new.game_final_inning, new.game_outs_recorded)
     is distinct from
     (old.id, old.pitcher_id, old.team_id, old.logged_by, old.started_at, old.created_at, old.kind, old.sport,
      old.charting_perspective, old.opponent, old.game_final_inning, old.game_outs_recorded) then
    raise exception 'session_saved_locked' using detail = 'Who and what a saved session belongs to can''t change.';
  end if;
  if old.sealed_at is not null and new.sealed_at is distinct from old.sealed_at then
    raise exception 'session_saved_locked' using detail = 'A sealed session stays sealed.';
  end if;
  -- The tombstone is written only by the server's own functions (delete_session, a1_purge_profile run as owner).
  -- Any API caller -- the app, a crafted request, the service role -- is refused.
  if v_api
     and (new.deleted_at, new.deleted_by, new.deleted_by_role, new.deleted_by_name, new.pitch_count)
         is distinct from (old.deleted_at, old.deleted_by, old.deleted_by_role, old.deleted_by_name, old.pitch_count) then
    raise exception 'session_saved_locked' using detail = 'Only delete_session() can delete a session.';
  end if;
  return new;   -- report_path / report_generated_at, and sealing an unsealed session, stay writable
end;
$function$;

-- ---------- 4. the owner's entry points ----------
-- The teams the caller's login heads (archived included): deletion waits until none remain.
create or replace function public.a1_headed_teams(p_account uuid)
returns jsonb
language sql
stable
security definer
set search_path to ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', t.id, 'name', t.name, 'archived', t.archived_at is not null,
                                               'has_sessions', exists (select 1 from public.sessions s where s.team_id = t.id))
                            order by t.name), '[]'::jsonb)
    from public.teams t join public.profiles p on p.id = t.coach_id
   where p.account_id = p_account;
$$;
revoke all on function public.a1_headed_teams(uuid) from public, anon, authenticated;

-- What the signed-in login (or one of its managed players) has scheduled, and what blocks a deletion.
create or replace function public.account_deletion_status(p_profile uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $$
declare
  v_uid uuid := auth.uid();
  v_target uuid;
  r record;
begin
  if v_uid is null then return jsonb_build_object('error', 'not_authenticated'); end if;
  v_target := coalesce(p_profile, v_uid);   -- default: the login (its primary profile)
  select id, account_id, managed_by, deletion_requested_at, deletion_due_at into r
    from public.profiles where id = v_target;
  if not found or r.account_id <> v_uid then return jsonb_build_object('error', 'not_entitled'); end if;
  return jsonb_build_object(
    'profile', r.id, 'player', r.managed_by is not null,
    'requested_at', r.deletion_requested_at, 'due_at', r.deletion_due_at,
    'headed_teams', case when r.id = v_uid then public.a1_headed_teams(v_uid) else '[]'::jsonb end);
end;
$$;
revoke all on function public.account_deletion_status(uuid) from public, anon;
grant execute on function public.account_deletion_status(uuid) to authenticated;

-- Mark for deletion. The typed confirmation is checked HERE, not only in the app. p_profile null = the whole login;
-- a managed player's id = that player (the parent deletes the player; the parent's login stays).
create or replace function public.request_account_deletion(p_confirm text, p_profile uuid default null)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_uid uuid := auth.uid();
  v_target uuid;
  r record;
  v_heads jsonb;
begin
  if v_uid is null then return jsonb_build_object('error', 'not_authenticated'); end if;
  if p_confirm is distinct from 'DELETE' then return jsonb_build_object('error', 'confirmation_mismatch'); end if;
  v_target := coalesce(p_profile, v_uid);
  select id, account_id, managed_by, deletion_requested_at, deletion_due_at into r
    from public.profiles where id = v_target for update;
  if not found or r.account_id <> v_uid then return jsonb_build_object('error', 'not_entitled'); end if;
  if r.id <> v_uid and r.managed_by is null then
    return jsonb_build_object('error', 'not_entitled');   -- a non-primary profile that isn't a managed player: delete the login instead
  end if;
  if r.deletion_requested_at is not null then   -- a second request during the grace is a no-op
    return jsonb_build_object('ok', true, 'status', 'already_scheduled', 'due_at', r.deletion_due_at);
  end if;
  if r.id = v_uid then
    v_heads := public.a1_headed_teams(v_uid);
    if jsonb_array_length(v_heads) > 0 then
      return jsonb_build_object('error', 'still_head', 'teams', v_heads);
    end if;
  end if;
  update public.profiles set deletion_requested_at = now(), deletion_due_at = now() + interval '7 days'
   where id = r.id;
  return jsonb_build_object('ok', true, 'status', 'scheduled', 'due_at', now() + interval '7 days', 'profile', r.id);
end;
$$;
revoke all on function public.request_account_deletion(text, uuid) from public, anon;
grant execute on function public.request_account_deletion(text, uuid) to authenticated;

create or replace function public.cancel_account_deletion(p_profile uuid default null)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_uid uuid := auth.uid();
  v_target uuid;
  r record;
begin
  if v_uid is null then return jsonb_build_object('error', 'not_authenticated'); end if;
  v_target := coalesce(p_profile, v_uid);
  select id, account_id into r from public.profiles where id = v_target;
  if not found or r.account_id <> v_uid then return jsonb_build_object('error', 'not_entitled'); end if;
  update public.profiles set deletion_requested_at = null, deletion_due_at = null where id = r.id;
  return jsonb_build_object('ok', true, 'status', 'restored');
end;
$$;
revoke all on function public.cancel_account_deletion(uuid) from public, anon;
grant execute on function public.cancel_account_deletion(uuid) to authenticated;

-- ---------- 5. the purge: one profile, service role only (the delete-account function's scheduled run) ----------
-- Returns the storage paths to remove (report files, their U12 archive copies, the headshot) and counts only.
create or replace function public.a1_purge_profile(p_profile uuid)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_reports text[];
  v_tombstoned int := 0;
  v_pitches int := 0;
  v_notes int := 0;
  v_recharted int := 0;
  s record;
  n int;
  v_child jsonb;
  v_child_profiles int := 0;
begin
  if not exists (select 1 from public.profiles where id = p_profile) then
    return jsonb_build_object('ok', true, 'status', 'already_gone');
  end if;
  if exists (select 1 from public.teams where coach_id = p_profile) then
    return jsonb_build_object('error', 'still_head');
  end if;
  -- a parent's managed players first: deleting the parent's profile would otherwise CASCADE them (and their
  -- sessions) without tombstones
  for s in select id from public.profiles where managed_by = p_profile and id <> p_profile loop
    v_child := public.a1_purge_profile(s.id);
    if v_child ? 'error' then return v_child; end if;
    v_child_profiles := v_child_profiles + 1 + coalesce((v_child->>'profiles')::int, 0);
    v_tombstoned := v_tombstoned + coalesce((v_child->>'tombstoned')::int, 0);
    v_pitches := v_pitches + coalesce((v_child->>'pitches')::int, 0);
    v_notes := v_notes + coalesce((v_child->>'notes')::int, 0);
    v_reports := coalesce(v_reports, '{}') || coalesce(array(select jsonb_array_elements_text(v_child->'reports')), '{}');
  end loop;
  -- the report files of every session this profile pitched (tombstoned or not)
  v_reports := coalesce(v_reports, '{}') || coalesce((select array_agg(report_path) filter (where report_path is not null)
                                                        from public.sessions where pitcher_id = p_profile), '{}');
  -- his own sessions -> tombstones (a record only)
  for s in select id, deleted_at from public.sessions where pitcher_id = p_profile loop
    if s.deleted_at is null then
      select count(*) into n from public.pitches where session_id = s.id;
      v_pitches := v_pitches + n;
      update public.sessions set deleted_at = now(), deleted_by = null, deleted_by_role = 'deleted_account',
             deleted_by_name = null, pitch_count = n
       where id = s.id;
      v_tombstoned := v_tombstoned + 1;
    else
      update public.sessions set deleted_by = null, deleted_by_role = 'deleted_account', deleted_by_name = null
       where id = s.id;
    end if;
    delete from public.game_events where session_id = s.id;
    delete from public.pitches where session_id = s.id;
    delete from public.session_notes where session_id = s.id;
    delete from public.session_opened where session_id = s.id;
  end loop;
  update public.sessions set pitcher_id = null, report_path = null, report_generated_at = null
   where pitcher_id = p_profile;
  -- sessions he charted for other pitchers stay theirs; he becomes a former coach
  update public.sessions set logged_by = null where logged_by = p_profile;
  get diagnostics v_recharted = row_count;
  -- a tombstone he wrote (deleting someone's session as head) loses his name
  update public.sessions set deleted_by = null, deleted_by_role = 'deleted_account', deleted_by_name = null
   where deleted_by = p_profile;
  -- notes he wrote are deleted
  delete from public.session_notes where author_id = p_profile;
  get diagnostics v_notes = row_count;
  delete from public.invites where invited_by = p_profile;
  update public.team_coaches set invited_by = null where invited_by = p_profile;
  -- memberships first: removing a pitcher_teams row makes G3's trigger log a departure that references this profile,
  -- which would then block the profile delete (the CLAUDE.md "deleting a team with a rostered pitcher" landmine)
  delete from public.pitcher_teams where pitcher_id = p_profile;
  delete from public.pitcher_team_departures where pitcher_id = p_profile;
  -- the profile itself; staff rows, red-dot state, accuracy zones and managed players cascade
  delete from public.profiles where id = p_profile;
  return jsonb_build_object('ok', true, 'reports', to_jsonb(coalesce(v_reports, '{}')), 'tombstoned', v_tombstoned,
                            'pitches', v_pitches, 'notes', v_notes, 'recharted', v_recharted, 'profiles', v_child_profiles);
end;
$$;
revoke all on function public.a1_purge_profile(uuid) from public, anon, authenticated;
grant execute on function public.a1_purge_profile(uuid) to service_role;

-- The due work, oldest first: whole logins (primary profiles) and managed players. Service role only.
create or replace function public.a1_due_deletions()
returns table (profile_id uuid, account_id uuid, is_player boolean, due_at timestamptz)
language sql
stable
security definer
set search_path to ''
as $$
  select p.id, p.account_id, p.managed_by is not null, p.deletion_due_at
    from public.profiles p
   where p.deletion_due_at is not null and p.deletion_due_at <= now()
     and (p.id = p.account_id or p.managed_by is not null)
   order by p.deletion_due_at;
$$;
revoke all on function public.a1_due_deletions() from public, anon, authenticated;
grant execute on function public.a1_due_deletions() to service_role;

-- ---------- 6. the audit log: counts only, no names, emails or ids of the deleted person ----------
create table if not exists public.account_deletion_log (
  id          bigint generated always as identity primary key,
  ran_at      timestamptz not null default now(),
  kind        text not null check (kind in ('login', 'player', 'export')),
  profiles    int not null default 0,
  tombstoned  int not null default 0,
  pitches     int not null default 0,
  notes       int not null default 0,
  files       int not null default 0
);
alter table public.account_deletion_log enable row level security;   -- no policy: clients can't read or write it
revoke all on public.account_deletion_log from anon, authenticated;
grant select, insert on public.account_deletion_log to service_role;

-- ---------- 7. sending limits (H1 Part 2) ----------
insert into public.rate_limit_config (key, max_count, window_seconds, note) values
  ('account_deletion_day', 5, 86400, 'A1: account-deletion emails per user per day'),
  ('account_export_day',   3, 86400, 'A1: data exports per user per day')
on conflict (key) do nothing;
