# R4 — Cross-team visibility: every coach a pitcher plays for can see his work (Oct 5, 2026)

**Joel, Oct 5, 2026.** A pitcher on more than one team (high school and travel, college and summer) is one arm. Every coach of every team he is currently on should be able to **see** every session he charts, whichever team it was charted for, so they all know the work he's putting in and can mind his pitch counts. Other teams' coaches **can't respond** (notes), **edit**, delete or archive anything: the session still belongs to the pitcher and the team it was charted for.

This pulls R4 forward from Track R (Dec–Mar). It supersedes the CLAUDE.md roster decision that other-team coaches see only a one-line summary (date, pitch count, team) — that was decided and never built; Joel wants full visibility, read-only.

## The rule

- **Recording team** (the team the session was charted for, `sessions.team_id`): its coaches can do everything they can today — read, add notes, generate and send reports, delete (head coach, via the tombstone). After the pitcher leaves, they keep the sessions charted while he was theirs (G3), not later ones.
- **Other current teams:** coaches of any *other, non-archived* team the pitcher is **currently** on can read the session, its pitches and events, its notes, and open its report if one exists. They can't write notes, generate or send reports, or delete. When the pitcher leaves their team, that visibility ends immediately (they never had the recording-team claim).
- **An archived team counts as not current** for this rule. Its coaches keep the sessions charted for it (P1-09 keeps memberships) but stop seeing the pitcher's new work for other teams.
- **The pitcher** sees all of his own sessions, always.
- **Sports never mix.** A pitcher's baseball and softball profiles are separate people to the database (S4), so a softball coach can never see baseball work through this rule.

## What changes on screen

1. **Roster → History for a pitcher** shows all of his saved sessions across his current teams. Sessions charted for another team carry a small chip with that team's name ("for Diamond Elite") and open read-only: no Add note box, no Generate/Send report, no delete. View Report appears only if a report already exists.
2. **Roster workload line** (the pitch-count ask): under each pitcher's name, `Last pen · Oct 3 · 42 pitches` and `7 days · 87 · 30 days · 310`, counted across all teams he is on. Games count their pitches too, labeled. One function, `pitcher_workload(p_profile)`, feeds it; the same numbers appear at the top of his History. (Drafting addition — strike if unwanted.)
3. **Red dots (U10)** follow visibility: a coach who can now see another team's session gets a dot for it, like any other new session he can see.
4. **The pitcher's own History** shows all his sessions in one list with team chips, not one team at a time, and a filter by team if he wants it. *(Drafting decision — today the pitcher sees one team at a time, which Joel didn't expect; D3 says the sessions are his.)*

## Decisions made in drafting (Joel may override)

1. **Full detail, not a summary.** Other-team coaches see the pitch chart, velocities, results and the notes, read-only. Notes are already visible to anyone holding the report link (S3 option A), so hiding them in-app would be theater.
2. **Open an existing report, yes; generate one, no.** Generating is the recording team's and the pitcher's.
3. **Leaderboards unchanged.** Each team's board stays what it is today; precondition confirms whether it counts a roster pitcher's sessions for other teams.
4. **Privacy page:** the current sentence ("the coaches of any team the player is on") already describes this rule; add the clause "coaches of your other teams can see your sessions but only the team you charted for can add notes." Joel approves; version bump.

---

## The packet (paste for Claude Code — after P1-09 ships)

```
ID:              R4
Title:           Cross-team visibility — coaches of every team a pitcher is on
                 can read his sessions; only the recording team can act on them
Spec:            plans/r4-cross-team-visibility.md (on GitHub; pull first, work
                 only from what GitHub has). Build to it.
Depends on:      G3 (team stamp, departed-pitcher rule), S3 (notes), S4 (profiles),
                 H1 (saved sessions locked), P1-09 (archive) — all shipped.
Staging only.    Only Joel ships to production. One migration; staging first;
                 fresh production backup first. This changes READ policies: show
                 every policy and helper as SQL before applying; RLS matrix before
                 and after.

PRECONDITIONS — REPORT, with file and line numbers, before any SQL or code:
  1. The read policies on sessions, pitches, game_events, session_notes and
     the dots tables, and the helper each uses (recording-team coach check).
  2. The notes INSERT check as built in S3 ("coach of a team the pitcher is
     currently on") — confirm whether a coach of a different team could insert
     a note today by direct call; it must become recording-team only.
  3. Who may generate/send a report for a session (send-session-report's
     ownership check) and who may call delete_session() (H1 Part 3a).
  4. get_team_leaderboard: does it count a roster pitcher's sessions charted
     for other teams?
  5. The pitcher's History: how it is filtered today (one team at a time?) and
     where the team chip and filter would go on phone and iPad/laptop.
  6. The P1-13 boot snapshot and offline History: whether other-team sessions
     are cached for coaches (they should behave like any visible session).
  7. Policy count (expected: edited, not added); RLS matrix (pitcher, recording
     head coach, recording assistant, other-team coach, archived-team coach,
     departed-team coach, stranger, anon) on every table, run BEFORE changes.
  Build nothing until Joel has read the report.

MIGRATION r4_cross_team:
  - Helper is_current_coach_of_pitcher(p_pitcher uuid): true when the caller
    owns a coach profile (S4 is_my_profile) on a NON-archived team the pitcher
    is currently on. SECURITY DEFINER, read-only, search_path ''. No policy
    references teams and pitcher_teams directly (42P17).
  - sessions / pitches / game_events / session_notes SELECT: recording-team
    coach (as today) OR is_current_coach_of_pitcher(pitcher) OR the pitcher.
  - session_notes INSERT: recording-team coach only (session.team_id), not
    "any current team". DELETE: author only (unchanged).
  - delete_session(): unchanged — pitcher or recording team's head coach.
  - send-session-report ownership check: pitcher or recording-team coach for
    generate/send; opening an existing report link is unchanged (anyone with
    the link).
  - pitcher_workload(p_profile): last pen date and pitch count, pitches in the
    last 7 and 30 days across all the pitcher's teams, games included and
    separable; readable by the pitcher and any coach who can read his
    sessions. SECURITY INVOKER if the policies suffice, else DEFINER with the
    same visibility check inside.
  - Dots: no schema change if they key off session visibility; report.

CLIENT:
  - Coach roster → pitcher History: all visible sessions; other-team sessions
    carry a team chip and open read-only (no note box, no Generate/Send, no
    delete; View Report only if a report exists). Workload line on the roster
    and at the top of History.
  - Pitcher History: all his sessions with team chips; optional team filter.
  - Privacy page clause (spec decision 4) — DRAFT FOR JOEL; version bump after
    approval, recorded in the commit.
  - CLAUDE.md: replace the old roster summary-line decision with this rule.

OUT OF SCOPE: cross-team notes or reports; coaches seeing sessions of pitchers
  on teams they don't coach; pitch-count limits or alerts (a later packet can
  build on pitcher_workload); any change to the leaderboard; archive behavior
  (P1-09).

ACCEPTANCE (both sports; SQL shown):
  1. RLS matrix after vs before: the ONLY new reads are other-current-team
     coaches on sessions/pitches/events/notes; archived-team and departed-team
     coaches gain nothing; stranger and anon unchanged.
  2. Staging: pitcher on Team A and Team B charts a pen for A. B's head coach
     and assistant see it in his History with the "for Team A" chip, open the
     pitch chart and notes, and have no Add note, Generate/Send or delete; a
     direct note insert and a direct report request by B's coach are refused;
     A's coaches keep everything. Pitcher removed from B → B's coaches lose it
     at once; pitcher removed from A → A's coaches keep it (G3).
  3. Archive Team B (P1-09): B's coaches keep B's own sessions and no longer
     see the pitcher's new sessions for A.
  4. Workload line: numbers match SQL across both teams, 7/30-day windows,
     games labeled; the pitcher sees the same numbers.
  5. Dots: B's coach gets a dot for the new A session and it clears on open.
  6. Pitcher History shows sessions from both teams with chips; filter works.
  7. Offline: a coach's cached History includes visible other-team sessions;
     P1-01 checks 1–3 pass; CACHE_VERSION bumped.
  8. Privacy clause approved and live; policy count reported; schema.sql
     regenerated; CLAUDE.md updated.
VERIFICATION: Staging with Joel as a coach on two teams sharing one pitcher
  (his Cairn and Kings Christian setup is the real case). Production after a
  fresh backup.
ROLLBACK: git revert; down migration restores the previous policies and the
  notes check verbatim from schema.sql and drops the two functions.
SIZE: M.
ESCALATE IF: the visibility helper can't avoid teams + pitcher_teams in a
  policy; the RLS matrix shows any read gained by anyone other than
  other-current-team coaches; the pitcher's History can't show all teams
  without a data-model change.
```

### Standing constraints (in force)

Every schema/RLS change via migration, staging first, fresh backup before production; show SQL first and run the RLS matrix before and after. No policy references `teams` and `pitcher_teams` directly (42P17). Sessions belong to the pitcher; the recording team acts on them; everyone else reads. Saved sessions and frozen reports are immutable. Sports never mix. GitHub is the source of truth. **Only Joel ships to production.**
