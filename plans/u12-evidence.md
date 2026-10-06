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
