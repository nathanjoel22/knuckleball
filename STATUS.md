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
- **D1 (design standardization), not started (Oct 13):** spec `plans/d1-design-standardization-2.md` is on GitHub, but its references aren't yet: `docs/design/DESIGN.md`, `css-variables.css`, `design-tokens.json`, `tailwind-v4.css` (then `AUDIT.md`), and `docs/type-sheet-reference.html`.
  - Joel's decisions: the staging work (`live-game-oct12`) stays on staging for his review before production. **Sign-in pages: option (b), move the 11 sign-in/sign-up pages to the light app look in Stage 3** (an explicit exception to "colors stay").
  - Preconditions report first, once the references land.
- **H1 grace path:** close no earlier than **Oct 19, 2026**. Drop the 6 grace policies, seal the remaining sessions, and show Joel any leftovers first.
