# CLAUDE.md — Knuckleball

Standing context for every Claude session working in this repo. Read fully before touching anything.

## Design principle (binding)

**Charting never requires the network. Only syncing and sending reports do.** A team must be able to open Knuckleball anywhere — including with no internet — and chart a complete bullpen. Login is the single honest exception, and only on first use: the standard is **log in once, then chart anywhere forever**. A token refresh that fails purely for lack of network must never bounce a charter to a login screen or block charting; genuine auth failures while online still must. Reports are never generated from an unsynced session. Any change that makes charting depend on a network round trip is a regression, whatever else it improves.

## Roster & visibility model (decided by Joel, Aug 28 2026 — Track R, built in stages; the status board says which are live)

Data follows the player. Sessions belong to the pitcher permanently; a team's view of a pitcher exists only through a current pitcher_teams membership row. Specifics, all decided — do not relitigate:
- Adding an existing account to a roster ALWAYS requires the player's in-app acceptance (pending invite shown at login). No auto-add, no acceptance email.
- Players can be on multiple rosters. Every pen is filed at session start: one of the pitcher's teams, or "independent" (NULL team_id). **Built (P2-01/02, Oct 22 2026, `plans/p2-solo-pitchers.md`, decisions in `plans/p2-preconditions.md`):** a pitcher on a team answers "Which team is this for?" on the start screen (his teams + Independent; default = his last answer on the device, `kb:fileLast:<pitcher>`; fixed once charting starts; the session carries it as `fileTeam`, `sessionFiling()`); a pitcher on no team is always Independent (no "No team yet" wall any more -- only a coach needs a team); a coach always files under his team, and `sync_session` refuses a coach filing Independent. Independent sessions: the pitcher's own; his current non-archived coaches read them under R4 (read-only, "Independent" chip); only the pitcher deletes them or makes/sends their report; no notes; never on a leaderboard; their report says "Independent" and its trends use his independent sessions only. `profiles.level` (asked at pitcher signup, changed in Profile -> Level) sets an independent game's first extra inning; team games keep `teams.level`.
- **Cross-team visibility (R4, Joel, Oct 5 2026 -- replaces the never-built "summary-only" rule).** The **recording team** (`sessions.team_id`) keeps everything: read, notes, reports, delete (head coach); after the pitcher leaves it keeps the sessions charted while he was theirs (G3). Coaches of every **other non-archived team the pitcher is currently on** READ his sessions -- pitches, events, notes, an existing report -- charted **since he joined their team** (`is_current_coach_of_pitcher(pitcher, started_at)` in the four SELECT rules), and can't add notes, create/send reports (send-session-report checks the recording team) or delete. Leaving that team ends it at once; an archived team counts as not current. The pitcher sees all of his own, in one History with team chips and a team filter. `pitcher_workload(ids[])` (SECURITY INVOKER, so it counts what the caller can see) feeds the roster's pitch-count line; the roster dot functions follow the same visibility. Leaderboards stay per team. Sports never mix (separate profiles). **Reports stay per team (R4 follow-up, Joel, Oct 6 2026, v152):** a report's team name, uniform number and trend sections (pen history, a game's recent pens and game trend) come only from the session's OWN team (`reportTeamId` / `sameReportTeam` in the tracker) -- never from the wider cross-team History, so another team's sessions can't be frozen into a shareable link.
- Membership ending — player leaves or coach removes, both with explicit confirmation — instantly removes the team's ENTIRE view of that player, both directions, automatically. The player keeps every session regardless of who recorded it. Re-joining restores nothing retroactively.
- Saved sessions are IMMUTABLE. Pitches are freely editable during a session (in-session correction on any row of the recent-pitches log). The moment "End session & save" is pressed — from a pitcher account or a team account — the pitch data is final for everyone, including coaches. Never build a post-hoc pitch editor; one was built and deliberately reverted on Aug 28 2026. Self-reported performance data that can be quietly revised after the fact is not trustworthy, and this data informs development and recruiting conversations.
- Deletion remains available: the pitcher may delete their own sessions, the coach may delete their team's. Every deletion leaves a visible tombstone in history showing the date, the number of pitches thrown, that it was deleted, and which account deleted it (player or team). Deleted sessions are excluded from all stats, trends, and reports.

## Charting surface decisions (Joel, Aug 29 2026 — Track U)
- The grid is drawn from the CATCHER'S perspective. Stored pitch coordinates are always physical; the left-handed-batter view mirrors DISPLAY NUMBERING ONLY, never stored data.
- Grid v2 (U2) is 7×7 with the strike zone at rows/cols 2-4. Boxes are numbered 1-49 per a Joel-approved diagram committed to the repo — that diagram is the canonical numbering spec, and the mapping lives in ONE shared module used by both charting and report rendering (never duplicated).
- Legacy 5×5 sessions are never migrated or touched; they render through the legacy path permanently.
- Batter side (RHB/LHB) is stored on every pitch charted after U2; it is a simulated-batter toggle, distinct from profiles.throws (the pitcher's hand).
- Reports are HTML pages at unguessable URLs, content frozen at save time (single dated exception: the Oct 6 2026 Cairn re-render, Amendment 16); PDF generation is retired with U4. Anyone with the link can view — that is the chosen trust model.

**Zone numbering protocol (D8, Sept 9 2026).** Boxes 1/4/7 are ALWAYS the inside
column, 2/5/8 middle, 3/6/9 outside — in every charting perspective and for either
batter side. Rows never flip. A zone number is a display label computed at render
time from the stored catcher-frame coordinate plus batter side (`zoneNumberFor`),
never stored and never a second copy of the mapping. Labels therefore mirror on
screen with perspective (and, after U2, batter side) so the low column is always on
the batter's side; the "Inside" accuracy highlight must always sit under the 1/4/7
labels. ~~Reports and history always render the catcher's view~~ — superseded by Amendment 16 below.

**Pitcher's view after the fact (Amendment 16 / U12, Joel, Oct 6 2026).** Every report grid (pen and
game) and every after-the-fact grid in the app (History's heat map, the accuracy-zone editor) is drawn
in the PITCHER'S view, captioned as such. One setting each side, kept in step: `REPORT_VIEW` in
`send-session-report/helpers.ts` and in the tracker. It is a draw-time left-right mirror only
(`viewCol` / `perspectiveCol(col, REPORT_PERSPECTIVE)`); zone labels come from `zoneNumberFor` with the
STORED column, so 1/4/7 stay inside for both batter sides; miss-tendency left/right reads as drawn; taps
in the zone editor map back to stored columns. Storage is untouched and the charting screen keeps the
charter's own perspective. `send-session-report/from_rows.ts` rebuilds a report from stored rows alone
(same builders as the app, session's own team only, today's names/numbers); it backs the operator-only
`rerender-reports` function (OPERATOR_EMAILS secret; dry run by default; archives originals to the
private `reports-archive` bucket with a SHA-256 manifest; rollback mode). The Cairn University Baseball
re-render (team `7e1648c1-0582-44e9-984d-a9735a88e4da`, dated 2026-10-06) is the single exception to
"reports are frozen" — never re-render anything else without Joel's explicit decision.
Stored coordinates stay catcher-frame, always — this protocol changes nothing about
storage.

## Relative accuracy v2 (U14, Joel, Oct 15 2026; `plans/u14-relative-accuracy-v2.md`, decisions in `plans/u14-preconditions.md`)

- **Asked at the start of every session:** "Turn on Relative Accuracy?" Yes / No on the start screen. A bullpen always asks; a Live Game asks only with **Intent** on, because without a called spot there is nothing to score. Stored as `sessions.ra_on` through `sync_session`, locked once saved (H1 lock). It's shown read-only as the RA on / off pill while charting.
- **Default answer:** the pitcher's last answer. It's remembered on the device (`kb:raLast:<pitcher>`) and on `profiles.relative_accuracy_enabled`, which is now that remembered answer, not a Profile switch. The pitcher or his head coach writes it, best effort when online. First time = No.
- **Marked cells:** up to **4** per pitch type per batter side, in Profile's painter (`RA_MAX_CELLS`, "n of 4"); the database refuses more (`accuracy_zones_four_cells`, NOT VALID: applies to new and changed rows).
- **Scoring, at tap 2, never recomputed:** `pitches.accuracy_hit_kind` = `exact` (landed the target cell) / `ra` (landed a marked cell for that type and side, with the cells copied onto the pitch) / `miss` (`scoreU14`, `gameHitScore`). A pitch with no batter uses the vs-RHB cells. The in-session editor rescores when the type changes. **One accuracy number** = (exact + ra) / pitches (`isHit`), everywhere: the live counter, History, trends, Bullpen to game, reports and the leaderboard ("we count whatever you call accurate as accurate").
- **Old sessions never change:** a pitch without a hit kind keeps the U7 `in_accuracy_zone` / exact path. Old reports were byte-compared before and after.
- **Reports:** a U14 session gets per-pitch-type exact / RA grids inside each batter-side block (exact `--brand-mid` via `--kr-link`, RA `--brand-soft`, misses as hollow rings; legend only with RA on; headline "H hits of N — E exact, R RA"). Pens charted with no batter get a "No batter" block. Intent games get them too. These use inline styles only, so the report stylesheet is unchanged.
- **Reset (Joel's instruction):** `supabase/scripts/u14_reset_list.sql`, then `u14_reset_run.sql`. It clears every zone and switch and proves the pitches unchanged by checksum. The lists are in `plans/u14-evidence/`; cleared zones are not restored.

## Session tags (SR1 Stage A, Joel, Nov 19 2026; `plans/sr1-session-reports.md`, decisions in `plans/sr1a-preconditions.md`)

- **Asked on a bullpen's start screen**, after "Turn on Relative Accuracy?": "What's this pen for?" Command · Velocity ·
  Short pen · No tag (`SESSION_TAGS`; two rows of two). The default is No tag every time; nothing is remembered.
  Games are never asked.
- **Fixed at Start bullpen** (`s.purpose`): a pill beside RA on / off while charting. Stored as `sessions.purpose`
  (`command` / `velocity` / `short_pen`, null = no tag) through `sync_session`, which saves anything else as null.
  It's locked at the save (`sessions_h1_lock`).
- **Copied to `session_stats.purpose`**, so baselines filter without a join (SR1 Stage B: a tagged pen compares only
  with pens of the same tag; an untagged pen with all pens).
- **Shown** as a chip on History's card (pending ones too) and in the report header ("Nov 18 · Command pen · team"). The
  report reads it from the session row, never the payload. Untagged pens and games render byte-for-byte as before.
- Migration `20261123000000_sr1a_session_tags`; rollback in `supabase/rollback/`; test
  `supabase/tests/sr1a_session_tags.sql`. Policies 32 / storage 12, unchanged.

## Reports, answer-first (SR1 Stage C, Joel, Nov 19 2026; `plans/sr1-session-reports.md`, decisions in `plans/sr1c-preconditions.md`)

Applies to reports made from Stage C on; every report made before stays exactly as it was.
- **Tabs:** a pen has Summary · Command · Velocity & workload · Trends; a game has Summary · Location · Batters · Pitch
  types · Trends · Every pitch.
  - They're radio inputs + labels with `:checked` rules: no script, and report.html / History unchanged.
  - Every id / name carries the session's first 8 characters (`ids()` in `send-session-report/sr1.ts`).
  - Every section the old reports had is kept inside a tab. The game's full pitching line opens Every pitch.
- **Summary:** a headline sentence (rules, never free text: `penHeadline` / `gameHeadline`), the window switch (1 / 3 /
  12 months, season, a year ago except college; 3 months default), four tiles against `session_baselines()` (change
  vs the window's average, range bar from 5 sessions, "only N · needs 3"), and What stood out.
  - What stood out has at most three items, judged on 3 months only, by the rules and sizes in `sr1.ts`.
  - The game's "2 of first 3" tile has no comparison.
- **The fastball** for "FB avg mph" (Joel): the most thrown of 4SFB / 2SFB (baseball) or FB (softball), labelled by
  its abbreviation.
- **The comparison is read on the server at save time** through the caller's own client (`loadComparison`): the
  baselines, the last five same-kind (same-tag) sessions for "best of the last six", and `profiles.throws` for arm /
  glove side (left / right as drawn when unset). This is the report's one deliberate server read (landmine 5 stands
  for the pitches and the Trends history).
- **No he / his / him in report text;** the footer is "Numbers and patterns only: compared with <First name>'s own
  sessions, never graded." The pitcher's-view caption (Amendment 16) sits at the end of Summary.
- **Dates are Eastern** (Joel, Nov 19 2026): every date a report or its email prints uses `TZ` (`America/New_York`,
  `send-session-report/sr1.ts`): the header, print titles, "generated", and email subjects. Before that the header and
  "generated" were UTC, so an evening session showed the next day; reports already sent keep their date.
- **Colours:** seven new `REPORT_VARS` tokens per sport (`up`, `down`, `info`, `band`, `warn-bg`, `warn-line`, `hl`).
  Baseball's "up" is #1A7F50 (contrast). Up / down always carry a sign or an arrow.

## Reader versions (SR1 Stage E, Joel, Nov 19 2026; decisions in `plans/sr1e-preconditions.md`)

- **One stored file carries its level's versions** (decision 10; `data-kr-versions` on `.page`):
  - little league: coach · player · parent;
  - high school (softball "High school & up" too) and college: coach · player.
  - The level is the report's own (`session_workload` / `session_baselines`), so the level confirmation matters.
- **Which shows:** `kr-as-player` / `kr-as-parent` on an ancestor; none = coach. The rules live in the stored file
  (`ver()`, `tabBarVersions` in `send-session-report/sr1.ts`).
  - **report.html** reads `&v=player|parent`. Its CSP hash was recomputed.
  - **History** sets the class from who is looking (`reportViewerVersion`, `applyReportVersion`, at every draw):
    - a pitcher's own login or a teen's own sign-in → player;
    - a parent, a linked parent or family → parent;
    - coaches and facility staff → coach.
  - A version the file doesn't carry (high school / college parents, every report from before Stage E) shows the
    coach version.
- **Player versions** speak in "you"; coach and parent versions use the first name.
  - **Little league player:** Summary · Where it went · Progress; two tiles, What went well (or the best pitch's line),
    the kid's 7-day wording, and **no velocity shown anywhere**. It's hidden by CSS, not removed (Joel accepted).
  - **Little league parent:** Summary · Progress; workload and rest first, then How it went.
  - **High school player:** four tiles, the top two items. **College player:** the full report in "you".
- **Copy Report URL** stays the plain (coach) link; Stage F's emails carry `&v=` per recipient.

## Report emails per recipient (SR1 Stage F, Joel, Nov 19 2026; decisions in `plans/sr1f-preconditions.md`)

- **One message per recipient** (up to 4: coach, additional contact, the pitcher's own, parent or guardian), each with
  its slot's version.
- **Slot → version:**
  - coach / additional contact → coach;
  - the pitcher's own → player, or **parent** for a parent-created player (that slot is the parent's own address);
  - parent → parent.
  - A version the report doesn't carry → coach.
- **The button** opens the report with that `&v=`.
- **Frozen with the report:** each new report ends with an HTML comment (`<!--kr-email {...}-->`, `emailComment` /
  `readEmailComment` in `send-session-report/sr1.ts`) holding each version's subject, headline, numbers, bullets,
  rest / 7-day / compared-with lines and button label. So a resend says what the frozen report says.
  - A report made before Stage F has none and keeps the plain "report is ready" email.
- **The layout** is `brandedEmail`'s optional `summary` (tables and inline styles); every other email is unchanged.
- **The "Parent or guardian" contact** (`contact_emails.parent`) is offered to every player who isn't college-only
  (`collegeOnlyPlayer`).
- Sending limits unchanged (H1 counts recipients already).
- **Known gap:** a player's contacts panel is reachable only on the iPad / computer charting screen (since N1 Stage B).

## Printing a report (SR1 Stage G, Joel, Nov 19 2026; decisions in `plans/sr1g-preconditions.md`)

- **One page per tab.** A report made from Stage G on prints every tab of the version on screen, each from a new page,
  Summary first. The rules are the stored file's own `@media print` in `SR1_CSS` (`send-session-report/sr1.ts`).
  - Hidden in print: the tab row and the window switch.
  - The window chosen on screen is the one printed.
  - The header prints on page 1 only. Pages 2 onward start with a print-only title line (`.kr-ptitle`):
    "<tab> · <name> · Bullpen · <date> · compared with 3 months".
- **Each panel carries its versions** (`kr-pv-coach` / `-player` / `-parent`, from the same labels as the tab row;
  `panel(i, html, labels, title)`), so a `&v=` link or a player's History prints only that version's pages.
- **Where you print:** report.html (its Print button, Share → Print, a browser's Print / Save as PDF). History stays a
  screen view.
- **No split** inside a card, tile row, chart, table row or at-bat line. A tall older section may continue onto the
  next sheet between its blocks.
- Reports made before Stage G print as they always did (the open tab only).

## Workload, rest and level (SR1 Stage D, Joel, Nov 19 2026; decisions in `plans/sr1d-preconditions.md`)

- **Baseball only.** Joel: "leave softball alone, pitch count rules don't apply there". Softball has no age group, no
  rest card and no 7-day card.
- **A Pitch Smart age group** (MLB / USA Baseball's seven groups):
  - `teams.pitch_smart_age`: the head coach sets it in Account → Team, through `set_team_age_group`;
  - `profiles.pitch_smart_age`: a pitcher's own, in Pitcher settings, for Independent games.
  - None set: the report says so; it never guesses from the level.
- **The level is confirmed once per team** (`teams.level_confirmed_at`, stamped by `set_team_level`).
  - Until then the head coach's Home shows "Confirm your team's level": Level of play, plus the age group for
    baseball.
  - Save confirms it on every device; Not now hides it on that device.
  - Stage E's reader versions depend on the level.
- **Reports** (from Stage D on):
  - **Rest card** on games: Pitch Smart's table (`PITCH_SMART` in `send-session-report/sr1.ts`, from
    mlb.com/pitch-smart, checked Nov 19 2026) for the game's pitch count. Back on the game's Eastern date + rest days
    + 1. Above the table, its top band; above the daily max, one plain line.
  - **7-day card** on every report: `session_workload()`, the 7 days up to the session, counted like
    `pitcher_workload`, under the caller's read rules. A heads-up past 100 / 125 / 150 (little league / high school /
    college; no level = college); it never says a pitcher can't throw.
- Migration `20261125000000_sr1d_workload`; rollback in `supabase/rollback/`; test `supabase/tests/sr1d_workload.sql`;
  report-side check `scripts/sr1d-check.ts`. Policies 32 / 12.

## Sports: baseball and softball (Track S — S1 + S2, Joel, Oct 1 2026)

- Every profile, team and session has a `sport` ('baseball' | 'softball'), derived by SECURITY DEFINER triggers (`20261001000000_s1_sport.sql`). Cross-sport team joins are refused; a team's or session's sport never changes; a profile's sport can't change once it has a team or sessions. Sign-in checks the account's sport and role; every login/sign-up link carries `?sport=`. The sport / role picker (`signin.html`, formerly `index.html`) always opens on "Which sport?".
- Client: `SPORTS` config in the tracker (catalog, palette, velo range, `hasDelivery`, `hasTimeToPlate`, `hasLeaderboard`, `hasLiveGame`) + `applySport()`; theme via `html[data-sport]` CSS variables set before paint. Softball: blue/pink theme, no leaderboard, no Set/Windup, no time to home.
- **Softball Live Game (S2):** same as baseball except no delivery (`pitches.delivery` null) and no ⏱. Own fastpitch field (`GG_FIELD_SVG_SOFTBALL`: all-dirt infield, pitcher's circle low in column 3 / row 4, bases spaced so none sits on a grid line). Softball's + More has **Illegal pitch** instead of Balk: runners up one base AND a ball added (ball 4 = walk), saved as the existing `balk` + `auto_ball` game_events rows (flagged `illegalPitch`/`illegalPitchBall` in the draft so the log shows one line and one Undo removes both) — no new event type.
- Reports: `SPORT_PALETTE_HEX` + `useSportPalette()` in `send-session-report/helpers.ts`; since D2 Stage D (Oct 13 2026) a NEW report carries its own colors and fonts as `--kr-*` CSS variables written into the file for its sport (`reportVars` in `helpers.ts`; values = `css/tokens.css`), so it never reads the site's stylesheet and a later token change can't restyle a report already sent. S1's softball hex swap (`themedCss`) is retired. Reports sent before D2 keep their own CSS and are never touched; "byte-identical" now means only that: a stored report is never regenerated (Known landmine 5). Softball game at-bats show side only, no delivery.

## Session layouts (Joel, Oct 1 2026 — G1b-r5 / G1b-r6)

- **Phones (≤500px, `isPhoneWidth`, `phoneSessionMode`)**: one session header (‹ team · photo · name · #num · offline dot · 9-dot sheet with perspective / opponent / End session & save / Discard), Set-Windup as one flip button, swipeable grid-square pitch chips in their own colors, grid capped at 340px.
- **iPad portrait (501–860px)**: the stacked layout, deliberately unchanged (Joel chose "option B").
- **iPad landscape / laptop (>860px, `isWideSession`)**: two columns for pen and Live Game — left: perspective, pitch types (never more than two per row), delivery (pen: + batter, pitch counter beside the perspective chips); right: the grid, sized by `sizeWideGrid()` to fit the viewport (cap 560, min 44px cells, batter silhouette 80% of grid height with room on both sides so the grid never moves). Live Game: Undo / New batter / New inning centered under the grid (no clock in Live Games since Oct 14, Joel; bullpens keep it). Hints show on the grid's caption line. Rotating across 860px re-renders.
- Discard session sits beside End session & save on every non-phone width (same confirm and `discardActiveSession` as the phone sheet).
- Pitch labels display in capitals everywhere; stored names are unchanged.
- Live Game state: Set/Windup defaults from the bases and velocity "Reset" are live. G1b-r3's in-grid entry (scorebook, More, ADV, DP, fielders, in-grid velocity) was replaced by G5 below.
- Live Game phones: Set/Windup sits in the status bar (the ⏱ clock was removed from Live Games Oct 14, Joel, and from bullpens by U15, Nov 6; reports still show time to home); the pitch-type row is full width (Oct 8). iPad / laptop: the account button sits in the pitcher header's row (Oct 7).

## Charting screen batch (U15, Joel, Nov 6 2026; `plans/u15-charting-phone-batch.md`, decisions in `plans/u15-preconditions.md`)

Where this and the sections above differ, this wins.
- **The Pitches bubble** (`renderArsenalSheet`) is the one editor for a pitcher's arsenal: each pitch with Edit accuracy (the
  U14 painter, inline) and Remove (confirm), then Add a pitch from the sport's list. Ways in:
  - the **"+"** (`renderArsenalPlus`), where the ⏱ was: right of Windup / Set on phones; beside the delivery control on
    iPad / laptop; softball (no delivery) at the start of the pitch row on phones, beside "Pitch type" elsewhere;
  - **holding a pitch chip** for 500 ms (a move cancels, so the strip still swipes), which opens it on that pitch; a tap
    still only selects;
  - **Profile's Pitch mix → Edit pitches**, and the "no pitches yet" prompts.
- **Who edits an arsenal:** one function, `set_pitch_arsenal(p_pitcher, p_types text[])` (migration
  `20261106000000_u15_pitch_arsenal`): the pitcher's own login (a parent for a player they created) or any coach who
  can see the pitcher on a current, non-archived team (`coach_sees_pitcher`: assistants and facility group coaches
  too). Relative-accuracy cells follow the same people in the app (the database already allowed any coach of the
  pitcher). Linked guardians and teens stay read-only (F1-G). Name, throws, uniform and radar gun stay head-only (R6).
  Online only ("Needs a connection"). The old direct column write and `coach_set_pitch_types` are **kept until cached
  apps (v336 and earlier) have updated**; a later migration removes both.
- **Mid-session:** relative-accuracy edits score later pitches only (the hit kind is stored at the tap). A session keeps
  the colour order it started with (`activeSession.typeOrder`, `colorTypesFor`), so adding or removing a pitch never
  recolours what's charted. A removed pitch stays on the pitches already thrown, and a new report lists it
  (`reportPitchTypes`).
- **Perspective:** a bullpen always opens behind the pitcher, a Live Game behind the catcher (the device no longer
  remembers a last choice). Phones: a **Catcher / Pitcher** button on the pitch-count line (Live Game: just under the
  scoreboard) flips it until the first pitch; after that a tap says "Perspective is set for this session". iPad / laptop
  keep the chips, same lock. Storage is unchanged (catcher frame).
- **The clock is retired** everywhere. `pitches.time_to_plate` stays; new pitches write null; History and reports show
  the times of sessions that have them.
- **Switch pitcher (coaches):** tapping the pitcher's name (phone header, or the name on iPad / laptop while charting)
  opens the roster. Nothing charted: it switches. Otherwise **Save and switch** / **Discard and switch** (two-step) /
  **Keep charting**. Then the new pitcher's start questions with his own defaults; in a Live Game after a save,
  "Continue from where X left off?" is already Yes, the R3 hand-off (inherited runners, `relieved_session_id`). A
  discard never continues. A pitcher with an unfinished session of his own lands on its Resume prompt.
- **Parent's player profile:** Pitch mix and Relative accuracy sit right under the photo buttons.

## Voice call (U16, Joel, Nov 8 2026; `plans/u16-voice-call.md`, decisions in `plans/u16-preconditions.md`)

- **The call:** the target tap says "<full stored pitch name> <area name>" out loud. That's a bullpen's tap 1, or a Live
  Game's intent tap when the game started with Intent = Yes (`speakCall`, from `handleZoneTap` / `handleGameZoneTap`). The
  tap that marks where the pitch went is silent and lets the call finish. Nothing is stored.
- **Area names (Amendment 17):** `ZONE_NAMES` in the tracker, keyed by `zoneNumberFor`'s 1-9: up and in, middle up, up and
  away, middle in, middle middle, middle away, low and in, middle low, low and away ("away", never "out").
  - The report's `ZONE_NAMES` (`send-session-report/helpers.ts`) hold the same nine strings; `.githooks/pre-push`
    refuses a push where they differ.
  - `zoneAreaName(cRow, cCol, side)` names all 25 cells: a ring cell takes the zone cell it touches, plus "plus" off
    either side (corners too) or "extra" above or below.
  - The batter side changes the words; perspective never does. A "no batter" pen speaks as vs RHB.
  - Every string is in `plans/u16-speech-table.md`.
- **Speech:** on-device `speechSynthesis` only: no network, no audio files. Rate 0.9 (a little slower than normal; Joel, Nov 8 --
  the packet's 1.1 shipped first in v338, then 1.0 in v339), pitch 1.0, `lang` en-US.
  - **iPhone-safe (v340):** it names no voice when the browser's default is on the device (always so on iOS), and only
    otherwise the first local en-US voice.
  - `cancel()` runs only when a call is still playing, and then the new call follows about 60 ms later. iPhone Safari
    drops a `speak()` made right after `cancel()`.
  - The first call is spoken inside the tap, which iOS needs.
- **The switch:** Voice On / Off under the perspective chips (phones: the 9-dot sheet). It's one per-device setting,
  `kb:voice` ('off', or absent = On). It's hidden in a game without Intent and wherever the browser has no speech. The
  Play Store Android app's WebView has none, so the app shell needs a native text-to-speech plugin before it can speak
  (not built).

## Live Game on the field (G5, Joel, Oct 6–8 2026; evidence `plans/g5-evidence.md`)

Built far past the uploaded spec `plans/g5-live-game-diamond.md` -- where they differ, Joel's later decisions (below) win.
- **The flip:** after a location tap the pitch chart turns over (a flat card turn, ~650 ms; no 3D -- iPad Safari mis-sized a 3D flip) to the **field on its back**: the same square and the same 25 boxes in every layout, the field drawn upright. At rest the field is built exactly like the chart (`g5Card` → `.zone-grid.g5-flat`); the two-face card exists only during the flip. Next / Undo / New batter flip back.
- **The field** (in the field's own units, 100 a box): home plate mid box 15; foul lines through 17/3 and 23/11; fence arc from box 4's top-left corner, peaking mid 7, to box 10's top-right; 1B and 3B just inside the lines (mid 23 / mid 17, outer side on the line), 2B at the bottom of 25; dirt from 17's top-left corner peaking mid 25 to 23's top-right; mound mid 24; V mower stripes (fair #8CBA5A/#6FA548, foul #60963C/#548A35), plaid infield grass -- softball: all-dirt infield, pitcher's circle. The report draws it in `send-session-report/diamond.ts`. **Since V1 (Joel, Nov 18 2026)** the app's charting field has the V1 boards' look and the report keeps its own: the box layout, the geometry and what a tap means stay identical in both; the drawings may differ.
- **Boxes** (row 0 top): `5 6 7 8 9 / 4 19 20 21 10 / 3 18 25 22 11 / 2 17 24 23 12 / 1 16 15 14 13`. What happened? Swing 1 · Looking 2 · Ball 12 · In Play 13 · Foul 14. Foul → Foul Tip 13 (any foul ball) · Foul Out 12 (any caught foul, incl. a caught strike three -- stored as an out in play, not a K). H/O/E: O 12 · H 13 · E 14. Contact: Bunt 1 · Pop 2 · GB 12 · Fly 13 · LD 14. Location: Fly flashes the outfield and Bunt the infield at once; GB / Pop / LD wait for IF 12 / OF 13 (stored `pitches.spray_field`); HR? 13 on a fly hit, 14 on a line-drive hit, then the area over the fence (hit_type HR, bases empty, no runners question). Foul Out shades foul ground only; a ball in play's location shades fair ground only (exact opposites). Runners: 3B 17 · 2B 25 · 1B 23 · Next pitch 24 (radar off).
- **Rules:** outs only when recorded (O, a strikeout, + Out); the runners question after every plate appearance except a strikeout and a homer (walks -- including ball four by + Ball -- pre-fill the forced runners); runs are not tracked; three outs end the half-inning. + Out / + Strike / + Ball under the field (+ Strike / + Ball also under the chart): auto strike / auto ball events (pitch-clock), never pitches. The G3 extra-inning "runner on 2B?" prompt sits under the chart. Velocity after the flip back sits in the chart's last two rows.
- **Data:** `pitches.spray_box` (1–25), `runners_after` (bitmask), `spray_field` (IF/OF) -- game-only (CHECKs), saved by `sync_session` (migrations `20261007000000_g5_spray_box`, `20261008000000_g5_spray_field`). New games leave `hit_type` (except HR), fielders, `runner_advances`, `runs_scored`, `bb_x/bb_y` NULL. Old games are placed on the field by fielder (C 15, P 24, 1B 23, 2B 22, SS 18, 3B 17, LF 19, CF 20, RF 21).
- **Game report:** spray charts on the field (all / by result / by contact / by pitch type, Infield · Outfield counts), what led to it (per box, per contact, pitch type × result), base states, "The pitches that mattered" (strike three, first-pitch strikes, hits, outs in play, walks, errors), "Bullpen to game" (same pitch, same spot vs the last 5 bullpens, same team; the app sends `recentPenPitches`, `from_rows.ts` builds the same).

## Field art on the charting screens (V1 Part A, Joel, Nov 18 2026; `plans/v1-field-art-and-guided-flow.md`, decisions in `plans/v1-preconditions.md`)

- **The stage** (`v1Stage`): every charting chart (bullpen and Live Game, both views, both sports) and the ball-in-play
  field sit on a drawn ballpark, the boards in `plans/v1-field-art/` (pictures in `boards/png/`).
  - Phones (≤500px) use the 440 × 518 phone boards; everything wider the 740 × 580 wide boards.
  - The art is one SVG scaled by its `viewBox` (`V1_SCENE`, generated from the boards). The chart's 25 boxes sit in
    `.v1-box` exactly where the board puts them.
  - The batter is the traced silhouette (`KB_BATTER_D`), solid `--batter`, scaled to the strike zone (`V1_BATTER`).
    None for a bullpen with No batter.
  - Chalk is the photo texture (`assets/field/chalk-line.png`, `chalk-ring.png`, precached), never a stroke.
  - Colours are the `--field-*` / `--plate-*` / `--batter` tokens in `css/tokens.css`; the app's chrome keeps its own.
- **The ball-in-play field** is its own stage. Its 25 boxes sit on the field's square, the same `G5_BOX` layout and
  handlers. `g5FieldSvg` now draws only the live layers (the shaded area asked about, the gold base under a runner).
  The flip turns the whole stage (`v1Flip`).
- **Layout (Joel's approved changes):**
  - Phones: the chart runs edge to edge. In a Live Game, the view button sits in the status bar's Windup / Set slot
    until the first pitch (`v1StatusSlot`), and the batter pill and step badge sit under the art (`v1PhoneUnder`).
  - Phones: "+" is the pitch strip's last item.
  - Wide (> 860px): Delivery above Pitch type, "+" the last grey choice in the Pitch type box (`pitchTypeTray(p, grid,
    plus)`), Recent pitches in a right column (`.wide-log`). `sizeWideGrid` sizes the stage (`--stw`); `--zg` is still
    the chart's side.
  - 501–860px keeps its stacked controls with the wide scene.
- Reports, History, Trends and the accuracy painter keep their own drawings.

## The guided Live Game flow (V1 Part B, Joel, Nov 18 2026; decisions in `plans/v1-preconditions.md`)

Live Game only; bullpens keep their flow and their No batter / vs RHB / vs LHB pill.

- **One prompt** under the chart says what to tap next (`gameStepPrompt`). It reads **Select Batter Side**, then
  **Select Pitch Type**, then **Select Pitch Intent** (Intent on only), then **Select Pitch Outcome**. After that, today's
  steps follow: what happened, ball in play, runners, velocity.
- **There is no RHB / LHB button.**
  - Step 1 pulses the two outside columns (Relative Accuracy's overlay, in see-through black since Nov 18). A tap on one puts the batter on
    that side of the screen (catcher's view: left = RHB; pitcher's view: right = RHB). A tap anywhere else does
    nothing, and nothing is recorded.
  - The side is kept per at-bat, `s.batterSides[atBatIndex]`, in the draft. So:
    - every path that moves to a new batter starts at step 1;
    - Back across an at-bat restores the previous batter's side;
    - a killed tab comes back to the same step;
    - a started game resumes even before its first pitch.
  - "Not chosen" is a real state (`gameBatterChosen`): no Live Game pitch is ever saved without a side.
  - A game started before Part B keeps the side it had.
- **The pitch type stays selected** across pitches and batters, and is kept in the draft (`s.selType`). It clears on a
  pitching change. While none is chosen (step 2), the pitch choices pulse faintly. A chart tap in step 2 does nothing.
- **A wrong side:** tap the batter, or More → **Change batter side**. Both go back to step 1 for this batter. The pitches
  already charted to him take the new side, rescored for Relative Accuracy (`gamePickBatterSide`).
- **A pitching change mid at-bat:** the hand-off carries the side when the count isn't fresh (Q7).
- **A third out made on the bases between pitches:** the same batter leads off the next inning at 0-0 (Q8).
- **Reduced motion:** both pulses are steady tints.

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
  → contact (Bu GB LD FB; a bunt lights the infield by itself. **Since Nov 18 (Joel) there's no PU: FB covers
  pop-ups**, takes IF as well as OF, and a fly fielded in the infield is never a sacrifice fly, as a pop-up never was;
  games charted before keep their 'pop') → location (IF / OF / FOUL, and FENCE for a homer;
  OF on a homer = inside the park) → **Who fielded it?** (positions as yellow pills on the field; a tap selects /
  unselects; with runners on, tap the outs in order -- 6-4-3 = force at 2B + batter; a force away from first with no
  out at first is a fielder's choice; Unassisted; a fly / line / pop out is one tap) → the batter is placed and runners
  pushed only as far as forced → **each runner asked, lead runner first** (HELD · ADV TO 2B/3B/HOME · OUT; OUT asks the
  base, or after a catch Doubled off / Out advancing to …) → **Confirm the play** (the play written out; Next saves;
  third outs and home runs stop here too). The Outs shown go up when the play is saved.
- **Where the play's buttons sit (Joel, Nov 18 2026):** every row of a ball in play (FC / E / H / O, the hit, contact,
  location and runner rows) keeps the chart's box size. The buttons are in order and centred under home plate, and ‹ Back
  starts under the leftmost one; Next ends under the rightmost (`g5PlayBelow`, `.g5-shift`).
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

## App chrome and History (Joel, Oct 8–9 2026; v188–v194)

- **History cards (v188):** every pen and game card shows the report's first chart (`renderHistoryPlot`): dots by pitch type in the PITCHER'S view (Amendment 16), a grey translucent ring, a cream 3×3 strike zone, no zone numbers and no heat shading, above a drawn home plate (`renderPerspectivePlate`, our own drawing -- no stock images). Games also get a per-type table (`gameHistoryTypeTable`).
- **Wordmark (v189):** "KNUCKLEBALL" in all caps in Black Ops One, no diamond or period, on every page -- `privacy.html` / `terms.html` too since D2 Stage C (Joel approved, Oct 13 2026). The font is self-hosted (`vendor/fonts/BlackOpsOne-Regular.ttf`, `@font-face` in `vendor/fonts/fonts.css`, license `vendor/fonts/OFL.txt`) and precached by `sw.js` so it shows offline. The Noto files were tried and removed (Oct 8).
- **Coach dock (v190–v193; history: N1 Stage A below is the rule now):** coaches on phones (≤500px, `coachDockShown`), never during the charting screen (`phoneSessionMode`), get a translucent bar fixed to the bottom (`renderCoachDock`, `dockGo`): **Home** (house) → New Session's "What will we be charting today?"; **Charts** (clipboard) → History; **Roster** (person) → opens the pitcher list and scrolls to the top of the page; **Profile** (gear) → the coach profile. Home / Charts / Profile roll the roster up and land with the pitcher's header box at the top of the screen (Profile: the top of the page content). It slides away scrolling down and returns scrolling up (its own jumps don't hide it); a highlight pill glides under a finger sliding along the bar and snaps to the nearest button on release; taps glide it too. Pure UI, no network. iPad and laptop have no dock; since Oct 26 pitchers get one too (Home · Charts · Trends · Profile), see Trends below.
- **Trends (Joel, Oct 26 2026, v310; the bar and tab details are history: see N1 Stage A below):** a tab after History: the selected pitcher's saved sessions added up (All / Bullpen / Live Game) -- strike % and peak velocity per pitch type, one point per session, and one pitcher's-view 5x5 plot per pitch type of every pitch. Built on every render from History's data (`renderTrendsView`); no report, no network. Home (same day) is four squares -- Charting, History, Trends, Profile (Armcare / Mental Game kept as concepts, not shown) -- and the phone bottom bar is Home · Charts · History · Trends · Roster · Profile for coaches, Home · Charts · History · Trends · Profile for pitchers (`dockKeys()`); Charts opens the Bullpen / Live Game question (or Resume), History opens History. **Since Oct 29 (Joel), History and Trends share one button, Analysis** (History's icon): it opens History and stays lit on History and Trends, so the bar is Home · Charts · Analysis · Roster · Profile (coaches) / Home · Charts · Analysis · Profile (pitchers); Trends is in the page's tabs and on Home.
- **Navigation (N1 Stage A, Joel + Jordan, Nov 15-16 2026, v343; `plans/n1-navigation-and-home.md`, decisions in
  `plans/n1a-preconditions.md`; replaces the Nov 5 v331 rules):**
  - **One name per place** (`PLACE` in the tracker): Home, Chart, History (its views **Sessions** and **Trends**),
    Roster, More, Pitcher settings (a pitcher's own setup), Account (the login, team and data).
  - **Phones** (any window ≤500px; `dockDevice()`, since Stage B) always show the bottom bar, never sliding
    away, hidden only on the charting screen and while a typing field has focus; **no tab bar** there. Bar
    (`dockKeys()`): coaches Home · Chart · History · Roster · More; players, parents and teens Home · Chart · History ·
    More; view-only friends and family Home · History · More. History stays lit on Sessions and Trends (the
    `analysisTray` above All / Bullpen / Live Game); More stays lit on Account. Every bar button lands at the very top
    of the page (v335).
  - **More** (`renderMoreView`, a section's first screen, no Back): Your account (the login's name and role, its email,
    one row per profile to switch, + Add a sport), Team (Add a player; for coaches Join codes and invite links -- only
    a facility side's coaches or a team's head -- and Team settings, which open Account at those sections), Help
    (Getting started and Help and support → `help.html`, Privacy · Terms), then **Sign out**. On phones the avatar
    opens More; More's Team group also holds the team switcher (`teamSwitchHtml`).
  - **Chat** is an icon at the top right, left of the avatar (`chatIconBtn`), only in a facility, with the unread +
    reports count; never on the charting screen. No Chat on the bar or in the tabs, and no coming-soon page, on the web
    and in the store apps alike.
  - **Sign out asks first** (`askSignOut`, `renderSignOutSheet`): "You're signed in as <name>", plus how many sessions
    on this device haven't synced (they stay and sync when the same login signs back in). The phone footer's Sign out
    is gone; the sidebar's opens the same sheet. The first-run screens keep their direct Sign out.
  - **Account / Pitcher settings:** a pitcher's page is one page with two headed groups, Pitcher settings (photo, name,
    pitch mix, relative accuracy, uniform, level, throws, radar gun, who can see) then Account (email, password, your
    data, then a separate **Danger** group with Delete my account at the very bottom -- Stage B); a coach's own page is
    Account (with team admin). On phones ‹ Back on Account goes to More. On iPads and computers Account also carries
    the profile switcher, Add a player and Sign out (`renderAccountExtras`).
  - **Chart** opens the chooser as two cards (Bullpen, Live Game) with the pitcher's last session under them, from the
    device's data (absent offline for a pitcher the coach never opened).
  - **Leaderboard is hidden for now** (no tab; `renderLeaderboardView` kept). The KNUCKLEBALL wordmark goes Home
    (`goHome`).
  - **Help** shows "‹ Back to Knuckleball" always, and the store apps open it inside the app (not the Safari sheet):
    `help` is out of the 17 pages' native link handler. Privacy, terms, reports and delete-account keep the sheet.
- **Menu, roster and Manage (N1 Stage B, Joel, Nov 17 2026, v344; `plans/n1b-preconditions.md`, evidence
  `plans/n1b-evidence.md`):**
  - **iPads and computers** (≥501px) have no bar and no tab row: a menu down the left (`renderSideNav`, `navGo`) --
    the wordmark, the team switcher and sport, Home, Chart, History (Sessions, Trends), Roster (coaches, with the
    facility's new count), a Facility section (Chat; Coaches and groups for the manager), Help and getting started,
    and the name row that opens Account. Above 860px it is 280px wide; from 501 to 860px a 72px icon rail that opens
    over the page (`state.navOpen`, ☰). **Phones** get a plain header instead of the old sidebar block: the wordmark,
    then Chat and the avatar. Neither the menu nor the header is drawn on the charting screen (decision 8; before
    Stage B the iPad / computer charting screen kept the sidebar).
  - **The roster is a page** (`state.view = 'roster'`, `renderRosterPage`): rows carry no actions; tapping one opens
    the **pitcher's page** (`'pitcher'`, `openPitcherPage`): header, the newest 5 sessions, Pitcher settings, then
    **Manage**. Above 860px the list and the pitcher's page sit side by side; narrower, ‹ Back returns to the list.
    `rosterCollapsed`, the Roster toggle bar and "the roster stands alone" are retired. A coach's tap on the pitcher's
    name opens their page (on the charting screen it still opens the switch sheet).
  - **Manage** (`renderManage`, `renderManageSheet`): Clear "New" (no question); Move to / Add to coach (manager: pick,
    then Confirm); Remove from <coach>'s group / my group (a sheet; when it's their only group the sheet says they stay
    at the facility under No coach yet; no email); Remove from facility / from this team (a sheet; the removal email,
    then the membership, as before). Wording uses they / them.
  - **The pitcher chip** (`renderPitcherChip`, `renderPickSheet`) replaces the big header on Chart (before charting),
    Sessions and Trends for a coach, or a parent with more than one player; picking keeps the view. Switching team
    keeps the view too (a pitcher's page becomes the roster; an archived team turns Chart into History). Picking on the
    Roster page opens the pitcher's page; launch still opens Home.
  - **Coaches and groups** (`'coaches'`, facility manager): the side's coaches with their group sizes and Show code, No
    coach yet, and Print all codes.
- **Home is the week (N1 Stage C, Joel, Nov 17 2026, v345; `plans/n1c-preconditions.md`, evidence `plans/n1c-evidence.md`):**
  `renderHomeView` replaces the four squares (`renderHomeTiles` is kept but unused); Home has no pitcher header.
  - **The line score** (`renderLineScore`, a real table): pitches per day, Sunday to Saturday in the device's time, P and
    S totals; today outlined ("–" until charted), days still to come empty. "Pitches" is `pitch_count`, the number the
    roster's "Last 7 days" line uses. Sessions waiting in the outbox count.
  - **Pitcher / teen:** line score, Chart today (Resume), the newest coach's note, Last session (History's plot, pitches,
    accuracy, chips, Open report), Trends. **Parent / linked guardian:** the player chip, "<Name> threw N pitches in S
    sessions this week." over the line score, the note ("For <name> · from …"), Latest report, Earlier. **View-only
    family:** the same without Chart.
  - **Coach:** "This week" with the team's name; Active (a pitcher with a session this week) of the roster, Sessions,
    Pitches; Start a session; the roster line score (who threw first, then "+ N with no pitches this week"); Needs your
    attention (facility New pitchers; no session in `IDLE_FLAG_DAYS` = 5 or more, longest first, from
    `pitcher_workload.last_at`; "No sessions yet"; unread chat); Recent sessions. **Facility manager:** the same across
    every coach plus By coach. A pitching coach's Home covers their group (the read rules decide).
  - **Data:** a pitcher's / parent's Home uses History's data on the device; a coach's reads `session_stats`
    (`pitcher_id, started_at, kind, pitch_count`) for the roster, the last 14 days (`loadWeekRows`, on team load, after
    a sync, and when Home shows and the copy is over 2 minutes old). The rows and `state.workload` go in the offline
    snapshot, so Home draws offline with "As of <time>". No migration.
- **Get started (N1 Stage D, Joel, Nov 17 2026, v346; `plans/n1d-preconditions.md`, evidence `plans/n1d-evidence.md`):** a
  card at the top of Home (`renderGettingStarted`). Steps are data, one list per role (`GS_STEPS`: coach, facility
  owner, pitcher / teen, parent / guardian; none for view-only family), each `{ id, label, hint, go, done(ctx) }`.
  Adding a step is one entry. Done comes from data the app holds, or from a device mark
  (`kb:gs:<uid>:<profile>:<step>`, `gsMark`) where it can't tell. Hide is per login and profile on the device. When
  every step is done it says "You're all set" once, then leaves Home. More → Getting started (`openGettingStarted`)
  shows "n of N" and brings it back. The every-visit setup reminder banner is retired; the pitcher's one-time setup
  popup stays; the coach Welcome popup no longer opens on facility sides.
- **Zone pictures, the recap and notes (N1 Stage E, Joel, Nov 17 2026, v347; `plans/n1e-preconditions.md`, evidence
  `plans/n1e-evidence.md`):**
  - Every History bar (pens and games) has a small zone picture (`renderZoneThumb`): a 5x5 heat map in the pitcher's
    view, the 3x3 zone outlined. It's built from the stats row's per-type cells or the pitches (`plotSessionOf`), so it
    draws offline. Reports stay open under their bars (Nov 5).
  - **The recap** (`renderRecap`, `state.recap`): one full-screen dark screen after End session & save, from the session
    just saved on the device. It shows FINAL · BULLPEN / LIVE GAME, the name, pitches, accuracy (a game: IP, K, BB, H),
    top velo only with radar, the plot with per-type count · accuracy, a callout only when true (best accuracy for a
    type over the last 5 sessions; a new top velo), and Send report / View report / Done. Save and switch skips it.
    The count-up and slide-in stop under reduced motion.
  - **Coaches' notes are back, on the recap only** ("Note to the pitcher", 280 characters; no comment box in History).
    A note is queued on the device (`kb:noteQueue:<uid>`) and saved to `session_notes` after its session syncs
    (`flushNoteQueue`, after every sync); a failed save shows under the outbox notice. Notes show on Home, in History
    and on the report page, facility sessions included.
  - **Facility notes:** `is_coach_of_session` (only the `session_notes` INSERT rule uses it) allows a facility session
    when the coach sees the pitcher (`coach_sees_pitcher`: their own group, or the manager). Normal teams unchanged.
    Migration `20261118000000_n1e_facility_notes` (rollback in `supabase/rollback/`, test
    `supabase/tests/n1e_facility_notes.sql`); 32 policies.
- **The pitcher card and milestones (N1 Stage F, Joel, Nov 17 2026, v348; `plans/n1f-preconditions.md`, evidence
  `plans/n1f-evidence.md`):**
  - **The card** (`renderPitcherCard`) heads the pitcher's page (coaches) and the pitcher's own Account (and a parent's
    or linked view of the player). It shows uniform number, hand, photo or initials, team · year (or "since <month
    year>"), name, pitch chips, then Sessions, Pitches (`pitch_count`), Top velo (only with readings), Accuracy (bullpens).
    It counts from the sessions the viewer can read (`cardSessions`), so a coach's card counts that team's view.
  - **Share** (J2, option A; `canShareCard`): an adult pitcher on their own card; the parent login a player sits on, or a
    linked guardian; never coaches, view-only family or a teen's own sign-in. The card is drawn by hand on a canvas
    (`drawCardPng`, 1080 × 1350) and shared as a file where the browser can, else downloaded. In the store apps it's
    shown full screen to press and hold (no file plugin in the shell; Joel, Q1).
  - **Milestones (Joel's list; no pitch counts, which push throwing more):** the 1st session; the 1st, 3rd and 5th
    bullpen and live game; total sessions at 10, 20, 50, 75, 100 then every 50; strikeouts in live games at 1, 5, 10,
    every 10 to 100, every 100 to 1,000, then every 1,000; every new top velocity, the first reading included; and the
    weekly run at 4, 8, 12, 26 and 52 weeks. One list (`MILESTONES`), worked out on the device; nothing on the server.
    A milestone is dated by the session that earned it.
  - **Where they show:** a banner on the pitcher's, teen's and parent's Home for 7 days, one at a time, dismissable
    (`kb:ms:<uid>:<profile>:<id>`). The run card ("N weeks running", this week's days with "Rest") and Recent sit under
    the card. Wording never tells a pitcher to throw more.
- **A facility's name, logo and colors (N1 Stage G, Joel, Nov 17 2026, v349; `plans/n1g-preconditions.md`, evidence
  `plans/n1g-evidence.md`):**
  - **Who sets it:** the facility's manager, in Account → Facility look (`renderFacilityLook`): a logo (PNG, JPEG or
    WebP, made to fit 256 × 256 on the device, 256 KB at most) and two colors.
  - **What it changes:** the two colors become the brand / dock / accent tokens (`facilityTokens`, `FAC_VARS`). A pair
    whose text can't reach 4.5:1 is refused at the picker.
  - **Who sees it:** everyone on that facility while a facility team is the current team (both sports' sides). They get
    the logo, name and "Powered by Knuckleball" in the menu and the phone header (`renderFacIdentity`). Never the pitch
    palettes, reports, the Live Game field, emails or the wordmark. An archived side gets no look.
  - **Storage:** `organizations` gains `brand_color`, `accent_color`, `logo_path` and `branding_updated_at`, still with no
    client grant. The manager writes through `set_facility_branding`; members read through `my_facility_brandings`. Logos
    live in the private `facility-logos` bucket (`<org>/logo.png`): members read, the manager writes (4 storage
    policies; `public` stays 32).
  - **On the device:** rows in `kb:facBrand:<uid>`, logos in IndexedDB `kb-facility`, and the active tokens in
    `kb:facThemeActive` for the pre-paint script, so the look paints offline and before load.
  - Migration `20261119000000_n1g_facility_branding`. The rollback can't delete the bucket (Supabase refuses storage
    deletes in SQL); the dashboard does that. Test `supabase/tests/n1g_facility_branding.sql`.
  - **Normal teams too (G2, Joel, Nov 17 2026, v351; `plans/n1g2-preconditions.md`, evidence `plans/n1g2-evidence.md`):**
    - **Who sets it:** a team's **head coach** (not assistants), in Account → **Team look**, the same editor.
    - **Who sees it:** the team's coaches, rostered pitchers and their parents and linked family, while it's the current
      team.
    - **Storage:** `teams` gains the same four columns (no client grant). The head writes through `set_team_branding`
      (refused for a facility side or an archived team). `my_brandings()` returns facility sides (as
      `my_facility_brandings`, kept for older apps) plus normal teams (`org_id` null), gated by `is_team_reader`.
    - **Logos:** in the private `team-logos` bucket (`<team>/logo.png`): readers read, the head writes. Storage policies
      12; `public` stays 32.
    - **In the app:** `lookKey` / `lookBucket` pick the facility or team side.
    - Migration `20261120000000_n1g2_team_branding`; rollback leaves the bucket; test
      `supabase/tests/n1g2_team_branding.sql`.
- **One name, and Account's order (Joel, Nov 17 2026, v352):** a login's own sport profiles are one person: More and
  Account show the name once, with a Baseball | Softball switch when there are two (`ownSportProfiles`,
  `renderSportSwitch`). Change name saves to all of them; players and linked players keep their own rows and names.
  "Add a player" is called **Create Child's Profile** everywhere. A coach's Account runs: the look, join codes and
  invite links, Name, team admin, Archive / Delete this team, Your data, Email, Password, Danger (last).
- **One "‹ Back" (F1-D, Joel, Oct 29 2026; `plans/f1d-preconditions.md`; v324):** top left of the page (in the account
  row on phones; its own row when the account sits in the pitcher header), every size, browser and installed. It goes
  to the section's first screen, never browser history: start questions → "Bullpen or Live Game?"; (an opened History
  session → the list: gone with the History feed, Nov 5); a chat thread → the chat list; the accuracy painter or Add a player → the
  top of Profile; a coach's Player Profile → the roster. **Never on the charting screen**, not even before the first
  pitch, and never on a section's first screen (`headerBackTarget` / `headerBack`). It replaced the chooser's own
  "‹ Back" buttons and the chat thread's "‹ Chats". The phone bar is unchanged (decision A).
- **History is a feed (Joel, Nov 5 2026, v328; `plans/hf1-preconditions.md`):** no tap to open a session and no "View
  report" tab. Every saved session's frozen report is drawn under its card as History scrolls (fetched as it nears the
  screen, drawn inert in a shadow root, kept on the device in IndexedDB `kb-reports`, max 100, cleared at sign-out,
  so it opens offline after that); 20 sessions at a time, "Show older sessions" for more. Sessions started from Nov 5
  get their report made the first time they're on screen (same call and gate as before); older ones without a report
  keep **Create report** (and the card's plot and table). **Copy Report URL** copies the link and opens nothing; the
  link still opens `report.html` as before; Email report is unchanged; the installed app keeps Share. **No new coaches'
  notes** (Chat is the direction): the comment box is gone; existing notes show read-only in History and on the report
  page; `session_notes` is untouched. A row's "New" dot clears once its card is on screen. **Each session's bar (date, pitches, strikes, accuracy...) opens and
  closes its report on tap / click / Enter** (an arrow shows which; Nov 5, v330). **Since Nov 17 (Joel, v350) every
  report starts closed** (`state.openSessions`); opened ones stay open for that page load. Arriving at a session from the
  recap, Home or a pitcher's page (`openSessionInHistory`, `openPitcherSession`) opens that one. Phones get **↑ Back to
  top** at the end of History and Trends.
- **Roster on phones (v191, v194):** the list stays rolled up until Roster is tapped (dock or the Roster bar; team load and leaving a session start it rolled up); picking a pitcher or another dock button rolls it up. Open, it shows EVERY pitcher (no 220px inner scroll box at ≤860px) -- the page scrolls.

## Installable app (P2-05, Joel, Oct 15 2026; `plans/p2-05-pwa-install.md`, decisions in `plans/p2-05-preconditions.md`)

- **Manifest:** `manifest.webmanifest` (start and id `/bullpen-tracker.html`, scope `/`, standalone, theme `#061A12`, background `#F3F5F2`), linked from all 15 pages along with the iOS home-screen tags, the 180 Apple icon, a favicon and `css/standalone.css`. Every page sets `viewport-fit=cover`.
- **Icons and splash** come from ONE source, `assets/app-icon.svg`: since Oct 22, 2026 the main logo, "The spot" (white cells, the gold pocket, on brand green; it replaced the Oct 15 "KB" placeholder). `node scripts/splash.js` redraws `icons/` (192, 512, 512 maskable, 180, 32) and `splash/` (40 iOS splash images, 20 devices × 2 orientations, plus `splash/links.html`, the tags carried by index, login and the tracker). It uses this Mac's Chrome and `sips`: no package, no outside service, and the output is committed. After changing the icon, re-run it and bump CACHE_VERSION. All of it is precached.
- **`css/standalone.css`:** the safe-area insets go on `:root` (pages set their own body padding). Installed, a strip in the sport's `--brand-bg` sits behind the black-translucent status bar.
- **Install banner** (Home only, once per device, `kb:install` = dismissed / installed): Android uses `beforeinstallprompt` (one Install button); iOS explains Share → Add to Home Screen, and only when the outbox is empty, because a home-screen app's storage is separate from Safari's. **It is OFF** (Joel, Oct 23, 2026: "I don't like or want it there"; `window.KB_INSTALL_BANNER = false` in the tracker's head), and Chrome's own install prompt is always held back too. It was on Oct 22-23, after the real logo ("The spot") replaced the placeholder icon.
- **Updates:** an installed app is rarely reloaded, so a worker that takes over from an older one shows "A new version of Knuckleball is ready · Reload" (never on the charting screen). The app also checks for a new version whenever it comes back to the front.
- **The iPhone / iPad store app's opening film** (`index.html`, `kb-app-splash`, iOS only):
  - Signed in, it never shows: the head script goes straight to the app.
  - Signed out, the first time on a device, the whole hero film plays (14.8 s). Only a film that played to its end is
    remembered (`kb:introSeen`).
  - After that, one of three parts at random (Joel, Nov 18 2026):
    - the opening, 0-3.5 s;
    - the mitt and the middle-school boy and girl, 5.0-8.25 s;
    - the older pair and their strikeout pitches, 8.3-14.25 s.
  - Each stops on its own last frame. Then the logo, then "Which sport?". With no signal it goes on after 4.5 s.
- No pull-to-refresh on the charting screen (`html.charting`). Report, privacy and terms show "‹ Back" only when installed (report: a plain link, because its CSP allows no inline script).

## What this is

Knuckleball (knuckleballonline.com) is a bullpen and live-game tracking app for baseball and softball pitching coaches and pitchers: two-tap pitch charting on a 5×5 zone grid (target vs. actual; `GRID_SIZE = 5` -- the U2 7×7 grid was specified but never shipped), pitch types, velocity, heat maps, one accuracy percentage (exact + relative-accuracy hits, U14), trend charts, and an emailed link to a frozen HTML session report. Charting typically happens on an **iPhone/iPad, often with no wifi** — never assume network availability in the tracker flow.

**Operator context that changes how you work:** the owner (Joel) is a solo, part-time developer, newer to the terminal, on a Mac. Prefer copy-paste one-liners, explain what commands do, and never assume a CI system, a second environment, or another human reviewer exists unless DEPLOY.md says so. Current scale: 1–3 teams. Bias every decision toward simple and operable over scalable.

## Architecture

- **Pages (L1, Oct 21 2026; `plans/l1-landing-page.md`):** `index.html` = the marketing landing page at `/` (no service-worker registration, no Supabase, nothing from another host; an inline script forwards a signed-in device or an auth link -- `?code=` / `#access_token=` -- to `signin.html` with `location.replace`, except the page's own `#section` anchors; hero film and screenshots in `media/`, never cached by `sw.js`). **Since R7 Stage A** (Joel, Nov 19 2026; `plans/r7-one-login.md`, decisions in `plans/r7-preconditions.md`) there is one sign-in, `login.html`: email and password, no sport screen and no role cards. Its New account form (`login.html#new`) is one form: name, email, password, the two sport cards and four account types (Pitcher · Parent · Coach · Facility, today's cards at a smaller size), the P1-10 age and terms questions for the type chosen, then Create account. Under 13 turns it into a Parent account (the name typed becomes the player's). A coach's team name, a pitcher's level and a parent's player are asked in the app afterwards. Facility asks the facility's name and makes the facility on the spot (R7 Stage B, under Training facilities). `?role=` / `&sport=` preselect New account; `?next=` (allow-listed join / staff / player links) returns there after signing in. `signin.html` and `pitcher-` / `coach-` / `parent-signup.html` are kept as forwards only (old emails, Help, bookmarks, app shells); `facility-signup.html` stays for operator links. The app opens the account's own role (`pickActiveProfile`); a parent with two or more players is asked "Which pitcher?" on a fresh sign-in (`kb:freshSignin`). Landing "Sign in" → `login.html`, Join → `login.html#new`; policy-page brand links → `/`.
- **Frontend:** static HTML/CSS/vanilla JS, hosted on GitHub Pages, DNS via Cloudflare. No framework, no build step, no bundler. Keep it that way — do not introduce npm, React, TypeScript, or a build pipeline without explicit approval.
- **Backend:** Supabase — Postgres with RLS, Auth (email), Edge Functions (Deno). Project ref: `fkgccjhuimkkbupbanxp`.
- **Email:** Resend, free plan (100/day, 3,000/month). Knuckleball's own emails (reports, verification, guardian approval, Change Email, removal notices) go through the Edge Functions and H1's sending limits. Supabase Auth's own emails -- now only password resets and new-pitcher invites -- go through Auth SMTP: production uses custom SMTP `smtp.resend.com` as `nate@knuckleballonline.com` (50/hour); staging uses Supabase's built-in sender `noreply@mail.app.supabase.io` (fixed 2/hour). Those Auth emails use the same Resend quota but are NOT counted by H1's circuit breaker (Oct 5 2026). Report links open frozen HTML pages (U4/U4b) and use no email.
- **Edge Functions** (each verifies the caller's JWT and works through the caller's own RLS-scoped client; the service role is used only where named): `invite-pitcher` (coach invites a pitcher; admin client only for `inviteUserByEmail`); `send-session-report` (builds the frozen HTML report from a client-supplied payload, uploads it to the public `reports` bucket at an unguessable token filename -- the admin client's upload -- and emails a `report.html?r=<token>` link only to the player's saved report contacts; gated on `is_pitcher_report_eligible`, refusal text names the reason via `pitcher_report_block`); `send-verification-email`; `send-guardian-consent` (P1-10); `request-email-change` (admin client only for `generateLink`); `send-removal-notice`; `delete-account` / `export-account` (A1; caller's JWT for status / request / cancel / export, the service role only for the sending limit, the guardian address, global sign-out, the export's reads of the caller's own rows and the scheduled purge); `facility-invites` (operator-only, OPERATOR_EMAILS: facility signup links for `operator.html`, and since R7 Stage B its Facilities list; the admin client writes `facility_invites` and reads `organizations` / managers' names after the operator check; sends no email); `facility-notify` (R7 Stage B: caller's JWT; the admin client only claims the caller's own self-serve organization's `notified_at` (and undoes it if the send fails) and takes the sending limit; one email to the operator); `rerender-reports` (U12, operator-only: refuses any login not in `OPERATOR_EMAILS`; uses the admin client throughout to rebuild one team's existing reports from stored rows via `send-session-report/from_rows.ts`, archive the originals to the private `reports-archive` bucket and overwrite them at the same links; dry run by default, `run` needs the dry run's `expect_count`, `rollback` restores the archive after checking each SHA-256; never sends email). Every sender calls `_shared/rate_limit.ts` (`rate_limit_take` with the service role) before sending -- see "Sending limits (H1 Part 2)".

## Schema and RLS

Source of truth: `supabase/schema/schema.sql` (live production dump, 2026-08-25) + `supabase/schema/SCHEMA_NOTES.md`. As of P1-08, `supabase/migrations/` exists with a baseline migration generated from that dump, and the old stale hand-written `supabase/schema.sql` (which predated the RLS-recursion fix and the current pitches model) has been deleted.

The real tables (from the dump): `profiles` (incl. `contact_emails jsonb`), `teams` (`coach_id` → auth.users), `pitcher_teams` (`pitcher_id` → **profiles**, not auth.users — required for the PostgREST embeds the roster code uses; keep it that way), `invites`, `sessions` (`pitcher_id` → auth.users NOT NULL; `team_id` → teams, nullable since P2-01 (NULL = independent); `logged_by` → auth.users — the person who charted, which may be a coach or teammate rather than the pitcher), `pitches` (`session_id` → sessions; `target_row/col` + `actual_row/col`; `accuracy_mode` with a check constraint matching the relative-accuracy modes).

There are 32 RLS policies on production and staging (since F1-A, Oct 29 2026: + the two facility group read rules; F1-G edits rules but adds none) (production and staging, Oct 28 2026 after SC1: + the `session_stats` read rule; 29 after the H1 grace close, Oct 21 2026 -- 34 before it, Oct 5 after the teams hotfix; S3 session_notes: coaches add, author deletes, author/pitcher/current coaches read via `is_coach_of_session`; the report page reads notes through `get_report_notes(token)`). Since H1 nobody holds FOR ALL on sessions, pitches or game_events: see "Saved sessions and sync (H1)" below. Decision D3 is settled and built: sessions belong to the pitcher, team affiliation is optional (`team_id` nullable since P2-01, migration `20261026000000_p2_01_team_optional`).

**Profiles vs logins (S4 Stage A, Oct 2 2026).** A login (auth user) owns one or more profiles (`profiles.account_id`); its primary profile has `id = account_id` and holds email verification. Profiles no longer reference `auth.users`; `sessions.pitcher_id/logged_by/deleted_by`, `teams.coach_id` and `invites.invited_by` reference `profiles`. Every policy and function checks ownership with `is_my_profile(p)` (team helpers: "the caller owns a profile in that row"); functions acting as the caller take an optional profile id and otherwise use the login's only profile (`my_single_profile()`), refusing with `profile_required` when the login has several -- never `auth.uid()` as a profile id. "Add a sport" = `add_sport_profile(sport)`. Report eligibility reads verification through the profile's login. The app runs one ACTIVE profile at a time (`kb:activeProfile:<uid>`, per-profile offline snapshots `lastKnownContext:<uid>:<profile>`), switches in place without a reload, and sign-in never refuses for sport (nor, since R7 Stage A, for the kind of login). Down migration: `supabase/rollback/20261002020000_s4a_profiles_down.sql`. RLS proof: `supabase/tests/s4_rls_matrix.sql` (identical before/after on staging).

**One login, several roles (R7 Stage C, Joel, Nov 19 2026; `plans/r7-one-login.md` Stage C, decisions in
`plans/r7-preconditions.md`, evidence `plans/r7c-evidence.md`).**
- **A role** is a profile on the login (coach or pitcher, per sport), a parent's players or `player_links` rows, or a
  facility (`organizations.manager_login`). No new table.
- **Gained only by accepting a link, and only when the page asks (`p_add_role`):**
  - `join_team_via_invite` / `join_group_via_token`: a coach or parent login → Pitcher ("Pitch for <team> too?");
  - `join_team_as_coach`: an adult pitcher or parent login → Coach ("Coach <team> too?");
  - `accept_player_link`: any adult login → Parent of that player;
  - `create_facility_self` / More → "+ Start a facility": any adult login → Facility.
  - New profiles are made in one place, `r7_add_role_profile` (adults only, never a child sign-in), with
    `profiles.created_via` (`team_link` / `qr_code` / `staff_link` / `facility`; null = signup).
  - Without `p_add_role` the joins behave as before (old apps).
- **Kept:** every age rule, `coaches_must_be_adults`, a child sign-in's single role, one facility per login,
  `create_team` for coaches. A facility manager's own coach profile can join another team's staff (Joel's case).
- **What a two-role login reads = the union of its roles, never more** (decision 6; `supabase/tests/r7_roles_matrix.sql`
  splits each role onto a twin login and compares row for row). The app shows each role only its own screens.
- **The switcher** (`my_roles()`, cached in `kb:roles:<uid>`; `renderRoleSwitch`): More → Your account on phones, a
  Role select under the team in the side menu, Account's extras. Plain names: "Coach — <team>", "Facility — <name>",
  "Pitcher — <teams>", "Parent — <player>". Shown only with more than one role. `switchRole(profile, team)`.
- **What sign-in opens:** Account → **Your roles** → "Open this first" (`set_opening_role` → the primary's
  `opens_profile` / `opens_team`, so every device). Unset: the primary, a facility manager's facility first. A cold
  start reopens the last role used on the device (as before).
- **Facility hand-off** in Account (`renderFacilityHandoff`, `handoff_facility`): both sides to a coach already on both
  staffs. Deleting the account stays refused (`still_head`) until then.
- Delete and export already cover every profile on the login (A1), so every role.
- Migration `20261122000000_r7c_roles`; rollback `supabase/rollback/20261122000000_r7c_roles_down.sql`; tests
  `supabase/tests/r7c_roles.sql`, `r7_roles_matrix.sql`. Policies 32 / storage 12, unchanged.

**Parent accounts and players (S4 Stage B, Oct 2 2026).** A parent login has a primary profile with role `parent` (no sport; never charts, never joins a team) created by `ensure_account_setup('parent', name)` from `parent-signup.html`. Any login attested 'adult' can `add_player(name, sport, throws, consent)`: a managed pitcher profile (`account_id` = that login, `managed_by` = its primary profile, `guardian_consented_at` + `consent_via = 'parent_created'`, reports to the login's email via `contact_emails.pitcher`); no email, login or age is ever stored for a player. Players join teams through `join.html`'s "Join as:" picker (shown only to logins that are parents or manage players). Coaches see "Parent account" (`get_roster_verification.managed`). Parents, like coaches, can only attest 'adult'. Under 13 is possible ONLY as a parent-added player -- self-signup still has no under-13 answer. One-time notices in the tracker (the age box, "Who's charting?") share one overlay path in `render()`: dead-center over the app on the shaded backdrop (`--scrim`: since D2, the sport's own dark), one at a time. Rollback: `supabase/rollback/20261002060000_s4b_players_down.sql`; acceptance: `supabase/tests/s4b_acceptance.sql`.

**Departed pitchers (G3, Joel, Oct 2 2026).** A session belongs to the team it was charted under (`sessions.team_id`, never changed after insert). Coaches read sessions — and their pitches, game_events and notes — by that team (`is_team_coach(team_id)`, `is_coach_of_session_team`), so they keep a pitcher's sessions from while he was on the team after he leaves; writing notes still needs him on the team now (`is_coach_of_session`). A new session can only be filed under a team the pitcher is on now, or one he left after the session started (trigger `sessions_g3_team_check`, reading `pitcher_team_departures`, which a trigger fills whenever a `pitcher_teams` row is deleted). The pitcher always sees all his own sessions. Departed pitchers' old sessions are reachable by SQL only (no app screen yet, Joel's call).

**Live Game events and levels (G3).** `game_events` also stores `seq` and the count/inning before each event. Event types now include `illegal_pitch` (softball: ADV = with runner_advances, no ADV = without; always followed by its `auto_ball`) and `tiebreak_runner` (extra innings, "Start with runner on 2B?"). Game reports and `compute_game_summary` count IBB / auto-ball-four / auto-strike-three as BB/K and list them under "Other events"; pitch stats never include them. `teams.level` (baseball little_league / high_school / college; softball little_league / high_school_up, CHECK-tied to sport, head coach sets it) decides the first extra inning: 7 / 8 / 10 and 7 / 8.

**Migration history.** Every schema change up to P1-08 was applied to production by hand; `supabase/migrations/20260826082320_baseline.sql` is the snapshot of that state and the first real migration this repo has. The baseline was later registered on production, and `supabase migration list` (Oct 6 2026) showed every migration recorded there, identical to this repo; `db push` runs only new files (see DEPLOY.md). Keep regenerating the dump in `supabase/schema/schema.sql` after any approved schema change — it stays the human-readable source of truth.

**Report gate invariant (P1-10, Oct 2 2026; P2-01 removed the team condition, Oct 22 2026 -- Amendment 11's temporary restriction retired).** A report can be generated or sent only when: the pitcher's LOGIN is email-verified AND the calling coach is verified (Amendment 11) AND the pitcher's login is attested 'adult' OR has guardian approval (13-17) AND, for a parent-added player, the player's own consent stamp is set (S4 B). Existing logins that haven't answered the one-time age box get NO reports until they answer (Joel, option a). The age bracket, terms version and guardian state live on the login's PRIMARY profile; `guardian_email` and `guardian_consent_token` are never client-readable; guardian emails go only to the stored address, once per 10 minutes (`claim_guardian_send`). The one-time box is decided only on the online load -- it never appears offline. Policy pages (`privacy.html`, `terms.html`, Version 2026-10-29: parent accounts and under-13s approved Oct 2, the accurate leaderboard sentence Oct 3, in-app deletion / export and 7-day backups Oct 14, training facilities and chat Oct 29, linked sign-ins Oct 29 -- quiet updates, `TERMS_VERSION` stays 2026-10-17 so no "I agree" box) were approved by Joel; any text change needs his re-approval in the commit message. Fonts and supabase-js are self-hosted under `vendor/` -- pages load nothing from third-party hosts; keep it that way (the privacy policy says so).

**Change Email (Joel signed off as an auth-flow change, Oct 2 2026).** The address lives ONLY in `auth.users` (no `profiles.email`). The client never calls `supabase.auth.updateUser({ email })`. `request-email-change` (Edge Function, caller's JWT) calls `begin_email_change()` (records the request in hidden profile columns, cancels any outstanding verify link, 1 per 10 minutes), has Supabase GENERATE (not send) the email-change link with the admin client -- its only admin use -- and sends ONE Knuckleball email via Resend to the new address. Landing (`bullpen-tracker.html?email_change=1`) runs `confirm_email_change()`: the login's `auth.users` email must equal the requested address with nothing pending; it sets `email_verified_at` and moves `contact_emails.pitcher` on every profile the login owns. The account stays verified on its old address while a change is pending. `verify_email` links are bound to the address they were sent to (`email_verify_sent_to`). Only `verify_email` and `confirm_email_change` set `email_verified_at`; neither reads `email_confirmed_at` (Amendment 9). Requires, in BOTH projects' Auth settings: "Secure email change" OFF, and the tracker's `?email_change=1` URL in the redirect allow-list. Rollback: `supabase/rollback/20261002070000_email_change_down.sql`.

**Staging report links.** `send-session-report` reads an optional `REPORT_SITE_ORIGIN` secret for the emailed link; staging's email links (`REPORT_SITE_ORIGIN`, `VERIFY_REDIRECT_URL` -> the verify and guardian-approval pages, `INVITE_REDIRECT_URL`) all point at **`http://Users-MacBook-Neo.local:8000`** (Oct 22, 2026): the Mac's Bonjour name, which stays the same when its Wi-Fi address changes (it was `.15`, `.68`, `.19`, then `172.16.225.140`), so a phone on the same network opens the local staging site while `python3 -m http.server 8000 --bind 0.0.0.0` runs. Before that the verify / guardian / invite links still pointed at `http://localhost:8080` (Sept), where an old service worker served pre-rebrand copies of those pages -- clear `localhost:8080`'s site data if one ever reappears. Production has no `REPORT_SITE_ORIGIN`, so it links to https://knuckleballonline.com; never set it on production.

**Saved sessions and sync (H1, Joel, Oct 3 2026; absorbs SC2).**
- **Nothing reaches the server until "End session & save"** (Joel accepts this). In-session edits and Undo are device-only; every session row is saved (`ended_at` set) when it's written.
- **One atomic call per saved session:** the outbox sends `sync_session(p_session, p_pitches, p_events)`, which checks entitlement itself (the pitcher's own profile, or a coach of the session's team, charting as one of their own profiles), inserts session + pitches + events (the sport and team triggers still fire) and sets `sessions.sealed_at` -- all or nothing. An id that's already saved and sealed returns `already_saved` and writes nothing, never a merge; the app clears the item and tells the user. Any other refusal keeps the item queued with its reason and retries; nothing is ever discarded. Never write sessions/pitches/game_events directly from the app.
- **The lock (every caller, server functions included):** `sessions_h1_lock` -- a saved session can't be un-saved, re-timed or change pitcher/team/kind/sport/start/game fields or its purpose (SR1 A); the tombstone fields are writable only by the server's own functions (`delete_session`); `report_path`/`report_generated_at` stay writable. `h1_child_lock` -- a saved session's pitches/events can't change (an identical re-send is skipped; the `after_pitch_id` FK may still clear itself), and nothing can be added once sealed.
- **Deleting is only `delete_session()`** (the pitcher for own sessions, the team's HEAD coach; assistants refused), which writes the tombstone. No client DELETE rule on any of the three tables.
- **Grace path: CLOSED on production Oct 21 2026** (Joel; migration `20261023000000_h1_grace_close`, after backup 2026-10-21-1538). It let devices on v144 and earlier sync through the old direct path (INSERT into saved-but-unsealed sessions) via five "H1 grace" policies -- not six, as this file used to say. Closed after no old-path write since Oct 7: the five policies dropped (34 -> 29) and every saved session sealed (69 on production, contents unchanged). Every saved session is now sealed; only `sync_session` writes sessions, pitches and game_events. Rollback re-creates the policies (`supabase/rollback/20261023000000_h1_grace_close_down.sql`); sealing is never undone. Test: `supabase/tests/h1_grace_closed.sql`.

**Session stats (SC1 server half, Joel, Oct 28 2026; `plans/sc1-preconditions.md`).**
- `public.session_stats` holds one row per saved, live session, with counts, never percentages: pitches, pitch count,
  strikes, hits (the one U14 accuracy number), exact / RA, U7 zone counts, velocity n / sum / min / max (Amendment
  10), time to home, per type (with cells by batter side and delivery), per side, and cells. A game also gets
  `compute_game_summary`'s JSON plus WP / BK / SF / SAC / hit types.
- It is written only by the `sessions_sc1_stats` trigger through `finalize_session_stats`. The trigger fires when
  `sync_session` seals a session, when R3 changes a game's `exit_*` / `final_at`, and when the session becomes a
  tombstone (row removed).
- **A stats error never stops a save** (`sc1_try_finalize` catches it and logs it to `session_stats_failures`;
  re-run `select public.sc1_try_finalize(id)`).
- One read policy, the same as `pitches`; no client writes.
- **The app reads it (SC1-B, Joel, Oct 28 2026, option C; `plans/sc1b-scope.md`; staging, v317):** History's cards,
  type tables and plots, Trends, the reports' pen history and game-trend velocity, and the roster's pitch-count line
  (`pitcher_workload`) come from the row; the app reads only `stats_version` 2 (`STATS_VERSION`) and otherwise uses
  that session's pitches. v2 adds a game's `innings` (the highest inning a pitch was thrown in; no longer shown) and per
  type `side_strikes` / `delivery_strikes` (Trends' splits). The game card shows **innings pitched** (Joel, Oct 29): the
  summary's `outs_recorded` as innings.outs, like the report's IP (`gameIpText`).
- **Pitch rows** are fetched only for the newest 20 (`HISTORY_PREFETCH_N`) sessions of the signed-in pitcher's own
  History and of pitchers this viewer has opened (tapped) on this device (`kb:histOpened:<uid>:<profile>`) -- never
  for a roster pitcher who was only auto-selected -- and per session when a report needs them
  (`ensureSessionPitches` / `reportPitchSessions`). Older History plots are drawn from the row's cells (Joel approved:
  same boxes, grouped by type inside a box).
- **Offline History:** those prefetched pitchers' History is kept in **IndexedDB** (`kb-history`), never localStorage
  (the outbox and drafts live there and must never run out of room), at most 200 sessions with pitches device-wide
  (`HISTORY_CACHE_MAX`), the least recently opened pitcher's oldest first. Sign-out (and a revoked login) clears this
  login's copy (`histCacheClear`).
- Any change to how a stat is computed changes the app AND `finalize_session_stats` together (bump
  `stats_version` in both, recompute). Then `scripts/sc1-compare.js` and `scripts/sc1b-compare.js` must show 0
  differences.
- A column only carried from the session, not computed (SR1 A's `purpose`), needs no bump and no recompute.
- Rollback: `supabase/rollback/20261028000000_sc1_session_stats_down.sql`; test: `supabase/tests/sc1_session_stats.sql`.
  SC1-B: rollback `supabase/rollback/20261029000000_sc1b_stats_v2_down.sql`; test `supabase/tests/sc1b_workload_rls.sql`.
- **History baselines (SR1 Stage B, Joel, Nov 19 2026; decisions in `plans/sr1b-preconditions.md`).**
  - `session_baselines(session)` (SECURITY INVOKER: it counts what the caller can read, like `pitcher_workload`) pools a
    pitcher's earlier sessions of the same kind from this table. A tagged pen counts only same-tag pens; the session
    itself and anything later never count, nor sessions under 10 pitches.
  - Windows: 1, 3 and 12 months; this season (Nov 15, or Sep 1 for college, Eastern time); a year ago (not college).
  - Averages from 3 sessions, the 10th-90th percentile range from 5, per pitch type too.
  - The level is the team's, else the pitcher's profile level, else the sport's last level (`sr1_session_level`).
  - A game's first-pitch strikes are rebuilt from the stored rounded % (exact under 100 first pitches).
  - This is the one server-side read a report makes on purpose (landmine 5 otherwise stands).
  - Proof: `supabase/tests/sr1b_baselines.sql`, and `scripts/sr1b-compare.js <ref> <pitcher>...` (by hand from the
    pitches, 0 differences). Any change to a stat's computation re-runs it.

**Training facilities (F1-A, Joel, Oct 29 2026; `plans/f1-training-facilities.md` v2, decisions in
`plans/f1a-preconditions.md`; staging, v321).** A third login area beside Pitcher and Coach.
- **Model:** an `organizations` row (`manager_login`) owns two teams, `teams.kind = 'facility'`, one per sport, ALWAYS
  both (decision B). The **Facility Manager is plain head of both** (`teams.coach_id`; two coach profiles on one login),
  so every head rule works unchanged. "Facility login" = a login that owns an organization (`is_facility_login()`); its
  profiles are ordinary `coach` profiles.
- **Signup:** Joel makes the link on **`operator.html`** (Oct 31 2026: the `facility-invites` Edge Function, OPERATOR_EMAILS
  only, writes the `facility_invites` row with the service role after `facility_email_status` checks the email can work;
  it lists open / used / expired links and cancels unused ones; it never sends email -- the page opens a ready message in
  Joel's own mail app). `facility-signup.html?t=<token>` makes the
  login, then `create_facility(token)` makes everything, once (wrong email / used / expired refused; same login again
  returns the same org). (Decision E, invite-only, was reversed by R7 Stage B: see the next bullet.)
- **Self-serve (R7 Stage B, Joel, Nov 19 2026; `plans/r7-preconditions.md` item 5, evidence `plans/r7b-evidence.md`):**
  New account → Facility asks the facility's name and the 18+ box, makes the login, then `create_facility_self(name)`.
  - **Same result as a link, by construction:** both call `f1_make_facility` (not callable by clients). Levels take
    the teams' default; the manager changes them in Account. `organizations.created_via` = `operator_link` /
    `self_serve`.
  - **Refusals:** `already_manager` (one per login), `login_in_use`, `adult_required`, `name_invalid`, and `daily_cap`
    (all self-serve facilities, `rate_limit_config` `facility_self_serve_day`, 20; tune there).
  - **Verified before adding people:** a self-serve facility whose manager's primary profile has no
    `email_verified_at` takes no pitcher and no coach but the manager. The trigger `r7_facility_verify_gate` on
    `pitcher_teams` and `team_coaches` covers every way in; joins raise `facility_unverified`. The app shows "Verify
    your email to invite coaches and pitchers" (`my_facility_needs_verify`, `facVerifyBlocked`) in place of codes and
    links, and the join pages say "Not open yet". Operator-made facilities are never gated.
  - **Joel's email:** `facility-notify` sends one plain email per self-serve facility to the first `OPERATOR_EMAILS`
    address, claimed once with `organizations.notified_at`; the app retries if login.html's call failed
    (`kb:facNotify`).
  - **operator.html:** a Facilities list (`facility-invites` `facilities`): how each was made, when, and whether a
    self-serve manager is verified. Operator links work as before.
  - Migration `20261121000000_r7b_facility_self_serve`; rollback `supabase/rollback/20261121000000_r7b_facility_self_serve_down.sql`; test
    `supabase/tests/r7b_facility_self.sql`. Policies 32 / storage 12, unchanged.
- **Cards (decision A) -- retired by R7 Stage A (Nov 19 2026):** there are no sign-in cards; nobody is refused for the kind of
  login at sign-in. History: `login.html?role=facility` signed in only facility logins; the Pitcher and Coach cards refused
  them. Browser-side only (sign straight out, plain message); the server's read rules still decide all access.
  **Since Nov 5 (Joel, v327):** the Pitcher card is for pitchers, parents (with their players) and teens' own sign-ins,
  and refuses any login with a coach profile; a player a coach added with no email of their own sits on the coach's
  login and opens from the Coach card. The Coach card refuses a login with no coach profile, so a player with their own
  email (their own login, even one a coach invited) signs in only on the Pitcher card. A login with no profile yet goes
  by its signup `intended_role`, or is let through.
- **Groups:** `coach_groups` (one per coach per facility team, made by trigger when a coach joins; `join_token` is
  F1-B's QR, never granted) and `coach_group_members` (`flagged_new`). Actions only through `add_to_group`,
  `remove_from_group` (since N1 Stage B, J3: removing the last group leaves the pitcher on the side under "No coach
  yet"; only Remove from facility ends the membership and logs the departure; migration `20261117000000_n1b_remove_from_group`), `move_between_groups`
  (manager only) and `clear_new_flag`; a coach acts on their own group only.
- **Narrowed R4 inside a facility (decision D):** `coach_sees_pitcher(team, pitcher)` replaced `is_team_coach(team)`
  wherever a pitcher is involved (the sessions / pitches / game_events / session_stats / pitcher_teams / profiles read
  rules, the report-link write, `is_current_coach_of_pitcher`, `is_coach_of_pitcher`, `is_coach_of_session_team`,
  `sync_session`'s charting check, the roster functions). It equals `is_team_coach` on `kind = 'team'` (proven by
  `supabase/tests/f1a_rls_matrix.sql`: every login, every table, before = after). On a facility team a pitching coach
  sees, charts and reports only their group's pitchers; the manager sees all. Coaches of the pitcher's other teams
  still read lesson pens (R4 stands).
- **No leaderboard on facility teams; notes since N1 Stage E only by the pitcher's group coach or the manager** (`is_coach_of_session`; `get_team_leaderboard` raises
  `facility_team`; the tracker hides both). `handoff_facility(new_manager)` = the R6 handoff on both sides at once
  (the new manager must already coach both; decision C).
- Rollback `supabase/rollback/20261030000000_f1a_facilities_down.sql` (refuses while facility sessions exist); tests
  `supabase/tests/f1a_acceptance.sql`, `f1a_rls_matrix.sql`; load test `plans/f1a-load-test.md`.

**Chat (F1-C1, Joel, Oct 29 2026; `plans/f1c1-preconditions.md`; staging, v322).** Only inside a training facility.
- **Threads:** `facility` (one per organization; only the manager posts; every coach, pitcher and parent there reads)
  and `private` (one open per pitcher per coach group: the group's coach and the family post; the side's manager reads).
  "Family" = the login the pitcher's profile sits on: the pitcher themself, or the parent who created the player
  (`chat_family_ok`; a 13-17 login needs the guardian's approval first), and since F1-G a linked second parent or the
  player's own sign-in (`chat_is_family`); never friends and family.
- **Access is computed, not stored:** `chat_access(thread)` from today's groups, so moving a pitcher
  (`move_between_groups`) takes the open thread to the new coach, who reads its history; leaving a group closes it
  (family keeps read-only). The four chat tables have no client grant and no policy (policies stay 32); the app uses
  only the `chat_*` functions.
- **Rules:** 2,000 characters, text only; YouTube links open in the browser (`chatBodyHtml`, escaped first). Author
  deletes their own message (text kept for the manager); pins up to 5 (the thread's coach, or the manager on the
  facility thread); Report reaches the manager (Resolved clears it); a coach's "Close this chat" = read-only, the
  manager reads it for 90 days, then pg_cron `f1c1-chat-clear` deletes it (`chat_clear_archived`).
- **Account deletion:** `a1_purge_profile` blanks their messages to "Deleted account" and closes private threads
  about them; Download my data has `chat_messages.csv`.
- **App:** a Chat tab after Trends and a Chat button after Analysis on the phone bar, only when `chat_summary()` says
  the login has a facility (cached per login, `kb:chatOn:<uid>`); the count = unread (a manager: the facility thread
  and their own trainees) + open reports. Polling, not real time (decision F): 30 s for the count, 5 s in an open
  thread. Online only; never on or over the charting screen.
- **Policy text:** the facility and chat additions on `privacy.html` / `terms.html` (Version 2026-10-29) were approved
  by Joel on Oct 29 as a quiet update: `TERMS_VERSION` stays 2026-10-17, so no login is shown the "I agree" box.
- Rollback `supabase/rollback/20261031000000_f1c1_chat_down.sql`; test `supabase/tests/f1c1_chat_acceptance.sql`.

**QR join codes (F1-B, Joel, Oct 31 2026; `plans/f1b-preconditions.md`; staging, v325).** One code per coach per facility
side (`coach_groups.join_token`) opens `join.html?c=<token>`: **parents first** (make a parent account or sign in on
the page, then the "Join as:" picker: pick or add the player); one small link, "I'm 18 or older and pitch for myself",
for adult pitchers (no 13-17 self-join from a code: `join_group_via_token` refuses a pitcher's own login under 18 with
`adult_required`). A join adds the facility membership and the coach-group row flagged New; a pitcher already there
joins the second coach's group too. A coach shows ("Show my join code": full screen, black on white, drawn on the device
by `vendor/qrcodegen.js`, Nayuki MIT v1.5.0, from codes cached per login, so it works offline), shares, prints
(`qr-print.html`: one black-and-white letter page per coach with the wordmark; the manager's "Print all codes") and
regenerates (`rotate_group_code`; the old code stops at once, joined pitchers stay) their own code; the manager every
code on their sides (`my_group_codes`). The migration also restored F1-A's intended column-only grants on
`coach_groups` / `coach_group_members` (Supabase's default table-wide SELECT had let a side's coaches read every join
code). Rollback `supabase/rollback/20261102000000_f1b_qr_join_down.sql`; test `supabase/tests/f1b_acceptance.sql`.

**Linked sign-ins for a parent's player (F1-G, Joel, Oct 29 2026; `plans/f1g-preconditions.md`; staging, v323).**
- **Who links:** only the parent who created a player (`profiles.managed_by`; the player sits on that parent's login)
  makes one-time links (7 days, one unused link per role), removes people and deletes the player. Roles
  (`player_links`, no client grant): `guardian` (one: two parents in all), `child` (one: the player's own sign-in,
  **13-17 only**, a brand-new login whose primary profile has role `child`, no sport, approved by the link,
  `consent_via = 'parent_link'`) and `family` (up to 5). The joiner opens `player-link.html?t=`: the child makes a new
  sign-in; adults sign in to, or make, a parent account (coach and pitcher logins are refused). Anyone linked can leave
  (`leave_player`). Under-13s never get a sign-in. Teens who signed up themselves keep the P1-10 email approval.
- **What each gets:** `guardian` and `child` chart for the player (`sync_session` takes `can_chart_for`; they chart
  AS the player, `logged_by` = the player, like the creator), read everything, send reports to the saved contacts (their
  own email verified) and chat (`chat_is_family`). `family` reads the charting history only (sessions, pitches, events,
  stats, notes, report links): no charting, chat, contacts or leaderboard. Nobody linked edits the profile, joins teams
  or deletes sessions.
- **Checks, not ownership:** `is_my_profile` is NOT widened (it grants writes). Read rules add `is_linked_to(pitcher)`
  (any role) or `can_chart_for(pitcher)` (owner, guardian, child) beside it; the policy count stays 32. The app adds
  `my_linked_players()` to the switcher (`fetchMyProfiles`, rows carry `linked_role`); `activeLinked()` /
  `viewOnlyLinked()` hide what the server refuses; the creator's Profile has "Who can see <player>"
  (`player_access`, `create_player_link`, `cancel_player_link`, `remove_player_link`).
- **Deletion and export:** links go with the player, the linked login or a removal; a purged child sign-in's chat
  messages blank like anyone's. Download my data has `player_access.csv`.
- **Policy text:** the linked sign-ins additions on `privacy.html` / `terms.html` (Version 2026-10-29) were approved by
  Joel on Oct 29 as a quiet update (`TERMS_VERSION` stays 2026-10-17, no "I agree" box).
- Rollback `supabase/rollback/20261101000000_f1g_player_links_down.sql` (refuses while links or child sign-ins exist);
  test `supabase/tests/f1g_acceptance.sql`.

**Sending limits (H1 Part 2).** Every function that sends email or writes a report file calls `takeRateLimit()` (`supabase/functions/_shared/rate_limit.ts`) before sending: per-user, per-recipient and a daily circuit breaker at 90% of `RESEND_DAILY_QUOTA` (Resend free plan: 100/day, 3,000/month), with one alert email to `ALERT_EMAIL` per day when it trips. Limits live in `public.rate_limit_config` (tune there, no deploy); events in `public.rate_limit_events` (pruned after 7 days). Neither table nor `rate_limit_take()` is reachable by clients -- the functions call it with the service role, passing the caller's verified id; that RPC is the service role's only use in those functions besides the existing report upload and `generateLink`. Over a limit -> HTTP 429 `{ error: <human message>, code: 'rate_limited' }`, shown in the UI as-is. Generating or viewing a report without emailing never counts against email limits. Not limited, on purpose: the anon token lookups (long random tokens). Supabase Auth's own limits are set by Joel in the dashboard, never `supabase config push`. CAPTCHA (Turnstile) is the recorded next step if signups are abused.

**Report recipients (H1 Part 3b).** `send-session-report` emails only addresses saved in the player's report contacts (`profiles.contact_emails`, edited only by the owning login -- the pitcher, or the parent for a parent-created player). Anything else -> 400, nothing sent. Coaches send to those contacts and can't add others.

**Teams are written only through functions (teams hotfix, Joel, Oct 5 2026).** Clients have no INSERT/UPDATE/DELETE on `teams` and no write policy; every change goes through a SECURITY DEFINER function with its own head-coach check (`create_team`, `rename_team`, `rotate_team_invite`, `rotate_coach_invite`, `hand_off_team_head`, `set_team_level`). Never add a direct client write path to `teams`. `sessions.team_id` is `ON DELETE RESTRICT`: the database refuses to delete a team that has sessions, whoever asks -- sessions belong to the pitcher and are never destroyed by a team action (P1-09 builds archive for such teams). Known: deleting a team that still has a rostered pitcher fails, because the G3 departure trigger logs a departure referencing the team being deleted; P1-09's `delete_team` handles it.

**Archiving and deleting teams (P1-09, Joel, Oct 5 2026).** A team that has sessions is never destroyed -- it is **archived** (`archive_team`, head coach only, typed-name confirm): `teams.archived_at` is set; it moves to an "Archived" section of the team picker; its invite links stop (`resolve_*_invite` return `team_archived`; `join_team_via_invite` / `join_team_as_coach` refuse; `get_team_invite_links` and rotations refuse); no new sessions (`sessions_g3_team_check` refuses, so `sync_session` does too -- a pen charted before the archive waits in the outbox and syncs if the team is restored); no rename or level change; the leaderboard is empty (`disabled: 'archived'`). **Memberships stay**, so coaches keep reading its sessions, pitches, events and notes, and pitchers keep report eligibility; coach notes stay writable. Opening it is read-only ("Archived · read only" banner; no New Session, invite links, roster editing, rename, level). **Restore** (`restore_team`) is head-coach only, any time, and the same invite link works again. A team with **no sessions at all** (tombstones count) can be **deleted** (`delete_team`, head coach only, typed-name confirm): roster rows first (G3 logs the departures while the team exists), then staff, then the team -- departures, invites and exclusions cascade. Team names are 2-60 characters (`teams_name_length`). Assistants and pitchers can't rename, archive, restore or delete.

**Account deletion and export (A1, Joel, Oct 14 2026; `plans/a1-account-deletion-export.md`, decisions in `plans/a1-preconditions.md`).** In the app, Profile -> Your data, online only:
- **Download my data** (`export-account`, caller's JWT, 3/day): a ZIP of every profile on the login (secret columns never), memberships, staff roles, the sessions they pitched, charted or (coach) their teams', pitches, game_events, their notes, report links, a README. Built with our own stored-ZIP writer -- no dependency.
- **Delete my account** (`delete-account` request: typed DELETE checked by `request_account_deletion`; a team HEAD is refused (`still_head`) until he hands off or archives): marks the primary profile (`deletion_requested_at` / `deletion_due_at`, not client-readable), signs the login out everywhere, emails the login (and a 13-17 login's guardian). Signing in during the 7 days shows the scheduled screen first (Restore / Keep it scheduled; checked on every online load and return to the app). A parent deletes or restores a player from the player's profile (the parent's login stays). Daily, pg_cron calls `a1_run_scheduled()` -> `delete-account` `execute` (header `x-a1-cron-secret` = `A1_CRON_SECRET`; address, anon key and secret in Vault as `a1_function_url` / `a1_anon_key` / `a1_cron_secret`), which runs `a1_purge_profile` (service role only) for everything due, removes report files (incl. `reports-archive` copies) and headshots, emails the completion, deletes the auth user and writes counts only to `account_deletion_log`.
- **What a purge leaves:** the pitcher's sessions become tombstones with `pitcher_id` NULL and `deleted_by_role = 'deleted_account'` -- date, kind, pitch count, no name, never openable; pitches, events, notes and reports go. Sessions the person CHARTED for others stay the pitcher's with `logged_by` NULL ("Logged by former coach"). Notes they wrote are deleted. Memberships and departures go. This is the H1 lock's single exception: the server's own function may clear `pitcher_id` / `logged_by` to NULL, nothing else, and no API caller can. Purges are not reversible.
- Backups are kept 7 days (the privacy policy says so): `scripts/prune-backups.sh` + its launchd job (BACKUPS.md). Rollback: `supabase/rollback/20261014000000_a1_account_deletion_down.sql`; test: `supabase/tests/a1_account_deletion.sql` (21 checks, rolled back).

**Column grants (security fix, Oct 2 2026).** `profiles` and `teams` have NO table-level SELECT for clients -- only an explicit column grant. Secret columns (`teams.invite_token`, `teams.coach_invite_token`, `profiles.email_verify_token`, and P1-10's guardian token/email) are never granted; they're reached only through their SECURITY DEFINER functions. A new column on either table is unreadable by clients until a migration grants it (and, for profiles, it's added to the tracker's `PROFILE_COLS`). Never `select('*')` on these tables.

RLS rules of engagement:

1. Never write or alter a policy without first dumping the current policies (`select * from pg_policies where schemaname='public'`).
2. Every schema/policy change is a migration file in `supabase/migrations/` — never a dashboard-only edit.
3. Policies on `teams` and `pitcher_teams` must never reference each other in a way that can recurse — this exact pair caused a production 42P17 infinite-recursion outage. The live fix is two `SECURITY DEFINER` helper functions, `public.is_team_coach(check_team_id)` and `public.is_team_member(check_team_id)`: any policy needing a cross-table team check goes through these helpers, never a direct subquery.
4. Test policy changes with three personas: coach, rostered pitcher, and (once they exist) solo pitcher.

## Deploy and environments

- Frontend: git push to the GitHub Pages branch. Rollback = `git revert` + push.
- Edge Functions: `supabase functions deploy <name>`. Rollback = check out last good version of the function directory, redeploy.
- Migrations and the full procedure: follow `DEPLOY.md`. Staging (`knuckleball-staging`, a second Supabase project, same org as production) gets every change first; production schema changes only after a fresh backup (`BACKUPS.md`).
- Auth config landmine: Supabase **Site URL / redirect URLs** were once left at `localhost:3000`, breaking every email link. Any auth-flow change: verify these settings.

## Who ships to production

Only Joel ships to production. Jordan Thayer (operations) has access to
both Supabase projects and the repo, but production changes are Joel's alone.

"Shipping to production" means any of:
- pushing or merging to `main` (GitHub Pages deploys the live site from it);
- applying a migration to the production project (fkgccjhuimkkbupbanxp);
- deploying an Edge Function to production;
- changing production Auth settings, secrets, storage policies, or RLS
  in the dashboard;
- deleting or editing production data.

Jordan, and any Claude Code session he runs, works on staging and on
branches, and opens pull requests for Joel to merge. Reading production
(queries, logs, dashboards) is fine for both.

Before any production action, a Claude Code session confirms who is
operating it (`git config user.name` / `user.email`, and ask if unclear).
If it isn't Joel, stop and say the change needs Joel. No exceptions for
"small" or docs-only changes to `main`.

Joel's git identity is `Nathan <joelhauserman@gmail.com>`.

## GitHub is the source of truth (Joel, Oct 3 2026)
- Packets and plan files come only from GitHub (github.com/nathanjoel22/knuckleball).
  Before starting any packet, pull from GitHub and work only from what GitHub has.
- Never use files from elsewhere on this Mac (Downloads, Desktop, etc.) as inputs.
- If a file Joel says he uploaded isn't on GitHub, stop and tell him. Don't work
  around it.
- Every pre-push check finishes before the push. If a check flags anything, stop
  and tell Joel before pushing.

## Secrets

Function secrets live in Supabase (`supabase secrets list`): `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `INVITE_REDIRECT_URL`, `RESEND_API_KEY`, `REPORT_FROM_EMAIL`, `VERIFY_FROM_EMAIL`, `VERIFY_REDIRECT_URL`, and since H1 `RESEND_DAILY_QUOTA` (the Resend plan's daily quota) and `ALERT_EMAIL` (Joel, for the circuit-breaker alert), since A1 `A1_CRON_SECRET` (the daily deletion run's shared secret, also in Vault as `a1_cron_secret`), and since U12 `OPERATOR_EMAILS` (`nate@knuckleballonline.com` on both projects -- Joel's dedicated operator login; the only login `rerender-reports` accepts). Historical note: a static `REPORT_API_KEY` once shipped in a public `report-config.js` — that pattern (any secret in a frontend file) is banned; if you ever find one, treat it as a live incident and flag it. The service-role key must never appear outside Edge Function env vars. The anon key is public by design; RLS is the actual security boundary.

## Known landmines

1. **RLS recursion** (see above) — the pair `teams` ↔ `pitcher_teams`.
2. **Missing foreign keys** once broke coach roster display (PostgREST embedding needs real FKs). When adding tables/columns, add the FKs.
3. **Profile-creation timing:** the profile row is created after email confirmation, with delay. Never assume a profile exists immediately after signup; handle its absence.
4. **Palette sync:** the pitch-type color palettes (one per sport) live in three places: the tracker page (`SPORTS[sport].palette`), `send-session-report/helpers.ts` (`SPORT_PALETTE_HEX`; `TYPE_PALETTE_HEX` is the baseball list) and `css/tokens.css` (`--pitch-1..8`, per sport). They must match exactly, in order -- change all three together; `.githooks/pre-push` refuses a push where they differ (D2, Oct 13 2026). Current values (D2; softball 6-8 darkened by Joel for readable chip labels): baseball `#FFB81C #22B573 #FF6B35 #E63946 #3D8BFF #B15CFF #F2E14C #00B8C4`, softball `#FF4F9A #2F9BFF #7A3FB8 #FF9F1C #00A99D #7A53FF #CD4730 #6C7684`. The report's own theme colors (`REPORT_VARS` in `helpers.ts`) follow `css/tokens.css` by hand.
5. **Client-computed reports:** the underlying pitches/history in the report payload are still client-supplied, not recomputed authoritatively from the database — accepted limitation, don't "fix" it in passing. This changed as of U4b in one way: the RENDERED report itself is now stored (`sessions.report_path`, the frozen file in the `reports` bucket) and deliberately never regenerated once set — every resend reuses the exact same file, so a later payload drift (e.g. new history) can't silently change a report someone already has the link to. The one exception so far is U12's Cairn re-render (Oct 6 2026, 23 reports, originals in `reports-archive/2026-10-06/` with a manifest); `from_rows.ts` can rebuild a report from stored rows, but nothing calls it except the operator-only `rerender-reports` -- re-render nothing else without Joel's explicit decision.
6. **Supabase default auth SMTP has tiny rate limits.** Bulk invites can silently fail mid-batch unless custom SMTP is configured (task P1-04 / SETUP.md). Production has custom SMTP (Resend, 50/hour); staging still uses the built-in sender at a fixed 2/hour, so bulk invites can't be tested on staging. Auth rate limits on both projects (Oct 5 2026): sign-ups and sign-ins 30 per 5 minutes per IP (Joel kept it; raise to ~100 if a team onboarding on one Wi-Fi hits it), token refreshes 150, token verifications 30. Change these only in the dashboard, never `supabase config push`.
7. **Free-tier Supabase projects pause when inactive** — relevant off-season. Check project status before diagnosing "the database is down".
8. **Offline is the normal case** for the tracker page: in-progress sessions autosave to localStorage, completed sessions queue and sync (tasks P0-03/P1-01). Never add code to the charting/save path that requires a network round-trip to keep charting. Data persistence and app availability are two separate problems — localStorage keeps the pitches, the service worker (P0-06) keeps the app openable offline. A field test proved that without the second, the first is unreachable.
9. **Service worker caching cuts both ways.** Once sw.js ships, a stale cached shell can strand users on old JS — exactly the failure mode that made a fixed bug look unfixed during P0-01. Always version the cache name, clean old caches on activate, and verify a deployed change actually appears after two reloads.

## Coding conventions

Vanilla JS in single-file pages; small shared JS only if a `js/` directory already exists. Match the existing style of the file you're editing. Edge Functions: Deno, esm.sh imports, the CORS-headers pattern already in the existing functions. Errors returned as JSON `{ error: string }` with proper status codes. No new dependencies without approval.

## Rules of engagement

**Never, without asking first:** run destructive SQL against production (or any UPDATE/DELETE without a WHERE you've shown); change RLS policies; change auth flows (signup, invite, reset); add dependencies, frameworks, or build steps; touch billing/legal text; delete user data; commit anything resembling a secret; deploy schema changes that haven't run on staging.

**Always:** work from a task packet when one exists, and respect its Out-of-scope and Escalate-if clauses; make schema changes as migration files; prefer the smallest change that passes acceptance; leave the codebase style-consistent.

**Release log (Joel, Oct 10 2026).** After every packet -- or request shipped without one -- reaches staging or production, add an entry at the TOP of `STATUS.md`: date, packet ID, staging or production, branch, commit, cache version, what was built, what deviated from the packet, open items. CLAUDE.md stays the rules; STATUS.md is the log. **At the start of every session, read the top of `STATUS.md`** (at least the newest few entries and "Standing open items") before starting work: it says what's on staging vs production right now and what's still open.

**Definition of done:** a task is complete only when every numbered acceptance check in its packet has been executed and the evidence (command output, query result, or click-path result) is shown. "It should work" is not done. If an acceptance check can't be run, say so explicitly — do not claim completion. If reality contradicts the packet (a file isn't where it says, the schema differs), stop and report the discrepancy instead of improvising around it.
