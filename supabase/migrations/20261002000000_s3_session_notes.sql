-- S3: coach notes on a saved session (baseball and softball).
--
-- Decisions (Joel, Oct 1 2026):
--  * Only coaches write -- a head or assistant coach of a team the pitcher is
--    CURRENTLY on, on a session thrown for that team after the pitcher
--    joined it. Any time after the session is saved (old sessions too);
--    never on a deleted (tombstoned) session. Pitchers only read.
--  * Readers: the pitcher, the note's author, and those same coaches.
--  * Immutable: no UPDATE at all. The author may delete their own note.
--  * Plain text, 1-2,000 characters.
--  * Reports (option A): the frozen report file is never touched. The report
--    page (report.html) shows the session's CURRENT notes in a "Coaches
--    notes" section, fetched through get_report_notes(token) -- anyone with
--    the report link sees them, the same trust model as the report itself.
--  * A new note re-dots that session for the PITCHER only (U10 session
--    dots): his session_opened row is removed. Coaches are never dotted by
--    a note. (Sessions saved before session_dots_since() never dot.)
--  * author_name is stored on the note because pitchers can't read coach
--    profiles under RLS (same approach as sessions.deleted_by_name).
--
-- No policy here references teams or pitcher_teams (42P17 landmine): the
-- coach check is one SECURITY DEFINER, read-only helper.
--
-- Rollback (manual):
--   drop function if exists public.get_report_notes(text);
--   drop table if exists public.session_notes;          -- drops its policies and triggers
--   drop function if exists public.session_notes_before_insert();
--   drop function if exists public.session_notes_redot();
--   drop function if exists public.is_coach_of_session(uuid);

-- Is the caller a coach (head or assistant) of this session's team, with
-- the session's pitcher currently on that team, and the session thrown on or
-- after the pitcher joined? (The same membership/join-date rule U10's
-- get_unopened_sessions uses.)
create or replace function public.is_coach_of_session(p_session_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.sessions s
      join public.team_coaches tc on tc.team_id = s.team_id and tc.coach_id = auth.uid()
      join public.pitcher_teams pt on pt.team_id = s.team_id and pt.pitcher_id = s.pitcher_id
     where s.id = p_session_id
       and s.started_at >= pt.joined_at
  );
$$;

revoke all on function public.is_coach_of_session(uuid) from public, anon;
grant execute on function public.is_coach_of_session(uuid) to authenticated;

create table public.session_notes (
  id          uuid        primary key default gen_random_uuid(),
  session_id  uuid        not null references public.sessions(id) on delete cascade,
  author_id   uuid        not null references public.profiles(id),
  author_name text        not null default '',
  body        text        not null check (char_length(body) between 1 and 2000),
  created_at  timestamptz not null default now()
);

create index session_notes_session_id_idx on public.session_notes (session_id);

comment on table public.session_notes is
  'S3: a coach''s plain-text note on a saved session. Never edited; the author may delete it. Read by the pitcher and his current coaches (RLS), and shown live on the session''s report page via get_report_notes.';

-- Before insert: the session must be saved and not deleted; author_name and
-- created_at are set here, never taken from the client.
create or replace function public.session_notes_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ended   timestamptz;
  v_deleted timestamptz;
begin
  select s.ended_at, s.deleted_at into v_ended, v_deleted
    from public.sessions s where s.id = new.session_id;
  if not found or v_ended is null then
    raise exception 'Notes can only be added to a saved session' using errcode = 'check_violation';
  end if;
  if v_deleted is not null then
    raise exception 'Notes can''t be added to a deleted session' using errcode = 'check_violation';
  end if;
  new.author_name := coalesce((select p.full_name from public.profiles p where p.id = new.author_id), '');
  new.created_at := now();
  return new;
end;
$$;

create trigger session_notes_before_insert
  before insert on public.session_notes
  for each row execute function public.session_notes_before_insert();

-- After insert: re-dot the session for its pitcher only.
create or replace function public.session_notes_redot()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.session_opened o
   using public.sessions s
   where s.id = new.session_id
     and o.session_id = new.session_id
     and o.viewer_id = s.pitcher_id;
  return null;
end;
$$;

create trigger session_notes_redot
  after insert on public.session_notes
  for each row execute function public.session_notes_redot();

revoke all on function public.session_notes_before_insert() from public, anon, authenticated;
revoke all on function public.session_notes_redot() from public, anon, authenticated;

alter table public.session_notes enable row level security;

create policy "Notes readable by author, pitcher and his coaches"
  on public.session_notes for select
  using (
    author_id = auth.uid()
    or exists (select 1 from public.sessions s where s.id = session_notes.session_id and s.pitcher_id = auth.uid())
    or public.is_coach_of_session(session_id)
  );

create policy "Coaches add notes to their pitchers' sessions"
  on public.session_notes for insert
  with check (author_id = auth.uid() and public.is_coach_of_session(session_id));

create policy "Authors delete their own notes"
  on public.session_notes for delete
  using (author_id = auth.uid());

-- Supabase grants ALL on new tables by default: take it all back, then give
-- only what the policies cover. No UPDATE, ever.
revoke all on public.session_notes from public, anon, authenticated;
grant select, insert, delete on public.session_notes to authenticated;

-- The report page's live "Coaches notes" (option A): the notes of the one
-- session whose stored report is this token. Anyone holding the report link
-- can call it -- exactly who can already read the report. Nothing for a
-- deleted session (its report is removed too) or an unknown token.
create or replace function public.get_report_notes(p_token text)
returns table (author_name text, body text, created_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select n.author_name, n.body, n.created_at
    from public.sessions s
    join public.session_notes n on n.session_id = s.id
   where p_token ~ '^[0-9a-f]{64}\.html$'
     and s.report_path = p_token
     and s.deleted_at is null
   order by n.created_at;
$$;

revoke all on function public.get_report_notes(text) from public;
grant execute on function public.get_report_notes(text) to anon, authenticated;
