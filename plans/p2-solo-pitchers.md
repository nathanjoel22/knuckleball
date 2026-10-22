# P2-01 + P2-02 — Solo pitchers: no team required (Oct 22, 2026)

**Joel, Oct 22, 2026.** An adult pitcher with no coach and no team signs up, charts bullpens (and games, if he wants), sees his History and Profile, and gets his reports — nobody else involved. This is the Phase 2 gate ("an adult pitcher can sign up alone and use the product end-to-end") and the thing the May 2027 individual-revenue window depends on. Both sports.

Two packets in the library (P2-01 the migration, P2-02 the experience) ship here as one, in two stages on one branch.

## The rules

1. **A session may have no team.** `sessions.team_id` becomes nullable. A pen with no team is **independent**. Every other column and rule is unchanged: sessions still belong to the pitcher (D3), saved sessions are still sealed (H1), pitches store the same things.
2. **Filing.** When a pitcher on one or more teams starts a session, he picks **which team it's for, or Independent** (Track R's filing rule, finally built). A pitcher on no team gets no question: every session is independent. **Coach-charted sessions file under the coach's team, as today.** The G3 check (`sessions_g3_team_check`) allows NULL and keeps refusing a team the pitcher isn't on.
3. **Who sees an independent session.** The pitcher, always. **Under R4, coaches of every non-archived team the pitcher is currently on can read it** (full detail, read-only, with an "Independent" chip), the same as they read his sessions for other teams. Nobody but the pitcher can add notes, generate or send its report, or delete it. A pitcher on no team: nobody else sees anything. *(Drafting decision: R4 says a coach should see all of his pitcher's work to mind the workload; an independent pen is work. Say so if independent pens should be private to the pitcher.)*
4. **Signup with no invite.** The sign-in page's Pitcher signup works with no team: it creates the login, the sport profile (S4), the P1-10 age attestation, and lands the pitcher on New Session with the setup modal (U9). No "join a team" wall. The invite-link path is unchanged, and a solo pitcher who later opens a team's invite link joins with his history intact (D3; R4 then shows that team's coaches everything, which is the R4 rule as built — R1's join-date gating is a later packet).
5. **Reports.** `is_pitcher_report_eligible` drops the current-team-membership half (Amendment 11 called it a deliberate temporary restriction until this packet). It becomes: **verified email AND (adult OR guardian-approved)**. Report contacts are already the pitcher's own (H1/Profile); nothing changes there. A pitcher on no team can generate and send his own reports; the caller-verified rule still applies.
6. **Empty states, no team.** The sidebar's team picker shows "Independent" and nothing else; Leaders tab hidden (leaderboards are per team); roster-related chrome hidden; History shows his sessions with the "Independent" chip; Profile shows no uniform number section (numbers are per team). Workload line (R4) still counts independent sessions.
7. **Games with no team:** allowed; the opponent field is free text as today; `teams.level` doesn't exist for an independent game, so the extra-inning tiebreak question uses a per-session choice (College / High school / Little League) asked at game start for independent games only. *(Drafting decision; strike it and default to College if you'd rather.)*
8. **Leaderboards unchanged:** independent sessions never feed a team leaderboard (they have no team).

## Screens (D2 look, U13 controls)

- **Filing tray** at session start, for pitchers on ≥1 team: a Segmented tray of team names + "Independent"; default = the team used last time; locked after the first pitch (same rule as U14's RA question). Pitchers on no team don't see it.
- **"Independent" chip** on session rows (History, coach roster views) using the badge style.
- **Pitcher signup** (sign-in page, both sports): already exists for the invite path; the no-invite path is the same form minus the team, with a line "You can join a team later with a coach's link."
- **New Session with no team:** same screen, no team picker, no Leaders tab.

## Decisions made in drafting (Joel may override)

1. Independent sessions are readable by the pitcher's current coaches (R4), not private.
2. Filing default = last used; locked after pitch 1.
3. Independent games ask the level at start (rule 7).
4. No pitcher-created teams, no coach discovery, no payments — all out of scope, as the library packets said.

---

## The packet (paste for Claude Code)

```
ID:              P2-01 + P2-02
Title:           Solo pitchers — team-optional sessions (migration) and the
                 no-team signup and experience; filing a session to a team or
                 Independent
Spec:            plans/p2-solo-pitchers.md on GitHub (pull first; work only from
                 GitHub). Screens per docs/design/target/DESIGN.md; trays and
                 badges from the U13 set.
Depends on:      D3 (pitcher-owned sessions), R0 (join links), P1-10 (attestation),
                 S4 (profiles), H1 (sealed sessions, report contacts), G3
                 (sessions_g3_team_check), R4 (cross-team reads), U9 (setup
                 modal), U14 (start-screen question pattern). All shipped.
Staging only.    One migration (Stage 1) + policy edits; fresh production backup
                 first; RLS matrix before/after; show SQL first. Only Joel ships
                 to production.

PRECONDITIONS — REPORT, with file and line numbers, before any code:
  1. Every place that assumes sessions.team_id is set: policies (list each
     with its predicate), sessions_g3_team_check, sync_session, delete_session,
     is_current_coach_of_pitcher / is_team_coach helpers, pitcher_workload,
     get_team_leaderboard, send-session-report (ownership + eligibility),
     History/roster queries, the team picker and draft key in
     bullpen-tracker.html, the report templates (team name on the report).
  2. is_pitcher_report_eligible today (exact predicate) and every caller.
  3. The pitcher signup path on signin.html: what it requires today (invite
     token?), what ensure_account_setup() does with no team, and what the app
     shows a pitcher with zero teams right now (screenshots).
  4. The sidebar/team picker and Leaders tab: how they behave with one team,
     many teams, zero teams.
  5. The extra-inning tiebreak: where teams.level is read for games.
  6. Counts on production: pitchers with zero teams (if any exist), sessions
     by team count; policy count (expected 29 before).
  7. RLS matrix BEFORE: pitcher, head coach, assistant, other-team coach,
     archived-team coach, stranger, anon × sessions/pitches/game_events/
     session_notes, including a (hypothetical) NULL-team row.
  Build nothing until Joel has read the report.

STAGE 1 — migration p2_01_team_optional (invisible to users):
  - sessions.team_id DROP NOT NULL. sessions_g3_team_check: NULL allowed;
    non-NULL still must be a team the pitcher is on (or left after start).
  - Coach SELECT policies: a NULL-team session is readable only via the R4
    current-coach path (is_current_coach_of_pitcher), never via team_id
    matching (NULL never matches — prove it, don't assume). Notes INSERT,
    report generate/send, delete: pitcher only for NULL-team sessions.
  - sync_session accepts team_id NULL; delete_session unchanged.
  - is_pitcher_report_eligible: drop the membership clause (spec rule 5);
    every caller re-tested.
  - Acceptance: RLS matrix AFTER vs BEFORE: the only change is that NULL-team
    sessions exist and are readable by the pitcher and his current coaches;
    nothing else gained by anyone; policy count reported; schema.sql
    regenerated; the existing app (unchanged client) passes the smoke
    checklist because it still always sends a team.

STAGE 2 — client + function:
  - Filing tray at session start (spec); stored via sync_session; locked after
    pitch 1; draft key includes the filing so a mid-session switch can't
    orphan pitches.
  - No-invite pitcher signup on signin.html, both sports; U9 modal; lands on
    New Session.
  - Zero-team experience per spec rule 6; "Independent" chip on session rows
    for the pitcher and for coaches reading via R4 (read-only controls hidden).
  - Independent games: level question at start (rule 7) feeding the tiebreak.
  - Report templates: "Independent" where the team name goes; workload line
    counts independent sessions.
  - Offline: a solo pitcher's cold launch and pen-in-airplane-mode work;
    P1-01 checks pass. CACHE_VERSION bumped.
  - CLAUDE.md: Amendment 11's "temporary restriction" line retired; Track R
    filing rule recorded as built.

OUT OF SCOPE: R1 join-date gating and summary-only views (R4's full-read rule
  stands); R2 pending roster invites; pitcher-created teams; coach discovery;
  payments and plans (P3); minors beyond what P1-10/S4 already allow.

ACCEPTANCE (both sports; SQL and screenshots shown):
  1. Fresh solo signup on staging (no invite) → attestation → setup modal →
     New Session with no team picker and no Leaders tab → chart a pen →
     save → History shows it with "Independent" → View report → Send report
     to his own contact → email arrives; no coach involved anywhere.
  2. Same pitcher opens a team's invite link → joins → prior sessions still
     his and visible to him; that team's coaches see them read-only with the
     Independent chip; the filing tray now appears at session start.
  3. A pitcher on two teams files a pen to Team A, one to Team B, one
     Independent: A's coaches get full control of the A pen only, read-only
     on the others (chips correct); B's coaches the mirror; a stranger
     nothing. Direct note insert / report request by a coach on the
     Independent pen refused.
  4. A solo pitcher's session is invisible to every coach account (SQL as each
     persona).
  5. An independent game asks the level, applies the tiebreak at the right
     inning, and reports with "Independent".
  6. Leaderboards unchanged (counts before/after for one team).
  7. RLS matrix after vs before as specified; policy count; schema.sql.
  8. Offline cold launch + pen as a solo pitcher; P1-01 checks pass.
  9. Screens match DESIGN.md / U13 at 390/iPad/laptop, both sports.
VERIFICATION: Joel signs up a throwaway solo pitcher on staging on his phone,
  charts a pen, sends himself the report, then joins his Cairn test team.
ROLLBACK: git revert; down migration restores NOT NULL (valid only while no
  NULL-team rows exist — check first) and the previous eligibility function.
SIZE: Stage 1 M · Stage 2 M.
ESCALATE IF: any coach policy can read a NULL-team session by any path other
  than R4's; the eligibility change would let an unverified or unconsented
  pitcher get a report; the draft/outbox can't carry the filing safely; the
  G3 check can't allow NULL without weakening the non-NULL rule.
```

### Standing constraints (in force)

Sessions belong to the pitcher; saved sessions sealed; no policy references `teams` and `pitcher_teams` directly (42P17); every schema/RLS change via migration, staging first, fresh backup first, RLS matrix before and after; report access requires pitcher verified AND caller verified; games never feed the leaderboard. GitHub is the source of truth. **Only Joel ships to production.**
