# R4 acceptance evidence

Packet: `plans/r4-cross-team-visibility.md`, with Joel's Oct 5 decisions: other-team coaches see a
pitcher's sessions **since he joined their team**; offline History stays as today (nothing is cached);
the workload line stays — then simplified to the last outing's date and pitch count plus the last 7
days (no 30-day count, no "Last pen" words). Applied to **staging** Oct 5 2026 (Joel OK): migration
`20261005020000_r4_cross_team.sql`, `send-session-report` deployed; app v149 → v151. Privacy "Your
coaches" wording approved by Joel as drafted; policy Version 2026-10-05.

Database scripts (live on staging, rolled back): `supabase/tests/r4_rls_matrix.sql`,
`supabase/tests/r4_acceptance.sql` (baseball), `supabase/tests/r4_acceptance_softball.sql`.

| # | Check | Result |
|---|-------|--------|
| 1 | Access matrix after vs before: the only new reads are other-current-team coaches | PASS. Before: each team's coaches saw only their own team's pen. After: A's and B's coaches also see the pitcher's pens for the other teams (including D, which he left — still his session). Unchanged: archived team C's coach (nothing), departed team D's coach (only D's own, G3), softball coach of his softball profile (nothing), unrelated coach and anon (nothing). Notes, delete_session and report-link writes unchanged. Policies 34 → 34 |
| 2 | B's coaches see A's pen read-only with a chip; direct note and report refused; removal ends it; A keeps its own | PASS. DB: B's head sees A's pens since he joined B, not the one from before; reads A's note; can't insert a note; removed from B → 0; removed from A → A keeps its 4. Live (Joel, Oct 5): `stagingsmoke` joined test team university, charted a Staging Knights pen; `+newcoach` saw ONLY that pen (1 of 29) with a "for Staging Knights" chip, read-only (no note box, no Send report, no Delete); `is_coach_of_session` false for him; his crafted report request → `403 "Only the pitcher or the coaches of the team this session was charted for can create or send its report."`; `+malachistaging` (Staging Knights) had notes, Send report and Delete |
| 3 | Archive B: B keeps its own, loses the pitcher's new A work | PASS (DB): B archived → B's head sees 0 of P's A sessions; B roster dots 0 |
| 4 | Workload matches SQL; the pitcher sees the same | PASS (DB): B's coach counts since the pitcher joined B (30-day bullpen 65 = SQL 65); the pitcher counts everything (95 = SQL 95). Display simplified per Joel: "Oct 3 · 42 pitches" / "Last 7 days · 87 pitches", on the roster and atop History |
| 5 | Dots: B's coach gets a dot for the new A session; clears on open | PASS. DB: unopened for B's head > 0, 0 after opening. Live: `+newcoach` saw the dot and opened the pen (session_opened row) |
| 6 | Pitcher History: all teams with chips; filter | PASS. Harness: chips on every row, team filter narrows the list. Live (Joel): History across teams with chips and filter |
| 7 | Offline; CACHE_VERSION | Offline History unchanged by decision (no sessions are cached for anyone). v151. P1-01 offline checks: at the production ship |
| 8 | Privacy clause approved and live; policy count; schema.sql; CLAUDE.md | Approved (commit def7719), Version 2026-10-05; policies 34; CLAUDE.md updated (the summary-line rule replaced). Live + schema.sql: at the production ship |

Both sports: the full acceptance ran on baseball and on softball teams with the same results; a
pitcher's other-sport profile never appears to these coaches.

Not cached offline (by decision): other-team sessions behave like every session — History loads
online. Leaderboards unchanged (each counts only its own team's sessions).

## Production (Oct 5 2026, Joel, after backup 2026-10-05-2323)

Operator Nathan / joelhauserman@gmail.com; backup confirmed post-P1-09, pre-R4. Applied
`20261005020000_r4_cross_team.sql`; deployed `send-session-report`; pushed v151 to main after clean
pre-push checks. Production after: 34 policies (4 read rules use `is_current_coach_of_pitcher`), the
three new functions, 82 sessions and 11 teams untouched. No production pitcher is on two teams yet,
so nobody's visibility changed at ship time; it applies the moment one is. Live: v151, privacy
Version 2026-10-05 with the new "Your coaches" wording, production config. schema.sql regenerated.

**Still to do (Joel):** P1-01 offline checks 1–3 in both sports; the real case (Cairn + Kings
Christian sharing a pitcher) checked from each coach's side once it exists on production.

## Follow-up (Oct 6 2026, Joel: "restore it"; shipped as v152, commit 2ccfc41)

Found during U12's precondition report: report trend sections (bullpen history, game recent pens,
game trend) were built from the History list, which R4 widened to every team the viewer can see — so
a new report could have frozen another team's sessions into a shareable link. Also, a pitcher's
mixed-team History meant a report generated while a different team was selected took that team's
name and uniform number. Fixed: all of these now come from the session's own team only (as before
R4). Harness: a Cairn pen reported while Kings is selected shows Cairn, Cairn's uniform number and
only Cairn's other pens; single-team payloads byte-identical to main. Nothing leaked: no production
pitcher was on two teams (the 2 reports generated after R4 shipped are single-team).
