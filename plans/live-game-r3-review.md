# Live Game R3 — review fixes before `live-game-back-more` ships (Oct 21, 2026)

> **Note added when saved (Joel, Oct 21 2026, branch `live-game-r3` from `main` at `34bfd82`).** This review was
> written against `live-game-back-more` at `e39142f` (v265), before it shipped. It shipped to production the same day
> (v280), with migrations `20261019000000_pitch_count_runs`, `20261020000000_live_game_r1`,
> `20261021000000_live_game_r2` and `20261022000000_runners_left` applied, and the H1 grace close took policies to
> **29**. So: A1 and A4 can't be fixed by editing those migrations (production has them) and need new migrations;
> "policies stay at 34" means 29; Stage B can't fold into R2, and `20261022000000` is taken; `runners_left` already
> exists as a count (0-3), not a bitmask; Stage C 3-4 already happened for the shipped work. The preconditions report
> (below the packet, once written) says how each item is handled.

**Jordan, Oct 21, 2026.** Review of PR #6 (`live-game-back-more` at `e39142f`, v265): the Oct 19 rework, Release 1 and
Release 2, the three staging migrations and the `send-session-report` changes. The work is solid: `SECURITY DEFINER` /
`INVOKER` and grants are kept on every replaced function, the H1 lock covers the new session columns, each migration
has a rollback and a SQL test, policies stay at 34, games saved before show NULL instead of wrong numbers, and
unearned and inherited runs never overlap (no double subtraction in `er`).

This packet holds what has to change before production. **Stage A is small fixes. Stage B is a pitcher's line staying
open for the runners he left on base. Stage C is the ship checklist.** Same branch, staging first. Only Joel ships to
production.

**Update, Oct 21 (Jordan, after talking with Joel):** both open decisions are made. The pitch count is A4. The starter's
runs is Stage B. The center-field logo needs no change (see the end of Stage B).

## Stage A — fixes (build now)

### A1 · Remove `pitches.hbp_swing` before it reaches production
HBP on swing was removed from the app on Oct 21 (v263), but the column, its CHECK and the `sync_session` write are
still in the migrations. Production has never seen it, so it should never get it.
- Remove `hbp_swing` from `20261020000000_live_game_r1.sql` (column, constraint, comment, `sync_session` insert) and
  from its rollback and `supabase/tests/live_game_r1.sql`.
- `20261021000000_live_game_r2.sql` also writes `hbp_swing` in its `sync_session`: remove it there too.
- Staging already has the column. Bring staging in line with a staging-only drop (after checking no staging row has
  `hbp_swing` set), recorded in STATUS.
- Remove it from the app in the same change: the sync payload (`hbp_swing:`), the pitch record (`hbpSwing`), the log
  label, and **History's `.select(...)`, which reads `hbp_swing`**. A select that names a dropped column breaks History.

### A2 · At-bat editor: changing Hit / Error / FC or the contact type must redo what depends on it
Today `saveEditGameRow` changes `inPlayOutcome` and `bbType` but keeps everything computed from them:
- **Hit → Error (or the reverse):** the batter-runner's unearned taint (`runnerMeta.u`) isn't updated, so if he scores
  later, that run stays earned (or unearned) when it shouldn't. Errors also count toward the "inning would have ended"
  phantom outs.
- **Contact type change:** the automatic SF / SAC (`pitches.sacrifice`) isn't re-derived (e.g. fly out with a run →
  ground out keeps "SF").

**Wanted:** after an editor save, replay the run ledger from that pitch forward (each play already stores its
`ledgerBefore`, which is the starting point) and re-derive `sacrifice` for the edited pitch. Plays whose earned runs were set by hand in the editor
keep the hand-set value. **If a replay isn't practical**, report that at the preconditions step. The fallback is a
message in the editor: "Earned runs later in this inning may need checking". Don't build the fallback without asking.

### A3 · Replaced runner on a fielder's choice (official scoring rule 9.16(g))
When an inherited runner is forced out on a fielder's choice, the batter who reaches in his place is still the
previous pitcher's runner. Today `gameLedger` gives the batter `i: false`, so that run is charged to the reliever.
**Wanted:** on an FC (and any force play) that puts out an inherited runner, the batter-runner takes the inherited
flag (one flag per runner put out). Add a check to the Release 2 headless suite. Stage B makes this matter more: those
runs now land on the starter's line.

### A4 · Count corrections change balls and strikes, never the pitch count (Jordan + Joel, Oct 21)
Today `gamePitchCountAdj` subtracts one for every −K / −B and moves the count for every top-bar Balls / Strikes
correction (`a.pc`). That value is saved as `sessions.pitch_count_adjust` and added in `pitcher_workload`, the roster's
7- and 30-day workload line. A coach fixing a wrong count on screen quietly lowers the pitcher's workload.

**The rule:** a correction modifies balls and strikes; it never removes a pitch.
- **−K / −B** and the **top-bar Balls / Strikes adjust** change the count shown only. The pitch count doesn't move.
- **+K / +B** (a pitch thrown but not charted) still add one to the pitch count, as built.
- So `pitch_count_adjust` only counts +K / +B and is never negative. The saved pitch count and the workload line are
  always ≥ the pitches charted.
- **Database:** change `sessions_pitch_count_adjust_check` in `20261019000000_pitch_count_runs.sql` to
  `pitch_count_adjust between 0 and 999` (and its rollback). Production has never had this migration. Bring staging in
  line (check no staging row is negative first) and record it in STATUS. The `greatest(0, …)` floors can stay.
- **Tests:** update `supabase/tests/pitch_count_runs.sql` (the −10 case becomes a refused insert) and the headless
  checks (ball → +K → −K → top-bar Balls −1: pitch count 2, count shown changes).

## Stage B — a pitcher's line stays open for the runners he left on base (Jordan + Joel, Oct 21)

**The problem:** when a reliever lets the starter's runners score, those runs are charged to nobody. The starter's
saved game never changes, and the reliever's line leaves inherited runs out (E2). Official scoring charges them to
the pitcher who put them on base.

**The rule (Jordan + Joel):** once a pitcher is removed, his **pitches are locked**. But if he left runners on base,
his **final stats can still change**: runs (R / ER) when his runners score, and the walk charged to him (E3). His
session goes into **full lock** once the inning is over, or once every runner he left on base is out or has scored.
This reverses Release 2's "the starter's saved game never changes".

### What to build (preconditions report first: these are the defaults, flag anything that doesn't fit)

**B1 · Two locks, not one.** Today `sync_session` sets `sealed_at` at save, and a session with `sealed_at` NULL is
treated as an unfinished old-app sync, which means another sync could add pitches. **So `sealed_at` keeps meaning
"pitches locked" and is still set at save.** Add `sessions.final_at` (full lock) plus the stats charged after he
left: `exit_runs`, `exit_er` and `exit_bb`, and `runners_left` (the bitmask when he came out). `final_at` is set at
save when he left the bases empty, so nothing changes for most games.

**B2 · Only the server writes them, and only from the reliever's saved rows.** One `SECURITY DEFINER` function, run
from the reliever's `sync_session` in the same transaction. It derives the amounts from the reliever's own saved
`inherited_runs` and unearned rows and its `charged_prev` walks. **The client never sends a number for another
pitcher's line.** Checks: the same team and sport, both games, the starter's session not yet `final_at`. The H1 lock
refuses any API change to the new columns, like the delete tombstone, and refuses every change once `final_at` is
set.

**B3 · Whose runner is whose.** `runnerMeta.i` is a yes/no today. It needs the **owner's session id**, so that a
second reliever who inherits the starter's runner still charges the starter. The hand-off (`kb:gameHandoff`) has to
carry the starter's session id and the owner of each runner. It doesn't today. Each relief session saves which
session it relieved (`relieved_session_id`, locked once saved). Earned or unearned for the starter follows each
runner's own taint (`u`). That needs an inherited-unearned count beside `inherited_runs`.

**B4 · When the full lock happens.** The reliever's sync sets the starter's `final_at` when the reliever's rows show
the inning ended, or show every one of the starter's runners out or scored. If the reliever is pulled with the
starter's runners still on, the lock passes along with the runners through the next hand-off.

**B5 · Two gaps the rule doesn't cover. Proposed defaults, Joel to confirm:**
- **Reliever charted on another device, or not charted at all:** "Starting mid-game?" with runners on also asks
  "Who was pitching?" It lists the team's games saved today that aren't `final_at`, plus "Not charted". If nobody
  links, the starter's session **locks in full by itself 6 hours after his save**. A scheduled job can do that, or
  the next read can.
- **The starter's report:** sent at save today. If he left runners on, **send it at full lock instead**, so it has
  his final R / ER. If he left the bases empty, nothing changes. A report sent can't be changed afterwards (reports are frozen).

**B6 · Stats.** `compute_game_summary` adds `exit_runs` / `exit_er` / `exit_bb` to `runs` / `er` / `bb`, and returns
`provisional: true` while `final_at` is NULL. The History card and live numbers match. The report shows the
pitching line with them included, and in the at-bat log, "R1 scores (charged to <starter>)".

**B7 · Proof.** SQL tests (staging, rolled back): a starter leaves runners on 1B and 3B, the reliever gives up a
single and both score → the starter's R 2, his lock set; a second reliever inherits the starter's runner; the
reliever ends the inning with the runners stranded → lock with exit_runs 0; a crafted call writing another
pitcher's `exit_runs` → refused; any change after `final_at` → refused; the 6-hour lock. Headless: the hand-off
carries owners, "Who was pitching?" and the starter's History card updating.

**New migration** `20261022000000_live_game_r3` (or folded into R2, since production has neither: your call at
preconditions), with a rollback and a test. Policies stay at 34.

### Center-field logo: no change (Joel, Oct 21)
Joel picked both marks: **the keypad (The spot, the slanted 3×3 zone) is the primary logo**, and **the plate
(Strikeout) is the secondary**, used in places like the mown center-field grass. `4c57aec` already mows the plate
there, so the branch is right as built. Fix the header in `docs/cf-logo-mown.md`, which says "design #2" over the
plate drawing.

## Stage C — ship checklist

1. Stages A and B on staging, each with its STATUS entry.
2. **A real phone pass** (both sports, a reliever hand-off with the starter's runners scoring, −K / −B leaving the
   pitch count alone, an error that scores later, the editor) and **a real report generated on staging** for a game
   (a starter who left runners on, and his reliever) AND a bullpen. None of these has been run yet.
3. Fresh production backup.
4. **Order matters.** Production migrations `20261019000000`, `20261020000000`, `20261021000000` (and Stage B's),
   then the site, then
   `supabase functions deploy send-session-report`. The new `from_rows.ts` selects the new columns, so the function
   deployed before the migrations breaks **every** report email (bullpen too). History's load reads
   `pitch_count_adjust`, so the site before the migrations breaks History.
5. Policies 34 after. Regenerate `supabase/schema/schema.sql`. Update CLAUDE.md's G5 section (Foul Tip / Foul Out,
   the on-field H / O / E and IF / OF boxes it describes are superseded) and the `.15` comments in
   `send-session-report/index.ts`.

## Later (not this packet)
- The strikeout rule now lives in four places: `compute_game_summary`, the app's `gameIsK`, and `isK` in both
  `compute_game.ts` and `connect.ts`. All four match today. A test that runs the same pitches through each and
  compares K counts would catch drift.
- Reserve `192.168.1.68` for the Mac in the router (STATUS, Oct 20).

## To get it into the repo
1. Save this file as `plans/live-game-r3-review.md` on `live-game-back-more`.
2. Your Claude Code reports on the preconditions before writing code, same as D1–D3: Stage A (A1's and A4's staging
   changes, A2's replay approach, A3's test), and Stage B (the B1 columns, the B2 function's checks, how B3's owners
   ride the hand-off, the B5 defaults, and one migration or two).
