# Live Game Release 2 — after Release 1, same branch

Joel, Oct 20 2026. No packet: the Release 2 items from the gaps review (`plans/live-game-r1.md`), with Joel's answers.

| ID | What | Decision |
|----|------|----------|
| C4 | Fielders and play notation | After the location, the nine positions are buttons on the field (C 15, P 24, 1B 23, 2B 22, SS 18, 3B 17, LF 4, CF 20, RF 10 -- Joel, Oct 21: yellow pills, letters only) and the yellow prompt asks **"Who fielded it?"** (Joel). Tap in order (6, then 3 = 6-3); Done, or Skip. Asked on hits, outs, errors and FC (Joel: hits too, with Skip). Saved as `pitches.fielder` (first) and `pitches.fielders` (the rest, "4-3"). Reverses G5's "no fielders on new games". |
| C2 | Sacrifice fly / bunt | Marked automatically (`pitches.sacrifice`), fewer than two outs before the play: an out on a fly ball or line drive with a runner scoring = SF; a bunt out with a runner moving up and no runner out = SAC. |
| E1 | Earned / unearned runs | Automatic, can be changed (Joel). Unearned: a runner who reached on an error or catcher's interference (or advanced "On error"), a run on a passed ball, a run after the inning would have ended but for an error (each batter reaching on an error or CI counts as an out for this), the extra-inning placed runner. Changed in the at-bat editor. |
| E2 | Inherited runners | Reliever's line only (Joel): IR (runners on when he started) and IRS (how many scored); their runs are left out of his R and ER. The starter's saved game never changes. |
| E3 | Walk on the starter's count | Reliever's line only: a walk to the batter he inherited at 2-0, 2-1, 3-0, 3-1 or 3-2 is charged to the previous pitcher (left out of his BB; that batter, if he scores, is the previous pitcher's run). "Starting mid-game?" also asks the count so this works without the hand-off. |
| E6 | Runner reasons and runs in the report | The at-bat log shows each play's runner moves (with reasons) and runs. |
| E7 | More count splits | Three-ball counts, leadoff batter reached, and plate-appearance results by count (K / BB / H / other per count). Also added: a two-strike row. |
| F5 | Fixing an earlier at-bat | Details only (Joel): pitch type, velocity, location (tap the chart), contact type, Hit / Error / FC, fielders, earned runs. Anything that changes outs, the count or the runners still needs Back. Not in this release: changing the field location (spray box). |

## Database (one migration, staging first)

`20261021000000_live_game_r2`: `pitches.unearned_runs`, `pitches.inherited_runs`, `pitches.charged_prev`;
the same three on `game_events`; `sessions.inherited_runners` (games; locked once saved). `sync_session` writes them;
`compute_game_summary` returns `runs` as runs charged to this pitcher (all runs minus inherited), `er`, `ir`, `irs`
and leaves charged-to-previous walks out of `bb`. Games saved before have none of these: `er` / `ir` / `irs` are null.
