# Live Game — Knuckleball

Moved word for word from CLAUDE.md on 2026-11-05 (card 015). CLAUDE.md's rules apply here too; read it first.

## Live Game on the field (G5, Joel, Oct 6–8 2026; evidence `plans/g5-evidence.md`)

Built far past the uploaded spec `plans/g5-live-game-diamond.md` -- where they differ, Joel's later decisions (below) win.
- **The flip:** after a location tap the pitch chart turns over (a flat card turn, ~650 ms; no 3D -- iPad Safari mis-sized a 3D flip) to the **field on its back**: the same square and the same 25 boxes in every layout, the field drawn upright. At rest the field is built exactly like the chart (`g5Card` → `.zone-grid.g5-flat`); the two-face card exists only during the flip. Next / Undo / New batter flip back.
- **The field** (in the field's own units, 100 a box): home plate mid box 15; foul lines through 17/3 and 23/11; fence arc from box 4's top-left corner, peaking mid 7, to box 10's top-right; 1B and 3B just inside the lines (mid 23 / mid 17, outer side on the line), 2B at the bottom of 25; dirt from 17's top-left corner peaking mid 25 to 23's top-right; mound mid 24; V mower stripes (fair #8CBA5A/#6FA548, foul #60963C/#548A35), plaid infield grass -- softball: all-dirt infield, pitcher's circle. Drawn in the tracker (`g5FieldSvg`) and in `send-session-report/diamond.ts` -- change both or neither.
- **Boxes** (row 0 top): `5 6 7 8 9 / 4 19 20 21 10 / 3 18 25 22 11 / 2 17 24 23 12 / 1 16 15 14 13`. What happened? Swing 1 · Looking 2 · Ball 12 · In Play 13 · Foul 14. Foul → Foul Tip 13 (any foul ball) · Foul Out 12 (any caught foul, incl. a caught strike three -- stored as an out in play, not a K). H/O/E: O 12 · H 13 · E 14. Contact: Bunt 1 · Pop 2 · GB 12 · Fly 13 · LD 14. Location: Fly flashes the outfield and Bunt the infield at once; GB / Pop / LD wait for IF 12 / OF 13 (stored `pitches.spray_field`); HR? 13 on a fly hit, 14 on a line-drive hit, then the area over the fence (hit_type HR, bases empty, no runners question). Foul Out shades foul ground only; a ball in play's location shades fair ground only (exact opposites). Runners: 3B 17 · 2B 25 · 1B 23 · Next pitch 24 (radar off).
- **Rules:** outs only when recorded (O, a strikeout, + Out); the runners question after every plate appearance except a strikeout and a homer (walks -- including ball four by + Ball -- pre-fill the forced runners); runs are not tracked; three outs end the half-inning. + Out / + Strike / + Ball under the field (+ Strike / + Ball also under the chart): auto strike / auto ball events (pitch-clock), never pitches. The G3 extra-inning "runner on 2B?" prompt sits under the chart. Velocity after the flip back sits in the chart's last two rows.
- **Data:** `pitches.spray_box` (1–25), `runners_after` (bitmask), `spray_field` (IF/OF) -- game-only (CHECKs), saved by `sync_session` (migrations `20261007000000_g5_spray_box`, `20261008000000_g5_spray_field`). New games leave `hit_type` (except HR), fielders, `runner_advances`, `runs_scored`, `bb_x/bb_y` NULL. Old games are placed on the field by fielder (C 15, P 24, 1B 23, 2B 22, SS 18, 3B 17, LF 19, CF 20, RF 21).
- **Game report:** spray charts on the field (all / by result / by contact / by pitch type, Infield · Outfield counts), what led to it (per box, per contact, pitch type × result), base states, "The pitches that mattered" (strike three, first-pitch strikes, hits, outs in play, walks, errors), "Bullpen to game" (same pitch, same spot vs the last 5 bullpens, same team; the app sends `recentPenPitches`, `from_rows.ts` builds the same).

## Live Game charting now (Joel, Oct 19–21 2026; v252–v280; shipped Oct 21)

**Where this and the G5 section above differ, this wins.** Superseded from G5: Foul Tip / Foul Out (Foul is always a
foul tip; a caught foul is Out → FOUL), H/O/E and contact and IF/OF on the field's boxes (they're cell-sized rows under
the field now), "+ Out / + Strike / + Ball under the field" (gone), "new games leave fielders NULL" (fielders are asked
again), "runner_advances NULL on new games" (kept on every play), and the Outs shown counting each out as it's called.
Plans and decisions: `plans/live-game-r1.md`, `plans/live-game-r2.md`; the full log is STATUS.md (Oct 19–21).
- **Under the chart:** K · backwards K · B · F · IP (cell-sized), then ‹ Back (undoes the last tap or action; there is no
  Undo) and More: +K / +B (a missed pitch: +1 pitch count, saved as `sessions.pitch_count_adjust`, never negative) / −K / −B
  (the count only -- R3 A4: a correction never removes a pitch; nor do the top bar's Balls / Strikes), Hit by
  pitch, Rare plays ▸ (Dropped 3rd, Intentional walk, Interference → Catcher's / Batter's, Violations → Clock ball /
  Clock strike (no pitch, not in the count), Foul bunt, Balk / softball Illegal pitch), New batter, New inning. Tapping
  Inning / Outs / Count in the top bar adjusts it. The top bar also shows **Runs** (his own; inherited runs scored as
  "+N inh").
- **A ball in play:** FC · E · H · O → H asks 1B / 2B / 3B / HR; E asks "Where did the batter end up?" (1B/2B/3B/Home)
  → contact (Bu PU GB LD FB; a bunt lights the infield by itself) → location (IF / OF / FOUL, and FENCE for a homer;
  OF on a homer = inside the park) → **Who fielded it?** (positions as yellow pills on the field; a tap selects /
  unselects; with runners on, tap the outs in order -- 6-4-3 = force at 2B + batter; a force away from first with no
  out at first is a fielder's choice; Unassisted; a fly / line / pop out is one tap) → the batter is placed and runners
  pushed only as far as forced → **each runner asked, lead runner first** (HELD · ADV TO 2B/3B/HOME · OUT; OUT asks the
  base, or after a catch Doubled off / Out advancing to …) → **Confirm the play** (the play written out; Next saves;
  third outs and home runs stop here too). The Outs shown go up when the play is saved.
- **Runs and the pitching line:** runs per play (`runs_scored`), unearned (`unearned_runs`: reached on E / CI, "On error",
  passed ball, after the inning would have ended, the placed extra-inning runner; changed in the editor), inherited
  (`inherited_runs`; runners on when he started -- hand-off or "Starting mid-game?" with inning / outs / runners / count),
  a walk on the starter's 2-0 / 2-1 / 3-0 / 3-1 / 3-2 count charged to him (`charged_prev`). The reliever's R / ER leave
  inherited runs out; the starter's saved game never changes. `sessions.inherited_runners` (IR) and
  `sessions.runners_left` (on base when he came out). Sacrifices (SF / SAC) are derived. Fielders in `fielder` /
  `fielders` ('SS-1B'; the same fielder twice = unassisted, 6U-3).
- **A pitcher's line stays open for the runners he left (R3 Stage B, Jordan + Joel, Oct 21-22; `plans/live-game-r3-*`).**
  Pitches lock at save (`sealed_at`); his runs / ER / walks can still grow until `sessions.final_at` (the full lock: set
  at save if no runner of his own is left on; else by the next pitcher's save once none of his runners is on base; else
  6 hours after his save, pg_cron `r3-final-lock` -> `r3_finalize_stale()`). Each runner carries its owner (the game he
  came from: `runnerMeta[b].s`); the hand-off and "Starting mid-game?" -> "Who was pitching?" (this device's games from
  the last 6 hours, plus the team's open games when online, or "Not charted") set the reliever's `relieved_session_id`.
  The reliever's rows carry `charged_runs` ([{s, u}] per inherited run) and `charged_prev_session`; his `sync_session`
  runs `r3_apply_relief` (server only, up the relief chain, capped at the runners each one left plus his charged walk)
  into the earlier pitchers' `exit_runs` / `exit_er` / `exit_bb`. Linking needs the same team, another pitcher, saved
  before and within 6 hours, and the caller a coach of the team or that game's own charter; a starter not saved yet ->
  `relieved_not_saved` (stays queued; after a day it saves unlinked). The H1 lock: `relieved_session_id` / `left_owners`
  never change; `final_at` / `exit_*` only by the server, never once final. `compute_game_summary` adds `exit_*` and
  returns `provisional`; a game with an open line has no report yet ("Line open" in History; `send-session-report`
  refuses with 409 `line_open`); its report says how many of the runners he left scored after he left.
- **During a game, before saving:** "edit" on any pitch in the log (type, velocity, contact, Hit / Error / FC, fielders,
  earned runs, Move location); anything that changes outs, the count or the runners still needs Back. Changing Hit /
  Error / FC or the contact re-runs the runs from that play to the end of its inning (`gameReplayLedger`; earned runs
  set by hand stay) and re-derives SF / SAC (`gameSacrifice`) -- R3 A2. A batter who reaches on a play that put out an
  inherited runner takes his place (rule 9.16(g), R3 A3).
- **Database (all on production Oct 21):** migrations `20261019000000_pitch_count_runs`, `20261020000000_live_game_r1`
  (`pitches.hbp_swing`: dropped by R3 Stage B, Oct 22), `20261021000000_live_game_r2`,
  `20261022000000_runners_left`, then R3 `20261024000000_live_game_r3a` (production Oct 22) and `20261025000000_live_game_r3b` (production Oct 22), each with a
  down script in `supabase/rollback/` and a test in `supabase/tests/`. `compute_game_summary` returns `pitch_count`,
  `runs` (his), `er`, `ir`, `irs`, `bb_charged_prev`, `runners_left`; a two-strike foul bunt is a K.
- **Game report:** WP / BK, ER, IR / IRS, SF / SAC in the pitching line; play notation, runner moves and runs in the at-bat
  log; runners left and inherited-runs lines; count splits and leadoff reached. The field charts draw a **baseball per
  ball in play** (ringed in the pitch colour by pitch type); every other chart keeps coloured dots (Joel, Oct 21).
- **The online catch-up keeps your place** (`reloadTeamKeepingPlace`): after a cached paint, the background reload keeps
  the team, pitcher, screen and an open session (Oct 21 fix for "taps Charting, then jumps back").
