# STATUS — what shipped, where, and what's open

The log. CLAUDE.md holds the rules; this file records each release. **A new entry goes on top every time a packet (or a request Joel ships without one) reaches staging or production**, with:
- date;
- packet ID;
- where it went;
- branch;
- commit;
- cache version;
- what was built;
- what deviated from the packet;
- open items.

Newest first. Entries from Oct 6 to Oct 9, 2026 and the "Earlier releases" section were written afterwards from git history.

---

## 2026-10-22 · Live Game R3, Stage B · **production**
- **Shipped by:** Joel ("everything looks good, ship stage B" after the Stage C phone pass); operator `Nathan <joelhauserman@gmail.com>`. Branch `live-game-r3` → `main` (admin merge). **Cache:** v294.
- **Checked first:** production's `sync_session` = Stage A's (md5 `8df74e48…`); `a1-account-deletion` job present; 29 policies; the branch's committed config points at production; `main` had nothing the branch lacked.
- **Backup first:** `~/knuckleball-backups/2026-10-22-1357-{schema,data}.sql` (29 policies; 124 sessions, 2,482 pitches, 68 events).
- **Database:** dry run listed only `20261025000000_live_game_r3b`; applied before the merge. After: 29 policies; `r3-final-lock` scheduled; every saved session final (0 open); `pitches.hbp_swing` gone; the 6 new session columns present; counts unchanged; `sync_session` and `compute_game_summary` identical to staging's (md5 `653b3955…`, `173b7042…`). `supabase/schema/schema.sql` regenerated.
- **Function:** `send-session-report` deployed to production after the site (reads `provisional`; 409 `line_open`).
- **Open:** none from the ship. Production's Redirect URLs still need `https://knuckleballonline.com/**` (it was added to staging by mistake). Staging's `REPORT_SITE_ORIGIN` is `.19`; the Mac is on another network today.

## 2026-10-22 · no packet (Mac Safari left pieces of the sign-in header behind) · **production**
- **Shipped by:** Joel ("ship it"); operator `Nathan <joelhauserman@gmail.com>`. Branch `fix-safari-repaint` from `main`. **Cache:** v293. Frontend only (`css/components.css`).
- **Found:** after "Password updated" on Mac Safari, two dark blocks sat under the angled header and cleared by themselves. The header reaches past its card's edges (full width); when a step hides its card, Safari repainted only the card's own area. **Fix:** `body.signin .signin-head` gets its own layer (`transform:translateZ(0)`), so Safari removes all of it. Applies to the ten sign-in pages; none has fixed-position content inside its headers.
- **Checks:** Chrome renders unchanged (the done screen at 390 / 584). Not reproducible outside Safari here -- Joel to say if it ever recurs.

## 2026-10-22 · no packet (sport picker branding) · **production**
- **Shipped by:** Joel ("Ship it now"); operator `Nathan <joelhauserman@gmail.com>`. Branch `signin-brand` from `main`. **Cache:** v291. Frontend only (`signin.html`, `css/components.css` -- rules scoped to `body.landing`, the picker).
- **Built:** "The spot" beside the KNUCKLEBALL wordmark (pocket in the sport's accent), and each sport's card shows its own mark (white cells, gold / rally-pink pocket) instead of a drawn ball. Fonts unchanged: they were already the brand set (Black Ops One, Big Shoulders Display, Archivo) -- `docs/design/DESIGN.md` still lists the pre-D2 fonts.
- **Checks (local):** marks render with the right colours in both cards and the header; no ball graphics left; Pitcher / Coach screen and its sign-in links unchanged; screenshots at 390.
- **Open:** the Pitcher / Coach line icons and the "Always a Step Ahead" tagline are unchanged (Joel didn't say). `DESIGN.md` typography is stale.

## 2026-10-22 · no packet (password-reset link opened the sport picker) · **production**
- **Shipped by:** Joel ("Ship it now"); operator `Nathan <joelhauserman@gmail.com>`. Branch `fix-reset-link` from `main`. **Cache:** v290. Frontend only (`signin.html`).
- **Found:** Joel's reset email opened "Which sport?". The reset page asks Supabase to return to `reset-password.html?sport=…`; when Supabase doesn't use that address it falls back to the Site URL, which since Oct 21 is `signin.html` (the picker), and the picker ignored the token. **Fix:** the picker hands any `#…type=recovery` link to `reset-password.html` (query and token kept) before anything else, signed in or not; the landing page's forwarder already passes tokens to the picker. Production's reset template uses `{{ .ConfirmationURL }}` (implicit flow, token in the hash).
- **Checks (local):** picker + recovery link -> reset form (signed out and signed in); `/` + recovery link -> reset form; a signup token and a plain visit unchanged; signed-in plain visit -> the app.
- **Open:** Joel's dashboard step -- add `https://knuckleballonline.com/**` to production's Redirect URLs so Supabase uses the reset page's own address (with `?sport=`) and never falls back. The picker's branding (fonts, artwork, "The spot" per sport) is being redone separately.

## 2026-10-22 · no packet (Live Game: No read, "Record Velocity"; the session menu is the mark) · **production**
- **Shipped by:** Joel ("ship these UI changes to production now"); operator `Nathan <joelhauserman@gmail.com>`. Branch `ui-noread-mark` from `main` (only the UI half of `live-game-r3`'s commits 9a34cdc..bb194c3, applied to `bullpen-tracker.html`; R3 Stage B stays on its branch). **Cache:** v289 (above every version `live-game-r3` used). Frontend only; no database or function change.
- **Live:** in a Live Game's velocity step, "No read" over the chart's top-right two cells (brand mid green, white text) clears any speed and moves on; Next pitch spans the full last row; the prompt says "Record Velocity" while the speeds are up (phones too). An untouched bar still saves no reading. The phone session menu button is the main mark ("The spot"): white cells like the names on that line, the bottom-right pocket gold (rally pink in softball), no lighter square.
- **Checks (this build, local, staging config):** No read 11/11 at 390 / 820 / 1180; the mark 6/6 (softball pocket rally pink checked separately); r1 47, r2 55, r3 20, outadv 8, r4 18, r5 5, glitchfix 5, fc65 8, lgr3 27 -- all pass.
- **Open:** Joel's phone check. While the speeds are up, the two corner cells under No read can't be tapped as the next pitch's spot (No read or Next pitch first).
## 2026-10-22 · no packet (Live Game velocity: No read, "Record Velocity"; the session menu is the mark) · **staging (local), branch**
- **Asked by:** Joel. Branch `live-game-r3` (rides with R3 Stage B). **Cache:** v288 (v284 had No read beside Next pitch; Joel moved it. v285 had the mark's pocket gold on a lighter square).
- **Built:** "No read" covers the chart's top-right two cells (v287; one cell in v285-v286) in the brand's mid green (`--brand-mid`, white text: away from the speeds and Next pitch, still a 44px+ target); Next pitch spans the whole last row again. No read clears any speed (an accidental touch of the bar) and moves on. While the velocity step is up, those two corner cells can't be tapped as the next pitch's location (No read or Next pitch first). The phone session menu button's 9 dots are now the main mark, "The spot" (index.html's `kb-mark` shape), its cells in the header's white like the team and pitcher names, the bottom-right pocket lit in the sport's accent (gold; rally pink) as in the logo, with no lighter square behind it (v288, Joel); same label and tap target. While the speeds are up, the prompt under the chart says "Record Velocity" (was "Tap where the pitch landed"; phones showed nothing). Unchanged: an untouched bar records nothing -- only a tap, the ‹ › arrows or a swipe save a speed.
- **Checks:** headless at 390 / 820 / 1180: 11/11 each (prompt, No read fills the top-right cell and is what a tap there hits, brand mid with white text, Next pitch full width, untouched = no reading, tap 88 then No read = none, Next pitch keeps a tapped speed); the menu mark 5/5 (nine cells, gold pocket, label, 44px target, opens the sheet). r1, r4, r5, glitchfix pass.
- **Open:** ships with Stage B unless Joel wants it sooner.

## 2026-10-22 · Live Game R3, Stage B · **staging**
- **Packet:** `plans/live-game-r3-review.md` Stage B, decisions 1-8 in `plans/live-game-r3-preconditions.md` (Joel: all yes). Branch `live-game-r3`. **Cache:** v283 (local staging site). Migration `20261025000000_live_game_r3b` on **staging only**; `send-session-report` staging **v68**.
- **Built:** a pitcher's line stays open for the runners he left. `sessions.final_at` (full lock), `exit_runs` / `exit_er` / `exit_bb`, `relieved_session_id`, `left_owners`; `pitches` / `game_events.charged_runs` + `charged_prev_session`; `r3_apply_relief` (server only, from the reliever's `sync_session`, up the relief chain, capped); `r3_finalize_stale` + pg_cron `r3-final-lock` every 15 minutes (6 hours after his save); the H1 lock covers the new columns; `compute_game_summary` adds `exit_*` and `provisional`; every earlier saved session backfilled final; `pitches.hbp_swing` dropped (decision 1). App: each runner carries its owner; the hand-off carries the game id, owners and names; "Who was pitching?" under "Starting mid-game?" with runners on (this device's games from the last 6 hours, plus the team's open games online, or Not charted); History adds the charged-after runs / ER / BB, a "Line open" tag, and holds Send / View report while open. `send-session-report`: 409 `line_open` for a provisional game; the starter's report says how many of the runners he left scored after he left.
- **Deviations:** `runners_left` stays the shipped count (`left_owners` carries owners -- decision 3); reports aren't sent at save, so an open line holds the buttons instead (decision 7); the reliever's report keeps "charged to the previous pitcher" (no name lookup on the server); a starter not saved after a day lets the relief save unlinked rather than wait forever.
- **Checks:** `supabase/tests/live_game_r3b.sql` on staging (rolled back): starter open, reliever's homer charges him R 2 / ER 1 and locks him, summary R 2 ER 1 not provisional; stranded -> final, exit NULL; the chain (reliever 1 leaves the starter's runner, reliever 2 lets him score -> the starter); the cap (5 claimed, 1 charged); bullpen final at save; missing starter -> `relieved_not_saved`; API writes of `exit_runs` / the link refused; a pitcher linking to a teammate's coach-charted game refused; API can't call the charging function; no change after final; the 6-hour job; the cron job scheduled. Rollback ran in a rolled-back transaction (columns gone, `hbp_swing` back, job and functions gone); staging left on Stage B, 29 policies, 0 open games. Headless: earlier suites 193/193; `lgr3b` 21/21 at 390 and 1180. Report caption rendered locally.
- **Open:** Stage C -- the real phone pass (both sports, a reliever with the starter's runners scoring, the editor, -K / -B) and real staging reports (a starter who left runners on and his reliever, and a bullpen); staging's `REPORT_SITE_ORIGIN` still `.68` (Mac on `.19`). Then production: backup, migration, site, function -- Joel's call.

## 2026-10-22 · Live Game R3, Stage A · **production**
- **Shipped by:** Joel ("ship stage A to production first, then build R3 Stage B"); operator `Nathan <joelhauserman@gmail.com>`. Branch `live-game-r3` → `main` (admin merge; also carries the R3 packet and preconditions). **Cache:** v282.
- **Checked first:** production's `sync_session` identical to staging's pre-R3 copy (md5 `d85a1373…`), the old CHECK (-999..999), 0 negative `pitch_count_adjust`, 29 policies; `main` had nothing the branch lacked; the branch's committed config points at production.
- **Backup first:** `~/knuckleball-backups/2026-10-22-0936-{schema,data}.sql` (29 policies; 123 sessions, 2,470 pitches).
- **Database:** dry run listed only `20261024000000_live_game_r3a`; applied before the merge. After: CHECK 0..999; `sync_session` = staging's (md5 `8df74e48…`), grants unchanged; 29 policies; 123 sessions / 2,470 pitches unchanged by it. `supabase/schema/schema.sql` regenerated (diff = exactly the migration).
- **Counts since Oct 21 (not the migration):** the daily A1 deletion job purged one login at 09:17 UTC Oct 22 (2 profiles, 8 sessions tombstoned, 100 pitches removed) and one bullpen (36 pitches) was saved -- 2,534 + 36 − 100 = 2,470.
- **Function:** `send-session-report` not redeployed (the branch changes only two comments in it); production stays on version 41.
- **Open:** Joel's phone check (+K then −K leaves the pitch count up; an error that scores, edited to a hit, becomes earned). `pitches.hbp_swing` is dropped with Stage B.

## 2026-10-21 · Live Game R3, Stage A · **staging**
- **Packet:** `plans/live-game-r3-review.md` (Jordan's review of PR #6); preconditions `plans/live-game-r3-preconditions.md`, Joel "all yes" to its 8 decisions. Branch `live-game-r3`. **Cache:** v282 (local staging site). Migration `20261024000000_live_game_r3a` applied to **staging only**.
- **Built:** A1 -- the app no longer sends, saves or reads `hbp_swing` (History's select included); `sync_session` stops writing it; the column is dropped with Stage B (decision 1). A2 -- the at-bat editor re-runs the runs from the edited play to the end of its inning (`gameReplayLedger`: the batter's error taint, would-be third outs, inherited / unearned splits) and re-derives SF / SAC (`gameSacrifice`, now shared with the play itself); earned runs set by hand stay; the + Ball-walk runner drags go through one helper (`gameLedgerDrags`) so a replay does the same. A3 -- a batter who reaches on a play that put out an inherited runner takes the inherited flag (9.16(g)). A4 -- only +K / +B count toward the pitch count; −K / −B and the top-bar Balls / Strikes move the count only. Database: `sessions_pitch_count_adjust_check` 0..999; `sync_session` stores `greatest(0, ...)` so an old app's queued negative adjustment saves as 0. `docs/cf-logo-mown.md` was fixed separately (PR #14). `.15` comments in `send-session-report/index.ts` now point to CLAUDE.md (comment only; not redeployed).
- **Deviations from the packet:** production already had R1 / R2 / runners_left, so A1 and A4 are a new migration for both projects (not edits to shipped files, not staging-only drops); the `hbp_swing` drop moves to Stage B; policies 29, not 34.
- **Checks:** `supabase/tests/live_game_r3a.sql` on staging: negative insert refused; an old app's -3 saved as 0 with an `hbp_swing` pitch (column NULL); +2 saved as 2. Rollback script ran inside a rolled-back transaction (CHECK back to -999..999), staging left on the new CHECK. Policies 29. Headless: the 8 existing suites 166/166; new suite `lgr3` 27/27 (A4 7, A3 6, A2 12, 2 queue checks); the same suite against main's app fails 13 -- every changed behaviour.
- **Open:** Stage B (next). Real phone pass and staging reports (Stage C) after B. Production: Stage A's migration, then the site, after a backup -- Joel's call. Staging's `REPORT_SITE_ORIGIN` is `http://192.168.1.68:8000` but the Mac is on `.19` today: emailed staging report links won't open until the secret or the router is fixed.

## 2026-10-21 · L1 landing page · **production**
- **Shipped by:** Joel ("run plans/l1-landing-page.md", then "Ship now (admin merge)"); operator `Nathan <joelhauserman@gmail.com>`. Packet `plans/l1-landing-page.md`; branch `l1-landing-page` → `main` via PR #11 (admin merge -- `main` needs a review). Commits `9612af0` (media), `1c161f1` (landing page at `/`, sign-in move), `f24a698` (docs, bundle removed). **Cache:** v281. Frontend only.
- **Gate 1 deviation:** `index.html` was the Which sport? / Pitcher-Coach picker, not a sign-in form (sign-in is `login.html`, sign-up separate pages). Joel kept the plan: the picker moved to `signin.html` unchanged except `noindex` and a `#signup` hook (its cards open `pitcher-signup.html` / `coach-signup.html`); `login.html`'s sport-unknown bounce and Back and the join pages' Back links → `signin.html`; privacy / terms footer brand links → `/` (link targets only, no policy wording). Footer "Delete account" → `delete-account.html` (privacy has no deletion anchor). Manifest unchanged (start_url already `/bullpen-tracker.html`). `sw.js`: `/signin.html` precached; `media/hero-*` and `media/shots/*` never cached.
- **Checks (local, staging config):** 1, 2, 3, 5, 6, 8, 9, 10, 11, 12 pass; 4 (fresh staging sign-up, sends a real email) and the sync half of 7 (needs a real login) not run. **Live:** `/`, `/signin.html`, `/media/hero-poster.jpg` 200; `/` carries 10 `signin.html` links; `/signin.html` noindex; the film serves byte ranges (206).
- **Open (Joel, on device):** installed home-screen app opens the app (not the landing page); Safari signed out → landing page, film plays, Sign in works; a password-reset email ends on the reset form. **Recommended (dashboard, both projects):** Site URL → `https://knuckleballonline.com/signin.html` and add it to Redirect URLs (the forwarder covers it meanwhile). **Packet §8 follow-ups:** "$—" / "Price not set" tiers, the arm-care teaser, "Talk to us", the designer's draft copy.

## 2026-10-21 · H1 grace path closed · **production**
- **By:** Joel ("close the H1 grace path"); operator `Nathan <joelhauserman@gmail.com>`. Branch `h1-grace-close`. No app or cache change.
- **Conditions (CLAUDE.md):** >= 14 days since H1 (Oct 5 -> Oct 19, met); no old-path write for a week (production's newest unsealed session was created Oct 7; none in the last 7 days, rechecked just before the close).
- **Leftovers shown to Joel first:** production 69 saved-but-unsealed, 0 unsaved; staging 49 saved-but-unsealed and 2 old unsaved test rows (Sept 23 with 2 pitches, Sept 26 with none) -- deleted on staging at Joel's word (scoped to their ids and `ended_at is null`).
- **Migration `20261023000000_h1_grace_close`:** drops the five "H1 grace" policies (CLAUDE.md said six -- a miscount; H1 created five) and seals every saved session. Rollback `supabase/rollback/20261023000000_h1_grace_close_down.sql` re-creates the policies exactly as production had them (read from `pg_policies`); sealing stays.
- **Staging first:** 34 -> 29 policies, 0 grace, 0 unsealed; `supabase/tests/h1_grace_closed.sql` (rolled back): an old-app session insert refused, `sync_session` saves and seals, adding a pitch afterwards refused.
- **Production:** backup `~/knuckleball-backups/2026-10-21-1538-{schema,data}.sql` (34 policies); dry run listed only this migration; after: 29 policies, 0 grace, 0 saved-but-unsealed, 122 sessions and 2,534 pitches unchanged. `supabase/schema/schema.sql` regenerated (29 policies).
## 2026-10-21 · Live Game rework + Release 1 + Release 2 (v280) · **production**
- **Shipped by:** Joel ("check it and assuming everything is good lets ship the live game branch"); operator `Nathan <joelhauserman@gmail.com>`. PR #6 (`live-game-back-more` → `main`), merge `98d2015` -- an admin merge (Joel's choice): `main`'s ruleset needs one approving review and an author can't approve his own PR. **Cache:** v280.
- **Checked first:** `main`'s new commits since Oct 19 (four uploads) only add `plans/l1-landing-page.md` and `plans/l1-landing-bundle.zip` -- nothing overwritten; the branch merged cleanly; the branch's committed config points at production.
- **Backup first:** `~/knuckleball-backups/2026-10-21-1526-{schema,data}.sql` (34 policies; the first attempt hit a Supabase API 502 and was retried).
- **Database:** production's `sync_session`, `sessions_h1_lock` and `compute_game_summary` checked first (the Oct 15 / Oct 17 versions the migrations replace); the dry run listed exactly `20261019000000_pitch_count_runs`, `20261020000000_live_game_r1`, `20261021000000_live_game_r2`, `20261022000000_runners_left`; applied before the merge. After: 34 policies; the 10 new columns present; `sync_session` / `compute_game_summary` the new versions; 122 sessions and 2,534 pitches intact; `supabase migration list` identical local / remote. `supabase/schema/schema.sql` regenerated.
- **Function:** `send-session-report` deployed to production (version 41) from the files on `main`; `REPORT_SITE_ORIGIN` still unset on production.
- **Site:** knuckleballonline.com serves `kb-shell-v280` (checked).
- **Docs:** CLAUDE.md gets "Live Game charting now" (supersedes the G5 section where they differ).
- **Open:**
  - Joel's production phone check (a short Live Game and its report; installed apps take the "new version" bar);
  - the H1 grace path close (due since Oct 19) is still open;
  - `pitches.hbp_swing` is unused (HBP on swing was removed) -- leave or drop later.

## 2026-10-21 · Reports: baseballs on the field only (dots restored) · **branch + staging function**
- **Branch:** `live-game-back-more` (PR #6). Joel: "just when it's the graphic of the baseball field". `svg.ts` back to its state before `b61149b` (coloured dots with halos, golden-angle spacing) for every location chart in game and bullpen reports; the field charts (`diamond.ts`) keep their baseballs (ringed on the pitch-type fields).
- **Proven:** Deno builds: the game report's four field charts draw 28 baseballs for 7 balls in play (7 ringed); the bullpen report has 0 baseballs and its dots and halos back; `deno check` passes.
- **Function (staging):** redeployed with this (version 67) so the reports Joel checks match. Production untouched.

## 2026-10-21 · send-session-report to staging (v66) · **staging**
- **Asked for by:** Joel. Commit `b61149b`. Production untouched.
- **Carries:** everything on the branch -- since v65: the force wording ("out advancing to 3B (force)"), baseballs on the field charts, every pitch dot a ringed baseball.
- **Open:** Joel to view new staging reports (game and bullpen) on his phone, then ship.

## 2026-10-21 · Reports: every pitch dot is a baseball · **branch (not shipped)**
- **Branch:** `live-game-back-more` (PR #6). Report only (`send-session-report/svg.ts`, not deployed). Joel: "Yes, every dot".
- **Changed:** every pitch mark in the game and bullpen reports (the location charts by type / result / side, "The pitches that mattered", "What led to it", the U14 exact / RA hit grids) is a small baseball ringed in its colour, instead of a coloured dot with a halo; pitches in one cell sit apart in a small centred grid inside the cell (was a golden-angle pile); seams shown where the ball is big enough. U14 misses stay hollow grey rings (not colour-coded). The print rule still outlines the ring (`.kb-dot`). Reports already sent never change.
- **Proven:** a game report and a bullpen report built in Deno: no halos left, 52 baseballs on the pen report; screenshots (crowded cells, the pitch-type grids, "The pitches that mattered"); `deno check` passes for send-session-report and rerender-reports.

## 2026-10-21 · Game report: baseballs on the field charts · **branch (not shipped)**
- **Branch:** `live-game-back-more` (PR #6). Report only (`send-session-report/diamond.ts`, not deployed). No app or database change.
- **Changed:** every field chart in the game report ("Balls in play — the field": all, by result, by how it was hit, by pitch type) draws a baseball for each ball in play in a box instead of the number -- several in one box sit in a small grid with space between them, all inside the box (more than nine: nine and "+N"). The pitch-type fields ring each baseball in that pitch's colour. The box shading stays, lighter. Caption updated. Reports already sent never change.
- **Proven:** a game report built in Deno: no numbers left on the fields, 28 baseballs for 7 balls in play across the four charts, 7 colour rings on the pitch-type fields; screenshots; `deno check` passes.

## 2026-10-21 · Live Game: a force elsewhere with no out at first is a fielder's choice · **branch (not shipped)**
- **Branch:** `live-game-back-more` (PR #6). **Cache:** v280. Asked for by Joel. No database change; report wording in `send-session-report` (not deployed; staging has v65).
- **Changed:** a ground ball or bunt out with runners on whose fielders (after the first) show a force at second, third or home and none at first is saved as a fielder's choice: the batter safe at 1B, the forced runner out, the other runners pushed as on a single and asked as normal (a third out goes straight to Confirm). Joel's case, 1B and 2B with two out, 6-5: "Fielder's choice 6-5 — batter safe at 1B · Runner from 2B out advancing to 3B (force) · Third out" (was "Ground ball out 6-5 · Runner on 2B held · Runner on 1B held · Third out"). With 1B in the taps (6-4-3) it stays a double play. Back returns to the fielders as the out that was tapped. A force now reads "out advancing to 3B (force)" in the confirm sentence and the report.
- **Proven:** headless Chrome, 8 new checks (Joel's case and how it saves -- FC, batter to 1B, one out, inning over; the no-out case asking the runner from 1B; 6-4-3 unchanged; Back from both) and every earlier set at 390, 820 and 1180; `deno check` passes; the report's runner text checked.

## 2026-10-21 · send-session-report to staging (v65) · **staging**
- **Asked for by:** Joel ("deploy the report function to staging first", before shipping). Commit `bedb336`. Production untouched.
- **Carries:** every report change on the branch since v64 -- "doubled off", 6U-3, out at / out advancing (with the base), runners left on base, the inherited-runs line.
- **Open:** Joel to view a staging game report on his phone (History -> View report), then ship.

## 2026-10-21 · Live Game: runner answers one size, "ADV TO" · **branch (not shipped)**
- **Branch:** `live-game-back-more` (PR #6). **Cache:** v279. Asked for by Joel. No database or function change.
- **Changed:** the runner question's answers read HELD · ADV TO 2B · ADV TO 3B · ADV TO HOME · OUT, all the same size as HELD / OUT (the "ADV TO" ones on two lines inside the button). Saved values unchanged.
- **Proven:** every label inside its button, one size, at 320, 390, 820, 1180; screenshot; every check set at 390, 820, 1180 (runner-question labels updated).

## 2026-10-21 · Live Game: the "jumps back" glitch, no velocity Reset, bigger position badges · **branch (not shipped)**
- **Branch:** `live-game-back-more` (PR #6). **Cache:** v278. Asked for by Joel. No database or function change.
- **Glitch (Joel: tap Charting, it opens the chart / Resume, the next tap jumps back):** opening the app online paints the cached screen at once, then the background catch-up (`loadFullContextOnline` -> `onTeamChange(teams[0], true)`) reset the team to the first one, the pitcher to the roster's first, the screen to Home, and reloaded the draft (`refreshDraftState` drops an open session back to "Resume session") -- landing a few seconds in, right on the next tap. Fixed in `reloadTeamKeepingPlace`: when the screen is already up, the catch-up keeps the team, pitcher, screen and an open or resumed session (with a pitch in progress). A first load (nothing painted) still starts fresh.
  - Proven in headless Chrome with the server half of `onTeamChange` stood in by its own resets (the real draft loader): the old path lands on Home with the session closed; the new one stays on the chart with the session and the pending pitch, and the next tap carries on; History stays History; a first load still lands on Home (5/5 at 390, 820, 1180). **Not run:** the real online path (headless runs with Supabase blocked); Joel's phone check.
- **Velocity:** Reset removed; Next pitch is the full row.
- **Position badges:** 16 px (the type scale's next size up from 13), 14 px under 360 px wide, cell-relative on iPad / laptop; every badge (with its tap order) checked inside its box at 320, 375, 390, 430, 820, 1180.
- **Proven:** every check set at 390, 820 and 1180 (47, 55, 20, 8, 18, 5, 5 -- all passing); screenshots.

## 2026-10-21 · Live Game: Runs in the top bar, runners left, inherited runs · **branch + staging database (not shipped)**
- **Branch:** `live-game-back-more` (PR #6). **Cache:** v277. Asked for by Joel. Report change in `send-session-report` (not deployed).
- **Database (staging, Oct 21):** migration `20261022000000_runners_left`: `sessions.runners_left` (games; 0-3; H1-locked), written by `sync_session`, returned by `compute_game_summary`. Policies 34 before and after. Rollback: `supabase/rollback/20261022000000_runners_left_down.sql`. Test: `supabase/tests/runners_left.sql` on staging, rolled back: runners_left 2, runs 0, ir 2, irs 1; changing it refused; a bullpen stores null.
- **Changed:**
  - **Runs** in the top bar (phone status bar and the iPad / laptop readout, beside Batter #): runs charged to this pitcher; inherited runners who scored show apart under it ("+1 inh").
  - **Runners left on base** when the game is saved (the pitcher came out, or the game ended mid-inning) are saved; the report says "Left 2 runners on base when he came out."
  - **Inherited runs** labelled where they happen: the confirm sentence ("Runner from 3B scored safely (inherited run) · 1 run scored (1 inherited)"), the at-bat log ("1 run (1 inherited)"), and the report ("1 of the 2 runners he inherited scored — charged to the previous pitcher, not in his R or ER."). They stay out of his R and ER (Release 2).
- **Proven:** headless Chrome: 5 new checks (Runs box, the inherited run in the confirm sentence, his R 0 / inherited 1, "+1 inh" in the bar, runners left 2 queued) at 390, 820 and 1180, and every earlier set; screenshots of both bars; the report in Deno (the two lines, the log, an older game without them); `deno check` passes.
- **Shipping order** now adds `20261022000000` after the other three migrations.

## 2026-10-21 · Live Game: five fixes from Joel's list · **branch (not shipped)**
- **Branch:** `live-game-back-more` (PR #6). **Cache:** v276. Asked for by Joel. No database change; the report's at-bat log reads the new "out at" too (`send-session-report`, not deployed).
- **Changed:**
  1. With runners on, the fielder prompt reads "Record outs, tap in order, then Done".
  2. On a hit, error, FC or ground ball, OUT for a runner asks "at which base?" (Out at 2B / 3B / home; saved as `thrown_out` with `at`). The confirm sentence says safe at / out at / scored safely for every runner.
  3. A third out and a home run (over the fence or inside the park) no longer save by themselves: they stop on "Confirm the play" ("... · Third out", "Home run (fly ball) · Runner from 1B scored safely · 2 runs scored"); once the third out is made nobody else is asked. Back from a homer's confirm returns to where it left the park (or who fielded it).
  4. Velocity: the speeds are cell-sized buttons on the chart's own cells (no dark band, no white bar, no dark fill on the chosen one); the gold window over the middle button marks the speed and a tapped speed slides into it; small < > at the ends. Cell steps are measured from the buttons (`veloStep`).
  5. More: Hit by pitch and Rare plays ▸ above New batter and New inning.
- **Proven:** headless Chrome at 390, 820 and 1180: Release 1 47/47, Release 2 55/55, runner questions 20/20, out advancing 8/8, and 18 new checks (HR confirm + Back + save, inside-the-park confirm + Back, third-out fly with nobody asked, safe at 3B, the prompt text, More order, velocity: no band, five cell-wide buttons, no fill and the window on the middle button, a tap sliding into the window, > to 76); screenshots; `deno check` passes. Older checks updated where the behaviour changed on purpose (third out / homer now confirm, OUT asks a base, the prompt text).

## 2026-10-21 · Live Game: doubled off, or out advancing · **branch (not shipped)**
- **Branch:** `live-game-back-more` (PR #6). **Cache:** v275. Asked for by Joel. No database change; the report's at-bat log names it too (`send-session-report`, not deployed).
- **Changed:** after a caught ball (fly, line drive, pop-up, foul out), OUT for a runner asks "Runner from 1B out — how?": **Doubled off**, or **Out advancing to** each base ahead of him (2B / 3B / home; Joel: "whatever base they're trying to advance to"), or Cancel. Saved as `how: 'out_advancing'` with `at` (the base; runner_advances already allows any JSON) or `doubled_up`. The confirm sentence reads e.g. "Runner from 1B out advancing to 3B". Back leaves the question first. A ground-ball OUT is still thrown out, no question.
- **Proven:** headless Chrome: 7 new checks (the question and its bases, Back, the sentence, saved `{from:1,to:0,how:'out_advancing',at:3}` with 2 outs, a runner from 2B offered 3B / home only, doubled off saved, a ground ball not asked), Release 1 47/47, Release 2 55/55, runner questions 19/19 at 390, 820 and 1180; screenshot; `deno check` passes.

## 2026-10-21 · Live Game: confirm the play · **branch (not shipped)**
- **Branch:** `live-game-back-more` (PR #6). **Cache:** v274. Asked for by Joel. No database or function change.
- **Changed:** replaces "Move Runners, or Next": once the batter and every runner are settled (and on an out with the bases empty, replacing "Out recorded — tap Next"), the prompt reads **Confirm the play** and the play is written out under the field, e.g. "Fly ball out to LF · Runner from 3B tagged up and scored · 1 run scored", "Ground ball, double play 6-4-3 · Runner from 1B forced out at 2B", "Batter reached 2B on an error by SS (E6) · Runner on 3B held". Dragging a runner still fixes it (the words follow); Next saves. Kept within the field's width.
- **Proven:** headless Chrome: the sentence for ten plays (fly with a tag-up, bases-empty fly, 6-4-3, 3U, line drive + doubled off, single + runner to 3B, double with two scoring, E6 to 2B, FC 6-4 with a run, and none while a runner is still asked); width inside the field at 320, 390, 820 and 1180; Release 1 47/47, Release 2 55/55, runner questions 19/19 at 390 and 1180; screenshots.

## 2026-10-21 · Live Game: "Move Runners, or Next" · **branch (not shipped)**
- **Branch:** `live-game-back-more` (PR #6). **Cache:** v273. Asked for by Joel. No database or function change.
- **Changed:** once every runner is answered (hits, errors, FC, outs), the yellow prompt reads "Move Runners, or Next"; a double play keeps its label in front ("Double play 6-4-3 — Move Runners, or Next"; phones "DP 6-4-3 · Move Runners, or Next").
- **Proven:** headless Chrome: the three prompt states read as above; Release 1 47/47, Release 2 55/55, runner questions 19/19 at 390, 820 and 1180.

## 2026-10-21 · Live Game: where did each runner end up? · **branch (not shipped)**
- **Branch:** `live-game-back-more` (PR #6). **Cache:** v272. Asked for by Joel. No database or function change.
- **Changed:** after a ball in play with runners on (hit, error, FC, out), once the batter is settled each runner is asked about, lead runner first: "Runner from 2B -- where did he end up?" with cells in the row under the field: HELD (not forced), each base he could reach (a forced runner starts where he was pushed), HOME when no runner ahead is still on base, OUT. Runner on 3B + any ball in play: HELD · HOME · OUT; runner on 2B + single: HELD · 3B · HOME · OUT; runner on 1B + hit: 2B · 3B · HOME · OUT. Next waits for every answer; Back undoes the last; dragging works again once answered. Saved as runner moves (forced / advanced, or tagged up on a catch; thrown out, or doubled off on a catch); a third out saves the play.
- **Proven:** headless Chrome: the new checks 19/19 (each of Joel's cases, Next waiting, a held lead runner blocking the trailing one, Back, a runner out, error and FC asking, the third out), Release 1 47/47 and Release 2 55/55 at 390, 820 and 1180 (their Next now answers the questions with the runner's current base); screenshot.

## 2026-10-21 · Live Game: Unassisted with runners on (6U-3) · **branch (not shipped)**
- **Branch:** `live-game-back-more` (PR #6). **Cache:** v271. Asked for by Joel. No database change; the report writes 6U-3 too (`send-session-report`, not deployed).
- **Changed:** a ground ball or bunt out with runners on: after "Who fielded it?", **Unassisted** sits beside Back until a second fielder is tapped. It means that fielder made an out himself at his own base (SS stepping on second forces the runner from first); then tap where he threw, then Done. Saved as the fielder twice in a row (SS, SS, 1B), written 6U-3 in the app and the report. A tap on a selected position still always unselects it (Joel: the more common fix).
- **Proven:** headless Chrome: Release 2 55/55 (new: Unassisted offered after the first tap, adds SS again, the runner from 1B forced at 2B, "Double play 6U-3", saved fielders SS-1B with 2 outs), Release 1 47/47 at 390, 820 and 1180; `deno check` passes.

## 2026-10-21 · Live Game: a tap selects or unselects a fielder · **branch (not shipped)**
- **Branch:** `live-game-back-more` (PR #6). **Cache:** v270. Asked for by Joel. No database or function change.
- **Changed:** on "Who fielded it?" / "Who made the out(s)?", tapping a selected position unselects it (the rest keep their order). Because a second tap no longer means "the same fielder made it", "Who made the out?" (ground ball or bunt, bases empty) gets an **Unassisted** button beside Back. With runners on, the "6, 6 = he stepped on second" double tap is gone too.
- **Proven:** headless Chrome: Release 2 51/51 (new: Unassisted offered, a second tap unselects with the bases empty and with runners on), Release 1 47/47 at 390, 820 and 1180; screenshot.

## 2026-10-21 · Live Game: HOME / FOUL / FENCE fit their buttons · **branch (not shipped)**
- **Branch:** `live-game-back-more` (PR #6). **Cache:** v269. Asked for by Joel (HOME ran outside its cell on his phone). No database or function change.
- **Cause:** the word labels' smaller size was overridden by the later `.g5-res-count` rule, so HOME / FOUL were drawn at 26 px (25 px on iPad / laptop), filling their buttons in Chrome and spilling over with the phone's own font.
- **Changed:** the word sizes now win (17 px; FENCE / HOME 14 px; 15 / 12 px under 360 px wide; 16 / 13 px on iPad portrait; iPad / laptop cell-relative as intended).
- **Proven:** headless Chrome, each label's text as a share of its button: HOME 66-69%, FOUL 73-76%, FENCE 73-76% at 320, 375, 390, 430, 820 and 1180 px (was HOME 26 px and FOUL 100% on the laptop layout); screenshot; Release 1 47/47, Release 2 48/48 at 390 and 1180.

## 2026-10-21 · Live Game: double plays from the fielders · **branch (not shipped)**
- **Branch:** `live-game-back-more` (PR #6). **Cache:** v268. Asked for by Joel. No database change; one report label (`send-session-report`, not deployed).
- **Changed (an out with runners on):**
  - **Ground ball / bunt:** "Who fielded it?", then "Who made the outs? Tap in order, then Done" (Done waits for at least one). Every fielder after the first is an out at his base -- 2B or SS second, 3B third, C home, 1B or P first (the batter). SS, 2B, 1B = runner from 1B forced at 2B + the batter: "Double play 6-4-3"; a third out saves the play. Each is a runner move (force out, or tagged out when not forced) that Back undoes one at a time, then back to the fielders.
  - **Fly / line / pop:** the first tap is the catch; tap where it was thrown, or Done.
  - Both go straight to "What happened to the runners?" (no "Out recorded" step); a tapped runner offers **Doubled off** (was "Doubled up"; stored `doubled_up` unchanged; the report says "doubled off") or Tagged out.
  - Bases empty: unchanged (one tap on a catch; who fielded it / who made the out on a grounder).
- **Proven:** headless Chrome: Release 2 48/48 (new: Done waits, 6-4-3 with the force out and label, outs shown wait, Back twice, 6-4-3 saved with fielders 2B-1B and 2 outs; line drive to SS then the runner doubled off), Release 1 47/47 at 390, 820 and 1180; screenshots; `deno check` passes.

## 2026-10-21 · Live Game: outs count when the play is saved · **branch (not shipped)**
- **Branch:** `live-game-back-more` (PR #6). **Cache:** v267. Asked for by Joel. No database or function change.
- **Changed:** the Outs shown (phone status bar, iPad / laptop readout) stay put while an out (or a runner out on a hit) is being entered and go up when the play is saved -- every out on it at once. Replaces Oct 12's "count each out the moment it's called". Runners not moved stay where they were (Joel: the outs number only).
- **Proven:** headless Chrome: a ground-ball double play shows 0 outs through O, the out screen and the runner doubled up, then 2 after Next; Release 1 47/47, Release 2 37/37 at 390 and 1180.

## 2026-10-21 · Live Game: fielder pills and the ball · **branch (not shipped)**
- **Branch:** `live-game-back-more` (PR #6). **Cache:** v266. Asked for by Joel. No database or function change.
- **Changed:** SS and 2B pinched in toward each other and down to the bottom of their boxes. In whichever position box the ball landed in, the ball and the pill share the box evenly (ball above, pill below, equal space above / between / below).
- **Proven:** headless Chrome, the ball in each of the nine position boxes: no overlap, both inside the box, gaps 6/6/6 px (390), 5/5/5 (820), 7/7/7 (1180); screenshot; Release 1 47/47, Release 2 37/37 at 390 and 1180.

## 2026-10-21 · Live Game: batter first, then runners · **branch (not shipped)**
- **Branch:** `live-game-back-more` (PR #6). **Cache:** v265. Asked for by Joel. No database or function change.
- **Changed:**
  - **Errors:** after the contact, "Where did the batter end up?" 1B · 2B · 3B · HOME (slots 2-5), then the location and fielders; the batter is placed by himself and runners ahead pushed only as far as they must go (like a hit); then the runners. Back from the location returns to this question.
  - **Outs:** fly ball / line drive / pop-up -- one fielder tap is the catch and goes straight on to the runners (F8). Ground ball / bunt -- "Who fielded it?" then "Who made the out?" (6, 3 = 6-3; the same fielder twice = unassisted, U3); that second question has no Skip.
  - **Bunts:** the infield lights by itself on every play (no IF tap).
  - Hits unchanged (1B / 2B / 3B / HR first, Joel).
- **Proven:** headless Chrome: Release 1 47/47, Release 2 37/37 at 390, 820 and 1180 px (new: putout question and Back, one-tap fly out, unassisted, error to 2B pushing the runner to 3B, Back from location to the batter question, bunt lights the infield); screenshots of both new questions.

## 2026-10-21 · Live Game: "Who fielded it?" positions restyled · **branch (not shipped)**
- **Branch:** `live-game-back-more` (PR #6). **Cache:** v264. Asked for by Joel. No database or function change.
- **Changed:** each position is a pill in the prompt's yellow with its letters only (no numbers); tapped = solid yellow with the tap order small beside the letters. C just below home plate, 3B top right of its box, 1B top left, SS / 2B / P where they were, LF one box left (box 4), RF one box right (box 10), CF high in its box. The whole box still takes the tap. Saved values unchanged (`fielder` / `fielders` as positions).
- **Proven:** headless Chrome: every pill inside its box at 390, 820 and 1180 px; screenshots at 390 and 1180; Release 1 47/47, Release 2 27/27 at 390 and 1180.

## 2026-10-21 · Live Game: Rare plays regrouped · **branch (not shipped)**
- **Branch:** `live-game-back-more` (PR #6). **Cache:** v263. Asked for by Joel. No database or function change.
- **Rare plays now:** Dropped 3rd · Intentional walk / **Interference** · **Violations** / Foul bunt · Balk / ‹ More.
  - Interference → Catcher's (batter to 1B, forced runners up) or Batter's (→ Batter out, or Runner on 1B / 2B / 3B out, as before).
  - Violations → Clock ball or Clock strike (no pitch; not in the pitch count).
  - **Removed:** Missed bunt and HBP on swing (B7 dropped). `pitches.hbp_swing` (migration `20261020000000`, staging only) is now unused by the app.
- **Proven:** headless Chrome: Release 1 47/47 (incl. the new Interference / Batter's / Violations steps and the two removed buttons doing nothing) and Release 2 27/27 at 390, 820 and 1180 px; screenshot of the tray.

## 2026-10-21 · Live Game: Balk into Rare plays · **branch (not shipped)**
- **Branch:** `live-game-back-more` (PR #6). **Cache:** v262. Asked for by Joel. No database or function change.
- **Changed:** Balk (softball: Illegal pitch) moved from More into Rare plays, beside HBP on swing; "Rare plays ▸" now sits in Balk's old spot beside Hit by pitch.
- **Proven:** headless Chrome at 390 px: More shows New batter / New inning / Hit by pitch / Rare plays ▸ (Rare plays beside Hit by pitch); Rare plays has Balk, which still moves every runner up one (a run from 3B); Release 1 45/45 and Release 2 27/27 at 390 and 1180 px.

## 2026-10-20 · Live Game Release 2 (gaps review) · **branch + staging database (not shipped)**
- **Branch:** `live-game-back-more`. **Cache:** v261. No packet: the Release 2 items, with Joel's answers (fielders on the field with the prompt in the yellow badge; earned runs automatic with an override; inherited runners / the starter's walk on the reliever's line only; the at-bat editor details only; hits ask the fielder too). Plan: `plans/live-game-r2.md`.
- **Built:**
  - **"Who fielded it?" (C4):** after the location, the nine positions are buttons where they stand on the field (number and letters); tap in order (6, 3 = 6-3), Done or Skip; Back takes off the last tap. Hits, outs, errors, FC. Saved in `pitches.fielder` / `fielders`; the log reads 6-3, F8, U6, E6, to LF. Reverses G5's "no fielders on new games".
  - **Sacrifices (C2):** automatic with fewer than two out: a fly ball or line drive out with a run = SF; a bunt out that moves a runner up with no runner out = SAC.
  - **Earned runs (E1):** a run ledger on the draft (who is on each base, unearned / inherited) updated by every pitch, event and the runners screen, undone by Back. Unearned: reached on an error or catcher's interference, moved "On error", scored on a passed ball, after the inning would have ended but for errors, the extra-inning placed runner. Live line and History card show R and ER.
  - **Reliever's line (E2 / E3):** runners on at the start (hand-off or "Starting mid-game?", which now also asks the count) are inherited: IR saved on the session, their runs saved per play and left out of his R and ER. A walk to the batter he inherited at 2-0 / 2-1 / 3-0 / 3-1 / 3-2 is the previous pitcher's (left out of his BB; that runner's run too). The starter's saved game is never touched.
  - **At-bat editor (F5):** "edit" on every game pitch in the log (and "Show all" past 12): type, velocity, contact, Hit / Error / FC (FC only when a runner was out on the play), fielders ("6-3", "8", "LF"), earned runs, and Move location (the next chart tap). Changing the field location (spray box) isn't in it.
  - **Report (E6 / E7):** pitching line ER, IR / IRS, SF / SAC (columns only when there is data); the at-bat log adds the play notation, SF / SAC, and each at-bat's runner moves with why and its runs (R / ER, inherited); Results by count adds three-ball and two-strike rows, how plate appearances ended in each count, and "Leadoff batter reached base in N of M innings". A two-strike foul bunt now ends the at-bat in the log.
- **Database (staging, Oct 20):** migration `20261021000000_live_game_r2`: `unearned_runs`, `inherited_runs`, `charged_prev` on pitches and game_events; `sessions.inherited_runners` (games, H1-locked); `sync_session` writes them; `compute_game_summary`: `runs` charged to this pitcher, `er`, `ir`, `irs`, `bb_charged_prev`, `bb` without charged walks (all null for games saved before). Policies 34 before and after. Rollback: `supabase/rollback/20261021000000_live_game_r2_down.sql`.
- **Proven:**
  - `supabase/tests/live_game_r2.sql` on staging as the staging pitcher, rolled back: a reliever's game -> runs 2, er 1, ir 2, irs 1, bb 0, bb_charged_prev 1; SF and fielders stored; changing IR after saving refused; an older-style game -> er / ir / irs null.
  - Headless Chrome, real page, made-up pitcher, Supabase unreachable: Release 2 27/27 and Release 1 45/45 at 390, 820 and 1180 px, no page errors (6-3 with Back, single to LF, SF, SAC, no SF on the third out, E6 then an unearned run, runs after the would-be third out, passed ball vs wild pitch, Back restoring the ledger, the editor's five changes and a refused entry, Move location, Show all, a reliever at 3-1 with 1B / 3B: charged walk, inherited run, R 0 / BB 0, the queued IR). Screenshots: "Who fielded it?", the editor, the mid-game count.
  - The game report in Deno: ER / IR-IRS / SF-SAC columns and values, 6-3 / E6 / 2B to LF / F8 SF, runner moves with runs and ER, SB from an event, the count rows and leadoff line; an older game shows none of the new columns. `deno check` passes for send-session-report and rerender-reports.
- **Function (staging, Oct 21, Joel's OK):** `send-session-report` deployed to staging only (version 64) with the Release 2 report changes. Production untouched.
- **Not run:** a real phone; a real report generated on staging.
- **Shipping order:** production migrations `20261019000000`, `20261020000000`, `20261021000000` FIRST, then the site, then `send-session-report`. Regenerate `schema.sql`; update CLAUDE.md's G5 section.

## 2026-10-20 · Live Game Release 1 (gaps review) · **branch + staging database (not shipped)**
- **Branch:** `live-game-back-more`. **Cache:** v260. No packet: Joel's choices on the 42-gap review of v259, then four layout answers. Plan and decisions: `plans/live-game-r1.md`. Release 2 (C2, C4, E1, E2, E3, E6, E7, F5) comes later.
- **Joel held the ship** ("fix first") after his phone check of v259 passed; this goes out with the rest of the branch.
- **Built:**
  - **Hits (A1, C1):** after H, **1B · 2B · 3B · HR** (slots 2-5); HR left the location row. The batter goes to his base by himself and runners ahead are pushed only as far as they must (saved as `forced` moves). A home run's location row: OF = inside the park (keeps `spray_field` OF), FENCE = over the fence.
  - **FC (A2):** **FC · E · H · O**. After the location: "Tap the runner who was out", then the batter is on 1B; Next waits for it. Saved as `in_play_outcome = 'fc'`. Greyed with the bases empty.
  - **Runner moves kept (A4):** `batter_to` and `runner_advances` on walks, HBP, hits, errors, FC and HRs (forced pushes, drags, `hr`); outs unchanged. On a hit, a dragged runner can be **Hit by ball** (C8, an out).
  - **Bunt K (A3):** a two-strike foul bunt counts as a K in the app, `compute_game_summary` and the report.
  - **Reliever's IP (A5):** moving the inning in the top bar moves the carried-over outs too (Back restores it). **Final inning (A6):** the last inning a pitch or event happened in. **History card (A7):** counts IBB / auto ball four as BB, auto strike three as K, and shows R.
  - **More → Rare plays ▸:** Dropped 3rd (batter out / reached; only with two strikes and 1B open or two out), Intentional walk, Catcher's int., Batter's int. (batter out / a runner out), **Clock ball / Clock strike** (A8: no pitch, not in the pitch count; +K / +B stay the missed pitch, +1), Foul bunt, Missed bunt, **HBP on swing** (B7: a swinging strike with `hbp_swing`).
  - **Starting mid-game (E4):** without a hand-off, the start screen asks "Starting mid-game?" (inning, outs, runners); only his own outs count.
  - **Report (E5):** WP and BK (softball: Illegal) in the pitching line; at-bat log shows 1B / 2B / 3B / HR, FC, batter's interference and the bunt K.
- **Database (staging, Oct 20):** migration `20261020000000_live_game_r1`: `pitches.hbp_swing` (games, swinging strikes only), `sync_session` writes it, `compute_game_summary` counts the bunt K. Policies 34 before and after. Rollback: `supabase/rollback/20261020000000_live_game_r1_down.sql`.
- **Proven:**
  - `supabase/tests/live_game_r1.sql` on staging as the staging pitcher, rolled back: k=1 for a two-strike foul bunt (also with no outs counter: outs_recorded 1, derived); `hbp_swing` saved; a double's `hit_type` 2B, `batter_to` 2, forced move kept; FC saved; `hbp_swing` on a ball refused. Nothing left behind.
  - The real page in headless Chrome with a made-up pitcher and Supabase unreachable: 45/45 checks at 390, 820 and 1180 px, no page errors (double, FC, both HRs, walk, single + run, hit by ball, HBP, every Rare play, IBB, clock vs +B, inning adjust + Back, final inning, Back paths, stats, the queued row, History card = live numbers, mid-game start). Screenshots of FC · E · H · O, the hit row, FENCE, Rare plays, FC's runner question and the start screen.
  - The game report built in Deno: WP / BK columns (two runners on one wild pitch = one WP), the bunt K, 2B / FC / BI in the log, softball "Illegal". `deno check` passes.
- **Function (staging, Oct 20, Joel's OK):** `send-session-report` deployed to staging only (version 63), with the Oct 19 report changes (R, pitch count, center-field logo) and these. Production untouched.
- **Not run:** a real phone; a real report generated on staging.
- **Shipping order:** production migrations `20261019000000` then `20261020000000` FIRST (History now reads `hbp_swing` and `game_events`), then the site, then `send-session-report`. Regenerate `supabase/schema/schema.sql` after. On shipping, update CLAUDE.md's G5 section.

## 2026-10-20 · no packet (staging report links) · **staging**
- **Asked for by:** Joel. No code, database or cache change.
- **Changed:** the staging `REPORT_SITE_ORIGIN` secret: `http://192.168.1.15:8000` → `http://192.168.1.68:8000`. The Mac's address on the home Wi-Fi changed, so emailed staging report links no longer opened. Verified by the stored secret's SHA-256 fingerprint (`193306103ad0fbda…`, matching the new value).
- **Not redeployed:** `send-session-report` on staging (last deployed Oct 14). Redeploying from `live-game-back-more` would also put that branch's undeployed report changes on staging. Not checked by sending a real report email.
- **Production:** untouched. It has no `REPORT_SITE_ORIGIN`.
- **Docs:** CLAUDE.md "Staging report links" updated. The comments in `send-session-report/index.ts` still say `.15` (code unchanged; update with the next change to that file).
- **Open:**
  - reports emailed from staging before today still point at `.15`;
  - reserve `192.168.1.68` for the Mac in the router so the address stops changing.

## 2026-10-19 · Live Game: Back / More, Foul = foul tip · **branch + staging database (not shipped)**
- **Branch:** `live-game-back-more`. **Cache:** v259. Asked for by Joel (no packet). **One migration (staging only), and a report function change (not deployed):** see "Saved pitch count and runs in reports".
- **Built:**
  - **Foul:** always a foul tip. The "Foul Tip / Foul Out" question is gone.
  - **Caught foul:** recorded as In Play → Out → contact. On any contact but a ground ball, a **FOUL** button (box 14) flashes foul ground only. It's saved as an out in play in that box with `spray_field` NULL, the same columns as the old Foul Out.
  - **Result buttons:** the five buttons (K, backwards K, B, F, IP) are the chart's own cell size, a sixth row under the 5×5. They're always shown and become tappable once a location is tapped.
  - **Back and More:** under the five buttons on every layout. Undo is removed everywhere.
    - **‹ Back** steps back one tap within a pitch; otherwise it undoes the last action (pitch, event, + / − count, New batter, New inning).
    - **More** (Joel, follow-up) turns the five buttons into **+K −K · +B −B**, same cells, middle one empty, and shows **New batter / New inning** under Back / More. Any of them closes it again.
  - **− Strike / − Ball:** change the count only; the pitches stay as charted (Joel's choice). New batter, New inning and the minus buttons keep their "before" in the draft (`s.manualActs`, ordered by `seq`, never synced), so Back can undo them.
- **O / E / H (Joel, follow-up):** IP still flips to the field, but O / E / H are no longer on the field's boxes. They're the cell-sized row under the field (columns 2-4), in the same place as K / B / F / IP under the chart. O is greyed out when it would make a fourth out. On iPad / laptop the prompt sits above them, like "What happened?" on the chart side, with only ‹ Back below (no + Out / + Strike / + Ball on this step; + Out stays on the runners step for double plays). On phones the field keeps the chart's band under it while O / E / H are asked, with the badge in it (where "Tap Pitch Result" sits, spanning K to IP), so O / E / H land exactly on the backwards-K / B / F buttons and Back doesn't move (a center-field badge was tried first and replaced).
- **Contact row (Joel, follow-up):** after O / E / H, the five contact choices also leave the field for that row, letters only, all five cells: **Bu · PU · GB · LD · FB** (bunt, pop, ground, line, fly; same stored values). The prompt there reads "What type of contact?", with only ‹ Back below. + Out / + Strike / + Ball are gone from every field screen (Joel, follow-up): the location, home run and runners screens show ‹ Back (and Next › on the runners question, radar on) in the Back / More layout. An out on the bases is a runner dragged and called Out. + Strike / + Ball stay in More on the chart side.
- **Bunt: Strike Three Foul? (Joel, follow-up; later replaced, see the next Bunt entry):** a bunt's location step no longer offers FOUL on the field. With two strikes, **Strike Three Foul?** sits to the right of ‹ Back. It saves the existing two-strike foul bunt (G1b decision 11: result `foul`, `bb_type` bunt, strike three, the out, at-bat over, no location). FOUL (caught in foul ground) stays for pop up / line drive / fly ball outs. The location prompt ("Select Ball in Play Location") now sits above the field's buttons on every layout (phones: in the band; home run "Where did it leave the park?", foul ground "Where was it caught?"). It goes straight on to velocity (radar on) or the next pitch, and the log reads "Strike three foul (bunt)". Unchanged: the K stat and reports don't count a two-strike foul bunt as a K (they never did).
- **Fixed on the branch (never shipped):** the phone band code read the play while the card flipped back to the chart, after the play was already cleared, so the redraw crashed after a field play (introduced in 91cf536). Checked after the fix: strike three foul, single, homer, foul pop out and IP → Back, radar on, phone and laptop, no page errors.
- **Location row (Joel, follow-up):** IF / OF / FOUL / HR are no longer on the field's boxes. They're the cell-sized row under the "Select Ball in Play Location" prompt, in fixed slots: IF 2, OF 3, FOUL 4, HR 5. The one chosen is highlighted, and FOUL / HR toggle off when tapped again. A **fly ball** no longer lights the outfield on its own: it offers FOUL / OF / HR first, the one that can't apply greyed (HR unless a hit, FOUL unless an out). Ground ball: IF / OF. Pop up / line drive: IF / OF plus FOUL (out) or HR (line-drive hit). Bunt: see below.
- **Bunt (Joel, follow-up, replaces Strike Three Foul?):** a bunt shows IF · OF · FOUL · HR, OF and HR always greyed. Nothing lights until IF. FOUL with two strikes records the two-strike foul bunt at once (out, at-bat over, then velocity; log "Strike three foul (bunt)"). With fewer than two strikes FOUL is a caught foul bunt on an out (foul ground lights), otherwise greyed (a plain foul bunt is F on the chart).
- **All four, always (Joel, follow-up):** every contact type shows IF · OF · FOUL · HR in their slots, the ones that can't apply greyed. IF: not on a fly ball. OF: not on a bunt. FOUL: an out that isn't a ground ball, or a bunt on two strikes. HR: a line-drive or fly-ball hit. Checked all ten contact × out/hit combinations, plus a two-strike bunt.
- **Outs and the runners (Joel, follow-up):** an out's location leads to the out screen ("Out recorded — tap Next": the ball, the runners, ‹ Back / Next ›).
  - Nobody on: Next saves the play, then velocity (radar on) or the next pitch.
  - Runners on: Next asks "Tap or move runners who advanced or are out". Drag a runner to a base or home, then **Advanced / Tagged up / On error / Thrown out / Force out** (Force out added in a follow-up; saved as `force_out`, an out); or tap a runner, then **Doubled up / Tagged out**. A third out saves at once. Back undoes the last move, then returns to the out screen.
  - **Saved** with the pitch in `pitches.runner_advances` as `[{ from, to (0 out, 4 home), how }]`. This is the G1b column live games had left NULL; it allows any JSON array, and `sync_session` already sends it, so there's **no database change**. Reports don't show the reasons yet (nothing reads that column for live games); that would be a report change.
  - Hits and errors keep their own runners screen (Joel: outs only). The batter token is gone on an out.
  - **Radar off:** the "Next pitch" box on the mound is gone for every play; Next sits beside Back under the field.
  - Checked: out with nobody on → velocity; 1B + 3B → 3B tagged up home, 1B doubled up, Back ×3 to the out screen, redo, Next → `[{3→4 tagged_up},{1→0 doubled_up}]`, outs_on_play 2, runners_after 0; a double play for the third out saves itself; a hit with a runner still asks for the batter.
- **E / H / O (Joel, follow-up):** the prompt reads "In play — Error, Hit or Out?" (short form "Error, Hit or Out?") and the buttons run **E · H · O** in columns 2-4.
- **Saved pitch count and runs in reports (Joel's answers to the open items, Oct 19):**
  - **Migration `20261019000000_pitch_count_runs` (applied to staging Oct 19; production untouched):** `sessions.pitch_count_adjust` (smallint, default 0; games only by CHECK; locked once saved by the H1 lock), written by `sync_session` (0 for a bullpen). `pitcher_workload` (the roster's pitch-count line) adds it. `compute_game_summary` adds `pitch_count` (charted pitches + the adjustment, never below 0; `pitches` stays the charted count, so Strike % and the other rates don't change) and `runs` (pitches' and events' `runs_scored`; null for games that recorded none, i.e. every field game before today). Policies 34 before and after. Rollback: `supabase/rollback/20261019000000_pitch_count_runs_down.sql`.
  - **App:** the saved game carries the adjustment (+K / +B / −K / −B and the top-bar count adjust); History's game card shows the adjusted pitch count (the delete warning still names the charted pitches).
  - **Game report (`send-session-report/template_game.ts`, not deployed):** Pitches in the header, the tiles and the pitching line use `pitch_count`; an **R** tile beside H and an R column in the pitching line when `runs` isn't null. Runner reasons are not shown (Joel). Reports already sent never change.
  - **Proven:** `supabase/tests/pitch_count_runs.sql` on staging as the staging pitcher, rolled back: a game with +2 → pitches 3, pitch_count 5, runs 4 (1 + 2 + a balk's 1), Strike % unchanged; workload 11 → 16; changing the saved adjustment refused; a game with no runs recorded → runs null, a −10 adjustment floors at 0; a bullpen sending 5 stores 0. The report built from a summary with and without the new fields (Deno): "5 pitches", "4 R" and the R column; an old summary shows 3 and no R. `deno check` passes.
  - **Shipping order:** production migration FIRST (History's load reads `pitch_count_adjust`), then the site, then `supabase functions deploy send-session-report` (the template works either way). Regenerate `supabase/schema/schema.sql` after the production migration.
- **Runs (Joel, follow-up):** every runner who reaches home safe is a run, saved in the existing `runs_scored` columns (pitches and game_events; no database change): a runner dragged home and called safe on a hit / error / walk's runners screen, a runner moved home on the out screen with Advanced / Tagged up / On error, a homer (everyone on plus the batter), a forced run on a walk or HBP, a balk / illegal pitch with a runner on 3B, and the between-pitch runners screen (stolen base, wild pitch and the rest, which already counted). Total shown as **R** beside H in the stat line (phone) and the stat boxes (iPad / laptop). Back takes runs off with their play. Not counted: a runner simply tapped off a base on a hit (drag him home instead). Reports don't show runs yet. Checked: single with 3B home 1, 3-run homer 3, bases-loaded walk 1, balk with 3B 1 (Back 0), sac fly tag-up 1.
- **Pitching change carries the game over (Joel, follow-up):** saving a Live Game remembers the inning, outs, count, runners and opponent on this device (`kb:gameHandoff`). Starting a Live Game for **another pitcher on the same team within 5 minutes** asks **"Continue from where <name> left off?"** (Yes by default, showing e.g. "Inning 4 · 1 out · 2-1 · runners on 1B, 3B"); Yes starts there, No starts fresh; asked once. The inning carries too (Joel listed runners, count and outs; the inning is needed to continue the same game). The reliever's saved `game_outs_recorded` counts only his own outs, and no extra-inning runner question is asked for an inning he took over. Checked: hand-off 1 minute old → question and summary → Yes → inning 4, 1 out, 2-1, 1B + 3B, opponent kept, Set; saving that game wrote a new hand-off.
- **Adjust from the top bar (Joel, follow-up):** tapping Inning, Outs or Count (phone status bar and the iPad / laptop readout) turns the result row into **▲ · the number · ▼** in the backwards-K / B / F cells, and the prompt (phone badge, or the caption line) reads **Adjust Inning / Outs / Balls / Strikes**. Count opens on Balls; **Adjust Strikes / Adjust Balls** switches (or tap Count again), **Done** closes, a chart tap closes it too. The box being adjusted is underlined in gold. It's a correction: no walk, strikeout or third out from here (balls 0-3, strikes 0-2, outs 0-2, inning 1+). Balls and strikes move the pitch count like +B / −B; inning and outs don't. Each tap is its own Back step (`s.manualActs`, device-only). Checked on a phone: balls 0→2, strikes →1, outs →2, inning →2, Back ×5 unwound each step, pitch count 0→3→1; a chart tap closed it; laptop drawn; no page errors.
- **Pitch count follows + / − (Joel, follow-up):** +K / +B add one to the session's pitch count and −K / −B take one off; the charted pitches and Strike% stay as they are. Read from the draft's own +K / +B events (flagged `pitchCountAdj`, device-only) and −K / −B acts, so Back undoes the count too. **Live counter only:** saved sessions, History, reports and the roster's pitch count still count charted pitches (−K / −B aren't saved at all); carrying it into those needs Joel's call and likely a database change. Checked: ball (1) → +K 2 → +B 3 → −B 2 → −K 1 → −B 0 → Back ×5 → 1, no page errors.
- **More: Hit by pitch, Balk (Joel, follow-up):** the More tray adds **Hit by pitch** (tap where it went first; the existing `hbp` result: batter to 1B, only forced runners move, `runners_after` saved, then velocity) and **Balk** (the existing `balk` event: every runner up one, no count change; greyed with the bases empty). Softball shows **Illegal pitch** there instead (the existing ADV illegal pitch: runners up and a ball). Back undoes either. Checked on a phone: 1B + 3B, 1-0 → HBP loads the bases, new batter, `runners_after` 7; Back restores; Balk → runner on 2B (3B scored); Back restores; no page errors.
- **Center-field logo (docs/cf-logo-mown.md, uploaded Oct 19):** Jordan's "Strikeout" mark (home plate cut as a band, the scorebook K inside, the spot) is mown into center field: the field's own two greens cross-cut at 90° and half the stripe width, each half against its own side of the V, a 5% shade, a 10% hairline, the spot a 22% white overlay. Centered at 0.74 of the way to the fence, 0.40 of the fence distance wide, under the fence line, bases, shading and markers; never takes taps. Both sports. The spec's symbol was the 3×3 grid ("design #2") but its heading and demo use design #1, so design #1 is drawn; the field here is upright, so the spec's 45° rotation is dropped. Same drawing added to `send-session-report/diamond.ts` (`CF_LOGO`): **not deployed** -- new game reports get it only when Joel deploys that function; sent reports never change.
- **No red hint on phones (Joel, follow-up):** the small red line over the top of the chart ("Select a pitch type first" and the rest) no longer shows on phones, in bullpens or Live Games. iPad / laptop keep it.
- **Invisible 5×5 on the field (Joel, follow-up):** the same 25 boxes and tap rules, with no box outlines. Foul ground and over the fence now flash as one shape on the field drawing (like IF / OF already did), not box by box.
- **Phone step badge (Joel, follow-up):** on phones the vs RHB / vs LHB pill moves to the left of its strip under the chart, and the step badge sits beside it, running to IP's right edge: **Tap Pitch Intent** (Intent on) → **Tap Pitch Outcome** → **Tap Pitch Result** (then K / B / F / IP). There's no badge during velocity or the extra-inning question. The old "Tap where the pitch is called" / "Now tap where the pitch went" hint rows under the chart are gone (iPad / laptop keep their prompt line).
- Phones no longer show New batter / New inning under the field; Back out of the play first.
- **Evidence:** headless Chrome on the real page, offline with a made-up login. Phone, iPad portrait and iPad landscape: the result buttons are the same width as the chart cells (64 / 60 / 66 px). The click-through checked foul, ball, More, − Strike, Back ×2, New batter + Back, + Ball / − Ball + Back ×2, and In Play → Out → Pop → FOUL → box 1 → Next (`in_play` / out / pop / box 1 / field null), then Back.
- **Open:** Joel to try it on a phone; ship when approved. On shipping, update CLAUDE.md's G5 section (Foul Tip / Foul Out, fly ball auto-outfield and the on-field H/O/E, contact and IF/OF boxes it describes are superseded).

## 2026-10-17 · W1 store reviewer account · **production data**
- **By:** Joel (asked for it; ran phase 2 and the verification update himself, Claude Code's auto mode blocks production writes). No code, database or cache change.
- **Created through the app's own calls** (public sign-up, `ensure_account_setup`, `record_attestation`, `join_team_via_invite`, `set_uniform_number`, `sync_session`):
  - coach `review@knuckleballonline.com` ("App Reviewer"), head of the baseball team **Knuckleball Review**;
  - pitcher `review-pitcher@knuckleballonline.com` ("Sample Pitcher", #21, four pitch types);
  - three sealed bullpens (90 pitches, Oct 8 / 12 / 15).
  - Passwords: on Joel's Mac only, never in the repo.
- **Deviation:** both logins were marked verified with a direct `update profiles set email_verified_at` (Joel, in the SQL editor), not through `verify_email`, because those two addresses don't forward anywhere. Test accounts only. Report-eligible afterwards (`is_pitcher_report_eligible` true).
- **Open:**
  - App access form in Play Console (and later App Store Connect) with these credentials;
  - a Live Game charted by hand with the reviewer login;
  - report emails to these addresses go nowhere unless Cloudflare routing is added.

## 2026-10-17 · Terms agreement box · **production**
- **Shipped by:** Joel ("ship it"); operator `Nathan <joelhauserman@gmail.com>`. Branch `terms-agree-notice` → `main`. **Cache:** v250.
- **Backup first:** `~/knuckleball-backups/2026-10-17-1730-{schema,data}.sql` (34 policies).
- **Database:** the dry run listed only `20261017000000_terms_agreement`; applied before the site push. After: 34 policies; `profiles.terms_agreed_at` (authenticated: SELECT only); `agree_to_terms` SECURITY DEFINER. 29 existing logins (age answered, older terms) will see the box; 0 on 2026-10-17 yet. `supabase/schema/schema.sql` regenerated (also picks up A1 / U14, not regenerated since Oct 8).
- **Open:**
  - who has agreed: `select count(*) from profiles where is_primary and terms_agreed_at is not null`;
  - the Play / Apple data forms stay "Shared: No" until data is licensed.

## 2026-10-17 · Terms agreement box · **staging (database) + branch**
- **Branch:** `terms-agree-notice`. **Cache:** v250. Not shipped.
- **Database (staging):** migration `20261017000000_terms_agreement`:
  - `profiles.terms_agreed_at` (clients read, never write);
  - `agree_to_terms(version)` (SECURITY DEFINER, the caller's primary profile; idempotent, keeps the first time).
  - Policies 34 before and after. Rollback: `supabase/rollback/20261017000000_terms_agreement_down.sql`.
- **App:** existing logins that answered the age question but accepted an older terms version get a one-time box, "We've updated our Privacy Policy and Terms", with **I agree** / Sign out. Like the age box, it's decided on the online load only and never shown over the charting screen. I agree is remembered on the device at once (`kb:termsAgreed:<login>`) and sent to `agree_to_terms` best effort, then retried on later online loads, so nothing waits on the network. New sign-ups already record 2026-10-17 and never see it.
- **Proven:**
  - `supabase/tests/terms_agreement.sql` on staging, as a real login, rolled back: 7/7 (bad version refused; agree stores version and time; a second agree keeps the first time; a direct client write is refused; anon is refused). Nothing left behind.
  - The real new functions in a stub harness: 9/9 (age unanswered → no box; current version → no box; old → box; agreed on the device → no box and resent; online / offline / network error / storage blocked).
  - All tracker scripts pass `node --check`; the box drawn with the real stylesheets at 390 px, baseball and softball.
- **Not run:** a live sign-in on the local staging site (no staging test login on hand).
- **Shipping order matters:** the tracker now reads `terms_agreed_at`. Production must get the migration **before** the site push, or profile loads fail.

## 2026-10-17 · Data licensing policy change · **production**
- **Shipped by:** Joel ("ship it"); operator `Nathan <joelhauserman@gmail.com>`. Branch `policy-data-licensing` → `main`. **Cache:** v249. No database or function change.
- **Policy / terms version 2026-10-17** (Joel approved the wording, Oct 17): Knuckleball LLC may use, license or sell charting data and the statistics built from it, attributed to the player (name, team, sport, level, jersey number, throwing hand), to teams, programs, organizations, scouts and analytics companies, on the same terms to any buyer. Never sold: email addresses, passwords, age brackets, consent records, profile photos, coach notes. Parent-added players (all under-13s) only with the parent's separate agreement (COPPA). Applies to data saved on or after Oct 17, 2026. Deleted data is left out of later licensing.
- **Changed:** `privacy.html` (new section "How we may use and license charting data"; old commitment (b) "We don't sell or share your data" replaced; (a) and (e) reworded), `terms.html` (licence clause), `guardian-consent.html` (licensing sentence replaces "We don't sell or share it"), `TERMS_VERSION` 2026-10-17 in the 7 sign-up / attestation pages.
- **Open:**
  - the policy's "Changes" section promises account holders a notice (email or in-app) for a change that matters; not sent yet, needs Joel's go-ahead;
  - Play / Apple Data safety stay "Shared: No" until data is actually licensed; flip them before the first sale;
  - a lawyer's review before any sale; a parental opt-in flow is needed before any parent-added player's data could be licensed.

## 2026-10-15 · W1 site batch · **production**
- **Shipped by:** Joel ("wording is good, ship it"); operator `Nathan <joelhauserman@gmail.com>`. Branch `w1-site-changes` → `main` (also carries the W1 report `w1-preconditions`). **Cache:** v248. No database or function change.
- **Live:**
  - the status-bar inset inside the store apps;
  - in-app links to privacy / terms / reports / deletion open in the phone's browser sheet;
  - Share for reports in the apps;
  - `delete-account.html`, the deletion wording approved by Joel, for Google Play's Data safety form: https://knuckleballonline.com/delete-account.html.
- **Open:** the store apps themselves (Joel's Apple / Google enrolment, TestFlight); the iOS link tap is a TestFlight check.

## 2026-10-15 · W1 site batch · **staging (local), branch only**
- **Branch:** `w1-site-changes`. **Cache:** v248. Not shipped.
- **Changes:**
  - `css/standalone.css`: the top inset and the brand strip apply wherever the system reports an inset, so inside the iOS / Android apps too (a browser tab reports 0);
  - an in-app link handler on 13 pages: inside the app, privacy / terms / reports / the deletion page open in the phone's browser sheet (does nothing in a browser);
  - a **Share** button beside "View report", in the app only;
  - new public page `delete-account.html` (Google Play's deletion link; wording mirrors privacy.html, **awaiting Joel's approval**), precached.
- **Proven (app shells against local staging):**
  - iPhone simulator and Android emulator: the page starts below the status bar on the brand strip;
  - Android: the page detects the app, Browser and Share are reachable, a tap on Privacy opens Chrome and the app stays on its page.
- **Not tested on iOS:** the link tap (the simulator can't be tapped from the command line); it uses the same code path, so it's Joel's TestFlight check.

## 2026-10-15 · P2-05 installable app · **production**
- **Shipped by:** Joel ("ship it"); operator `Nathan <joelhauserman@gmail.com>`. Branch `p2-05-pwa-install` → `main` (also carries `docs-u14-reset`). **Cache:** v247. No database or function change (dry run: up to date).
- **Live:** the manifest and iOS tags on all 15 pages; the KB icon, 5 icons and 40 splash images precached; safe areas; the "new version" bar; the install banner **off** (`KB_INSTALL_BANNER = false`).
- **Open (Joel):** iPhone and iPad (Add to Home Screen, icon and name, splash, an airplane-mode cold launch, chart and save a pen, notch / home bar clear, View report opens in a sheet with Done), both iPad orientations, Android (Chrome → Install app). The update bar shows on the next release. His logo later; the banner goes on when he says.

## 2026-10-15 · P2-05 installable app · **staging (local)**
- **Branch:** `p2-05-pwa-install`. **Cache:** v246. No database change. Preconditions and Joel's answers: `plans/p2-05-preconditions.md`.
- **Built:**
  - the manifest and iOS tags on all 15 pages (`viewport-fit=cover` everywhere);
  - the placeholder icon (`assets/app-icon.svg`, a K on brand green) and `scripts/splash.js` → 5 icons + 40 splash images, all exactly sized, all precached (sw.js: 79 files);
  - `css/standalone.css` (safe areas; a brand strip under the status bar);
  - the install banner (Android Install button; iOS how-to, only with an empty outbox), **switched off** until the logo lands;
  - the "new version · Reload" bar (never while charting), with an update check on every return to the app;
  - no pull-to-refresh while charting; installed-only Back links on report, privacy and terms.
- **Proven on this Mac** (Chrome over its DevTools protocol, `http://localhost:8000`):
  - installability errors none, manifest errors none;
  - the worker controls the page; cache `kb-shell-v246` holds 80 entries (40 splash, the manifest);
  - offline, a fresh launch of `start_url` opens (signed out → the cached sign-in page);
  - a version bump while open installs the new worker, deletes the old cache and fires the takeover once → the update bar;
  - the banner and update-bar rules (10 cases) in the real code;
  - standalone screenshots with emulated insets at 390, 375 and iPad 820, both sports.
- **Bug found and fixed:** the insets on `body` lost to the pages' own `body { padding:0 }` (tracker, policy pages); they moved to `:root`.
- **Not run (needs HTTPS):** the iPhone / iPad / Android installs. They're Joel's checks on production right after it ships (his call, Oct 15).
- **Privacy / terms:** the head tags and the installed-only "‹ Back to Knuckleball" link, approved by Joel (Oct 15); no policy wording changed.
- **Icon (v247, Joel):** "KB" from the KNUCKLEBALL wordmark (Black Ops One, white on brand green) stands in until his logo; every icon and splash image re-rendered (0 size mismatches).
- **Waiting on Joel:** his logo later (replace `assets/app-icon.svg`, re-run the script); whether the install banner goes on with KB.

## 2026-10-15 · U14 relative accuracy v2 · **production**
- **Shipped by:** Joel ("ship it"); operator `Nathan <joelhauserman@gmail.com>`. Branch `u14-relative-accuracy` → `main` (also carries `docs-a1-offline`). **Cache:** v245.
- **Backup first:** `~/knuckleball-backups/2026-10-14-2311-{schema,data}.sql`.
- **Database:**
  - checked first: production's `sessions_h1_lock`, `sync_session` and `get_team_leaderboard` were identical to the copies the migration replaces;
  - the dry run listed only `20261015010000_u14_relative_accuracy_v2`; applied;
  - 34 policies before and after; 2 new columns, 3 new checks.
- **Function:** `send-session-report` deployed; `REPORT_SITE_ORIGIN` still unset.
- **Before the reset:** pitches 2,161, checksum `1fa9c386…`.
- **Reset (production, Joel's OK):** list saved first (`plans/u14-evidence/reset-list-production-2026-10-15.md`: 11 pitchers, 33 zones). After the run: 0 zones, 0 switches on; pitches 2,161, checksum `1fa9c386…` unchanged; 208 zone-scored pitches keep their results. Joel tells the 7 pitchers who had zones to mark their new cells.

## 2026-10-15 · U14 relative accuracy v2 · **staging**
- **Branch:** `u14-relative-accuracy`. **Cache:** v244. Spec `plans/u14-relative-accuracy-v2.md`; preconditions and Joel's answers in `plans/u14-preconditions.md`.
- **Database (staging only):** migration `20261015010000_u14_relative_accuracy_v2`:
  - `sessions.ra_on`;
  - `pitches.accuracy_hit_kind` (exact / ra / miss; an RA hit must carry its cells);
  - at most 4 cells per zone (new and changed rows);
  - the H1 lock covers `ra_on`; `sync_session` carries both new columns;
  - the leaderboard counts exact + RA.

  Policies 34 before and after.
- **Reset (staging):** list saved (`plans/u14-evidence/reset-list-staging-2026-10-15.md`, 3 pitchers), then run: 0 zones, 0 switches on, pitches unchanged (367 rows, checksum `fe95b043…` before and after).
- **App:**
  - "Turn on Relative Accuracy?" on the start screen (bullpen; Live Game only with Intent), defaulting to the last answer; an RA on / off pill while charting;
  - the marked cells light up on tap 1 (Live Game too);
  - a one-time note when a pitch type has no cells for that side;
  - tap 2 stores the hit kind; the editor rescores on a type change;
  - one accuracy number on the counter, History and trends;
  - Profile: the switch is gone; the painter always shows, stops at 4, "n of 4".
- **Report (staging):** per-type exact / RA grids inside each batter-side block (pens and Intent games, plus "No batter" for side-less pens); an Accuracy tile and one Accuracy % column for U14 pens; Bullpen to game counts exact + RA; `ra_on` is read from the session row.
- **Proven:**
  - SQL checks, rolled back (`supabase/tests/u14_acceptance.sql`): 4 cells saved, 5 refused on insert and on update, `sync_session` stores `ra_on` and exact / ra / miss, an RA hit without cells is refused, an unknown kind is refused, a saved `ra_on` can't change, the leaderboard counts RA hits (76% → 75% over 85, i.e. 64/85).
  - The real app code (Node sim): start question default No → Yes stored and remembered; exact / ra / miss / target-is-marked → exact; no-cells hint; the editor rescores Fastball → Slider as ra; counter 80%; queued offline, synced with `ra_on` and all hit kinds. The same payload in staging's `sync_session` (rolled back): 4 of 5 = 80%.
  - Old sessions: the stats of all 69 staging sessions are identical before and after; four old reports (pen and game, both sports, one zone-scored) are byte-identical before and after.
  - U14 reports (sessions marked U14 in a copy of the staging data) reconcile: pen 15 exact + 8 RA + 3 miss = 26; Intent game 3 + 5 + 6 = 14; RA-off pen 7 of 19, exact only, no legend.
  - Screens at 390 / 820 / 1180, both sports.
- **Fix (v245, Joel's phone test):** tapping a cell in the painter threw the page back to the top (every tap redrew the whole page). A tap now redraws only the painter; Save / Clear keep the scroll position. Checked with the real code: counter 2 → 3 → 4 of 4, a fifth tap ignored, no full-page redraws.
- **Joel's verification (Oct 15):** passed -- an RA-on bullpen and a Live Game charted on staging, and their reports viewed ("everything worked well").
- **Not yet run:** the reset on production (a fresh list right before it).

## 2026-10-14 · A1 follow-up: "Account closing" roster tag · **production**
- **Shipped by:** Joel ("ship it"); operator `Nathan <joelhauserman@gmail.com>`. Branch `a1-closing-tag` → `main`. **Cache:** v243.
- **Backup first:** `~/knuckleball-backups/2026-10-14-2157-{schema,data}.sql`.
- **Database:** `20261015000000_a1_roster_closing` (dry run listed only it). Verified on production: Cy Young's head coach sees 1 closing pitcher, due 2026-10-22 01:46 UTC; 34 policies.
- **Also carried:** the STATUS line from `docs-a1-phone-check` (Joel's A1 phone check). That branch is superseded and needn't be merged.

## 2026-10-14 · A1 follow-up: "Account closing" roster tag · **staging**
- **Branch:** `a1-closing-tag`. **Cache:** v243.
- **Why:** Joel deleted a test pitcher on production and his coach still saw him on the roster -- correct during the 7-day grace, but nothing said so.
- **Database (staging only):** migration `20261015000000_a1_roster_closing`: `get_roster_closing(team)` returns the closing date only to coaches of that team (a managed player closes with its parent login's date too). Test `supabase/tests/a1_roster_closing.sql` (rolled back): head coach 1 with the right date; another team's coach 0; the pitcher 0; anon refused.
- **App:** "Account closing <date>" under the pitcher's name on the roster, the same style as Unverified; online only, best effort.
- **Also:** the STATUS-only commit 3e84121 on `docs-a1-phone-check` had swept in the staging config (`git commit -a`); fixed by a follow-up commit on that branch (it now differs from main by the STATUS line only). Main and the live site were never affected.

## 2026-10-14 · A1 account deletion + data export · **production**
- **Shipped by:** Joel ("ship it"); operator confirmed `Nathan <joelhauserman@gmail.com>`. **Branch:** `a1-account-deletion` merged to `main` (fast-forward, 12 commits incl. docs dd38dae). **Cache:** v242.
- **Backup first:** `~/knuckleball-backups/2026-10-14-1528-{schema,data}.sql`.
- **Database:** the four A1 migrations `20261014000000`–`0003`. Dry run listed exactly those. `rate_limit_take` on production differed from 0002 only by the two A1 kinds (diffed before applying). After: 34 policies, the daily job `a1-account-deletion` (09:17 UTC), limits 5 deletions / 3 exports a day, 0 scheduled, 0 nameless sessions.
- **Functions:** `delete-account` and `export-account` deployed. **Secrets:** `A1_CRON_SECRET` (a new value, not staging's), plus the Vault values `a1_function_url` / `a1_anon_key` / `a1_cron_secret`. `REPORT_SITE_ORIGIN` still unset.
- **Verified on production:** the job → function chain: 200, 0 due; execute without the secret → 403.
- **Site:** policy pages Version 2026-10-14 (approved by Joel), Profile → Your data, the deletion screens.
- **Open:**
  - ~~Joel's production phone check~~ — done Oct 14: Download my data and the Delete my account screens work on his phone;
  - ~~a before/after RLS matrix comparison~~ — skipped (Joel, Oct 14): A1 changed no policies or grants, and its functions were tested directly;
  - ~~offline phone checks~~ — passed (Joel, Oct 14).

## 2026-10-14 · A1 account deletion + data export · **staging**
- **Branch:** `a1-account-deletion`. **Cache:** v242.
- **Database (staging only):** migrations `20261014000000`–`0003`:
  - the deletion mark on profiles;
  - request / cancel / status (DELETE checked by the server; team heads refused);
  - `a1_purge_profile` (service role only);
  - tombstones with no pitcher (`deleted_account`), coach-charted sessions kept with `logged_by` NULL;
  - the H1 lock's one exception (clear to NULL by the server's own function only);
  - a counts-only audit log; two sending limits (5 deletions, 3 exports a day);
  - pg_cron + pg_net, a daily job at 09:17 UTC, its address / key / secret in Vault.
- **Functions (staging only):** `delete-account` (status / request / cancel / execute) and `export-account` (ZIP, own writer, no dependency). Secret `A1_CRON_SECRET` set on staging.
- **App:** Profile → Your data (Download my data / Delete my account; a parent's player: Delete / Restore this player); the two delete screens; the head-coach block; the scheduled-deletion screen on every online load and return; "Logged by former coach"; offline refuses with a message.
- **Docs:** CLAUDE.md (A1 section, functions, secret), BACKUPS.md (7-day retention + the prune job), the rollback covers all four migrations.
- **Proven on staging:**
  - 21/21 SQL checks (rolled back): the pitcher purge → 32 tombstones, no names, 0 pitches; the coach purge → 10/10 charted sessions kept; the player purge → the parent stays;
  - the cron → function chain: 200, 0 due;
  - execute without the secret → 403; an unsigned status call → 401;
  - the export's real code over staging rows: 43 sessions = the SQL count, 39/39 pitch columns, no secret columns, `unzip -t` clean;
  - policies 34; the RLS matrices run with A1 in place.
- **Joel's phone test:** request → scheduled screen → restore, "worked great". Staging Pitcher was left scheduled for Oct 21 and restored (Joel asked).
- **End to end (Joel's OK):** a throwaway staging login (`joelhauserman+a1test@gmail.com`, one pen, 3 pitches, a note), due now, run by the real cron path:
  - first try: the purge worked, but Auth couldn't load the hand-built login (NULL token columns, a fixture fault), so the login was left with no profile and nothing would retry it, and the completion email had already gone out;
  - **fixed in `delete-account`:** the login is loaded before anything is purged (skipped and left due if it can't be), and the completion email goes only after the login is deleted;
  - guard run: skipped, everything kept, still due;
  - full run: `{"kind":"login","ok":true}`; login, profile, membership, pitches, note and rate-limit rows all gone; the pen is a nameless record (`deleted_account`, 3 pitches); the log has counts only; policies 34.
- **Policy pages:** approved by Joel and committed (Version 2026-10-14, TERMS_VERSION on every sign-up page).
- **Backups:** the prune job is installed and ran (54 files older than 7 days deleted; Oct 8 and Oct 13 kept); daily at 10:00, log `~/knuckleball-backups/prune.log`.
- **Not run:** a before/after RLS matrix comparison (needs the A1 rollback run on staging, refused by the permission check); offline phone checks.
- **Production:** nothing. Needs a backup, the four migrations, both functions, `A1_CRON_SECRET` and the three Vault secrets (Joel's), the policy pages.

## 2026-10-14 · A1 preconditions report (no release)
- **Branch:** `a1-account-deletion`. No code changed.
- **Report:** `plans/a1-preconditions.md`, with 4 escalations for Joel:
  1. Pitcher deletion vs tombstones (`sessions.pitcher_id` CASCADE).
  2. A stub "former account" for coach-charted sessions (`logged_by` / notes / invites are NO ACTION).
  3. Coach notes: delete, per Apple.
  4. The privacy page has no backup sentence and no retention exists; the email-based deletion wording must change.
- **T1:** moved to later (Joel).

## 2026-10-14 · no packet (staging report links) · **staging**
- **Changed:** the staging `REPORT_SITE_ORIGIN` secret: `http://localhost:8080` → `http://192.168.1.15:8000`, the local staging site on Joel's home Wi-Fi. Verified by the secret's SHA-256 fingerprint before and after, and the staging `send-session-report` redeployed so it reads the new value.
- **Effect:** staging report emails now link to an address a phone on that Wi-Fi can open while the local server runs. Before, they pointed to `localhost:8080`, which nothing serves.
- **Production:** untouched. It has no `REPORT_SITE_ORIGIN` (confirmed), so its links stay https://knuckleballonline.com.
- **Docs:** CLAUDE.md and the comments in `send-session-report/index.ts` updated (code unchanged).
- **Open items:** if the Mac's Wi-Fi address changes, update this secret too.

## 2026-10-14 · D3 (corners, spacing, shadows, report sizes) + no clock in Live Games · **production**
- **Branch / cache:** `d3-design-cleanup` fast-forwarded to `main` · `kb-shell-v241` (production was v238). No database change.
- **Edge Function:** `send-session-report` deployed to production (D3 Stage D font sizes; new reports only).
- **What shipped:** the staging entries below.
  - The Live Game clock removed (bullpens keep it).
  - D3 Stage A: every corner on a radius token, 29 dead rules deleted, the phone sheet's 18px top corners.
  - D3 Stage B: every spacing value on the eleven-step scale.
  - D3 Stage C: every shadow on a token.
  - D3 Stage D: new reports' font sizes on the nine steps.
  - The v238 hotfix was already live.
  - Reviewed by Joel on staging before shipping.
- **Frozen reports:** untouched; `rerender-reports` not run or redeployed.
- **Open items:**
  - Joel's production check after two reloads (phone and iPad, both sports; a new report and an old link).
  - The dock-drag / tray-tap feel check from Stage C.
  - Jordan's side: re-sync `docs/design/target/` and `design-tokens.json` to the shipped `css/tokens.css`.

## 2026-10-14 · D3 Stage D (report font sizes) · **staging**
- **Branch:** `d3-design-cleanup` (no page change; `send-session-report` deployed to **staging only**).
- **Built (new reports only):** the spec's 12 rules onto the nine steps.
  - `body` 15 → 16.
  - `.header-meta`, `.type-grid h3`, `.legend-item`, `.data-table`, `.side-stats`, `.side-lists ul`, `.ab-row` 13 → 12.
  - `.type-grid-stats`, `.report-footer` 11.5 → 12.
  - `.brand-mark.small`, `.kb-mix` 11 → 10.
  - Not in the table, same role logic: the header wordmark 22 → 24 (the app's sign-in wordmark size).
- **Checks:**
  - Size census of the templates: 10 / 12 / 14 / 16 / 24 / 32 / 44 only. The charts' SVG-unit labels are unchanged (they scale with the drawing).
  - Four real staging sessions rendered through the real builders, with phone and print previews (pen 4 pages, softball game 8).
  - Three stored reports, pre-D2 viewer vs now: identical below the bar. The one pen-report difference is report.html's own footer line, as before.
  - Frozen reports untouched; `rerender-reports` not run.
- **Open items:** Joel generates a new pen and game report on staging. The production deploy of `send-session-report` and the D3 pages (v241) are Joel's.

## 2026-10-14 · D3 Stage C (shadows) · **staging**
- **Branch / cache:** `d3-design-cleanup` · `kb-shell-v241`. No database or function change.
- **Built:** every `box-shadow` reads tokens (30 rules).
  - The spec's five tokens: `--shadow-segment / -pop / -modal`, `--ring-select / -target`.
  - Its three additions: `--shadow-lift`, `--ring-focus`, `--press`.
  - Named per the preconditions: `--ring-target-strong` (the field's measured 3px selected box), `--ring-drop`, `--ring-pulse`, `--ring-plate` (the v232 dark plates), `--ring-danger` (the bullpen clock), `--ring-halo` (the target dot), `--ring-select-4` (the runner token).
  - `--ring-under` is the underline's geometry, so a pitch-type segment adds its own color at the point of use. A token can't follow a per-element `--seg-accent`, because tokens resolve once at the page root.
- **Folded (small visible changes, as decided):**
  - the info bubble, the coach dock and the account menu → `--shadow-pop`;
  - the dock pill at rest, the runner token and the locked tray → `--shadow-segment`;
  - the dragged runner → `--shadow-lift`;
  - the hidden leaderboard's "me" row 1px → 2px.
- **Checks:**
  - Grep: no literal box-shadow outside `tokens.css`.
  - 114 app states × before / after: 100 identical. The rest were timing (re-shot: identical) or the Live Game field's animation.
  - The runner token compared by eye: the same.
  - The dock pill lifted and the pressed button: identical values.
- **Open items:** the spec's video of the dock drag and a tray tap is Joel's check on his phone. Stage D (report font sizes) is next.

## 2026-10-14 · D3 Stage B (spacing) · **staging**
- **Branch / cache:** `d3-design-cleanup` · `kb-shell-v240`. No database or function change.
- **Built:**
  - `--s-6` added (Option 2: 2 · 4 · 6 · 8 · 12 · 16 · 20 · 24 · 32 · 48 · 64).
  - Every padding / margin / gap literal reads `var(--s-N)` in CSS and inline styles: 572 values. 398 were already on the scale; 174 moved to the nearest step (7 → 8 per the table; ties round down; 60 → 64, 80 → 64, 44 → 48). Negative values use `calc(-1 * var(--s-N))`.
  - Pages: the tracker, `buttons.css`, `components.css`, report.html, privacy / terms (spacing only, no wording) and the sign-in pages.
- **Kept literal, with a `/* geometry: … */` comment:**
  - 42 values in the charting grid, the Live Game field overlays, the batter / home-plate gutters, the velocity strip, the coach dock, the 9-dot icon and the U13 tray's 3px;
  - 9 inside `calc()` / `env()`;
  - three 1px pill paddings.
- **Checks:**
  - Census: zero off-scale spacing outside the exempt list.
  - The phone grid's top and the velocity strip's bottom at 375 / 390, both sports: identical to precondition 4 (bullpen 184 / 690 baseball, 184 / 710 softball; Live Game 184 / 455). 0px movement.
  - Before / after at 320 / 375 / 820 / 1180, both sports, 236 views (app + pages): no new sideways scroll, nothing newly cut off. The three "more lines" flags are baseline artifacts (a roster name, a History date line and the pitch log are each still on one line by eye).
  - The report.html CSP hash still matches; all 32 precached files exist.
- **Deviation:** the tracker was converted in one pass, not four. The measurements and the full check were run on the result, which shows no movement, so the passes weren't needed to localize anything.
- **Open items:** Joel's phone / iPad walk-through. Stage C (shadows) is next.

## 2026-10-14 · no packet (Live Game pitch saved with no type) · **staging**
- **Branch / cache:** `d3-design-cleanup` · `kb-shell-v237`. No database or function change.
- **The bug:** Joel's Oct 12 softball game for Clementine Pugh was refused by sync on every try: `null value in column "type" of relation "pitches"`. It's a bug since G1b, so production too.
  - A Live Game pitch took its type from the *current* selection when the play was recorded, not from the tap.
  - Reloading mid-play (a staging update, or iOS reloading a backgrounded page) and resuming the draft clears the selection. Finishing that play saved a pitch with no type.
- **The fix:**
  - The tap stores the type on the pending pitch, which is saved in the draft.
  - Resume restores the selection from it.
  - Both builders (`recordGameResult`, `commitFieldPlay`) and `g5Commit` use it, and refuse with "Pick this pitch's type, then tap again" rather than ever saving a pitch without one. `g5Commit` checks before it clears the field play.
- **Checked on the real code:**
  - Tap → reload/resume → ball: before, a pitch with type null; after, "FB".
  - An old draft with nothing selected: refused with the hint, play kept; picking DROP and tapping again saves DROP.
- **Open items:**
  - The stuck Oct 12 session itself (Joel's call on how to repair it).
  - Ship this fix to production soon (the bug is live there).

## 2026-10-14 · no packet (show why a session won't sync) · **staging**
- **Branch / cache:** `d3-design-cleanup` · `kb-shell-v236`. No database or function change.
- **Built:** the "N sessions pending sync" banner now lists each refused session's date and the server's reason. It was recorded in the outbox (`lastError`) but only ever shown as "· retrying".
- **Why now:** Joel's Oct 14 softball game for Clementine Pugh (Staging Softball Team) won't sync. Staging has no row for it, and the reason is only on his device.
- **Open items:** Joel reloads twice, taps Sync now and reads the reason; then the actual fix.

## 2026-10-14 · D3 Stage A (corners) · **staging**
- **Branch / cache:** `d3-design-cleanup` (includes `live-game-no-clock`) · `kb-shell-v235`. No database or function change.
- **Built:**
  - Every `border-radius` reads a token. 76 rules:
    - `--radius-control` 12: 29;
    - `--radius-circle`: 15;
    - `--radius-segment` 9: 10;
    - `--radius-pill`: 12;
    - `--radius-cell` 4: 7 (`.zone-grid`, `.g5-face` and `.g5-field` still share one);
    - `--radius-dock` 18: the coach dock;
    - the new `--radius-mark` 2px: chart marks.
  - The phone sheet's top corners at 18px (Joel's choice 7).
  - 29 dead rules deleted (the pre-G5 `.gg-*` grid and scorebook, `.brand-mark`, `.invite-btn`, `.game-panel-undo`, `.position-swipe-*`).
- **Checks:**
  - Grep: no literal `border-radius` outside `tokens.css` except 0.
  - 170 before/after views (app 38 states × 2 sports × 390 / 820 / 1180; 14 pages × 2 sports × 820 / 1180): 68 identical, the rest differ only at corners. Three outliers were screenshot timing (re-shot: 36–337 px), and the Live Game field screens animate as always.
  - The sheet and the menus were checked by eye.
- **Deviations:**
  - `.pitch-count-badge` stays a 12px scoreboard tile (D2 Stage C's later rule), not a circle.
  - `.roster-dot-count` is a pill (an 18px count badge).
- **Open items:** Joel's phone / iPad walk-through. Stage B (spacing) is next.

## 2026-10-14 · no packet (no clock in Live Games) · **staging**
- **Branch / cache:** `live-game-no-clock` · `kb-shell-v234`. No database or function change.
- **Built (Joel, Oct 14):** the ⏱ time-to-home clock is gone from Live Games: the phone status bar, the iPad / laptop bottom-left and the Live Game delivery tray. A game pitch never records a time.
- **Kept:** bullpens keep the clock (baseball; softball never had one). Reports keep their time-to-home lines. The `pitches.time_to_plate` column and every time already recorded are untouched. To bring the clock back to games, revert this commit.
- **Checked:** the clock is on all 12 baseball bullpen screens (390 / 820 / 1180, with the sheet open and closed) and on no Live Game screen in either sport. The phone status bar and the laptop action row look right.
- **Open items:**
  - Joel's check on phone and iPad.
  - D3 Stage B's 7px decision can be revisited, since the Live Game scoreboard now has room.
## 2026-10-14 · hotfix (Live Game pitch saved with no type; show why a session won't sync) · **production**
- **Branch / cache:** `hotfix-pitch-type` (from main `5be0c78`) · `kb-shell-v238`. **Shipped to production Oct 14 (Joel), main `eb2a070`.** No database or function change. Contains ONLY these two fixes; not the Live Game clock removal or D3.
- **Bug (live since G1b):** a Live Game pitch took its type from the selection at the moment the play was recorded. A reload mid-play (iOS reloading a backgrounded page, or an app update) clears the selection, so the pitch saved with type null, and sync refused that session forever (`null value in column "type" of relation "pitches"`). Found on Joel's staging softball game (Oct 12).
- **Fix:**
  - The tap stores the type on the pending pitch (saved in the draft).
  - Resume restores the selection.
  - `recordGameResult`, `commitFieldPlay` and `g5Commit` use it and refuse with "Pick this pitch's type, then tap again" rather than save a pitch without one.
- **Also:** the "pending sync" banner shows each refused session's date and the server's reason (it was recorded but never shown).
- **Checked on production's own code:**
  - Tap → reload/resume → ball: v233 saves type null; the hotfix saves "FB".
  - An old draft with nothing selected: refused with the hint, play kept; picking a type saves it.
- **Open items:** none. Merged back into `d3-design-cleanup`, which already had the same fix. Its one conflicting line keeps D3's no-clock version; D3 is now v239.

## 2026-10-13 · no packet (iPad-portrait perspective squeeze) · **production**
- **Branch / cache:** `d2-broadcast-rebrand` · `kb-shell-v233`. No database or function change.
- **Fixed:** on iPad portrait (501–860 px) the "Behind the catcher / Behind the pitcher" tray now stacks its two choices, as on iPad landscape and laptop. Side by side, they ran into each other in their narrow column (open since D2 Stage B). Checked at 600 and 820 px, bullpen and Live Game, both sports. CSS only; phones and laptops unchanged.
- **Shipped:** to production Oct 13 (Joel), v233.
- **Open items:** Joel's check on an iPad in portrait.

## 2026-10-13 · D2 (Broadcast · Big Shoulders rebrand, Stages A–D; with D1 Stage 1 already live) · **production**
- **Branch / cache:** `d2-broadcast-rebrand` fast-forwarded to `main` · `kb-shell-v232` (production was v227). No database change.
- **Edge Function:** `send-session-report` deployed to production (new reports in the D2 look, with their own `--kr-*` colors and fonts; new pitch palettes).
- **What shipped:** the staging entries below for D2 Stages A, B, C (with the v232 review fixes) and D. Reviewed by Joel on staging before shipping.
  - New colors, both sports.
  - Big Shoulders Display + Archivo, self-hosted.
  - The light sign-in pages under a dark angled header.
  - Flat cards, scoreboard status bars, a dark grid frame.
  - New session reports.
  - Privacy / Terms colors, fonts and wordmark (approved).
- **Frozen reports:** untouched; `rerender-reports` was not run or redeployed.
- **Open items:**
  - Joel's check on production after two reloads (phone and iPad, both sports): sign-in, charting, a new report, an old report link.
  - The iPad-portrait perspective tray squeeze.

## 2026-10-13 · D2 Stage D (new session reports) · **staging**
- **Branch:** `d2-broadcast-rebrand` (no page or cache change; `send-session-report` deployed to **staging only**).
- **Built:**
  - New reports carry their own colors and fonts (`--kr-*` variables per sport, in the file), so a later site change can't restyle a sent report. The softball hex swap is retired.
  - Brand band with the wordmark, slanted sport tag and the name in Big Shoulders caps; Big Shoulders headings and tile numbers; Archivo text; the D2 colors; chart text in Archivo with readable axis labels.
  - CLAUDE.md: the S1 byte-identical line and landmine 4 updated.
- **Checks:**
  - Four real staging sessions (pen and game, both sports) rendered through the real builders and report.html's path, with print previews.
  - Three stored staging reports render pixel-identical below the viewer bar, before vs after.
  - Each report's pitch colors are its sport's. Evidence: `plans/d2-stage-d.md`.
- **Open items:**
  - Joel generates a new pen and game report on staging (both sports) and opens an old link.
  - The production deploy of `send-session-report` is Joel's.
  - The whole D2 branch still to ship to production (pages v232 + this function).

## 2026-10-13 · D2 Stage C (components and pages) · **staging**
- **Branch / cache:** `d2-broadcast-rebrand` · `kb-shell-v232` (v232: Joel's review fixes -- a solid dark backing behind the chart's Reset / Next pitch and velocity rows so the grid lines never show across them, and a dark plate behind the sign-in pages' main button). No database or function change.
- **Built:**
  - `css/components.css` (slanted tag, badge, banner, flat card, the sign-in and landing looks).
  - All 10 sign-in pages plus index in the light look: a dark angled header with wordmark, tagline, slanted tag and a 44px title whose last word is gold / pink. No page CSS left.
  - D1's dark scope deleted.
  - App: flat cards; the brand strip with a slanted role tag; the phone status bars as a scoreboard (Big Shoulders numbers over labels); a dark strike-zone frame; 44px inputs; one Next Pitch component (two dead classes deleted).
  - Privacy / Terms show the KNUCKLEBALL wordmark (approved).
- **Deviations:** the Live Game scoreboard says "INN" under 400px so it fits with Windup and the clock. No title periods. Home has no section labels to tag. Evidence: `plans/d2-stage-c.md`.
- **Open items:**
  - Joel's phone and iPad walk-through (both sports, sign-in pages included).
  - The airplane-mode open.
  - The iPad-portrait perspective tray squeeze.

## 2026-10-13 · D2 Stage B (fonts and type) · **staging**
- **Branch / cache:** `d2-broadcast-rebrand` · `kb-shell-v230`. No database or function change.
- **Built:**
  - Big Shoulders Display (headings, names, big numbers) and Archivo (everything else) self-hosted and precached. Teko, IBM Plex Sans and IBM Plex Mono removed (fonts on a device: 412 KB → 241 KB).
  - The spec's face mapping on every page, report.html's shell included.
  - Exactly the nine sizes on every page.
  - Uppercase labels: Archivo 700, 0.1em, 90% width.
  - The 320 px Live Game status bar has room to spare.
- **Deviations:** the field captions keep tight spacing (they sit in fixed boxes). The legal pages' band wordmark is Big Shoulders caps until Stage C gives it Black Ops One. Evidence: `plans/d2-stage-b.md`.
- **Open items:**
  - Joel's phone and iPad walk-through (both sports), with an airplane-mode open after one online load.
  - An existing iPad-portrait squeeze in the bullpen perspective tray (it was cut off before; now the two labels touch).

## 2026-10-13 · D2 Stage A (colors) · **staging**
- **Branch / cache:** `d2-broadcast-rebrand` · `kb-shell-v229`. No database change. `send-session-report` deployed to **staging only** (new pitch palettes).
- **Built:**
  - `css/tokens.css` takes the Broadcast values for both sports (D1's names), plus the target's new names (`--brand-*`, `--on-accent`, `--on-danger`, `--flash-fg`, `--focus`, `--duration-*`, `--ease-*`, `--t-*`, `--s-*`, `--radius-segment`, `--ring-*`, `--shadow-segment/pop`, `--cut`, `--dock-pill`) and fixed per-sport colors (`--bb-*` / `--sb-*`) for the account chips and the "Which sport?" cards.
  - Softball's own button and chooser colors are gone (they follow `--accent` / `--brand-bg`); one gold (`--accent-game` = `--accent`).
  - The dark sign-in pages take the new brand colors until Stage C (decision 1).
  - Pitch palettes changed in the tracker, `helpers.ts` and `--pitch-N` together. `.githooks/pre-push` now checks all three on every push (decision 8; tested pass and reject).
  - Theme literals → tokens: warning tints, the dock, the notice backdrop and shadow, field pick/shade tints, the Live Game panel labels, the account chips, the medal stars, the relative-accuracy tag (`--brand-mid`), info notes, badges; report.html's top-bar rule and footer.
  - The throws tag and the "logged by coach" tag use `--accent-ink` (decision 3).
- **Deviations:**
  - **`readableTextOn()` was restored, not deleted (decision 7 reversed).** The preconditions report said it had no callers, but the filled `.pitch-chip` labels (pitcher header, profile) have always had fixed ink text. It now picks ink or white per color with each sport's real ink, and both chip builders call it.
  - Dark sign-in values I chose (the target has no dark scope): card-2 `#113726` / `#1A426E`, error red `#FF7A6E` (6.1:1 on the card; the light red is 2.7:1 there), softball faint text `#9FB2C6` (5.8:1).
  - The one-time notices' backdrop is now `--scrim` (the sport's dark), not Oct 2's navy, per the approved mapping. CLAUDE.md line updated.
- **Acceptance:**
  - **Grep:** no old theme hex in any app page outside the field art.
  - **Left by rule:** privacy.html / terms.html (need Joel's written approval), the report code (Stage D) and docs/.
  - **Palette check:** passes.
  - **Screenshots:** 114 app screens (38 states × 390 / 820 / 1180) + 14 pages × 2 sports × 3 widths.
  - **Contrast pairs:** see plans/d2-stage-a.md.
- **Joel's follow-ups (Oct 13):**
  - **(b)** Softball pitch slots 6–8 darkened just enough for white chip labels: `#8E6CFF`→`#7A53FF`, `#D2553F`→`#CD4730`, `#7D8794`→`#6C7684` (4.6:1). All 16 chip labels now pass AA. Changed in the tracker, `helpers.ts` and tokens; the palette check passes; staging function redeployed.
  - **privacy.html / terms.html** moved onto the tokens (colors only, wording unchanged), with Joel's approval. Their wordmark and fonts follow in Stages B/C.
- **Open items:** Joel's phone/iPad walk-through, both sports.

## 2026-10-13 · D1 Stage 1 (design tokens) · **production**
- **Branch / cache:** `d1-design-standardization` (stacked on `live-game-oct12`) · `kb-shell-v227`. No database change.
- **Built:**
  - New `css/tokens.css`: Jordan's `docs/design/css-variables.css` made loadable, with the spec's rename map. Every color is named by its job, not its color (`--amber` → `--accent`, `--field-dark` → `--ink` / `--brand-bg`, `--chalk` → `--on-dark`, `--red` → `--danger`, `--clay` → `--warning`, `--kind-btn` → `--chooser`, gold/silver/bronze → `--rank-1/2/3`, `--gg-gold` / `--game-gold` → `--accent-game`). It has four scopes: light, softball, the sign-in pages' dark look (`html[data-theme="dark"]`), and dark + softball. It also adds `--success`, `--strike`, `--ball` (were literals), `--pitch-1..8` and `--motion-fast` / `--motion-spring` (zero under reduced motion).
  - All 15 pages and `report.html` load it. The pages' own color blocks and `buttons.css`'s token block are deleted. The 11 sign-in pages carry `data-theme="dark"`. `sw.js` precaches it.
- **Acceptance:**
  - **Pixels:** 170 before/after screenshots (114 app screens, both sports at 375/390/1180, plus 14 pages × 2 sports × 500/1180, with every hidden step shown). 153 are identical. The other 17 are explained:
    - 14 animated screens differ just as much when the same code is shot twice;
    - 1 is the text cursor blinking;
    - 2 come from the test forcing softball onto the report viewer, which never has a sport (its real baseline is identical).
  - **Old names:** none left outside the frozen-report code (grep).
  - **Pitch colors:** `--pitch-N` equal `SPORTS[sport].palette` and `helpers.ts` in order, both sports.
  - **Other checks:** report.html's CSP hash still matches; all 27 precached files exist; the privacy/terms wording is unchanged (only variable names).
- **Deviations:** none in values. Radii, spacing and shadows are listed in tokens.css as Jordan's inventories but not yet used (per the spec, Stages 2/3). `--on-dark-line` replaces `--border-on-dark` in the report viewer only (one use).
- **Shipped:** to production Oct 13 (Joel), right after v226. No database or function change.
- **Open items:** Joel's offline check (P1-01 1–3) on a device. D1 Stages 2 and 3 are superseded: they're built as D2 Stages B and C (`plans/d2-broadcast-rebrand.md`).


## 2026-10-13 · live-game-oct12 (Oct 9–13 staging work) · **production**
- **Branch / cache:** `live-game-oct12` merged to `main` · `kb-shell-v226` (production was v195).
- **Database:** migration `20261012000000_live_game_intent` applied to production after a fresh backup (`~/knuckleball-backups/2026-10-13-1405-*`). It loosens `pitches_target_matches_kind` so a game pitch may carry a target (Intent); no rows touched. Rollback: `supabase/rollback/20261012000000_live_game_intent_down.sql`.
- **Edge Function:** `send-session-report` deployed to production (game reports list stolen bases, caught stealing, pickoffs, wild pitches, passed balls and other runner moves under "Other events").
- **What shipped:** every staging entry below from Oct 9 to Oct 13 on this branch:
  - U13 buttons and the draggable bottom menu;
  - the leaderboard hidden for both sports;
  - Live Game: big K / backwards K / B / F / IP letters under the chart; the chart flips only on In Play / Foul Out / runner questions; runner moves between pitches (drag or tap, Safe/Out, Why); a dragged runner held until answered; outs shown at once; Next blocked until the batter is placed on a hit or error; the softball ponytail;
  - start questions (radar gun, relative accuracy, opponent quick-picks, Intent);
  - the Home screen with Joel's tile drawings;
  - bold charting prompts;
  - the velocity bar alignment and mouse drag.

  Reviewed by Joel on staging (phone and iPad) before shipping.
- **Open items:** Joel's check on production after two reloads (phone and iPad); P1-01 offline checks; U13 4b (iPhone video of the bottom menu).

## 2026-10-13 · no packet (velocity bar: window alignment, mouse drag) · **staging**
- **Branch / cache:** `live-game-oct12` · `kb-shell-v226`. No database change.
- **Fixed:** the Live Game in-chart velocity bar's center window (gold; softball pink) ran a few px past the right edge of its square. It was positioned from the whole bar; now it sits on the strip's own box, exactly one square inside the strip's border. Checked zoomed at 390 px.
- **Built:**
  - A mouse can drag every velocity strip (bullpen and Live Game): grab cursor; the strip follows, then settles on the nearest square (smooth, with a backstop that always ends on a square).
  - In a Live Game that settle picks the speed, like a swipe. A drag is never also a click on a speed.
  - Finger swiping on phones and iPads was already native scrolling and is unchanged.
- **Open items:** Joel's check on laptop (drag) and phone (alignment).

## 2026-10-13 · no packet (a dragged runner holds his new base) · **staging**
- **Branch / cache:** `live-game-oct12` · `kb-shell-v225`. No database change.
- **Built:** a runner dropped on a new base (or home) stays locked there, outlined and gently pulsing, with his old base shown empty, until "Safe or out?" (and, between pitches, "Why?") is answered:
  - **Safe:** fills that base.
  - **Out:** removes him.
  - **Cancel:** puts him back.

  This covers the runners question after a play (the batter dragged from home too) and moves between pitches. The status-bar diamond keeps the official bases until it's answered.
- **Open items:** Joel's check on phone and iPad.

## 2026-10-13 · no packet (bold charting prompts) · **staging**
- **Branch / cache:** `live-game-oct12` · `kb-shell-v224`. No database change.
- **Built:** the charting prompt under the chart ("Tap where you're aiming", "Now tap where it actually landed", "What happened?", the field-step questions) is now 16 px, heavy, dark text on a pill tinted in the sport's accent, centered (was 10 px pale capitals). The same applies to the accuracy-zone editor's caption. The runner and extra-inning questions and the phone Intent hints are 16 px heavy too.
- **Deviations / choices:** the phone Live Game still has no caption line under the chart (Joel, Oct 13: fine without it).
- **Open items:** Joel's check.

## 2026-10-12 · no packet (outs show the moment they're called) · **staging**
- **Branch / cache:** `live-game-oct12` · `kb-shell-v223`. No database change.
- **Built:** the Live Game status line ("1 OUT", and the iPad/laptop Outs box) counts an out as soon as it's called, never more than three:
  - a runner dragged or tapped and called Out (on the runners question after a play, and between pitches before "why");
  - the batter's O;
  - + Out.

  Before, the count moved only when Next saved the play. Display only: what's saved, and when, is unchanged.
- **Open items:** Joel's check on phone.

## 2026-10-12 · no packet (Live Game Intent) · **staging**
- **Branch / cache:** `live-game-oct12` · `kb-shell-v222`. **Database:** `supabase/migrations/20261012000000_live_game_intent.sql` (rollback `supabase/rollback/20261012000000_live_game_intent_down.sql`) was **applied to staging on Oct 12 (Joel's OK)**: the dry run listed only this migration, and the rule read back from staging allows a game target (both fields or neither). Production still has the old rule (read back, untouched).
- **Built:**
  - The Live Game start screen asks "Turn on Intent?" (default No). Its **?** shows "For use with Pitchcom, Game Day Watches, GoRout, etc..." on mouse hover, or as a line under the question when tapped.
  - With Intent on, tap 1 marks the called spot (the bullpen's target dot). Tap 2 marks where it went: that box flashes a translucent dark color with a ball on it (yellow for softball), and K / backwards K / B / F / IP appear under the chart; everything after is unchanged.
  - Prompts: "Tap where the pitch is called" / "Now tap where the pitch went", plus a Reset target button.
  - The called spot is saved on the pitch (`target_row` / `target_col`), in the catcher frame like the actual spot.
  - With Intent off, nothing changes (no target saved).
- **Why the migration:** G1's `pitches_target_matches_kind` forbade any target on a game pitch. The new rule lets a game pitch have both target fields or neither (strictly looser; no data touched).
- **Checked:** the leaderboard function counts bullpens only, and the game report doesn't score accuracy, so Intent targets don't leak into any accuracy number.
- **Open items:** Joel's phone/iPad check (chart an Intent game; confirm it syncs and the pitches carry the called spot). Then production with the rest of the branch: fresh backup first, then the migration, then the app. Not built yet: using the called spot anywhere (e.g. game accuracy / miss distance in reports).

## 2026-10-12 · no packet (roster tap scrolls to the top) · **staging**
- **Branch / cache:** `live-game-oct12` · `kb-shell-v221`. No database change. The live site is still v195.
- **Built:** tapping a pitcher anywhere in the roster, however far down it's scrolled, smoothly scrolls the page back to the top (his name and the Home tiles), on every screen size. It scrolls once on the tap and again after his page draws. It goes through the dock's scroll helper, so the phone dock doesn't hide.
- **Open items:** Joel's check on iPad.

## 2026-10-12 · no packet (Home screen) · **staging**
- **Branch / cache:** `live-game-oct12` · `kb-shell-v220`. No database change. The live site is still v195.
- **Built:** after login (and after picking a pitcher) the app opens on **Home**, not on "What will we be charting today?".
  - Under the photo and name:
    - **Top row:** Charting (clipboard → the chooser, or "Resume" with a session in progress) and History (rising graph) as two big tiles, each about twice the area of a small one (v213).
    - **Second row:** three small tiles: Armcare (arm) and Mental Game (brain), both "Coming soon" and going nowhere, and Profile (gear → your own profile to edit).
  - On iPad/laptop (v216, from Joel's laptop mock-up) the tiles fill the whole area beside the roster: Charting and History split the top row (5:3 tiles, 32 px labels, 64 px icons); Armcare / Mental Game / Profile split the next into thirds (about square, 24 px labels, 48 px icons). **On phones every tile is the screen's width, one under the other, all the same size** (v215: 128 px tall, 44 px icon over a 20 px label -- a bit bigger than v214's Charting).
  - The tab row gains a **Home** tab, and the coach dock's Home goes to Home.
- **Deviations / choices:**
  - Tile icons: v217 drew a flexed arm, a brain with radiating lines and a solid gear in the style of Joel's examples (those were likely stock clip-art from Downloads, so not copied). v218: Armcare and Mental Game use **Joel's own drawings** instead. He uploaded `vendor/brain-arm.png` to GitHub (`bd2a2a8`, on `main`); it was split into `vendor/icons/arm.png` and `vendor/icons/brain.png` (256 px, transparent, ~40–50 KB each), shown as masks filled with the tile's color and precached. v219: Charting, History and Profile use his drawings too (`vendor/clipboard-graph-gear.png`, `12b73af` on `main`, split into `vendor/icons/clipboard.png`, `graph.png`, `gear.png`; near-white made transparent), so all five tiles use Joel's art. v220: Charting's icon is his `vendor/scatter.png` instead (`2125e2a` on `main`: a clipboard holding a 5×5 pitch chart with dots), saved as `vendor/icons/scatter.png`; the clipboard-only icon was removed. The coach dock keeps its own line icons.
  - Picking a roster name opens Home too (a red-dot name still opens History).
  - An archived team's Charting tile is greyed ("Archived team").
  - Switching teams from the team drop-down still lands on History.
- **Open items:** Joel's check on phone and iPad.

## 2026-10-12 · no packet (session start questions, bigger mode buttons) · **staging**
- **Branch / cache:** `live-game-oct12` · `kb-shell-v211`. No database change. The live site is still v195.
- **Built:**
  - Bullpen / Live Game buttons are bigger: 24 px type, 72 px tall, a size variant of the tray.
  - After picking, the start questions:
    - "Will you be using a radar gun today?" (default from the profile).
    - Bullpen only: "Would you like to use relative accuracy?" No turns it off for this pen; Yes scores against the zones painted in the profile.
    - Live Game: an optional opponent box with a drop-down of saved opponents.
  - The answers belong to the session (they never change the profile). A radar answer holds for the whole session.
  - Opponents are saved on the device per team, newest first; when online the list is refreshed from the team's saved games. Every opponent box (start, phone sheet, iPad/laptop) offers the same list.
- **Deviations / choices:**
  - Relative accuracy isn't asked for Live Game (no target there, so accuracy isn't scored).
  - The opponent list uses the browser's own type-ahead (`datalist`; iOS Safari 12.2+).
- **Open items:** Joel's check on phone and iPad.

## 2026-10-12 · no packet (Live Game: results under the chart, runner moves, ponytail) · **staging**
- **Branch / cache:** `live-game-oct12` (on top of `u13-segmented-buttons`) · `kb-shell-v210` (v210: the runner-move Why buttons wrap, two to a row on phones; v209: on a hit or an error the field can't turn back over until the batter is placed; v207: the Live Game status bar stays on one line at 320/375/390; v204/v206/v208: the ponytail attached to the back of the helmet, tip curling up, a little space above the shoulder; v205: the result letters at 32 px with no words under them -- screen readers still hear each word). `send-session-report` deployed to staging only. No database change: every event type was already allowed. The live site is still v195.
- **Built** (from Joel's Oct 12 list and his answers):
  1. Softball batter ponytail (mirrors with the figure); baseball unchanged.
  2. What happened as big letters (no words): K swing, backwards K looking, B, F, IP.
  3. Those buttons sit under the 5×5 with the tapped spot marked; Foul asks tip or out there too.
  4. Only In Play, a Foul Out (to pick where it was caught), the runners question after a walk, and a runner move flip to the field.
  5. Between pitches the status-bar diamond opens the field: drag a runner to a base or home, or tap runner then base. "Safe or out?" then "Why?":
     - safe: stolen base / wild pitch / passed ball / balk (softball: illegal pitch, via its existing ball-added save) / other;
     - out: caught stealing / pickoff / other.
  6. Dragging also works on the runners question after a play, including the batter from home; Safe or Out with no "why". Taps still work.
  7. On a hit or error, Next stays greyed out until the batter is put on a base (tapped, or dragged from home and called safe). Joel asked for hits; errors are included because the batter reaches there too.
  8. The game report's Other events lists stolen bases, caught stealing, pickoffs, wild pitches, passed balls and other runner moves.
- **Deviations / choices:**
  - A balk moves every runner up (the rule), whichever runner was dragged.
  - The field stays up after a runner move for the next one (Done to leave) and closes itself when the bases empty.
  - The ponytail shows wherever the silhouette shows (iPad/laptop and the zone editor). Phones show the vs RHB pill, not the figure.
- **Open items:** Joel's phone/iPad check (both sports): a pitch through every result, a foul out, a walk, a steal, a caught stealing, and a drag on the runners question; then a game report from staging showing the runner moves.

## 2026-10-10 · U13 (+ spec update `-2`) · **staging**
- **Branch / commit / cache:** `u13-segmented-buttons` · `61102f9` · `kb-shell-v202`. The live site is still v195.
- **Spec:** `plans/u13-segmented-buttons.md` + `plans/u13-segmented-buttons-2.md`; report `plans/u13-preconditions.md` (Joel's answers A–G); evidence `plans/u13-evidence.md`.
- **Built:**
  - Every button in the segmented style, with one shared `buttons.css` on every page (precached). Its tokens come from each sport's current colors, so no color changed.
  - `segTray()` trays for every pick-one group: a 150 ms sliding white segment, arrow keys, `aria-pressed`.
  - The pitch-type strip and pitch types as trays (type-color dot, selected underline in the type's color, colors generated from the palette).
  - One `btn-danger` class (20 buttons, zero inline red) and 44 px targets.
  - The bottom menu (coach dock) as the one draggable tray: spring, hold 150 ms to lift, drag follows the finger, release switches once.
  - A locked tray reads as locked.
  - Also on this branch, by Joel's requests: the G5 chart flip at 325 ms (was 650), and the leaderboard hidden for baseball too (`hasLeaderboard: false`, nothing deleted).
- **Deviations from the packet:**
  - Type is 16 px on buttons and 14 px in trays (the spec says 15), to keep the Oct 9 eight-size scale.
  - Three arrows stay narrower than 44 px (phone pitch-strip ‹ ›, phone bullpen velocity ‹ ›, in-chart velocity ‹ ›). At 44 px wide the phone pen would show about 2 pitch types instead of 3½; escalated.
  - Next pitch's two golds are unified to the theme primary.
  - On iPad/laptop, Windup|Set and None|RHB|LHB are trays (decision A); phones keep the single buttons.
  - A quick sideways slide on the bottom menu picks the segment up without the hold (the spec doesn't cover this case).
  - The v197 slide-on-every-tray was removed per spec `-2`.
- **Open items:**
  - Joel's device checks (bullpen, Live Game, History, Profile; phone + iPad; both sports).
  - Acceptance 4b: an iPhone video of the bottom menu.
  - P1-01 offline checks 1–3.
  - Joel's call on the narrow arrows and 15 vs 16 px.
  - When shipping: merge `main` (it has the spec `-2` upload) and run the pre-push checks.
  - If the leaderboard stays off, the privacy and guardian pages' leaderboard sentence needs Joel's approved rewording.

## 2026-10-09 · no packet (type scale) · **production**
- **Branch / commit / cache:** `type-scale-8` · `016d72d` · `kb-shell-v195`.
- **Built:** the tracker's 30 font sizes folded into 8 (10/12/14/16/20/24/32/44).
- **Deviations:** the phone status bar and ADV caption use 16 (not 20) so the status bar stays on one line.
- **Open:** the other pages (landing, sign-in, join) still use their own 9–12 sizes each.

## 2026-10-09 · no packet (coach dock, phone roster) · **production**
- **Branch / commit / cache:** `coach-mobile-dock` · `d9e81fd` · `kb-shell-v193`; then `roster-full-list` · `b939869` · `kb-shell-v194`.
- **Built:**
  - Coach phone dock: Home / Charts / Roster / Profile, translucent, hides scrolling down, glide pill.
  - The phone roster stays rolled up until Roster is tapped, and then opens the whole list.
- **Deviations:** none. **Open:** none.

## 2026-10-08 · no packet (wordmark) · **production**
- **Commit / cache:** `42c85f4` · `kb-shell-v189`; the Noto files were removed in `f73aad8`.
- **Built:** KNUCKLEBALL in self-hosted Black Ops One on every page, no diamond or period.
- **Open:** `privacy.html` / `terms.html` still show the old wordmark (a change there needs Joel's approval).

## 2026-10-08 · no packet (History cards) · **production**
- **Commit / cache:** `925d497` · `kb-shell-v188` (v185–v188).
- **Built:** History cards show the report's first chart (pitcher's view, dots by type, grey ring, cream zone) over a drawn home plate; games get a per-type table.

## 2026-10-08 · G5 Live Game on the field · **production**
- **Commit / cache:** `25290c2` · `kb-shell-v184`, after backup 2026-10-08-1527.
- **Migrations:** `20261007000000_g5_spray_box`, `20261008000000_g5_spray_field`; report functions deployed; schema dump `e714125`.
- **Built:** see CLAUDE.md "Live Game on the field" and `plans/g5-evidence.md`.
- **Deviations:** many, by Joel's later decisions, all recorded in CLAUDE.md. Where they differ from `plans/g5-live-game-diamond.md`, CLAUDE.md wins.
- **Open:** Joel's production phone check; P1-01 offline checks 1–3 on the G5 build.

## 2026-10-06 · U12 pitcher's-view reports · **production**
- **Commit / cache:** `9834627` (U12 complete) · `kb-shell-v153`.
- **Built:** pitcher's-view report and History grids; `from_rows.ts`; the operator-only `rerender-reports`; the Cairn re-render 23 of 23 (originals in `reports-archive/2026-10-06/`).
- **Open:** none (the phone and offline checks passed Oct 6).

## Earlier releases (Aug 14 – Oct 6, 2026)

Rebuilt from git history on Oct 10, 2026, so each entry is shorter than a live one:
- **Production:** everything below is on `main`, so on the live site. `supabase migration list` on Oct 6 showed every migration through then applied on production.
- **Final commit and cache version:** each entry gives the packet's last commit and the `CACHE_VERSION` at that commit.
- **Deviations:** only those that git, `plans/*-evidence.md` or CLAUDE.md recorded.
- **What's current:** CLAUDE.md holds the up-to-date rules for each feature.

- **2026-10-06 · R4 cross-team visibility** · `e1a261e` · v152 · migration `r4_cross_team`.
  - Coaches of every non-archived team a pitcher is on read his sessions since he joined; the recording team keeps notes, reports and delete.
  - Workload line = last time out + last 7 days.
  - Reports stay per team (v152).
  - *Deviation:* replaces the never-built "summary-only" rule. Evidence `plans/r4-evidence.md`.
- **2026-10-05 · P1-09 rename / archive / restore / delete a team** · `e905429` · v148 · migration `p1_09_teams`.
  - Shipped after backup 2026-10-05-1401.
  - Teams are written only through functions (teams hotfix).
  - Joel's phone and offline checks passed.
- **2026-10-05 · H1 hardening (absorbs SC2)** · `3a002f8` · v145 · migrations `h1_saved_lock`, `h1_rate_limits`.
  - Saved sessions are locked; one atomic `sync_session` with a seal; deletion only via `delete_session`.
  - Sending limits with a daily circuit breaker.
  - *Open:* close the grace path no earlier than Oct 19.
  - Evidence `plans/h1-evidence.md`.
- **2026-10-03 · P1-10 age attestation, guardian approval, policy pages** · `ae1dacd` · v144 · migration `p1_10_attestation`.
  - The report gate is now verified + on a team + adult or guardian approval (Joel's option a).
  - Self-hosted fonts and supabase-js.
  - privacy/terms approved by Joel (Version 2026-10-03b; "Your coaches" wording 2026-10-05).
  - All 14 checks evidenced (`plans/p1-10-evidence.md`).
- **2026-10-02 · S4 profiles (Stage A) and parent accounts + players (Stage B)** · `009d15a` · v142.
  - Migrations `s4a_profiles`, `rls_holes`, `s4b_players`; shipped after backup 2026-10-02-1135.
  - Change Email shipped the same day (`20261002070000_email_change`).
  - Two pre-existing RLS holes were fixed.
- **2026-10-01 · G3 Live Game cleanup** · `8f151c5` · v134 · migration `g3_live_game_cleanup`.
  - Departed-pitcher filing rule; `tiebreak_runner` / `illegal_pitch` events; `teams.level`.
- **2026-10-01 · S3 coaches' notes** · `59557e9` · v132 · migrations `s3_session_notes`, `s3_session_notes_no_update`.
- **2026-10-01 · S1 sports foundation + S2 softball Live Game** · `70f6ff4` · v129 · migration `s1_sport`.
  - Sport on every profile, team and session; softball theme; no leaderboard or Set/Windup for softball.
  - Softball field; Illegal pitch instead of Balk.
- **2026-10-01 · G1b-r5 phone and G1b-r6 iPad/laptop session layouts** · `131e315` (v119) and `ea239d0` (v123).
  - *Deviation:* iPad portrait stays stacked (Joel's option B).
- **2026-10-01 · G1b Live Game ball in play (r1–r6)** · `80ba9d8` · v125 · migrations `g1b_ball_in_play_field`, `g1b_r_scorebook_revision`.
  - *Deviations:* r2 replaced the field picture with scorebook cells (patent concern); r3's in-grid entry was later replaced by G5; r4 was deleted.
- **2026-09-30 · U11** (time to home, per-type location grids, phone roster roll-up) · `90a8064` · v95 · migration `u11_time_to_plate`.
- **2026-09-30 · U10** (Back button, radar default Yes, coach notices, headshots, roster/session dots) · `e142f47` · v94 · 5 migrations (`u10_*`).
- **2026-09-28 · G2 Live Game reports** · `22e88ca` · v79 · migrations `g2_live_game_reports`, `g2_foul_tip_strike_fix`.
- **2026-09-24 · R6 coaching staffs** (assistants, multi-team coaches, team admin in the coach profile) · `0b8edd9` · v64 · 4 migrations (`r6_*`).
- **2026-09-24 · G1 Live Game charting** (Bullpen vs Live Game chooser, setup modal) · `a5843b4` · v63 · migrations `g1_live_game_charting`, `g1_leaderboard_bullpen_only`.
- **2026-09-23 · U9 pitcher setup + radar-gun preference** · `ccc9ed7` · v56 · migration `u9_pitcher_setup_and_radar_gun`.
- **2026-09-22 · U4 / U4b HTML reports replace PDF** · `77e46fe` · v53 · migrations `u4_reports_storage`, `u4b_report_eligibility_gate`.
  - Frozen report at an unguessable link; the coach must be verified.
  - *Deviation:* U4 was paused first, then revived as U4b.
- **2026-09-21 · U8 team leaderboard** · `cd3cd1f` · v47 · migration `u8_team_leaderboard`.
  - *Note:* hidden again on staging, Oct 10 (U13 entry above).
- **2026-09-21 · U7 Profile tab + per-pitch accuracy zones** · `c9b993f` · v42 · migrations `u7_profile_lockdown_and_coach_edit`, `u7_accuracy_zones`.
- **2026-09-21 · U6 velocity strip** (replaces the slider) · `48f48bb`.
- **2026-09-20 · R0 invite links + deferred email verification** · `19ef098` · v32 · 6 migrations (`r0_*`).
  - Invite links replace email invites; custom verification; roster removal confirm + notice.
- **2026-09-09 · U2a batter side** (tappable silhouette, stored on every pitch) · `7b0697e` · v22 · migration `batter_side`.
  - *Deviation:* U2's 7×7 grid never shipped (`GRID_SIZE = 5`).
- **2026-09-09 · U5b / D8 zone numbering protocol** · `6298c50` · v19.
- **2026-09-08 · U5 charting perspective** · `7a3bcbf` · v18 · migration `charting_perspective`.
- **2026-09-08 · U1 iPad grid fix, bigger tap targets, home plate** · `5201104` · v9.
- **2026-08-28 – 09-25 · P1-15 delete a saved session with a tombstone** · `594c714` · v66 · migrations `session_soft_delete_tombstone`, `p1_15_fix_delete_session`.
- **2026-08-28 · P1-05 in-session pitch correction** · `06617d2` · v7.
  - *Deviation:* part 2 (post-hoc editing) was built and deliberately reverted. Saved sessions are immutable; never rebuild it.
- **2026-08-28 · P1-03 invite edge cases** · `65e9664` · v5. **P1-02 forgot password** · `8861052` · v4. **P1-13 instant offline startup** · `debb35c` · v3.
- **2026-08-27 · P1-12 server-side account setup** · `46d99ed` · migration `account_setup_server_side`. **P1-01 offline outbox + stay signed in** · `01c47cc`.
- **2026-08-26 · P1-08 staging project + migrations baseline** · `a0e2fc8` · migration `baseline`. **P1-04 custom SMTP doc** · `dc6f412`.
- **2026-08-25 · P0-06 offline app shell (service worker) + P0-04 field test** · `af3cf12` · v1.
  - Also: backups procedure (`893f071`), live schema + RLS captured (`409d384`), send-session-report requires a session (`45f9745`).
- **2026-08-14 – 08-24 · foundation** (no packets): the original pages and Supabase backend uploaded through GitHub, then the CNAME (knuckleballonline.com), README and CLAUDE.md (`a30b738`).

## Standing open items (not tied to one release)
- **Design (D1, D2, D3):** done, on production (v227, v232–v233, v241). Jordan's side: re-sync `docs/design/target/` and `design-tokens.json` to the shipped `css/tokens.css`.
- **T1 team branding (logo upload, team colors):** moved to later (Joel, Oct 14). Not started; no spec on GitHub yet.
- **NCAA softball illegal-pitch variant:** not built; needs a short spec of the rule.
- **Cross-checks owed by Joel:** U13 4b (iPhone video of the bottom menu); the P1-01 offline checks; the Stage C dock-drag / tray-tap feel check.
