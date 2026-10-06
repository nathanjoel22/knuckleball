# U12 evidence (in progress)

Packet: `plans/u12-pitchers-view-reports.md`. Joel's Oct 6 answers: target Cairn by team ID
(`7e1648c1-0582-44e9-984d-a9735a88e4da`, the one holding the 23 reports); Blue Bombers and Sledgehammer
are test teams; re-rendered reports use today's values; a `rerender-reports` function only Joel's login
can call, dry run by default; per-team trends restored (v152).

## Part 1 — pitcher's view (commit f3e1034, v153)

- Reports (harness on the real templates): RHB stored column 0 draws at column 4; 1/4/7 sit in the
  column nearest the batter for RHB (right) and LHB (left); no "catcher's view" left in a pen report;
  miss tendency left/right swapped to match the drawn view.
- App (harness on the real tracker): History heat map draws stored (2,0) at drawn column 4, label 1 on
  the RHB side; zone editor: the cell labeled 1 saves stored (1,1) for RHB and (1,3) for LHB, drawn on
  the batter's side; a stored painted cell shows on its mirrored drawn cell; captions "Pitcher's view".
- Charting screen byte-identical to main: behind catcher / behind pitcher × RHB / LHB, all four.

## Part 2 — rebuild from stored rows

`from_rows.ts` vs the app's own builders, same staging rows (Staging Pitcher, Staging Knights: 28
sessions, 106 pitches, 7 game summaries): every payload field identical for 2 pens (19-pen history
each) and 3 games (6-entry game trend); with one game's date moved after the pens, the recent-pens
branch (2 types) is identical too. All five rebuilt reports are drawn in the pitcher's view.

## Staging (Oct 6 2026, Joel OK "apply to staging")

Applied `20261006000000_u12_reports_archive.sql` (private `reports-archive` bucket, no storage
policies); deployed `send-session-report` and `rerender-reports`; `OPERATOR_EMAILS` =
`nate@knuckleballonline.com` (a dedicated operator login Joel created on staging; it receives mail).

| # | Check | Result |
|---|-------|--------|
| 1 | Four cases RHB/LHB × pitcher's view | PASS (part 1 harness): stored col 0 → drawn col 4; 1/4/7 in the column nearest the batter for both sides; rows unchanged |
| 2 | Pen and game reports drawn in the pitcher's view, new caption | PASS: all 9 re-rendered Staging Knights reports (3 games, 6 pens) carry two "— pitcher's view" grid headings and no "catcher's view"; Joel viewed a game and a Malachi Pugh pen at their old links: "looks awesome". Reports have no field/spray chart (svg.ts draws grids, legend, line charts only) |
| 3 | History and Profile in the pitcher's view, agree with the report | Harness PASS (part 1); Joel's side-by-side look: pending |
| 4 | Render-from-rows = client payload | PASS: 5 staging sessions (2 pens, 3 games, plus the recent-pens branch), every payload field identical |
| 5 | Production dry run lists every Cairn report | At the production ship |
| 6 | Archive + manifest; old links open; no email; others untouched | PASS on staging: dry run 200, count 9; run 200, 9 of 9; every file changed and is pitcher's view; archive holds 9 copies + manifest.json, each the original's exact byte size; all 30 Knights session rows identical before/after (report_path, generated, sealed, ended); storage objects updated = 9, all Knights (0 others of 17); no email path in the function; notes are read live by report.html (`get_report_notes`), not from the file |
| 7 | Rollback restores byte-for-byte | PASS: rollback 200, 9 of 9; SHA-256 of all 9 restored files identical to the fingerprints taken before the run |
| 8 | Escaping, CSP, CACHE_VERSION | report.html unchanged vs main (CSP hash untouched); escaping code unchanged (only import lines gained the view names); v153. P1-01 offline checks 1–3: at the production ship |

Refusals: no token 401; public app key only 401; operator with the wrong `expect_count` (8) 409
"nothing was changed" (files re-checked, still the originals); head coach of this team
(`+malachistaging`, not an operator) 403 "This tool is for the operator only."
