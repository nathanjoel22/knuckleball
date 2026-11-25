# C1 Stage A — evidence (Nov 25, 2026; staging)

Branch `c1-stage-a`, cache `kb-shell-v374`. Staging database: migration `20261129000000_c1a_charting_parts` (dry run, then
push; the parked F1-C2 file copied in for the push and removed). Staging functions: `send-session-report`,
`rerender-reports`. Checks ran in headless Chrome against the local staging site, signed in as a staging demo coach,
charting a demo pitcher.

## Done when

1. **The parts question is first; both = as before: PASS.**
   - Bullpen: "What parts of charting will you be handling?" with Intent — Pitch Calling and Outcome — Pitch Locations;
     Live Game: Intent — Pitch Calling and Outcome & Response — Pitch Locations and Results.
   - Both off: Start is disabled ("Choose at least one part"), and `startSessionNow` refuses too.
   - **Same taps, same rows:** the same scripted taps on `origin/main` (port 8001) and this branch, sync held back, the
     queued items compared without ids and times: a two-part bullpen (3 pitches), a game with Intent (side, call,
     location, K looking), and an Intent-off / Outcome & Response-only game (K, B, F): **IDENTICAL**. The only new
     fields are `chartedIntent` / `chartedOutcome` on the item (true / true; false / true) and `playFlags: null` on game
     pitches.
2. **"Turn on Intent?" is gone; Joel's order: PASS.**
   - Pen (both parts): What parts → What's this pen for? → Turn on Relative Accuracy? → radar.
   - Pen, Intent only: What parts → What's this pen for? (no RA, no radar). Pen, Outcome only: … → radar (no RA).
   - Game: What parts → radar → Starting mid-game? → Opponent. Game, Intent only: What parts → Opponent.
   - Which team is this for? (a pitcher on a team) is last.
3. **Each combination charts and saves offline, and reopens at the same step: PASS (6 of 6).** Each: start; network
   off (CDP offline + `navigator.onLine` false); one whole pitch; stop in the middle of the next; reload (online: the
   local dev server isn't the service worker's cache); Resume; network off again; save; network on; sync.

   | Combination | Step before → after the reload | Queued offline | After sync |
   |---|---|---|---|
   | Pen, both | tap 1 pending → tap 1 pending, same type | 1 pitch, no error | 0 left |
   | Pen, Intent only | `chosen` → `chosen` | 2 pitches (I/!O) | 0 left |
   | Pen, Outcome only | 1 pitch, type kept → same | 1 pitch (!I/O) | 0 left |
   | Game, both | call tapped → call tapped | 1 pitch | 0 left |
   | Game, O&R only | "what happened?" → same | 1 pitch | 0 left |
   | Game, Intent only | `chosen` → `chosen` | 2 pitches (I/!O) | 0 left |

4. **Intent only: PASS.**
   - Layout: ‹ Back above the batter button, instruction beside it; batter · Confirm Pitch · Next Pitch
     (`plans/c1-mockups/` showed it before building; the built screen matches).
   - "Select Pitch Type" → "Tap where you're aiming" → gone on a cell tap; Confirm pulses, then Next.
   - Back: from `aim` reopens the previous pitch (`confirmed`); again un-confirms it (`chosen`, 0 pitches); after the
     next pitch is confirmed the earlier one is frozen (`frozen: 1`, Back disabled at `aim`).
   - Voice (speech stubbed to a log): the cell tap says nothing; Confirm says "Four Seam Fastball middle up"; Next
     Pitch mid-call cancels nothing; the next Confirm while it still speaks queues the next call (no cancel). Pen and
     game the same. With both parts the call is still on the target tap, as before.
5. **O&R-only game = today's Intent-off game: PASS** (item 1's third comparison; DB: target null, location and result
   set).
6. **Intent-only game saves type and target only; nothing shows as zero: PASS.**
   - Saved on staging: `[1,2,null,null,null,'R',null,null]`, `[3,3,null,null,null,'L',null,null]` (target, location,
     result, side, inning, at-bat): type, target and batter side only. `game_final_inning` null; no game line in
     `session_stats`.
   - Scoreboard "–"; History "Intent only · 2 Pitches called" with no IP / K / BB / Strikes.
7. **More Plays: PASS, with the deviations below.** More Plays sits next to ‹ Back on the FC · E · H · O row
   (Infield fly, Ground-rule double, Fan interference; a count shows how many are on). Saved on staging: a foul with
   `play_flags = {foul_error}`, a pickoff event with no move, an `other` event with one out
   (`how: batting_out_of_order`); the log reads "Foul · E on foul", "Pickoff throw, no out", "Batting out of order".
8. **A pen charted in one part changes no accuracy, leaderboard, baseline or Trend: PASS.**
   - SQL (`supabase/tests/c1a_charting_parts.sql`, fails=0): Intent-only pen `scored 0, hits 0, located 0`;
     Outcome-only `located 2, scored 0, hits 0`; full pen `scored 2, hits 1`; only the full pen is a pen a baseline may
     use; the leaderboard reads only pens with both parts.
   - Every existing staging stats row is byte-identical after the v3 recompute: md5 of all 253 rows (without the new
     columns) `f35d9184…` before and after; 0 failures.
   - App: Trends leaves partial sessions out; History, recap, Home and the card show "—" or nothing.

## Other checks
- `supabase/tests/c1a_charting_parts.sql`: fails=0 (also: no part refused, a flag on a pen refused, half a location
  refused, the parts locked once saved, policies unchanged).
- Re-run on staging, all passing: `sc1_session_stats`, `sc1b_workload_rls` (0 differ), `sr1a_session_tags`,
  `sr1b_baselines`, `sr1d_workload`, `h1_grace_closed`, `f2s1_session_assignments`, `f2s4_camps`, `u15_pitch_arsenal`.
  `live_game_r3b` still fails on staging's fixture drift (a fixed pitcher left the team), as before this branch.
- Reports: `deno check` passes; `scripts/c1a-report-check.ts`: 0 fails of 185 (67 full-session reports byte-identical
  to origin/main across sports, levels and reader versions; 118 checks of the four partial cases). On staging the app
  made reports for an Intent-only pen, an Outcome-only pen and an Intent-only game ("Intent only", "—" tiles, Called
  spots).
- Policies 32 / storage 12 before and after.

## Deviations (approved by Joel, Nov 25 2026)
1. **WP / PB on the pitch** isn't a More Plays button: More Plays only shows during a ball in play, and a wild pitch on
   ball four or strike three isn't one. It's already chartable: answer the runners question with the forced base, then
   move the runner from the status-bar diamond with Wild pitch / Passed ball (a `wild_pitch` / `passed_ball` event after
   that pitch, as the stats count it).
2. **Obstruction and runner's interference** are reasons for a runner moved between pitches, not markers on a ball in
   play (`play_flags` has no value for them; the move carries the reason).
3. On the runners question (Next on the row), More Plays sits on its own row under Back / Next.
4. The Intent-only game's batter button flips the side for the batter at the plate; there's no "new batter" there (that
   device charts no results).
