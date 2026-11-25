# C1 — Report first (Nov 25, 2026)

The answers to the packet's "Report first" (`plans/c1-charting-parts.md`), from `origin/main` at `fd1e7a7` (v373).
Nothing is built. Line numbers are `bullpen-tracker.html` unless another file is named. **Section 10 is the yes/no
list for Joel.**

---

## 1. Start questions

### Today (`renderStartQuestions`, 9124–9151; no sport branch, so baseball and softball are identical)

| # | Question | Bullpen | Live Game | Sets | Where |
|---|---|---|---|---|---|
| 1 | Which team is this for? | pitcher on a team only | pitcher on a team only | `q.file` | `fileStartQuestion` 8925 (shown when `fileChoices()` 8910 isn't empty; never for a coach) |
| 2 | Will you be using a radar gun today? | yes | yes | `q.radar` | 9131 |
| 3 | Turn on Relative Accuracy? | yes | only with Intent on | `q.rel` | `raStartQuestion` 9010; game 9140 |
| 4 | What's this pen for? | yes | — | `q.purpose` | `tagStartQuestion` 9016 |
| 5 | Turn on Intent? (+ "?" help) | — | yes | `q.intent` | 9134–9139 |
| 6 | Continue from where X left off? | — | after a hand-off (5 min, same team, other pitcher) | `q.carry` | 9141–9143, `gameHandoff` 8855 |
| 7 | Starting mid-game? (+ Who was pitching?) | — | unless 6 is Yes | `q.mid…` | `startMidGameQuestion` 9052, `midFromQuestion` 9106 |
| 8 | Opponent (optional) | — | yes | read from the input | 9145 |

Bullpen today: [team] → radar → Relative Accuracy → pen purpose → Start.
Game today: [team] → radar → Intent → [Relative Accuracy] → [Continue from…] → [Starting mid-game?] → Opponent → Start.
`startSessionNow` (8933–8982) copies them onto the session (`s.intent` at 8951 is never sent to the server: the
server only sees whether a game pitch has a target).

### Proposed (Joel's order first, then today's others in their present order)

**Bullpen:** **Parts** → What's this pen for? → Relative Accuracy (*only when both parts are on this device*) → radar
gun (*only when Outcome is on this device*, see 10.3) → [Which team is this for?].

**Live Game:** **Parts** → radar gun (*Outcome & Response only*) → Starting mid-game? (*Outcome & Response only*) →
Relative Accuracy (*both parts only*) → [Continue from where X left off?] (*Outcome & Response only*) → Opponent →
[Which team is this for?]. "Turn on Intent?" and its help are removed; choosing Intent is the answer.

Notes:
- The parts question is two toggles (both on to start, as today's behaviour). Start stays disabled with neither, and
  says "Choose at least one part".
- "Which team is this for?" moves from first to last (the packet says the others keep their place *after* Joel's).
  If Joel prefers it to stay first, that's 10.2.
- Continue-from and Starting mid-game describe the count, outs and runners, which an Intent-only device doesn't
  chart, so it doesn't ask them (10.4).

---

## 2. The six combinations

Mockups (today's screens on staging with the new controls drawn in; demo names): `plans/c1-mockups/`
- `pen390-aim.png`, `pen390-sel.png`, `pen390-conf.png`: phone bullpen, Intent only. The three steps: aiming;
  cell chosen (Confirm Pitch pulsing); confirmed (Next Pitch pulsing).
- `game390-aim.png`, `game390-sel.png`: phone Live Game, Intent only (scoreboard blank, no result rows).
- `pen1280-sel.png`, `game1280-sel.png`: computer / iPad landscape.

**Layout of the Intent-only controls.** They replace the yellow guide under the chart (phone: the `.zone-caption` +
`renderPenBatterPill` at 13387–13390; wider: the `v1UnderRow` at 13424 / 13471):
- Row 1: **‹ Back** (one third wide, directly above the batter button), then the yellow **"Tap where you're
  aiming"**, shown only until a cell is chosen.
- Row 2: three equal buttons: **batter** · **Confirm Pitch** (#E5486B, white text) · **Next Pitch** (accent yellow).
- "The size of today's No batter button": its height (`--btn-h`). Its 160 px minimum width can't fit three across at
  390 px, so the three share the row equally (≈114 px each at 390, 15 px text). On wider screens they're 160+ px.
- The pulse is the target dot's (`targetPulse`, 1676–1678), as a ring on the button. Under reduced motion it's a
  steady ring (the global rule at 310–312 would otherwise remove it entirely).
- On wider screens, the left column's None / RHB / LHB tray (`renderBatterModeToggle` 6650) is hidden; the batter
  button replaces it. Velocity is hidden (it belongs to Outcome). Delivery (Windup / Set) stays; see 10.5.

| Kind | Parts | Screens and prompts | Saved per pitch | Blank |
|---|---|---|---|---|
| Bullpen | Intent + Outcome | today's | today's | nothing |
| Bullpen | Intent only | the mockups; "Tap where you're aiming", Confirm Pitch, Next Pitch; the log reads "aimed 4 · 4SFB" | type, target, batter side, delivery (10.5), ts | location, velocity, hit kind, zone, RA cells |
| Bullpen | Outcome only | today's screen with one tap per pitch: "Select Pitch Outcome", the grid pulsing (the V1 side-glow overlay on all 25 cells, 1365/1680) until tapped; type stays selected; velocity as today; the log reads "landed 4 · Strike" | type, location, velocity, batter side, delivery, ts | target, hit kind, RA cells |
| Live Game | Intent + O&R | today's Intent-on game | today's | nothing |
| Live Game | O&R only | today's Intent-off game, unchanged | today's Intent-off rows | target (as today) |
| Live Game | Intent only | the mockups; V1's Select Batter Side first, then the batter button shows "vs RHB"/"vs LHB" (no "No batter"); scoreboard "–" (section 4) | type, target, batter side, ts | everything else: location, result, count, inning, outs, runners, at-bat, velocity, delivery |

**One Intent-only pitch** (both kinds): pick a type (kept) → tap a cell (target dot; instruction gone; Confirm
pulses) → Confirm Pitch (voice call; Next pulses) → Next Pitch (the next pitch's aim). Back undoes the last step:
un-confirm → clear the cell → reopen the previous pitch (its cell and confirm). Once the next pitch is confirmed,
the earlier one is frozen. A pitch is written to the session when it's confirmed; un-confirming it removes it.

**After a killed tab, at the same step** (Done when 3): today a bullpen keeps `pendingTarget` and the selected type
only in memory (2516, 2527–2533) and a pen with no pitches isn't offered on reopen (6490–6526). The new modes keep
the step (`aim` / `chosen` / `confirmed`), the chosen cell and the type in the draft, and a draft with a started
session is offered even with 0 pitches. Whether the plain two-part bullpen gets this too (it would then also
remember tap 1): 10.6.

---

## 3. Schema change, and every reader of an empty target, location or result

### What the database allows today
- `pitches.target_row/col` nullable (G1); `pitches_target_matches_kind` (schema.sql:4915, from
  `20261012000000_live_game_intent.sql:9–14`) **requires a target on a bullpen pitch**.
- `pitches.actual_row/col` are **`NOT NULL DEFAULT 0`** (schema.sql:4852–4853), and `sync_session` writes
  `coalesce(r.actual_row, 0)` (`20261127000000_f2s4_camps.sql:325`). **A missing location is stored as cell 0-0 today.**
- `result` is nullable (4859).
- No session column says which parts were charted; "Intent" isn't stored at all (8951 never synced).
- There is **no `hasLocation` helper** in the code; it exists only in plan files (g6 31/113/270).

### Proposed migration (one file, staging first, rollback written first)
1. `sessions.charted_intent boolean not null default true`, `sessions.charted_outcome boolean not null default
   true`; at least one true (check). Existing rows: `charted_intent` = true for pens; for games = whether any pitch
   has a target (today's Intent on/off, now stored); `charted_outcome` = true for all. Both added to the H1 lock
   (`sessions_h1_lock`: never change once saved).
2. `pitches.actual_row/col`: drop NOT NULL and the default. Add `pitches_actual_pair` (both null or both set).
3. `pitches_target_matches_kind` becomes "both null or both set" for every kind.
4. `sync_session`: takes `charted_intent` / `charted_outcome` from the session JSON (missing = true, so old apps are
   unchanged). It refuses a pitch without a location in a session with Outcome, and a bullpen pitch without a target
   in a session with Intent. `coalesce(actual, 0)` stays only for sessions with Outcome (old apps).
5. `finalize_session_stats`: new count `scored` (pitches with both target and location); `hits` counted only among
   them; cells only from a real location; `stats_version` 3; all rows recomputed. Pens and games charted before
   have `scored` = their pitches with a target, so every existing number stays the same (`sc1-compare` /
   `sc1b-compare` / `sr1b-compare` must show 0 differences).
6. `get_team_leaderboard`, `session_baselines`: only sessions with both parts (10.8); spot % = hits / scored.
7. Policies: unchanged (32 / storage 12).

### Readers that must handle the empty case (new helpers `hasTarget(p)`, `hasLocation(p)`, `isScored(p)`)

**App (`bullpen-tracker.html`)**
- `isAccurate` 3076: **true when both are null** → must require `isScored`.
- `isRelativelyAccurate` 3216–3235: treats null as 0 (`nothingLow` is true for null).
- `scoreU14` 4627: 'exact' when both are null. `gameHitScore` 4634: no location check.
- `isHit` 4670. Rescoring 3156 / 7117 (guards the target only).
- `isStrikeCell` 3044, `zoneNumberFor` 3053.
- `sessionStats` 8120–8166: divides by all pitches. `penStatsFromRow` 8008–8031, `statsPct` 8000 (0 when empty).
- `sessionTypeAgg` 8065–8102. `pitchesFromCells` / `plotSessionOf` 8105–8119. `heatCounts` 8170.
- `renderHistoryPlot` 8579, `renderZoneThumb` 15269 (skip null; fine once nothing is stored as 0-0).
- History cards 14017–14021, 14098–14106; game type table 10316–10325.
- Trends `renderTrendsView` 14235–14300; `trendsIsStrike` 14208.
- Recap `renderRecap` 15326–15349, `recapCallout` 15314–15323.
- `gameStats` 10568–10583 (strike % over all pitches, unlike the SQL); `gameResultText` 10255.
- The log 13341–13359 ("aimed ball" / "landed ball" for null).
- Report payloads: `buildReportPayload` 16857, `buildRecentPensForGame` 16933–16986, `buildRecentPenPitchesForGame`
  16989, `buildGameReportPayload` 17025.

**Report (`supabase/functions/send-session-report/`)**
- `compute.ts`: `isExactHit` 24–26 (true for null/null), `computeSummary` 35–57, `computeCommandDetail` 61–97,
  `computePerSideBlock` 101–137, miss direction 74–77.
- `svg.ts`: `drawDots` 22–38 draws a null at the top corner; `drawGrid` 68, `drawGridByResult` 168, `drawHitGrid`
  253–256; `resultCategoryOf` 135–143.
- `template.ts`: grids 54/70/96/115/426/451; `penFacts` 253–271; headlines 360–411; `missPattern` / `missDirs`
  302/429/468; "0%" fallbacks 325/390/399/409/412/440/441/447/518–519.
- `template_game.ts`: grids 169–281; `gCounts` 532 (a null result counts toward strike %); in-zone 204/224/285/588/
  723/736; "0%" fallbacks 730–731, 771.
- `compute_game.ts`: types 21/23; `countsTowardPct` 68; in-zone 101–145, 217–228; **`pitchEndsAtBat` 314–320 ends an
  at-bat on a null result**.
- `connect.ts` 36/79–84/101 (`penCommand` already tolerant); `diamond.ts` 137–146/186; `from_rows.ts` 33–41, 58–59,
  64–78, 90–92; `sr1.ts` 231–285, `loadComparison` 70–71; `helpers.ts` `pct` 105–107 (already returns null).

**SQL:** `finalize_session_stats` (sr1a 291–355), `compute_game_summary` (schema 1186–1296; strike/in-zone "else 0"
1282/1285), `get_team_leaderboard` (f1g 535–539), `session_baselines` (sr1b 110–174). `session_workload`,
`pitcher_workload` and the roster functions read counts only.

**Scripts:** `sc1-compare.js` 20/25/30, `sc1b-compare.js` 36 (no null guard); `sr1b-compare.js` 55–56 is fine.

**Blank, never zero:** every "%" above shows "—" when its count is 0.

---

## 4. A Live Game charted Intent only, nobody on the other part

- **Scoreboard:** Inning, Outs, Count, Runs and Batter # show "–"; no runner diamond; the Catcher / Pitcher button
  stays. The stat line under the chart reads "Intent only · Pitches called: N" (mockups `game390-*`).
- **History card:** an "Intent only" chip. The plot shows the called spots as rings in pitch colours, captioned "Called
  spots". The line reads "N pitches called", with no strike %, IP, K, BB or H.
- **Report:** header as today with "Intent only"; one line, "Only the pitch calls were charted: no locations,
  results or counts." Then pitch mix, called spots per type and batter side, and the first-pitch call per batter side.
  - No pitching line, spray chart, at-bats, rest card or 7-day card: they need results.
  - The pitch count isn't known (calls aren't pitches thrown). See 10.10.

---

## 5. More Plays audit

**Recordable today:**
- Hit by pitch.
- Intentional walk.
- Catcher's and batter's interference.
- Dropped 3rd.
- Foul bunt.
- Clock ball / strike.
- Balk / softball illegal pitch.
- Stolen base, caught stealing and pickoff out (runner diamond, `G5_WHY` 12422–12425).
- Wild pitch and passed ball between pitches.
- Triple play, double play, fielder's choice.
- Sacrifices (derived).
- Inside-the-park homer.
- A third strike dropped with first base occupied (correctly a K).

Where they are:
- More ▾: 12693–12698.
- Rare plays ▸: 12703–12732.
- The FC · E · H · O row: `g5HoeRow` 12655–12679, with ‹ Back in `g5FieldActions` 12407–12412.

| Play | Status | Proposal |
|---|---|---|
| Wild pitch / passed ball **on the pitch** (strike three, ball four) | missing (G6 B8) | More Plays → "Wild pitch / Passed ball on this pitch": a `wild_pitch` / `passed_ball` event after the pitch (allowed today) |
| Throw-over with no out | missing (D1) | Rare plays → "Pickoff throw": a `pickoff` event, no advances |
| Defensive indifference | only as SB / Other (D3) | runner Safe → "Defensive indifference": `stolen_base` event with `how:'indifference'` (not a steal in stats) |
| Obstruction | only Safe → Other (D4) | More Plays → Obstruction: runner(s) awarded, `how:'obstruction'` |
| Runner's interference | Other / hit by ball | More Plays → Runner's interference: runner out, `how:'interference'` |
| Appeal play | Out → Other (D4) | runner Out → "Appeal" (`how:'appeal'`) |
| Error on a runner's advance after H / E / FC | missing (C6) | add "ADV on error" to the runner question (`how:'on_error'`, run unearned, as on O today) |
| Baseball illegal pitch, bases empty (a ball) | missing | Rare plays → Illegal pitch for baseball too (`illegal_pitch` + `auto_ball`); the stats count it as a BK only for softball today (sc1b 45), so that line needs a sport check |
| Batting out of order | missing (F1, no lineup) | More Plays → Batting out of order: an `other` event, 1 out, ends the at-bat |
| Infield fly | charted as a fly out; no marker (C5) | needs a flag column |
| Ground-rule double | charted as a 2B; no marker (C7) | needs a flag column |
| Fan interference | charted as the awarded result; no marker | needs a flag column |
| A dropped foul scored as an error | not recordable (C3) | needs a flag column (or `in_play_outcome='error'` on a foul, which every reader would misread) |
| Catcher's balk | = Balk | stays Balk |

**Needs a schema change:** a `pitches.play_flags text[]` column (G6 planned it; never built) for infield fly,
ground-rule double, fan interference and an error on a foul. Nothing needs a new event type: `'other'` plus a `how`
in `runner_advances` covers the rest. `commitAdjustEvent` builds `{from,to}` only (10054); adding `how` is app-only.

**Where it goes:** a ball-in-play button can only carry in-play plays. So More Plays (next to ‹ Back on the FC · E ·
H · O row) holds: Obstruction, Runner's interference, WP/PB on this pitch, Batting out of order, and, with the flag
column, Infield fly, Ground-rule double, Fan interference. Between-pitch plays (throw-over, DI, appeal, baseball
illegal pitch) go under today's More → Rare plays. Today's "More ▾" keeps its name; the new one is "More Plays".
Joel approves the list (10.11, 10.12).

---

## 6. Voice in Intent-only mode

- **Today:**
  - `speakCall` (6973–6992) runs on the target tap: bullpen 7010, game 9198.
  - It cancels only when a call is already playing, then speaks about 60 ms later.
  - Nothing else cancels speech except Voice Off (6948). `render()`, the second tap, End session and navigation never
    do.
- **Intent only:**
  - The cell tap says nothing; **Confirm Pitch** calls `speakCall(type, row, col)`.
  - **Next Pitch never touches speech**, so a call still playing finishes.
  - The next Confirm, if the previous call is still speaking, **queues** the new call (`speechSynthesis.speak` queues
    by itself) instead of cancelling it. So no call is ever cut off.
  - Back after Confirm doesn't stop a call that is playing.
- **iPhone / iPad (Safari and the store app):** the call runs inside the Confirm tap, as iOS requires for the first
  utterance. Queued calls play on. iOS pauses speech when the app goes to the background.
- **Desktop browsers and Chrome on Android:** the same code works unchanged.
- **The Play Store Android app:** its WebView has no speech, so the Voice switch stays hidden there. A native plugin
  is still unbuilt.

---

## 7. Stage B: shared charting

### Live tables (all with no client grant and no policy, read and written only through functions, like F2's: policies stay 32 / storage 12)
- `live_sessions`: id, pitcher, team, kind, sport, started_by (profile + login), started_at, last_activity_at,
  closed_at, compiled_session_id.
- `live_parts`: live_session, part (`intent` / `outcome`), holder profile + login, from_seq, left_at,
  piece_session_id. Unique open holder per part. That gives the first-to-tap rule (an `insert … on conflict do
  nothing`).
- `live_pitches`: live_session, `seq` (numbered by the server), then two groups of columns:
  - intent: type, target, batter side, confirmed_at, by, `no_pitch`;
  - outcome: a jsonb of today's pitch fields, recorded_at, by, `skipped_intent`.
  Each part writes only its own columns.
- Functions:
  - `live_start`, `live_join`, `live_leave`;
  - `live_put_intent`, `live_put_outcome`, `live_unconfirm`;
  - `live_poll(live, after_seq)`, `live_summary()`, `live_clock()`.
  Each checks the caller can chart the pitcher with **the same test `sync_session` uses**
  (`f2s4_camps.sql:257–258`: `can_chart_for`, `coach_sees_pitcher`, a live F2 assignment, a camp on its day), and
  that the caller holds a part for anything but `live_summary`.

### Staying in step: polling, not Realtime (recommended)
- Supabase Realtime is in the vendored supabase-js 2.117.2 and no CSP blocks it. But **Postgres Changes needs a
  SELECT policy on each table**, and private Broadcast needs policies on `realtime.messages`. Either widens what
  policies exist.
- Polling keeps the "functions only, no policy" pattern chat uses (`chatOpenThread` 15802–15811, 5 s).
- **The cadence:** a device in a live session polls `live_poll` every 1 s while waiting for the other part, every 3 s
  otherwise, and only while visible and online. The delay a charter feels after Confirm Pitch is about 1–1.5 s
  (half a poll plus a round trip).
- **The Live marks:** `live_summary()` on sign-in, on return to the app, and every 30 s on Home / Chart (chat's
  cadence). Marks appear and disappear within 30 s.

| Live sessions at once | Devices polling | Requests / second (1–3 s) | Comment |
|---|---|---|---|
| 10 | 20 | ~10–20 | trivial on today's instance |
| 100 | 200 | ~100–200 | heavy for the free / Micro database; needs the Pro plan's larger compute |
| 1,000 | 2,000 | ~1,000–2,000 | too much for polling; move to Realtime Broadcast (one channel per live session; about 6 messages a pitch) |

These are estimates. Supabase's connection and message quotas per plan must be checked on its pricing page before
Stage B. Recommendation: polling now (1–3 teams today), and Realtime Broadcast as a later step behind the same
functions.

### RLS matrix (to be run as a test, like `f1a_rls_matrix.sql`)

| Caller | sees the Live mark | can take a part | reads the other part | reads history |
|---|---|---|---|---|
| the pitcher's coach (incl. facility group coach) | yes | yes | while holding a part | as today |
| the pitcher's own login / creating parent / linked guardian / own teen sign-in | yes | yes | while holding a part | as today |
| F2 one-session-assignment coach | yes, inside the window | yes | while holding a part | **no** (unchanged) |
| F2 camp coach on a camp day | yes | yes | while holding a part | **no** (unchanged) |
| linked friends and family (view-only) | no | no | no | as today |
| a coach of another team the pitcher is on (R4 reader) | no | no | no | as today |
| anyone else | no | no | no | no |

### Two devices in a game: who owns what
- The **Outcome & Response** device owns:
  - the count, outs, inning, runners and runs;
  - New batter and the at-bat number;
  - pitching changes, Starting mid-game and the hand-off.
- The **Intent** device owns the type and the target.
- **Batter side:** whichever device sets it first for an at-bat. The other device sees it on its next poll; Intent's
  batter button and V1's Select Batter Side both write it.
- **A pitching change** ends this live session for the Outcome holder (Save and switch, as today). The Intent holder
  is offered "Keep calling for <new pitcher>?", which joins the new live session.
- **Starting mid-game** is answered only on the Outcome device.

---

## 8. Matching offline pitches by time

**Clock correction:**
- While online, each device measures `offset = server_now − (send + receive) / 2` with `live_clock()`, keeping the
  smallest-delay sample of the last 5.
- Every tap stores the device time plus that offset.

**Rule:**
- The pitches charted offline are matched, in order, to the session's pitches that are missing that part.
- An outcome at time `t` matches the earliest unmatched intent with `confirmed_at` in [t − 30 s, t − 0.5 s].
- An offline intent matches the earliest unmatched outcome 0.5–30 s after it.
- Order never crosses: a later tap can't take an earlier pitch.
- Anything unmatched is empty for that part.

**Tolerance:** ±2 s for clock error, inside a 30 s window. A bullpen pitch is usually 10–25 s from call to landing,
and a game pitch 15–30 s.

**Three cases it gets wrong:**
1. **Catching up.** An offline charter who taps several pitches late in a burst. Each lands near the next pitch's
   call, so they shift by one or more.
2. **A missed tap in a quick sequence.** If one outcome was never tapped, the next outcome can take the earlier
   intent (both inside 30 s). Every later pitch shifts by one until a gap over 30 s.
3. **A clock jump while offline** (time zone change, a manual change, a resync). All of that device's offline taps
   move together, and none may match.

Also: a "No pitch" that the offline device never saw leaves its outcome to pair with the next call.

---

## 9. Stage C: pieces, compiling, reports

- **Pieces:** each charter's End session & save goes through today's `sync_session`, with `live_session_id` and
  `piece_part`. A piece is an ordinary sealed session marked as a piece.
  - Hidden from History, Trends, the leaderboard, baselines, the roster workload and Home.
  - `finalize_session_stats` skips it (no stats row).
- **Compile:** `compile_live_session(live)` (server only) runs when every part that was taken has a saved piece.
  - It creates the **combined session** (new id): pitch by pitch, by `seq`; the target and type from the Intent
    piece, everything else and every game event from the Outcome piece.
  - It sets `charted_intent` / `charted_outcome` from what existed, and seals it. The stats trigger fires as for any
    save.
  - Pieces are never edited; each gets `compiled_into` (a server-only column, the H1 lock's pattern).
- **The report:** made as History makes any new session's report today: the first time someone with report rights
  has it on screen, from its pitches (`ensureSessionPitches`), through `send-session-report`. Then frozen. No new
  Edge Function.
  - Send / View go to the same people as any session of that pitcher and team (the report gate). Never an F2
    assignment or camp coach.
- **Three hours:** pg_cron `c1-compile-stale` every 15 minutes (as `r3-final-lock`).
  - For a live session whose most recent saved piece is 3+ hours old, or with no activity for 3 hours, it builds each
    missing piece from `live_pitches` (what reached the server) and compiles.
  - Pitches a device charted offline and never synced can't be included (11.3).
- **Empty parts:**
  - `session_stats` counts only what exists (`scored` = both). A session missing a part is left out of baselines,
    Trends and the leaderboard.
  - The SR1 report shows "—" and one plain line naming the missing part. The headline rules skip any tile with no
    data.
- **Delete:**
  - Before compiling, deleting a piece (its pitcher or the team's head, as today) tombstones it; the compile goes
    ahead without it, so that part is empty.
  - After compiling, deleting a piece changes nothing in the combined session. Deleting the combined session
    tombstones it as today; the pieces stay hidden.
- **Export and account deletion:** the session export already covers pieces and the combined session (by pitcher /
  charter / team). The live tables are added to the export and to `a1_purge_profile` (they go with the pitcher; a
  charter's name is cleared).

---

## 10. Yes / no for Joel

1. The parts question is two toggles, both on to start (today's behaviour by default). **Y/N**
2. "Which team is this for?" moves from first to last. **Y/N** (N = keep it first)
3. The radar question is asked only when Outcome is on this device (velocity is entered after the pitch lands). **Y/N**
4. Starting mid-game, Continue from where X left off, and Relative Accuracy are asked only on a device that charts
   the count (Outcome & Response) / both parts. **Y/N**
5. Delivery (Windup / Set) stays on an Intent-only bullpen device and goes with Outcome in a game (the bases set it).
   **Y/N**
6. The plain two-part bullpen also remembers tap 1 and the type after a killed tab (today it forgets them). **Y/N**
7. An Intent-only game pitch saves the batter side too, not only type and target. **Y/N**
8. *Drafting decision (packet):* Relative Accuracy is asked only when both parts are on this device. **Y/N**
9. A pen or game missing a part is left out of baselines, Trends and the leaderboard entirely (not just its
   accuracy). **Y/N**
10. An Intent-only game's pitch count = pitches called (it feeds the 7-day workload). **Y/N** (N = no pitch count;
    workload ignores it)
11. The More Plays list in section 5, split between More Plays (in play) and Rare plays (between pitches). **Y/N**
12. Add the `play_flags` column now (infield fly, ground-rule double, fan interference, error on a foul). **Y/N**
    (N = leave those four out)
13. *Assumed (packet):* anyone who can already start a session for the pitcher sees the Live marks and can take
    the open part; one person per part; first tap wins. **Y/N**
14. *Assumed (packet):* the Intent device's Back locks once the other device has recorded that pitch, or at the next
    Confirm Pitch. **Y/N**
15. *Drafting decision (packet):* a part whose charter leaves becomes open again from the next pitch. **Y/N**
16. Polling (1–3 s while charting, 30 s for the marks), not Realtime, for Stage B. **Y/N**
17. The matching window: 0.5–30 s, ±2 s clock tolerance. **Y/N**
18. In a shared game, the Outcome device owns count, batters and pitching changes, and either device may set the
    batter side. **Y/N**
19. A pitching change offers the Intent holder "Keep calling for <new pitcher>?". **Y/N**
20. The three-hour job also compiles a live session with no activity for 3 hours, even if nobody saved. **Y/N**
21. The combined session's report is made the first time it's on screen for someone with report rights (as History
    does now), not on the server at compile time. **Y/N**
22. Pieces are hidden everywhere in the app (History shows only the combined session). **Y/N**

## 11. What can't be built exactly as written

1. **"A game pitch charted Intent only has a type and a target and nothing else."** The same packet gives that
   screen a batter-side button and V1's Select Batter Side. Closest: save the side too (10.7).
2. **An Intent-only game device can't tell when an at-bat ends** (it charts no results). Closest: the at-bat comes
   from the Outcome device in Stage B. Alone, it has none, and the report has no per-batter view.
3. **"Automatically saved as they were" after three hours** can only include what reached the server. Pitches a
   device charted offline and never synced can't be saved for it. Closest: compile from `live_pitches`. If that
   device syncs later, its piece is kept as a record but isn't recompiled (immutable).
4. **"No existing policy is widened" together with "a realtime channel".** Supabase's realtime features need
   policies. Closest: polling through functions (section 7), Realtime later.
5. **"Each button the size of No batter"** can't fit three across at 390 px. Closest: the same height, equal
   thirds.
6. **Done when 5, "the same rows as today's Intent-off game".** The rows are identical except the new
   `charted_intent` / `charted_outcome` columns.
7. **Done when 18, "session_stats identical".** The stats row gains `scored` and `stats_version` 3. Every value that
   exists today stays identical (proved by the compare scripts).
8. **Done when 3 for "Intent only" in a game: "reopens at the same step"** includes Select Batter Side. It's kept in
   the draft as the V1 flow already does.
9. **An Intent-only game can't relieve or be relieved (R3):** the hand-off and inherited runners need the count and
   runners. Those questions are hidden there.
10. **Stage B counts on a signal on both devices.** A charter who loses signal keeps charting (packet), but the Live
    marks and joining need one.

---

## Joel's answers (Nov 25, 2026)

**Yes to every item in section 10, except 8, which Joel changed:** "let's make relative accuracy only something that
is measured and recorded in bullpens. in live games, relative accuracy is not something we measure anymore."

- **Bullpens:** Relative Accuracy is asked only when both parts are on the device (as 8 proposed).
- **Live Games:** never asked, never scored. A new game's Intent pitches score exact / miss only and `ra_on` is false.
  Games saved before keep what they stored, and their reports are frozen as they are.
