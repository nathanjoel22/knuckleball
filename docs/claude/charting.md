# Charting — Knuckleball

Moved word for word from CLAUDE.md on 2026-11-05 (card 015). CLAUDE.md's rules apply here too; read it first.

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
- Live Game phones: Set/Windup sits in the status bar (the ⏱ clock was removed from Live Games Oct 14, Joel -- bullpens keep it; reports still show time to home); the pitch-type row is full width (Oct 8). iPad / laptop: the account button sits in the pitcher header's row (Oct 7).
