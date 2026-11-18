Written against: `2036c48` (main; production v352). Packet: `plans/v1-field-art-and-guided-flow.md`. Bundle:
`plans/v1-field-art/` (README, 14 boards, 14 pictures, 2 textures). Also read: `plans/u14-relative-accuracy-v2.md`,
`plans/u15-charting-phone-batch.md`, `plans/u16-voice-call.md`, `plans/g6-live-game-gaps.md`, CLAUDE.md, STATUS.md.

# V1 · Field art and the guided Live Game flow · preconditions (Nov 18, 2026)

Nothing is built yet. Line numbers are `bullpen-tracker.html` at `2036c48`.

## Boards against their pictures

All 14 pictures match their markup. Nothing triggers the packet's "stop and ask" rule.

What the boards show that the packet text doesn't say:
- **The wide chart is much smaller than today's.**
  - The boards draw 64 px boxes (a 332 px chart) inside a 740 × 580 scene, on a 1232 × 860 screen.
  - Today `sizeWideGrid` grows the chart up to 560 px.
  - This is not in "Layout changes Joel approved" (question 1).
- **On the phone, most of the batter is off screen.** With the batter sized from the chart (scale 1.433), only the
  elbow, a strip of back and one foot show at the left edge (the right in the pitcher's view). That is what the boards
  draw, and it matters for question 6.
- **All 14 boards are Live Game.** There is no bullpen board and no 501–860 px board (questions 2 and 3).
- **The prompt pill is drawn two ways.**
  - The phone boards say "Tap Pitch Intent" in yellow.
  - The wide boards keep today's pink "Tap where the pitch is called".
  - Part B replaces both, so nothing to decide.
- **The wide scoreboard bar is lighter than the packet's colour:** `#334B45` (baseball) and `#2B4468` (softball), against
  the phone's `#050D09` / `#071A2E` (question 5).
- **The outfield wall's top rail is `#F2C230`** in the markup. It isn't in the packet's colour list.
- **The field's 25 boxes have no outlines.** Today's field has none either (`.g5-cell` outlines are hidden), so this
  matches.
- **The boards load Archivo and Big Shoulders from Google Fonts.** The app self-hosts its fonts and loads nothing from
  other hosts (the privacy policy says so), so the build uses the app's own fonts.

## 1. U15 and U16, and the approved layout changes

U15 (Nov 6) and U16 (Nov 8) are both on main and in production. Status of each approved change:

| # | Change | Today | V1 |
|---|---|---|---|
| 1 | Phone: view button in the Windup/Set slot | Windup/Set is at the right end of the scoreboard (`renderStatusDelivery`, 12036). The Catcher/Pitcher button has its own row under it (`.ph-persp-row`, 11640). | Build: the button sits in that slot until the first pitch, then Windup/Set. The row goes. |
| 2 | Phone: chart fills the width | Capped at 340 px (`.ph-layout .zone-grid`, 250) | Build |
| 3 | Phone: "+" last in the pitch strip | **U15 shipped "+"**, but first, before the strip (Live Game, 12030); in a bullpen it's right of Windup/Set | Move U15's one "+" (`renderArsenalPlus`); not a second one |
| 4 | Wide: Delivery above Pitch type; "+" inside the Pitch type box | Game: perspective, Pitch type, then Delivery with "+" | Build |
| 5 | Wide: Recent pitches in the right column | The log stacks under the controls at every width (`.session-grid-layout` is always a column, 706) | Build |
| 6 | Softball labels are stand-ins | — | Nothing to build |

## 2. How the scenes scale

- **The chart is the anchor.** Each scene is drawn in units of one box.
  - The plate sits below the bottom row, and the batter's scale is the strike zone's height ÷ 180.
  - The boxes, boxes' chalk, bases and wall sit where the board puts them, in box units.
  - So the scene can be any size and still look like the board.
- **One SVG per scene** with a computed `viewBox`, plus the chalk strips as positioned elements in the same units.
- **Phones (≤ 500 px, the 440 board):**
  - The chart is the screen width less the board's 4 px edges: 84 px boxes at 440, about 74 px at 390.
  - The scene's height is the chart plus the board's plate band.
- **Wide (> 860 px, the 1232 board):**
  - The scene panel takes the middle column.
  - The chart is the panel's width × 332 / 740 (question 1), never under 44 px boxes. The panel is held to the screen's
    height, as `sizeWideGrid` does today.
- **501–860 px** (iPad portrait, the stacked layout): question 2.
- **Phone landscape and small laptops** follow their width, as today. A short screen is held by its height like the wide
  layout, so the plate and the result buttons stay on screen.
- **The velocity strip and the edit panel:**
  - The velocity strip draws over the chart's last two rows, as today; the art stays under it.
  - The in-session edit panel opens where it does today; the art doesn't change or move for it.

## 3. Where the art lives

- **One scene builder**, `fieldScene({ view: 'catcher' | 'pitcher' | 'field', sport, layout: 'phone' | 'wide', side, box })`.
  - It returns the scene markup.
  - `renderZoneGrid` (bullpen and Live Game, both views) and `g5Card` (ball in play) call it.
  - It's one builder because every scene uses the same box units, plate, chalk, bases and batter. Two copies would drift
    apart, the way the palette rule exists to prevent.
- **The ball-in-play field** replaces what `g5FieldSvg` draws. It keeps the 25 cells, `G5_BOX` and every tap handler
  as they are, so the saved boxes can't change. This is checked with fixed tap points (Done when 4).
- **The rule this runs into:** CLAUDE.md (G5) says the field is drawn in the tracker and in
  `send-session-report/diamond.ts`, "change both or neither". The packet says reports are not touched (question 4).

## 4. Tokens

| Use | Packet value | Existing token | Proposal |
|---|---|---|---|
| Softball header | `#0B2540` | `--brand-bg` (softball) | Reuse |
| Softball accent | `#FF4F9A` | `--accent` (softball) | Reuse |
| Softball scoreboard | `#071A2E` | `--brand-bg-deep` (softball) is `#06172A` | Keep live (packet: live wins) |
| Baseball header | `#0A1A14` | `--brand-bg` is `#061A12` | Question 5 |
| Baseball scoreboard | `#050D09` | `--brand-bg-deep` is `#030D09` | Question 5 |
| Baseball accent | `#F2B741` | `--accent` is `#FFB81C` | Question 5 |

**New, in `css/tokens.css` per sport** (art only, no chrome):
- `--field-sky` `#BFE3F5`
- `--field-wall` `#1F4D3A` / `#16385C`
- `--field-rail` `#F2C230`
- `--field-grass` `#4E9A4B`
- `--field-grass-2` `#5BA756`
- `--field-infield` `#57A353` (softball: dirt)
- `--field-dirt` `#C99C6B`
- `--field-dirt-light` `#F6E3C4`
- `--plate-top` `#FAFAF7`
- `--plate-edge` `#9FA39A`
- `--batter` `#0E1110`
- the pitcher's-view backstop and stands colours from the boards

Today's `--gg-*` field variables give way to these.

## 5. Cost

- **Textures:** `chalk-line.png` 61.6 KB and `chalk-ring.png` 138 KB, about 200 KB, cached once by the service worker.
  - The ring is 480 × 480 but draws at most about 120 × 23 px (phone) and 160 × 30 px (wide).
  - A 240 × 240 copy would look the same at those sizes and is about 35 KB.
  - The original stays in `plans/`.
- **Code:** about 20–30 KB more in the tracker (the scenes, silhouette path, bases).
- **Render time:** each scene is one SVG of about 40 shapes plus 4–8 chalk strips (a rotated, clipped element with the
  texture as its background).
  - The app re-renders on every tap, so I'll measure an iPhone-sized render at Chrome's 6× CPU slowdown before and
    after, and report the numbers.
  - If the strips cost too much, the same look comes from drawing the texture inside the SVG (one pattern per line).
    Or the scene is kept between taps when nothing about it changed (only sport, view, side or size changes it).

## 6. A wrong batter side

The packet's default is to tap the batter. The trouble on a phone is that the batter is mostly off screen: only an elbow
and a foot show at the edge, a small target.

**Recommend both:**
- **(a)** tapping any visible part of the batter;
- **(b)** a **"Change batter side"** row in More (every screen size).

Either one goes back to Select Batter Side for this batter. The pitches already charted in this at-bat take the new
side (they're still in the draft). Earlier at-bats never change.

## 7. New batters today, and the third out on the bases

**Every path that moves to a new batter:**
- **The result of a pitch** (`applyGameResultProgression`, 8309; reset at 8445):
  - ball four;
  - strike three (looking or swinging), a two-strike foul bunt, a foul tip for strike three;
  - every ball in play (including sacrifices);
  - hit by pitch and catcher's interference;
  - dropped third strike (out or reached);
  - batter's interference (batter out);
  - "other".
- **Count buttons:** intentional walk, and +Ball / +Strike when it makes ball four or strike three (8903–8941).
- **More:** New batter (8731) and New inning (8760).
- **The runners question:** a third out made there after a play (11015–11023).

**Caught stealing or pickoff between pitches** (the scoreboard diamond → `commitAdjustEvent`, 8852):
- **Not the third out:** same batter, same count. Correct, and matches the packet.
- **The third out:** the inning rolls, but **the same batter leads off the next inning and keeps his count** (for example
  2-1).
  - Keeping the batter is right by the rules.
  - Keeping the count is a bug: the next inning should start 0-0.
  - Batter's interference with a runner out as the third out does the same.
- **V1 keeps the batter, and his side, in these cases, as today.** Fixing the count is question 8.

## 8. Keeping the pitch type selected

**This is already how it works.**
- `state.selectedType` changes only in `selectType` (5701). It is not cleared after a pitch or a new batter.
- `gamePitchType()` is `pend.type || state.selectedType` (8456).
- It clears on End session & save (6322), on a pitcher switch (`refreshDraftState`, 5629) and when that type is removed
  from the arsenal (5292).

So Part B's step 2 changes nothing about saved data. What changes:
- **Removed (dead once step 2 always prompts):** the "Select a pitch type first" paths in a game (7988), and the Live
  Game captions it replaces (11625–11627, the phone badges in `phoneLgPrompt` 11552).
- **Kept:** the "never save a pitch with no type" guard (8464 and five more). It protects the data and costs nothing.
- **Changes after a killed tab:** today, reopening clears the selected type, so a resumed game would land on Select Pitch
  Type again (question 9).
- **A pitching change:** today the reliever starts with no type, as the packet wants. The hand-off carries inning, outs,
  count and runners, but **not the batter side** (question 7).

## 9. What can't be built exactly as drawn

- **Fonts:** the app's own self-hosted Archivo and Big Shoulders, not Google's (privacy policy).
- **Wide chart size:** question 1.
- **Bullpen screens and 501–860 px have no board:** questions 2 and 3.
- **The batter under the boxes:** the boards draw the boxes over the batter, so he shows grey through them. Buildable as
  drawn. Taps on boxes stay boxes, and the batter is only tappable where no box covers him (question 6).
- **Relative accuracy glow with reduced motion:**
  - Today the global rule stops the animation and leaves the overlay at full strength: a solid dark box over the zone
    number.
  - The packet wants steady tints, so V1 gives both glows a fixed, light tint under reduced motion.
- **Everything else is buildable as drawn:**
  - the plate, boxes and baselines (with the 26 / 22 px offsets);
  - bases over the chalk with shadows to the right;
  - the chalk ring, the mowed logo, the field filling the width with sky above.

## What G6 means for V1

- G6 was never built under its own name. Most of its 26 cards landed in Live Game R1–R3 (Oct 19–22).
- Two points touch V1:
  - **F6, "batter side per batter", was a Skip on Oct 20.** Part B builds exactly that, so this packet is the newer
    decision.
  - **E3, a pitching change in the middle of an at-bat:** see question 7.

## Questions for Joel, each with a recommendation

1. **Wide chart size.**
   - *Recommend:* as the boards draw it. The chart is 332/740 of the scene's width: about 64 px boxes at 1232 × 860
     (today they're bigger), never under 44 px. On a bigger screen the whole scene grows.
   - *Or:* keep today's chart size and crop the scene around it.
2. **iPad portrait (501–860 px).**
   - *Recommend:* the wide scene, inside today's stacked layout. The controls stay where they are (your Oct 1 "option
     B"), with the chart full width as it is now.
3. **Bullpens.**
   - *Recommend:* the same scenes, with today's bullpen controls and the batter pill kept.
   - On wide screens, Recent pitches goes to the right column there too, so both modes match.
4. **The report's field.**
   - *Recommend:* let the charting field look different from the report's field. The rule becomes "the box layout and
     the tap meaning stay identical", not "the drawing is identical". Reports stay untouched, as the packet says.
5. **Baseball's chrome colours.**
   - *Recommend:* keep the live tokens (header `#061A12`, scoreboard `#030D09`, accent `#FFB81C`) and use the boards'
     colours only for the art. The boards' `#0A1A14` / `#050D09` / `#F2B741` and the wide `#334B45` are each within a
     shade of the live ones; changing them would restyle every other screen.
6. **A wrong batter side.** *Recommend:* tap the batter, and "Change batter side" in More.
7. **A pitching change in the middle of an at-bat.**
   - *Recommend:* the hand-off carries the batter's side when the at-bat continues (the count isn't fresh). The reliever
     starts at Select Pitch Type, not Select Batter Side.
   - A hand-off between at-bats starts at Select Batter Side.
8. **The third out on the bases keeps the count.**
   - *Recommend:* a one-line fix in V1's Part B (the count resets to 0-0 when that out ends the inning; same batter).
   - *Or:* leave it for another time.
9. **A killed tab.**
   - *Recommend:* the draft keeps the selected pitch type too. A resumed game then comes back exactly where it was:
     Select Batter Side if that's where it was, otherwise the next tap.
