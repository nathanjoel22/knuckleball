# SR1 Stage C · The new report: tabs and the four layers · preconditions (Nov 19, 2026)

Read at `e0da3c7` (main: Stage A live v361, Stage B live, its function on production). **Branch:**
`sr1c-report-tabs`, from `origin/main`.

**Stage C builds the coach version** (the full report) of a new bullpen and game report. Stage E adds the player and
parent versions. **Every report already sent stays exactly as it is.** Nothing is re-rendered, and History and
report.html keep drawing old files unchanged.

**Pictures:** `b01`–`b05` and `g01`–`g07` (read). The text below gives structure and rules; the pictures are the look.

## 1. What changes, where it is now

**Report function** (`supabase/functions/send-session-report/`, 3,248 lines today):

| File | Now | Stage C |
|---|---|---|
| `template.ts` (445 lines) | `buildReportHtml` (L420): one long page with Header · Summary tiles · Location · Type grids · Command detail · Per-side blocks · Velocity depth · Workload · Trends · Footer | Rebuilt as header + tab bar + four panels (section 3a). Today's builders are reused inside the tabs. |
| `template_game.ts` (593 lines) | `buildGameReportHtml` (L559): 19 sections in one column | Header + tab bar + six panels (section 3b). Every kept section moves as it is. |
| `template.ts` CSS (L348–419) + `GAME_CSS` | one stylesheet, `.page` max-width 820px | Adds the tab, window-switch, tile, range-bar, stood-out and line-strip rules (radio `:checked` rules, no script). |
| `helpers.ts` `REPORT_VARS` (L35–47) | 19 tokens per sport | Gains 7 tokens per sport (section 5). |
| `index.ts` (L229–419) | reads the session row; builds from the client's payload | Also reads `session_baselines(session)` and the last same-kind sessions' `session_stats`, both through the caller's own client, and the pitcher's `throws`. Passes them to the builders. |
| new `stoodout.ts` | — | The headline rules and What stood out patterns: one file, starting values as constants. |
| `from_rows.ts` | the operator's re-render twin of the live path | Builds the same new layout with the comparison read through its own client. Nothing calls it except the operator-only `rerender-reports`, and re-rendering stays Joel's decision. |
| `compute.ts` / `compute_game.ts` | the numbers | New: where misses went, times through the order, after the first pitch, two of the first three, fastball by pitch order. |

**Unchanged:**
- **Pages:** `report.html`, History (`feedReportHost`, bullpen-tracker.html L16626) and `sw.js`.
- **Why the tabs work with no script there:** `inertReport()` (report.html L148) and `feedInert()` (tracker L16609)
  drop `script,iframe,frame,frameset,object,embed,applet,form,meta,base,link,noscript,template` and `on*`
  attributes. They keep `<input>`, `<label>` and `<style>`, so radio tabs need no change on either page.
- **History's shadow root:** it rewrites `:root` → `:host` and `body` → `.kr-body`; the tab rules use neither.
- **Not touched:** the email (Stage F), the palettes, `diamond.ts`, `connect.ts` (only moved), the database (Stage B's
  function is already live).

**Where the packet doesn't match the repo:**

1. **The packet says the header meta reads "date · tag · team",** but today's line also carries pitches, batter and
   "charted by". Those move to the Summary card's second line, as `b01` draws them ("42 pitches · 3 pitch types ·
   charted by the coaching staff").
2. **"Best command pen of his last six" needs a ranking that Stage B's function doesn't return** (it returns
   aggregates only). The report function reads the last same-kind (and same-tag) `session_stats` rows itself, through
   the caller's client: the same reach as the baselines. No migration.
3. **Arm side / glove side need the throwing hand,** which isn't in the payload today. The function reads
   `profiles.throws` through the caller's client (the column is granted). If it isn't set or can't be read, the
   columns are "To the left / To the right (pitcher's view)".
4. **The picture's Command table says "VS LAST 5"; the packet says "vs average".** The packet wins: the column
   follows the window switch ("vs 3-mo avg").
5. **The game's full pitching line** (WP, BK, ER, IR / IRS, SF / SAC, runners left) has no tab in the pictures:
   Summary carries only IP · P · K · BB · H · R. See question 6.
6. **Today's per-batter-side blocks keep the U14 exact / RA grids,** which CLAUDE.md records as a report rule.
   `b02` draws only a small "By batter side" table. Both go in Command: the table first, then today's blocks.
7. **Print:** until Stage G, printing shows only the open tab. Stage G makes every tab print.

## 2. CLAUDE.md decisions this stage changes

| Recorded now (quoted) | New rule beside it |
|---|---|
| Landmine 5: "the underlying pitches/history in the report payload are still client-supplied" | Unchanged for the pitches and the Trends history. The comparisons (Stage B) and the "last six" ranking are read on the server, under the caller's own rules. |
| G5 / Live Game "Game report: spray charts … What led to it … The pitches that mattered … Bullpen to game" | All kept, unchanged, inside tabs: Location (pitches that mattered), Batters (spray, What led to it, Base states), Trends (Recent bullpens, Bullpen to game). |
| Amendment 16: every report grid in the pitcher's view, "captioned as such" | Unchanged. The perspective caption moves from the footer to the end of Summary (packet). |
| U14: "headline 'H hits of N — E exact, R RA'" in the pen report | Kept in Command, above the hit / miss grids. Summary's headline is the new sentence. |
| Footer: "That's a conversation between a pitcher and his coach." | Replaced (section 4, decision 16). |

## 3. The tabs

**How they work (both kinds):**
- At the top of the report sit radio inputs for the tabs (`<input type=radio name="t-<8 chars of session id>">`) and
  for the windows (`name="w-<id8>"`, 3 months checked).
- Labels in the brand band select them.
- Panels and window variants show through `#…:checked ~ .kr-main …` rules.
- Every id and name carries the session's first 8 characters, so two reports open in History's no-shadow fallback
  never collide.
- No script, no `:target`, no animation.
- On a phone the label row scrolls sideways (`overflow-x:auto`), as `b01` shows.

### 3a. Bullpen: Summary · Command · Velocity & workload · Trends

| Tab | Contents (top to bottom) | Source |
|---|---|---|
| Summary (`b01`) | Headline sentence (section 4) and its card line (date · tag · N pitches · N pitch types · charted by) · window switch + caption · four tiles: On the spot, Strike %, FB avg mph, Pitches (each: value, change vs the window's average, range bar + "normal a–b" from 5 sessions; "only 2 pens · needs 3" below 3) · What stood out (≤ 3) · the perspective caption | new; baselines from Stage B |
| Command (`b02`) | Takeaway headline · per-type hit / miss grids (filled = on the spot, ring = missed; today's U14 headline and legend kept above them) · pitch table (# · strike · spot · vs avg, following the window) · **where misses went** (new: up / down / arm / glove, All + each pitch) · by batter side (table) · today's per-side blocks with the U14 grids · today's location chart | `renderTypeGrids`, `renderCommandDetail`, `renderPerSideBlocks`, `renderLocationChart` + new |
| Velocity & workload (`b03`) | Takeaway headline · fastball by pitch order with the last-10 band (new chart; only with gunned fastballs) · pitch table (avg · range · mix) · delivery and times to home | `renderVelocityDepth`, `renderWorkload`, `deliverySplitLine` + new |
| Trends (`b04`) | Takeaway headline · one small line per number (on the spot, strike %, FB mph, pitches), last 6 pens, value at the right | today's `history` payload, `renderTrends` redrawn |

### 3b. Game: Summary · Location · Batters · Pitch types · Trends · Every pitch

| Tab | Contents | Source |
|---|---|---|
| Summary (`g01`) | Headline and card line (date vs opponent · N batters · charted by) · line strip IP · P · K · BB · H · R · window switch + caption · four tiles: Strike %, 1st-pitch strike, 2 of first 3 (no comparison: Stage B answer 3), In zone · by-inning table (pitches · strike % · FB mph; the inning named in What stood out highlighted) · What stood out · the perspective caption | new + `renderPitchingLine` numbers |
| Location (`g02`) | Takeaway · today's location charts (by result) and type grids · The pitches that mattered | kept |
| Batters (`g03`) | Takeaway · **times through the order** (new: batters, hits, K, BB by 1st / 2nd / 3rd+ time; a new time every 9 batters) · **after the first pitch** (new: 0-1 vs 1-0, batters and reached H + BB) · balls in play on the field · What led to it · Base states · by count · by batter side · leadoff reached | new + kept |
| Pitch types (`g04`) | Takeaway · by-type table (# · strike · avg · K) · FB mph by inning (small line, first → last) · today's velocity section | `renderByType`, `renderVelocity` + new |
| Trends (`g05`) | Takeaway · small lines from today's game trends · Recent bullpens vs this game · Bullpen to game (both unchanged) | kept |
| Every pitch (`g06`) | The full pitching line (question 6) · Other events · the at-bat log, as today | kept |

**College (`g07`):** no "Year ago" button.

**Tab headlines** ("Fastball found its spot 56%; curveball 22%", "Hitters did the most damage second time through: 4
hits in 9", …) are each one template with numbers, listed in section 4.

### 3c. iPad (820px), not drawn

```
┌──────────────────────── 820 ────────────────────────┐
│ KNUCKLEBALL                    [BASEBALL · BULLPEN] │  brand band, as the phone
│ TEST PITCHER #21                                    │
│ Nov 18 · Command pen · Demo Eagles JV               │
│ SUMMARY  COMMAND  VELOCITY & WORKLOAD  TRENDS       │  all labels fit: no sideways scroll
├─────────────────────────────────────────────────────┤
│ [Headline card, full width]                         │
│ [1 mo][3 mo][12 mo][Season][Year ago]  (max 520px)  │
│ caption                                             │
│ [tile][tile][tile][tile]   four across from 640px   │
│ [What stood out, full width]                        │
└─────────────────────────────────────────────────────┘
```

From 640px the tiles sit four across. Everything else is the phone layout centred in the existing 820px page.
The game's line strip and by-inning table are already full width.

## 4. The sentences (rules, never free text, never AI)

**Words:**
- No "he / his / him" anywhere (decision 16).
- The pitcher is named by their first name (the first word of the stored name).
- Numbers under 11 in a "last N" phrase are words ("last six").
- "pen" means "command pen" / "velocity pen" / "short pen" when tagged, and "pen" when not.

**Summary headline, bullpen.** The first rule that applies wins:

| # | When | Sentence |
|---|---|---|
| B1 | This pen's on-the-spot % is the highest of its last *k* same-kind, same-tag pens (this one + the 5 before, each 10+ pitches, 4 ≤ k ≤ 6) | "Best {pen} of the last {k}: {spot}% on the spot, led by the {type}." (led by = the type with the best spot % on 5+ pitches; the clause is dropped if none) |
| B2 | It is the lowest of those *k* | "Toughest {pen} of the last {k}: {spot}% on the spot." + ", {type} misses went {dir}." when a misses-one-way item exists |
| B3 | A What-stood-out item exists | the largest item's own sentence, as the headline |
| B4 | otherwise | "{spot}% on the spot and {strike}% strikes over {n} pitches." |

**Summary headline, game:**

| # | When | Sentence |
|---|---|---|
| G1 | A rate item and an inning item both exist | "{Rate} {up\|down} to {v}%, but strikes {faded\|rose} to {x}% in the {nth}." (the "but" only when they point opposite ways; otherwise "and") |
| G2 | Strike % is the best / worst of the last *k* games (4 ≤ k ≤ 6) | "Best strike-throwing game of the last {k}: {s}% strikes." / "{s}% strikes, the fewest of the last {k} games." |
| G3 | A What-stood-out item exists | the largest item's sentence |
| G4 | otherwise | "{IP} innings, {P} pitches: {s}% strikes, {fps}% first-pitch strikes." |

**Tab headlines (one each):**
- **Command:** "{Type} found its spot {a}%; {type2} {b}%." (the best and worst type on 5+ pitches; one type: "{Type}
  found its spot {a}%.")
- **Velocity:** with 20+ gunned fastballs and a 2+ mph fade, "Fastball held {a}–{b} for {n} pitches, then slid to
  {c}–{d}."; otherwise "Fastball averaged {avg} mph ({lo}–{hi})". With no radar: "No velocity today: the radar gun
  was off."
- **Trends:** "{Metric} has {climbed\|fallen} in {m} of the last {k} pens" (the metric with the most same-direction
  steps, at least 3 of 5); otherwise "{k} pens of trends: on the spot, strikes, velocity and pitches".
- **Location:** "{n} of {N} pitches in the zone ({pct}%)".
- **Batters:** "Hitters did the most damage {nth} time through: {h} hits in {b}" (one time through: "{h} hits from
  {b} batters").
- **Pitch types:** "{Type} carried it: {n} of {N}, {s}% strikes".
- **Trends (game):** "Last {k} games: strikes {s1}% → {s2}%".
- **Every pitch:** "{B} batters, {P} pitches".

**What stood out** (judged against the 3-month default only, at most three):

| Item | Rule (starting values = packet table) | Marker |
|---|---|---|
| A rate outside the normal range | strike %, on the spot, first-pitch strike %, in zone, FB velocity, and each per pitch type, outside the 3-month 10th–90th range (needs 5+ sessions) | ▲ above / ▼ below; pitches outside range → i |
| Misses going one way | 60%+ of a pitch type's misses in one direction, with 5+ misses (bullpen) | ▼ |
| Fastball fade | last 10 gunned fastballs 2+ mph under the first 10 (needs 20+) | i |
| Hits clustered (games) | half or more of the hits in one third of the zone (up / middle / down rows of the 5 × 5), with 4+ hits | ▼ |
| Side split | one batter side's strike % 15+ points under the other, 10+ pitches each | i |
| An inning (games) | an inning whose strike % (8+ pitches) falls outside the 3-month strike-% range | i |

**Order by size:**
- **Rates:** points beyond the nearest edge of the range, divided by the range's width (minimum width 5 points, or 1
  mph).
- **Patterns:** misses one way = its share minus 50 points, over 10; fade = mph dropped, over 2; hits clustered =
  share minus 33 points, over 10; side split = gap over 15; inning = as a rate.
- **Ties:** the order of the table.

**Footer (for your yes):** "Numbers and patterns only: compared with {First name}'s own sessions, never graded." Then
today's links line (Knuckleball LLC 2026 · knuckleballonline.com · Privacy · Terms · generated {date}).

**Other new wording:**
- **Window caption:** "Compared with {First name}'s 3-month average · 11 pens · command pens only" (+ " · default" on
  3 months).
- **Thin window:** "only 2 pens · needs 3" / "no pens then" (games: "games").
- **What stood out's caption:** "Always judged against the 3-month default, so it doesn't change with the window."
- **The two runner lines** (template_game.ts L179–180): "Left 2 runners on base when the pitcher came out; 1 of them
  scored after and is in this line's R." / "1 of the 2 inherited runners scored — charged to the previous pitcher, not
  in this line's R or ER."

## 5. New colours (`REPORT_VARS`, both sports)

| Token | Baseball | Softball (proposed) | Text contrast (white card) |
|---|---|---|---|
| `--kr-up` | **#1A7F50** (the picture's #1E8A57 is 4.35:1, under 4.5) | #1D6FB0 | 5.01 / 5.31 |
| `--kr-down` | #B4511B | #B0175A | 5.08 / 6.74 |
| `--kr-info` | #2F6FD6 | #6A4BC4 | 4.81 / 6.15 |
| `--kr-band` | #BCD9C9 | #C8DCEF | fill only |
| `--kr-warn-bg` / `--kr-warn-line` | #FFF1E6 / #F2B48A | #FFF0F6 / #F2A9C8 | down on warn-bg 4.59 / 6.11 |
| `--kr-hl` | #FFF6DD | #FDEFF6 | ink on it 17.45 / 13.94 |

- **Softball's choices:** "better" is the softball blue (no green), "worse" the softball dark pink, "info" a purple
  outside both palettes.
- **Meaning never rests on colour alone:** up / down always carry ▲ ▼ or a sign.
- **The warn colours** come into use with Stage D's 7-day card.

## 6. Questions for you

1. **The fastball for "FB avg mph"** and the velocity tab. Pitch names vary (production: Four Seam 253 sessions, Two
   Seam 59, softball "Fastball").
   - **Recommendation:** the session's most-thrown type whose name contains "Fastball", labelled "FB". If there's no
     fastball, the most-thrown type, labelled by its name ("SLIDER AVG MPH").
2. **No radar** (no gunned pitches): **Recommendation:** the tile reads "—" with "radar off" under it, and Velocity's
   chart is replaced by one line. The four-tile layout stays.
3. **Two of the first three for strikes:** what counts.
   - **Recommendation:** a batter counts when two of their first three pitches were strikes, or their at-bat ended
     on a strike before the third pitch (put in play, or a foul-out). Shown as "{x} of {batters}" with the %.
4. **The Summary headline rules and tab headlines** (section 4): **yes as written?** They're constants in one file,
   easy to change after a month of real reports (the packet's review before Stage E).
5. **What stood out's order by size** (section 4): **yes as written?**
6. **The full pitching line** (WP, BK, ER, IR / IRS, SF / SAC, runners left, leadoff reached) has no place in the
   pictures.
   - **Recommendation:** Summary keeps the six-cell strip. The full line opens **Every pitch**, above the at-bat log.
7. **The footer wording** (section 4): **yes?**
8. **Softball colours** (section 5), and the baseball "better" green darkened to #1A7F50 for contrast: **yes?**
9. **Size:** a new report carries every window's tiles (5 × 4 small blocks) and per-type comparisons, so it will be
   bigger.
   - Today's sizes, rendered on staging: pens about 28–30 KB, games about 67–69 KB.
   - **I'll stop and report if either more than doubles** (packet section 5).

## 7. Checks after your yes (packet 10–14, plus every-stage 1–4)

- **Staging, local site, 390 and 820, both sports, as a coach:**
  - a new pen and a new game report, with the tabs and window switch used in report.html;
  - the same in History, with two reports open at once;
  - the no-shadow fallback forced locally.
- **The pictures side by side:** every one of them beside a staging screenshot of the built screen at 390, each
  difference listed. A softball report shows no baseball colour.
- **The numbers:** each window's tiles equal `session_baselines()` for that session (shown side by side). A college
  report has no Year ago.
- **What stood out:** seeded sessions above range, below range, with a miss pattern and with a fade each produce their
  item, and never more than three.
- **Words:** no "he / his / him" in a softball or a baseball stored file (grep).
- **Sizes and old reports:** sizes before and after. Old reports hash the same.
- **The rest:** pre-push checks; no cache bump (no page changes); a STATUS entry and the CLAUDE.md lines in the PR.
