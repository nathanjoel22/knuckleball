# G5 — Live Game on the diamond (Oct 6, 2026)

**Joel, Oct 6, 2026.** Live Game becomes two surfaces: the square **pitch-location chart** (pitcher's view, U12) and a **field diamond** the chart rolls into after every location tap. Everything about a pitch's outcome is tapped on the diamond's 25 boxes. The point of the chart is **where balls in play land and how they were hit**, plus enough balls, strikes and outs to count innings. Not every baseball outcome is modeled (Joel: "We are not concerned with every possible baseball outcome").

**Supersedes G4** (`claude/g4-live-game-flow-v2.md`, never built) and, in Live Game only, G1b-r3's in-grid entry: the scorebook box, choice boxes, 3×3 position block, Done, DP box, ADV/Fix runners, the in-grid velocity bar and the More menu. Both sports; one flow (S2).

**References (save to `docs/` via GitHub):** `game-flow-v3-reference.html` and `game-flow-v3.png` (the twelve screens; 12 is the softball field), `game-field-numbering.html` and `game-field-numbering.png` (the field with boxes 1–25). Match them; where they differ from this spec, the spec wins.

## The field (fixed geometry; reports aggregate on it)

- The 5×5 grid, rotated **45° to the left**, so the old bottom-left corner is the bottom point. On a 390pt phone the diamond's square side is 253pt (cells ≈46pt); it occupies the same width and height as today's grid. On 375pt phones cells must still be ≥44pt. **iPad and laptop** (Joel, Oct 7): the diamond's cells stay **exactly the same size as the location chart's cells** on that screen (r6 grid size), so the rolled diamond is wider and taller than the square (its width is the square's side × √2). Only the phone shrinks the cells to fit; those screens have room.
- **Box numbers** (Joel): box 1 holds home plate; count up the third-base line to 5 (left point); clockwise around the edge — 6–9 to the top point, 10–13 to the right point, 14–16 back toward home; then the inner ring 17–24 the same way; 25 in the center. In unrotated row/column terms (row 0 top, column 0 left): 1=(4,0) 2=(3,0) 3=(2,0) 4=(1,0) 5=(0,0) 6=(0,1) 7=(0,2) 8=(0,3) 9=(0,4) 10=(1,4) 11=(2,4) 12=(3,4) 13=(4,4) 14=(4,3) 15=(4,2) 16=(4,1) 17=(3,1) 18=(2,1) 19=(1,1) 20=(1,2) 21=(1,3) 22=(2,3) 23=(3,3) 24=(3,2) 25=(2,2).
- **Home plate** points toward the backstop (down), the same orientation as on the location chart. **Its top (the flat edge facing the pitcher) sits on the corner where boxes 1, 2, 16 and 17 meet**, and the plate hangs down into box 1 (Joel, Oct 7). The foul lines run from that point along the grid lines, so **boxes 2–5 and 13–16 are foul ground**, plus box 1 behind the plate; fair territory is the 4×4 block of the other 16 boxes.
- **Bases** (Joel, Oct 7): **1B on box 15** and **3B on box 3**, each sitting in fair ground with its outer edge lined up exactly with the outer edge of its foul line. **2B in box 25**, moved down so its bottom corner touches the top corner of the infield grass square. Mound in box 17. A base turns **yellow** while occupied.
- **Fence**: an arc centered on home plate passing through the corner where boxes 8, 9, 10 and 21 meet; its ends land in boxes 7 and 11. Beyond it (box 9 and parts of 8 and 10) is over the wall.
- **Dirt** (Joel, Oct 7): one rounded shape whose bottom corner sits exactly on home plate's point (the 1/2/16/17 corner), running up both foul lines and rounding off behind the bases; it stays entirely inside boxes 17, 18, 24 and 25 (its arc never passes the outer edges of 18, 25 and 24). No dirt in foul territory. Infield grass square inside the bases. **Only the two foul lines (home to 1B and home to 3B, continuing to the fence) are drawn in white; there are no lines from 1B to 2B or 2B to 3B.** **Softball** (Joel, Oct 7): same geometry, boxes and buttons; the infield grass square is drawn **all brown (dirt)**, and 2B stays exactly where it is on the baseball field even though there's no grass corner to touch. Softball uses its palette and draws the pitcher's circle instead of a mound. Screen 12 of game-flow-v3.png shows it.
- **Roll direction** (Joel, reminder Oct 7): the chart rolls 45° **left** into the diamond and always rolls 45° **right** when it returns to the pitch-location chart.

## The flow

| # | Screen | What's live | Then |
|---|---|---|---|
| 1 | **Location chart** (square, pitcher's view) | tap a location | the chart **rolls 45° left** into the diamond (animated, ~350 ms; reduced motion → instant) |
| 2 | **What happened?** | box **7 Ball · 8 Looking · 21 Swing · 10 Foul · 11 In Play** — each box fills white with the existing icon and label, gold edge, flashing | Ball/Looking/Swing/Foul → step 3 · In Play → step 4 |
| 3 | **Non-contact pitch** | recorded; the diamond **rolls back right** to the square chart. Radar on: velocity strip under the chart + **Next pitch**. Radar off: chart reset for the next pitch | — but ball four (walk) goes to step 7 first |
| 4 | **In Play** | **21 H · 11 O · 7 E**, white, flashing | step 5 |
| 5 | **How was it hit?** | **11 GB · 8 Pop · 21 LD · 10 Fly · 7 Bunt**, white, flashing | step 6 |
| 6 | **"Select Ball in Play Location"** | all 25 boxes flash a translucent dark tint (foul boxes included, for foul pop-up catches) | tap one → the other tints clear and a **baseball** marks that box → step 7 |
| 7 | **"Select current bases for baserunners"** | boxes **3, 25, 15** flash; tap any combination; each selected box shows **3B / 2B / 1B** in black on white and its base turns yellow; tap again to clear | radar on: **Next** (above Back, bottom-right) → roll back → velocity → Next pitch · radar off: **box 17 shows "Next pitch"** → roll back, reset |

Always on the diamond: **‹ Back** bottom-right (steps back one screen; on screen 2 it rolls back and cancels the location tap) and **+ Add out** bottom-left (adds an out; for double and triple plays).

## Rules (Joel)

1. **Outs.** Tally an out only when one is recorded: **O** adds one; a strikeout (strike three looking or swinging) adds one; **+ Add out** adds each extra out on the play. Three outs end the half-inning: count resets, bases clear, inning advances, delivery re-defaults. H and E add none.
2. **The runners question follows every plate appearance except a strikeout.** Hits, outs, errors and walks (ball four) all go to "Select current bases for baserunners." Strikeouts leave runners where they were. Pitches that don't end the at-bat never ask.
3. **Pre-fill** the bases screen with the obvious result so most plays are one tap: walk → forced advances; anything else → the runners as they were before the pitch plus nothing for the batter (the charter adds him). The charter's taps are the truth.
4. **Runs are not tracked.** Reports don't show runs allowed.
5. **Delivery**: Windup with the bases empty, Set with anyone on, re-defaulted per batter and after the bases screen; the button switches it (existing behavior).
6. **Count** advances from the result: ball, called strike, swinging strike; a foul adds a strike below two strikes; ball four is a walk; strike three is a strikeout. A new at-bat starts after a strikeout, a walk or any ball in play.
7. **Not modeled** in this flow (Joel, point 19): the More menu (HBP, dropped third, catcher's/batter's interference, foul tip, IBB, auto ball/strike, balk, softball illegal pitch), stolen bases and other between-pitch runner moves, single/double/triple/HR distinction, fielders, runs. *Drafting decision for Joel:* the G3 extra-inning "runner on 2B?" prompt stays, asked as a Yes/No on the location chart at the start of an extra half-inning per the team's level of play. Strike it if unwanted.
8. **Undo, New batter, New inning** stay under the chart as manual fallbacks; Undo reverses the last recorded pitch or bases change in one step.

## Data

- `pitches.spray_box smallint NULL CHECK (1..25)` — Joel's box number, for balls in play. `pitches.runners_after smallint NULL CHECK (0..7)` (1st=1, 2nd=2, 3rd=4) — written after every plate appearance that asks. `outs_on_play` = 1 for O or a strikeout plus Add-out taps. Existing columns kept: `result`, `in_play_outcome` (hit/out/error), `bb_type` (GB/LD/POP/FB/BUNT), `runners_before`, count, outs, inning, at-bat index, delivery, batter side, velocity. `bb_x`/`bb_y` set to the box center so older readers don't break. `hit_type`, `fielder(s)`, `runner_advances`, `runs_scored` left NULL in new games.
- Old games: the renderer maps their `bb_x`/`bb_y` to a box number so spray charts include them.
- Everything rides H1's one-call `sync_session()` save.

## Reports (game renderer, both sports; location grids in the pitcher's view per U12; the field drawn as above)

1. **Spray charts on the 25-box diamond**: all balls in play; hits / outs / errors; per batted-ball type (GB, LD, Pop, Fly, Bunt); **per pitch type** — counts and shading per box, foul boxes included.
2. **What led to it**: for each ball-in-play box and each batted-ball type, the pitch types and pitch locations that produced it; a **pitch type × result** matrix (Ball · Called strike · Swinging strike · Foul · In play: hit / out / error); the **deciding pitch** of every strikeout, walk and ball in play (type and location), summarized per outcome with a small location grid each.
3. **Base states**: one row per state — empty · 1st · 2nd · 3rd · 1st+2nd · 1st+3rd · 2nd+3rd · loaded — with pitches, strike %, pitch mix, balls in play, hits, outs, strikeouts and walks from that state, and the same table split by pitch type. No runs column.
4. **Innings pitched** from the out count. Existing sections stay; frozen reports untouched.

---

## The packet (paste for Claude Code — after P1-09; Joel decides its place against R4 and U12)

```
ID:              G5
Title:           Live Game on the diamond — location chart rolls into a 25-box
                 field; outcome, contact, spray box and baserunners tapped on the
                 field; velocity on the roll back; spray and base-state reports
Spec:            plans/g5-live-game-diamond.md on GitHub (pull first; work only
                 from GitHub). References in docs/: game-flow-v3-reference.html,
                 game-flow-v3.png, game-field-numbering.html,
                 game-field-numbering.png.
Supersedes:      G4 (never built); G1b-r3 in-grid entry in Live Game.
Depends on:      U12 (pitcher's view) if shipped — otherwise build against the
                 current view and leave the view constant to U12; G3 (level of
                 play, tiebreak), S2 (softball game), H1 (one-call save), r5/r6
                 layouts. Staging only; only Joel ships to production.

PRECONDITIONS — REPORT, with file and line numbers, before any code or SQL:
  1. The Live Game state machine as built (location tap → in-grid steps →
     velocity → Next Pitch), Resume/Undo, and every element this replaces.
  2. Count/out/inning/at-bat logic and the walk/strikeout rules — reuse, don't
     copy.
  3. The one-call save payload; where spray_box and runners_after ride along.
  4. compute_game_summary and the game renderer: every read of fielders,
     hit_type, runner_advances, runs_scored, bb_x/bb_y.
  5. How the field is drawn today (docs/game-grid-field.svg, softball field)
     and how the reference's field geometry (spec "The field") will be drawn
     as one SVG inside the rotated grid, both sports.
  6. Rotation: CSS transform on the grid container with tap targets still
     mapped to cells after rotation (hit-testing on rotated elements), at
     390, 375 and iPad/laptop (r6) widths; cells ≥ 44pt; whether the r6
     layout has room for a diamond with chart-size cells on iPad/laptop.
  7. The radar-on/off setting (U9) and where velocity sits on the square chart
     after the roll back.
  8. What happens to the More menu, ADV and the G3 tiebreak prompt in the code
     — what is removed vs kept per spec rule 7.
  9. Game pitch counts on staging/production for the old-data mapping.
  Build nothing until Joel has read the report.

MIGRATION g5_spray_box:
  pitches.spray_box smallint NULL CHECK (spray_box BETWEEN 1 AND 25);
  pitches.runners_after smallint NULL CHECK (runners_after BETWEEN 0 AND 7);
  sync_session() accepts both; no policy change (count before/after).

CLIENT (Live Game, both sports):
  - Field SVG per spec (numbers are not drawn in production; they're the
    reference). Diamond = the 5×5 grid rotated −45°, same cells, field behind.
  - Roll animation both directions (~350 ms, ease; reduced motion → instant).
  - Screens per the flow table; white flashing box buttons with the existing
    icons for Ball/Looking/Swing/Foul/In Play; text buttons H/O/E and
    GB/Pop/LD/Fly/Bunt in the spec's boxes; dark flashing tint for location
    and base selection; baseball marker; 1B/2B/3B labels; yellow bases.
  - Back bottom-right; Next above it (radar on, bases screen); + Add out
    bottom-left on every diamond screen; box 17 "Next pitch" (radar off,
    bases screen).
  - Rules 1–8 from the spec: outs, runners question after every PA except a
    strikeout, pre-fill, no runs, delivery default, count, not-modeled list,
    Undo/New batter/New inning.
  - Remove: scorebook box, choice boxes, position block, Done, DP box,
    ADV/Fix runners, in-grid velocity, More menu (Live Game only).

REPORTS: spec "Reports" 1–4 in the game renderer; old games mapped from
  bb_x/bb_y; frozen reports untouched; strict escaping.

ACCEPTANCE (both sports; stored rows shown):
  1. Screenshots of every reference screen at 390, 375 and iPad landscape,
     side by side with game-flow-v3.png; cells ≥ 44pt; on iPad/laptop the
     diamond's cells measure the same as the location chart's; the roll animates both
     ways; reduced motion shows no animation.
  2. Box mapping: tapping each of the 25 boxes in the location step stores the
     matching spray_box (1–25 per the spec map) — full table.
  3. Flows: ball, called strike, swinging strike, foul (<2 and 2 strikes),
     strikeout looking and swinging (out +1, no bases screen), walk (bases
     screen pre-filled with forced advances), single with runner on 1st
     (H·LD·box·bases), groundout double play (O·GB·box·Add out·bases → outs
     +2), error (E·GB·box·bases, no out), foul pop-up caught in box 4
     (O·Pop·box 4). Each stored row matches the spec.
  4. Three outs end the half-inning; Windup/Set re-default; level-of-play
     tiebreak prompt (if kept) at the right inning.
  5. Radar on: velocity + Next pitch after the roll back for every result;
     radar off: box 17 Next pitch on the bases screen and no velocity step.
  6. Back steps back one screen everywhere; on "What happened?" it rolls back
     and cancels the location; Undo reverses the last pitch including its
     bases change.
  7. Reports: a staging game with the cases in 3 renders spray charts (all,
     by result, by batted-ball type, by pitch type), the pitch × result and
     deciding-pitch sections and the base-state table with counts hand-checked
     against SQL; an old game renders with mapped boxes; softball themed.
  8. Offline through a full at-bat, kill the browser, Resume at the same
     screen; save offline, reconnect → one-call sync with the new columns.
     P1-01 checks 1–3 pass; CACHE_VERSION bumped.
VERIFICATION: Joel charts a real inning on his phone and iPad (both sports on
  staging) including a walk, a double play, an error and a foul pop-up, and
  reads the report. Production after a fresh backup.
ROLLBACK: git revert; down migration drops the two columns.
SIZE: L.
ESCALATE IF: rotated cells can't be hit-tested reliably at 375pt; any cell
  falls below 44pt; the softball field can't share the geometry; the one-call
  payload needs a format change beyond two columns.
```

### Standing constraints (in force)

One Live Game flow for both sports. Locations stored in the catcher frame; displays follow U12. Saved sessions immutable; frozen reports untouched. Games never feed the leaderboard or accuracy stats. Every schema change via migration, staging first, fresh backup first. GitHub is the source of truth. **Only Joel ships to production.**
