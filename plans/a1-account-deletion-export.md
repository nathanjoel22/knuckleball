# A1 — Delete my account, and take my data with me (Oct 14, 2026)

**Joel, Oct 14, 2026.** Any account holder can **export everything Knuckleball holds about them** and **delete their account from inside the app**, without emailing anyone. This is the first step toward the App Store wrapper (Apple requires in-app account deletion for any app with account creation) and it makes the privacy page's deletion sentence true in the database, the same way H1 did for the other promises.

## The rules

1. **Export** is a download, from Profile, for the signed-in login: a ZIP with `profile.json` (every profile on the login: name, sport, role, teams, contacts, attestation/consent records), `sessions.csv` (one row per session the person owns or, for a coach, charted), `pitches.csv` (one row per pitch, every stored column, catcher-frame coordinates as stored), `game_events.csv`, `notes.csv` (notes they wrote), `reports.txt` (the links to their frozen reports), and `README.txt` explaining the columns. Built server-side by a new Edge Function, returned to the browser as a file; nothing is emailed. Coaches get their teams' sessions too, because they charted them.
2. **Delete** is two screens from Profile: an explanation of exactly what goes and what stays, then a confirmation that requires typing **DELETE**. On confirm: the login is signed out everywhere and marked for deletion; a confirmation email goes to the login's address (through the existing function and H1's limits). **Seven days later** a scheduled function deletes for good. Signing in during the seven days shows one screen: "Your account is scheduled for deletion on <date>" with **Restore my account** / **Keep it scheduled**. *(Drafting decision: seven days, not thirty. The privacy page says data is removed within 30 days; seven is inside that. Precondition 6 checks the exact wording.)*
3. **What deletion removes:** the auth login; every profile on it (S4: one login, many profiles) including parent-created players (S4 B); their memberships; guardian/consent records; report contacts; the person's own sessions and everything under them, **through `delete_session()`** so each leaves the P1-15 tombstone (date, pitch count, "deleted account" instead of a name) for the recording team; the frozen report files for those sessions (as P1-15 already does); red-dot and read-state rows; outbox or draft rows server-side if any.
4. **What deletion keeps:** sessions a **coach** charted for pitchers are the pitchers' (D3: sessions belong to the pitcher), so they stay, with `charted_by` pointing at a tombstoned account ("a former coach"); notes the person wrote stay with the author shown as "Former coach" / "Former player"; teams the person belonged to; audit rows H1 writes; and whatever sits in database backups until those rotate (the privacy page already says so; Jordan's backup retention is the number to quote).
5. **A head coach can't delete while still the head of a team.** The explanation screen lists those teams and offers the R6 handoff or P1-09 archive/delete per team; deletion proceeds once none remain. Assistants are just removed.
6. **A minor's account** (13–17, P1-10) deletes the same way; the guardian gets the confirmation email too. Parent-created players are deleted by the parent from the player's profile (same two screens, no email to the child).
7. **Both sports**, one flow, themed by `tokens.css`.

## Screens (D2 look, U13 controls)

- **Profile → "Your data"** card (white, 1px line, 12px, no shadow): a short line, then two buttons: **Download my data** (secondary) and **Delete my account** (the one danger class; `--surface` fill, `--danger` text). Nothing gold here; the page's primary action stays Save.
- **Delete, screen 1:** Big Shoulders 800 title ("DELETE YOUR ACCOUNT"), Archivo body: the keep/remove lists from rules 3–4 as two plain lists, the seven-day note, the head-coach block if it applies (with per-team handoff/archive links in `--brand-mid`). Buttons: **Continue** (danger) / **Back** (secondary).
- **Delete, screen 2:** a 44px input ("Type DELETE to confirm"), the danger button disabled until it matches, then **Delete my account** (danger, solid `--danger-bg` with white text is allowed here as the one destructive confirm). No gold on either screen.
- **Scheduled-deletion interstitial at sign-in:** the sign-in page's dark angled header with the slanted tag "ACCOUNT SCHEDULED FOR DELETION", the date in Big Shoulders, **Restore my account** (primary, gold) / **Keep it scheduled** (tertiary).
- **Email:** the existing report-email template family; subject "Your Knuckleball account will be deleted on <date>"; one link back to sign in. Plain, no gold text.
- No new control types; trays only where there's a choice (there isn't one here).

## Decisions made in drafting (Joel may override)

1. Seven-day grace, restore by signing in. (Apple is satisfied by in-app initiation plus a stated completion date.)
2. Export is self-serve and immediate, not emailed, so it never touches Resend quotas or the H1 limits.
3. Coach-charted sessions survive a coach's deletion (they're the pitcher's data). A pitcher's deletion removes his sessions everywhere, tombstones included, because he is the data subject.
4. Export includes the frozen report **links**, not the files, to keep the ZIP small; the links keep working until deletion.

---

## The packet (paste for Claude Code)

```
ID:              A1
Title:           Account deletion (in-app, 7-day grace) and full data export
Spec:            plans/a1-account-deletion-export.md on GitHub (pull first; work
                 only from GitHub). Screens follow docs/design/target/DESIGN.md
                 and U13; no new control types; danger class for destructive
                 actions; gold only on the restore screen's primary.
Depends on:      S4 A+B (profiles), P1-10 (guardian records), P1-15 (delete_session
                 + tombstones), H1 (email limits, audit), R6 (head handoff), P1-09
                 (archive/delete team), D2 (tokens.css). All shipped.
Staging only.    One migration + two Edge Functions (export-account,
                 delete-account; the scheduled hard delete may be a cron'd call of
                 the second). Service-role key only in function env. Fresh
                 production backup before the migration. Only Joel ships to
                 production.

PRECONDITIONS — REPORT, with file and line numbers, before any code:
  1. Every table with a row tied to a login or profile (profiles, pitcher_teams,
     team_coaches, sessions, pitches, game_events, session_notes, report
     contacts, guardian/consent, dots/read-state, invites, departures, audit,
     anything else): the column that ties it and the FK's ON DELETE behavior.
  2. delete_session(): exact signature, who may call it, what it leaves
     (tombstone columns) and removes (Storage report file).
  3. S4's login→profiles mapping and S4 B's parent→player ownership; P1-10's
     guardian rows; how a minor's guardian email is stored.
  4. R6: how a head is detected and handed off; P1-09 archive/delete entry
     points; which to link from the block screen.
  5. send-session-report's email path and H1's limits; whether a one-off
     account email can reuse the Resend call and the per-user limit.
  6. The privacy page's exact deletion and backup sentences (and Jordan's
     backup retention), so the screens and the policy agree; version bump
     needed? (Joel approves any wording change; CLAUDE.md rule.)
  7. Supabase Auth: deleting a user via admin API from an Edge Function
     (service role in env only); effect on active sessions/refresh tokens;
     whether sign-out-everywhere exists today.
  8. Export: row counts for the largest account on production (ZIP size
     estimate); whether a function can stream a ZIP or must build in memory.
  9. Apple guideline 5.1.1(v) text, quoted, so the flow is checked against it.
  Build nothing until Joel has read the report.

MIGRATION a1_account_deletion:
  - profiles/login: deletion_requested_at timestamptz NULL, deletion_due_at
    (requested + 7 days). RLS: only the owner reads; only the functions write.
  - Tombstone text: delete_session() writes "deleted account" when the actor
    row is gone; session_notes/charted_by display falls back to "Former
    coach"/"Former player" via the existing display function (no PII kept).
  - A SECURITY DEFINER request_account_deletion() / cancel_account_deletion()
    pair callable by the owner; the hard delete runs only in the function.
  - Policy count reported before/after; RLS matrix (owner, other user,
    coach of the person's team, anon) on the new columns.

FUNCTIONS:
  - export-account: auth required; builds the ZIP per spec rule 1 for the
    caller's login (all profiles; coaches include sessions they charted);
    returns application/zip; logs one audit row; rate-limited (H1 table,
    e.g. 3/day).
  - delete-account: (a) request: validates typed confirmation server-side,
    refuses if still head of any non-archived team (returns the list), marks
    deletion, signs out everywhere, sends the confirmation email (guardian
    too for minors); (b) cancel: clears the mark; (c) execute (scheduled,
    service role): for every login past deletion_due_at, delete_session() each
    owned session, remove rows per precondition 1, delete the auth user;
    idempotent; one audit row per account with counts, no PII.
  - Scheduling: pg_cron or an external daily trigger — report which the
    project supports; Joel sets it up in the dashboard if needed.

CLIENT:
  - Profile → "Your data" card; the two delete screens; the sign-in
    interstitial; parent-created player deletion from the player's profile.
  - Offline: the card shows but both actions require being online (clear
    message); nothing queues in the outbox.
  - Privacy page: wording per precondition 6, with Joel's approval in the
    commit message; CLAUDE.md updated; CACHE_VERSION bumped.

OUT OF SCOPE: deleting a team (P1-09); changing email (U7); data portability
  to other apps' formats; deleting individual sessions (P1-15); admin-side
  deletion tooling; GDPR/CCPA request intake outside the app.

ACCEPTANCE (both sports; SQL and screenshots shown):
  1. Export on staging for a pitcher on two teams and for a head coach: the
     ZIP opens; sessions.csv row count = SQL; pitches.csv columns = the
     pitches table; reports.txt links open; README describes every column.
  2. Delete, pitcher: after confirm, signed out on a second device within a
     minute; email received (and the guardian's for a minor); sign-in shows
     the interstitial with the right date; Restore clears it and the account
     works; Keep leaves it. After the scheduled run: auth user gone; every
     table from precondition 1 has zero rows for the login; each owned session
     left a tombstone readable by the recording team showing "deleted
     account"; report files gone from Storage; a report link 404s.
  3. Delete, coach: refused while head of a team, with the team listed and
     working handoff/archive links; after handoff, succeeds; sessions he
     charted still open for the pitcher and his coaches with "Former coach".
  4. Parent deletes a created player: the player's profile and sessions go;
     the parent's login stays.
  5. Mistyped confirmation is refused server-side (direct call), not only in
     the UI; a second request during the grace is a no-op; a stranger can't
     request deletion for another login (direct call refused).
  6. RLS matrix before/after; policy count; audit rows contain counts only.
  7. Screens match DESIGN.md: danger class, no gold text, 44px targets, Big
     Shoulders titles, flat cards; before/after screenshots at 390/iPad/
     laptop, both sports.
  8. Offline: card visible, actions refused with a message; P1-01 checks pass.
  9. Privacy wording approved and live; CLAUDE.md updated.
VERIFICATION: Joel deletes a throwaway staging account end to end on his
  phone, restores one, and lets one run to the hard delete.
ROLLBACK: git revert; down migration drops the two columns and functions;
  remove the schedule. Executed hard deletes are not reversible — staging
  only until Joel ships.
SIZE: L.
ESCALATE IF: a table ties to a person without an FK the function can follow;
  delete_session() can't be called for another actor's session from the
  function; the auth admin delete can't run from the Edge Function env; the
  ZIP for the largest account exceeds what the function can return; the
  privacy page's promise can't be met as written.
```

### Standing constraints (in force)

Service-role key only in Edge Function env vars. Every schema/RLS change via migration, staging first, fresh backup before production; show SQL first; RLS matrix before and after. Saved sessions immutable; deletion only through `delete_session()` with a tombstone. Emails only through the functions and H1's limits. Strict escaping. Privacy-page wording changes need Joel's approval in the commit. Screens built from `tokens.css` and the U13 set. GitHub is the source of truth. **Only Joel ships to production.**
