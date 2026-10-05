# P1-09 — Rename, archive and delete a team (refreshed Oct 5, 2026)

**Joel, Oct 5, 2026.** The last Phase 1 item that needs Claude Code. The August library packet said "roster management UI (remove pitcher, rename/delete team)"; R0 already shipped remove-pitcher, so what's left is **rename**, and what "delete" means now that every session carries the team it was charted for (G3) and sessions belong to the pitcher (D3).

**The rule:** a team that has sessions is never destroyed. It is **archived**: it disappears from everyone's lists, its invite link stops working, nobody can chart new sessions for it, and its history stays readable. A team with **no sessions** (a test team, a mistake) can be **deleted** outright. Both are head-coach actions with a typed confirmation, the same shape as P1-15's session delete.

## What each action does

**Rename.** Head coach only, active teams only. 2–60 characters, trimmed, enforced by a CHECK. The new name shows everywhere live: header, roster, team switcher, join pages, History rows, new reports and their emails. **Reports already generated keep the old name** (frozen). Sport and level never change with a rename (S1 locks sport; level is its own setting).

**Archive.** Head coach only. Sets `teams.archived_at` and `archived_by`. Then:
- The team leaves every list: coach team switcher (moves to an **Archived** section), rosters, the leaderboard (the function returns an empty board for an archived team, like softball), the pitcher's team area, "Join as:" pickers.
- The invite links stop: `resolve_team_invite` and `resolve_coach_invite` return `team_archived` and `join.html` says "This team is no longer active." `join_team` and `join_team_as_coach` refuse.
- **No new sessions for it:** G3's session team check (`sessions_g3_team_check`) also refuses an archived team. This applies inside H1's `sync_session()` too, since the trigger fires there.
- **Memberships stay.** Coaches keep read access to the team's sessions, pitches, events and notes exactly as today; pitchers keep report eligibility for their past sessions (Amendment 11 still requires a team membership — ending memberships would grey out View Report on every old session, which is wrong). Nothing is deleted.
- **Read-only when opened.** A coach can open an archived team from the Archived section and browse rosters, History and reports; there is no New Session, no invite link, no roster editing, no rename. A banner says "Archived · read only" with **Restore** for the head coach.
- **Pitchers whose only team is archived** see a banner on New Session: "Your team *Cairn Baseball* was archived by its coach. Your History and reports are still here. To chart new sessions, join a team with an invite link." Their sessions default to another active team if they have one.
- T1 branding (later): an archived team's branding can't be changed and isn't applied.

**Restore.** Head coach only; clears `archived_at`. Everything resumes, including the same invite link.

**Delete.** Head coach only, **only when the team has zero sessions** (the function counts; the UI shows which action applies). Removes coach and pitcher memberships (departures logged for consistency), dots rows, and the team row. Refused with a clear message if any session exists — "This team has 58 sessions and can be archived, not deleted."

**Confirm step** for archive and delete: the dialog states the consequences in plain words (archive: "disappears from all lists, invite link stops working, players can't chart new sessions for it, history stays, you can restore it"; delete: "permanent, no sessions exist") and requires typing the team name.

## Decisions made in drafting (Joel may override)

1. **Archive keeps memberships** rather than ending them, for the report-eligibility reason above and so coaches keep their read access without a new rule.
2. **Coach notes on an archived team's sessions stay writable** (a coach adding a note to a finished season's pen is harmless). Say so if you'd rather archived means no new notes.
3. **Restore is unlimited** — any time, by the head coach. Cheap, and it makes a mistaken archive a non-event.
4. **Delete is hard, and only for session-less teams.** No tombstone for teams; there's nothing to remember about a team that never charted.
5. **An assistant on an archived team** sees it in Archived and can browse; can't restore.

---

## The packet (paste for Claude Code)

```
ID:              P1-09
Title:           Rename, archive and delete a team
Spec:            plans/p1-09-team-rename-archive.md (on GitHub; pull first and
                 work only from what GitHub has). Build to it.
Goal:            Head coaches can rename an active team; archive a team with
                 sessions (hidden everywhere, invite link off, no new sessions,
                 history readable, restorable); and delete a team that has no
                 sessions. A team with sessions can never be destroyed.
Depends on:      R0, R6, G3 (sessions.team_id + team check), H1 (sync_session),
                 S1 (sport lock), S4 (profiles). All shipped.
Staging only.    Only Joel ships to production. One migration: staging first,
                 fresh production backup first. Show every function, trigger and
                 policy change as SQL before applying.

PRECONDITIONS — REPORT, with file and line numbers, before any SQL or code:
  1. teams: columns, constraints, every FK that points AT teams (sessions,
     pitcher_teams, team_coaches, roster_seen, session_opened, departures,
     invites, anything else) and each FK's ON DELETE behavior. sessions.team_id
     must not cascade — confirm.
  2. How a session's team is chosen at creation when a pitcher is on more than
     one team (client default, selector, or first membership).
  3. sessions_g3_team_check as it stands; resolve_team_invite,
     resolve_coach_invite, join_team, join_team_as_coach, get_team_leaderboard
     — the exact predicates to extend.
  4. Every place the team name is rendered (header, roster, switcher, join
     pages, History, report renderers and email subject/body) and whether any
     of them caches the name.
  5. The head-coach check helper (R6) to reuse.
  6. Counts on staging and production: teams, teams with zero sessions, teams
     with no active coaches; policy count (expected unchanged after P1-09).
  Build nothing until Joel has read the report.

MIGRATION p1_09_teams:
  - teams.archived_at timestamptz NULL, teams.archived_by uuid NULL;
    CHECK on name: 2–60 chars after trim.
  - rename_team(p_team, p_name), archive_team(p_team), restore_team(p_team),
    delete_team(p_team): SECURITY DEFINER, search_path '', head coach of that
    team only (reuse the R6 helper), explicit entitlement check inside each;
    rename/archive/delete refuse on an archived team except restore;
    delete_team refuses when any session has team_id = p_team, otherwise
    removes memberships (log departures), dots rows and the team in one
    transaction.
  - sessions_g3_team_check: also RAISE when the team is archived.
  - resolve_team_invite / resolve_coach_invite return team_archived;
    join_team / join_team_as_coach refuse for an archived team.
  - get_team_leaderboard returns an empty board for an archived team.
  - No direct client UPDATE/DELETE on teams for name/archived columns (confirm
    the existing policies already prevent it; if a client UPDATE path exists,
    report it before removing it).

CLIENT:
  - Coach Profile → team card (head coach only): Rename (inline, validated),
    Archive team or Delete team (whichever applies, from the session count),
    typed-name confirm with the consequences stated. Assistants see neither.
  - Team switcher: active teams, then an "Archived" section. Opening an
    archived team shows the read-only banner ("Archived · read only", Restore
    for the head coach); hides New Session, invite link, roster edits, rename.
  - Pitcher: archived team removed from team areas and session-team choices;
    banner on New Session when the pitcher's only team is archived.
  - join.html: "This team is no longer active." for team_archived.
  - CLAUDE.md: the archive rule ("a team with sessions is never destroyed"),
    what archive hides and keeps, and that restore is head-coach only.

OUT OF SCOPE: ending memberships on archive; team tombstones; transferring
  sessions between teams; merging teams; branding (T1); any change to who may
  remove a pitcher (R0) or hand off head coach (R6).

ACCEPTANCE (both sports; SQL shown for the refusals):
  1. Rename: head coach renames; the new name appears in header, roster,
     switcher, join page, History and a newly generated report; a report
     generated before the rename is byte-identical afterwards; assistant and
     pitcher are refused (UI hidden, direct call refused); 1-char and 61-char
     names refused.
  2. Archive a team with sessions: hidden from the coach switcher's active
     list and present under Archived; hidden from rosters, leaderboard (direct
     call returns empty), pitcher team areas and "Join as:"; both invite links
     show "no longer active" and join_team / join_team_as_coach refuse; a new
     session for it is refused by the trigger AND via sync_session(); the
     team's past sessions, pitches, events, notes and reports still readable
     by its coaches and pitchers; View Report still available in-app for a
     pitcher whose only team is archived; the pitcher's New Session banner
     shows; opening the archived team is read-only with the banner.
  3. Restore: head coach restores; everything resumes including the same
     invite link; assistant refused.
  4. Delete: a team with zero sessions is deleted with its memberships and dots
     rows (SQL before/after); the same call on a team with sessions is refused
     with the count in the message; assistant refused; the UI shows Delete
     only for session-less teams and Archive otherwise.
  5. Typed confirmation: wrong text rejected for archive and delete.
  6. Reports and emails for a renamed or restored team use the current name;
     frozen files unchanged.
  7. Policy count before/after; schema.sql regenerated; CLAUDE.md updated;
     P1-01 offline checks 1–3 pass; CACHE_VERSION bumped.
VERIFICATION: Staging with a throwaway team (create → rename → chart one pen
  → archive → check pitcher and coach views → restore; and a second empty team
  → delete). Production after a fresh backup; Joel renames nothing real until
  he's checked one archived team's read-only view on his phone.
ROLLBACK: git revert; down migration drops the two columns and four functions
  and restores the previous trigger/resolver/join/leaderboard bodies verbatim
  from schema.sql.
SIZE: M.
ESCALATE IF: any FK to teams cascades into sessions or pitches; a client
  UPDATE path on teams exists that policies don't block; the session-team
  choice (precondition 2) has no way to exclude an archived team; the
  leaderboard or resolvers can't take the archived check without referencing
  teams and pitcher_teams directly in a policy (42P17).
```

### Standing constraints (in force)

Every schema/RLS change via migration, staging first, fresh backup before production; show SQL first. No policy references `teams` and `pitcher_teams` directly (42P17 — use helpers). Sessions belong to the pitcher and are never destroyed by a team action. Saved sessions and frozen reports are immutable. Assistants cannot administer. GitHub is the source of truth — pull first; work only from what GitHub has. **Only Joel ships to production.**
