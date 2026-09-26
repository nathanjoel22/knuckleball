-- G1b -- Ball in play: field view, runner tracking, plays and runner events.
--
-- Precondition report (Sept 27 2026) confirmed: pitch ids are client-generated
-- UUIDs (genUUID() at creation, bullpen-tracker.html), and syncOutbox() already
-- upserts pitches with onConflict:'id' before this migration existed -- so
-- game_events.after_pitch_id can be a real FK (pitches sync before events in
-- the same outbox item, per Joel's decision, so the referenced row always
-- exists by the time an event referencing it is inserted).
--
-- game_events RLS is the pitches policies verbatim, re-keyed on
-- game_events.session_id -- same helpers, same shape, no new access pattern.
--
-- delete_session() (P1-15) is redefined in this same migration to also
-- delete game_events for the session -- Joel caught that this isn't just a
-- missing line: after_pitch_id being a real FK means skipping it wouldn't
-- fail the pitches delete (the FK is ON DELETE SET NULL, not RESTRICT), but
-- it would leave every event for a deleted game as a permanently orphaned
-- row. Fixed here since this migration is what creates the problem. Not
-- done here: compute_game_summary's read of the new columns (Joel: after
-- G1b's client work is done, as its own change).
--
-- ---------------------------------------------------------------------------------
-- ROLLBACK (no auto-down; write a new migration with this body if you need
-- to revert):
--
--   -- Restore delete_session() to the P1-15 body (no game_events
--   -- reference) BEFORE or after dropping game_events -- order doesn't
--   -- matter, CREATE OR REPLACE doesn't care whether that table exists:
--   create or replace function public.delete_session(p_session_id uuid)
--   returns jsonb language plpgsql security definer set search_path = ''
--   as $$
--   declare
--     v_uid uuid := auth.uid(); v_pitcher uuid; v_team uuid; v_role text;
--     v_count integer; v_name text; v_report text;
--   begin
--     if v_uid is null then return jsonb_build_object('error', 'not authenticated'); end if;
--     select pitcher_id, team_id, report_path into v_pitcher, v_team, v_report
--       from public.sessions where id = p_session_id and deleted_at is null;
--     if not found then return jsonb_build_object('error', 'session not found or already deleted'); end if;
--     if v_pitcher = v_uid then v_role := 'pitcher';
--     elsif public.is_team_head(v_team) then v_role := 'coach';
--     else return jsonb_build_object('error', 'not entitled to delete this session'); end if;
--     select full_name into v_name from public.profiles where id = v_uid;
--     select count(*) into v_count from public.pitches where session_id = p_session_id;
--     update public.sessions set deleted_at = now(), deleted_by = v_uid,
--       deleted_by_role = v_role, deleted_by_name = v_name, pitch_count = v_count
--       where id = p_session_id;
--     delete from public.pitches where session_id = p_session_id;
--     return jsonb_build_object('ok', true, 'report_path', v_report);
--   end;
--   $$;
--
--   drop table if exists public.game_events;
--
--   alter table public.pitches
--     drop constraint if exists pitches_g1b_fields_check,
--     drop constraint if exists pitches_runner_advances_is_array,
--     drop column if exists bb_type,
--     drop column if exists bb_x,
--     drop column if exists bb_y,
--     drop column if exists fielders,
--     drop column if exists runners_before,
--     drop column if exists batter_to,
--     drop column if exists runner_advances,
--     drop column if exists outs_on_play,
--     drop column if exists runs_scored,
--     drop column if exists sacrifice;
--
--   alter table public.pitches
--     drop constraint if exists pitches_in_play_outcome_check,
--     add constraint pitches_in_play_outcome_check
--       check (in_play_outcome = any (array['hit','out','error','reached']));
--     -- Note: any row already carrying 'fc' violates the restored
--     -- constraint. Decide per row before adding it back.
-- ---------------------------------------------------------------------------------


-- ============================================================================
-- pitches: the field-flow columns. All nullable; all NULL for a bullpen
-- pitch (CHECK below); all still nullable for a game pitch too -- most are
-- meaningful only for an in-play (or derived-sacrifice) result, and
-- runners_before is meaningful for every game pitch but this migration
-- doesn't attempt to enforce "which fields for which result" at the DB
-- level, matching how hit_type/fielder already work (no such constraint
-- exists for those either -- it's an application-level concern).
-- ============================================================================

alter table public.pitches
  add column bb_type          text,
  add column bb_x             numeric(5,4),
  add column bb_y             numeric(5,4),
  add column fielders         text,
  add column runners_before   smallint,
  add column batter_to        smallint,
  add column runner_advances  jsonb,
  add column outs_on_play     smallint,
  add column runs_scored      smallint,
  add column sacrifice        text;

comment on column public.pitches.bb_type is
  'Batted-ball type for an in-play result: ground/line/fly/pop/bunt. NULL for every non-in-play pitch and every bullpen pitch.';
comment on column public.pitches.bb_x is
  'Normalized batted-ball location, x axis. Home plate origin: bb_x=0.5 is the center line, 0/1 are the field diagram''s left/right edges (docs/field-diagram.svg). May be outside [0,1] if ever tapped past the diagram''s own bounds -- not clamped, not invented.';
comment on column public.pitches.bb_y is
  'Normalized batted-ball location, y axis. 0 = home plate, 1 = the center-field fence (docs/field-diagram.svg''s own coordinate convention, documented in that file). Can exceed 1 -- a home run lands past the fence, and this is a real recorded location, not an error.';
comment on column public.pitches.fielders is
  'Optional fielder SEQUENCE for a play with more than one touch, e.g. "6-4-3" -- distinct from the existing, unchanged `fielder` column (the single first fielder, required for an out/error, G1). NULL when only one fielder is relevant or none was recorded.';
comment on column public.pitches.runners_before is
  'Bitmask of occupied bases immediately before this pitch: 1st=1, 2nd=2, 3rd=4 (0-7). Written on EVERY game pitch from this migration forward, not only in-play ones -- makes every pitch row self-contained the same way outs_before/balls_before/strikes_before already are, and is what Undo restores from.';
comment on column public.pitches.batter_to is
  'Where the BATTER ended on this play: 0 = out, 1/2/3 = that base, 4 = scored. NULL for anything that isn''t an in-play result.';
comment on column public.pitches.runner_advances is
  'Array of {"from": <1|2|3>, "to": <0|1|2|3|4>} for every RUNNER (not the batter -- see batter_to) who moved on this play. 0 = out, 4 = scored. NULL when there were no runners on base to move.';
comment on column public.pitches.outs_on_play is
  'Total outs recorded on this single play (0-3) -- comes from where the runners (and batter) ended, per decision 8, never from a separate counter. A double play is 2 here, something the old single-result-implies-one-out model could never represent.';
comment on column public.pitches.runs_scored is
  'Runs that scored on this single play (0-4) -- a runner or the batter tapped to Home. Earned/unearned is out of scope; this is just runs allowed.';
comment on column public.pitches.sacrifice is
  'SF or SAC, DERIVED after the fact from the play (fly + batter out + a run scored = SF; bunt + batter out + a runner advanced = SAC) -- never tapped directly. NULL for everything else, including a play that happens to look like one but doesn''t meet the definition. The pre-G1b path of tapping "Sac bunt"/"Sac fly" as a RESULT directly is retired (see pitches_result_check, unchanged, which still allows those two result values only because existing rows already carry them).';

alter table public.pitches
  add constraint pitches_bb_type_check
    check (bb_type is null or bb_type in ('ground','line','fly','pop','bunt'));
alter table public.pitches
  add constraint pitches_runners_before_check
    check (runners_before is null or runners_before between 0 and 7);
alter table public.pitches
  add constraint pitches_batter_to_check
    check (batter_to is null or batter_to between 0 and 4);
alter table public.pitches
  add constraint pitches_outs_on_play_check
    check (outs_on_play is null or outs_on_play between 0 and 3);
alter table public.pitches
  add constraint pitches_runs_scored_check
    check (runs_scored is null or runs_scored between 0 and 4);
alter table public.pitches
  add constraint pitches_sacrifice_check
    check (sacrifice is null or sacrifice in ('SF','SAC'));
-- Defense-in-depth, not a full schema for the array's contents (a client
-- bug that sends the wrong-shaped objects inside the array still gets
-- through -- jsonb doesn't have per-key CHECKs) -- but a client bug that
-- sends a bare object or a string instead of an array is caught here
-- rather than silently stored and misread by whatever reads it later.
alter table public.pitches
  add constraint pitches_runner_advances_is_array
    check (runner_advances is null or jsonb_typeof(runner_advances) = 'array');

alter table public.pitches
  add constraint pitches_g1b_fields_check check (
    (kind = 'bullpen'
      and bb_type is null and bb_x is null and bb_y is null and fielders is null
      and runners_before is null and batter_to is null and runner_advances is null
      and outs_on_play is null and runs_scored is null and sacrifice is null)
    or (kind = 'game')
  );


-- ============================================================================
-- in_play_outcome: widen again to add 'fc' (fielder's choice) -- G2's
-- migration (20260927000000) already added 'reached' for the Dropped 3rd
-- drill-down; this is the second, separate widening the two of them agreed
-- would happen here rather than being bundled into G2's.
-- ============================================================================

alter table public.pitches
  drop constraint pitches_in_play_outcome_check,
  add constraint pitches_in_play_outcome_check
    check (in_play_outcome = any (array['hit','out','error','fc','reached']));


-- ============================================================================
-- game_events: runner corrections that don't come from a pitch (stolen
-- base, caught stealing, pickoff, wild pitch, passed ball, balk, other).
-- after_pitch_id is a real FK (see this file's header) -- nullable, since an
-- event can happen with no specific pitch to anchor to (e.g. a pickoff
-- between pitches). ON DELETE CASCADE on session_id mirrors pitches'
-- own FK (belt-and-suspenders -- sessions are never hard-deleted; the real
-- cleanup path is delete_session(), which does not yet know about this
-- table -- see this file's header note).
-- ============================================================================

create table public.game_events (
  id               uuid primary key default gen_random_uuid(),
  session_id       uuid not null references public.sessions(id) on delete cascade,
  at_bat_index     smallint,
  after_pitch_id   uuid references public.pitches(id) on delete set null,
  event_type       text not null check (event_type in
                     ('stolen_base','caught_stealing','pickoff','wild_pitch','passed_ball','balk','other')),
  runners_before   smallint check (runners_before between 0 and 7),
  runner_advances  jsonb check (runner_advances is null or jsonb_typeof(runner_advances) = 'array'),
  outs_on_play     smallint check (outs_on_play between 0 and 3),
  runs_scored      smallint check (runs_scored between 0 and 4),
  created_at       timestamptz not null default now()
);

comment on table public.game_events is
  'Runner corrections with no pitch of their own (G1b decision 2): the only way to record a caught-stealing/pickoff out, a stolen base, a wild pitch, a passed ball, or a balk. A correction tool, not a scorebook -- see the packet''s own framing.';
comment on column public.game_events.after_pitch_id is
  'The pitch this event happened after, if any (nullable -- some events, like a mid-count pickoff, have no anchor pitch to point at). Client-generated pitch UUIDs mean this FK is always satisfiable as long as pitches sync before events in the same outbox item (syncOutbox()''s own ordering, not enforced by this FK alone).';

alter table public.game_events enable row level security;

-- Verbatim copies of pitches' three policies (dumped fresh immediately
-- before writing this, not from memory -- see the precondition report),
-- re-keyed on game_events.session_id. Same helpers (is_team_coach), same
-- shape, no new access pattern introduced.
create policy "Coaches manage events for their team's sessions" on public.game_events
  for all using (
    exists (select 1 from public.sessions s where s.id = game_events.session_id and public.is_team_coach(s.team_id))
  ) with check (
    exists (select 1 from public.sessions s where s.id = game_events.session_id and public.is_team_coach(s.team_id))
  );

create policy "Pitchers manage events in own sessions" on public.game_events
  for all using (
    exists (select 1 from public.sessions s where s.id = game_events.session_id and s.pitcher_id = auth.uid())
  ) with check (
    exists (select 1 from public.sessions s where s.id = game_events.session_id and s.pitcher_id = auth.uid())
  );

create policy "Coaches view events for their team's sessions" on public.game_events
  for select using (
    exists (select 1 from public.sessions s where s.id = game_events.session_id and public.is_team_coach(s.team_id))
  );


-- ============================================================================
-- delete_session(): the FK above being ON DELETE SET NULL already means
-- deleting a game's pitches would NOT fail against a game_events row that
-- references one (SET NULL, not the default RESTRICT) -- but without this
-- change, those event rows would survive forever with a nulled reference,
-- silently contradicting P1-15's own "the pitches... are gone" promise for
-- a sibling table it was written before this migration ever existed.
-- Same function as 20260925050000 (P1-15's fix-forward), with exactly one
-- addition: delete game_events for the session before deleting its
-- pitches. Order is for clarity, not correctness (SET NULL means either
-- order succeeds) -- events first reads as "delete the things that point
-- at pitches, then the pitches," matching the FK direction.
-- Event count is returned in the jsonb result (trivial -- one more SELECT,
-- one more key) but NOT persisted as a new sessions column: that would need
-- its own migration work (a column, a CHECK, UI to show it) beyond what
-- this fix is for.
-- ============================================================================

create or replace function public.delete_session(p_session_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid         uuid := auth.uid();
  v_pitcher     uuid;
  v_team        uuid;
  v_role        text;
  v_count       integer;
  v_event_count integer;
  v_name        text;
  v_report      text;
begin
  if v_uid is null then
    return jsonb_build_object('error', 'not authenticated');
  end if;

  select pitcher_id, team_id, report_path into v_pitcher, v_team, v_report
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

  select full_name into v_name from public.profiles where id = v_uid;

  select count(*) into v_count from public.pitches where session_id = p_session_id;
  select count(*) into v_event_count from public.game_events where session_id = p_session_id;

  update public.sessions
     set deleted_at      = now(),
         deleted_by      = v_uid,
         deleted_by_role = v_role,
         deleted_by_name = v_name,
         pitch_count     = v_count
   where id = p_session_id;

  delete from public.game_events where session_id = p_session_id;
  delete from public.pitches where session_id = p_session_id;

  return jsonb_build_object('ok', true, 'report_path', v_report, 'event_count', v_event_count);
end;
$$;

-- Grants unchanged (already authenticated-only, revoked from public/anon
-- since the original migration; create or replace doesn't reset a
-- function's ACL).
