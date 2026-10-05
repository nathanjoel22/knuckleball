# P1-09 acceptance evidence

Packet: `plans/p1-09-team-rename-archive.md`. Preceded by the **teams hotfix** (shipped to
production Oct 5 2026 after backup 2026-10-05-1300): `sessions.team_id` ON DELETE RESTRICT and no
direct client writes on `teams` — the two escalations the P1-09 precondition report found.

P1-09 applied to **staging** Oct 5 2026 (Joel OK): migration `20261005010000_p1_09_teams.sql`; app
v147, then v148 (Profile reachable on a laptop for a team with no pitchers yet — a gap that predated
P1-09, found in the walkthrough). Database script: `supabase/tests/p1_09_acceptance.sql` (both sports,
run live on staging, rolled back). App: harness checks (`p109-check.js`, `p109-empty.js`) against the
real tracker code. Policies 34 → 34.

| # | Check | Result |
|---|-------|--------|
| 1 | Rename: head only, 2–60 chars, shows everywhere; old reports frozen | PASS. DB: head renames (trimmed), 1 char and 61 chars → `team_name_length`, 60 ok; assistant and pitcher → `not authorized`; softball head renames. Live: Joel renamed P109 Test ↔ P109 Throwaway (the database keeps the last saved name). New reports take the name the app sends (current); generated reports are frozen files, never regenerated, so they keep the old name by construction |
| 2 | Archive a team with sessions | PASS. DB: assistant `not_authorized`, head ok; then rename / level / new invite link / show invite links / delete → `team_archived`; head, assistant and pitcher still read the session and its pitches; pitcher still report-eligible; leaderboard `disabled: archived`, empty; new session refused via `sync_session` and directly (`team_archived`); both invite links resolve archived; new pitcher and new coach joins → `team_archived`. Live (Joel, Oct 5): typed-name confirm refused a wrong name; P109 Throwaway (1 session) archived; under "Archived" in the Team menu; "Archived · read only" banner with Restore; no New Session tab; History shows the 5-pitch pen; the copied invite link said "This team is no longer active."; the pitcher (`stagingsmoke`) saw the archived-team banner on New Session and the pen in History |
| 3 | Restore | PASS. DB: assistant `not_authorized`, head ok; the same invite link resolves active; a new pitcher joins and a new session saves. Live: Joel restored; the link works again |
| 4 | Delete only for session-less teams | PASS. DB: a team with 1 session → "This team has 1 session and can be archived, not deleted."; an empty team with a roster and staff → deleted with 0 leftover rows (roster, staff, departures); pitcher and assistant → `not_authorized`. Live: Profile offered Archive for the team with a session and Delete for `P109 Empty`, which Joel deleted; no orphan staff or roster rows anywhere on staging |
| 5 | Typed confirmation | PASS (harness: wrong case refused before any call; live: wrong name refused) |
| 6 | Reports/emails use the current name; frozen files unchanged | PASS by construction: the report request carries the team's current name; the report email subject has no team name; the removal notice reads it live; stored reports are never regenerated |
| 7 | Policy count; schema.sql; CLAUDE.md; offline; CACHE_VERSION | 34 → 34; CLAUDE.md updated (archive rule); v148. schema.sql and P1-01 offline checks: at the production ship |

Harness (both roles): Archived group listed after active teams; read-only banner (Restore for the
head only; assistant sees no Restore); no New Session, rename, level, invite links, roster ✕ or
archive/delete on an archived team; Archive vs Delete by session count; pitcher banner (and "switch
to <active team>" when he has one); normal screens byte-identical to main.

**Known, by decision:** an archived team's head-coach handoff, coach/pitcher removal and uniform
numbers are hidden in the app but not refused by the database (the packet didn't require it). A pen
charted before an archive and synced after waits in the outbox with "This session's team was archived
… It will sync if the head coach restores the team."

## Production (Oct 5 2026, Joel, after backup 2026-10-05-1401)

Operator Nathan / joelhauserman@gmail.com; backup confirmed post-hotfix and pre-P1-09 (the first
backup output pasted was the 13:00 pre-hotfix one and was refused). Applied
`20261005010000_p1_09_teams.sql`; production after: 34 policies, the four new functions, resolvers
return `team_archived`, the name rule in place, 11 teams (0 archived), 82 sessions. v148 pushed to
main after clean pre-push checks; live site v148, production config. schema.sql regenerated.

**Decided:** View report for a pitcher on an archived team is accepted on the database proof (Joel,
Oct 5). **Was open:** the in-app View report for a pitcher on an archived team — eligibility is proven in the
database (`is_pitcher_report_eligible` true while archived); no report was generated during the
walkthrough.

**Done (Joel, Oct 5):** phone check of an archived team's read-only view on production (throwaway team: create, archive, look, restore, delete) and P1-01 offline checks — all good. P1-09 complete.

~~Still to do (Joel):~~ before renaming anything real, check one archived team's read-only view on
his phone (a throwaway team on production: create, archive, look, restore, delete); P1-01 offline
checks 1–3.
