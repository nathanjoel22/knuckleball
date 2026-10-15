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
- **Open:** the production reset. Its list goes to Joel first; it runs only on his OK (it clears every painted zone).

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
- **A1 account deletion and export:** preconditions report `plans/a1-preconditions.md` (Oct 14); waiting on Joel's decisions. Then the App Store wrapper (Dec–Jan).
- **T1 team branding (logo upload, team colors):** moved to later (Joel, Oct 14). Not started; no spec on GitHub yet.
- **NCAA softball illegal-pitch variant:** not built; needs a short spec of the rule.
- **Cross-checks owed by Joel:** U13 4b (iPhone video of the bottom menu); the P1-01 offline checks; the Stage C dock-drag / tray-tap feel check.
- **H1 grace path:** close no earlier than **Oct 19, 2026**. Drop the 6 grace policies, seal the remaining sessions, and show Joel any leftovers first.
