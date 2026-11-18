# V1 Part A · the look · evidence (Nov 18, 2026)

Branch `v1-field-art`, cache `kb-shell-v353`. Tested on the local staging site (staging database), headless Chrome with
device emulation. "Before" is today's main (v352), served from a separate copy; "after" is this branch. Nothing was
saved: every test session was thrown away before End session & save.

Pictures:
- `plans/v1a-evidence/boards-*.jpg`: each board picture beside the same screen on staging.
- `plans/v1a-evidence/<sport>-<size>.jpg`: before (top row) and after (bottom row).
  - Six screens each: catcher's view vs RHB, vs LHB, pitcher's view vs RHB, vs LHB, the ball-in-play field, a bullpen.
  - Sports: `sb` softball, `bb` baseball. Sizes: 390 × 844, 440 × 912, 820 × 1180, 1280 × 800.
- Every picture was scanned for "@" (no email addresses): none.

## Done when

Items 6-10 are Part B's (the guided flow); they are checked in that pull request.

1. **Each board beside a staging screenshot: PASS.**
   - `boards-phone-bb.jpg`, `boards-phone-sb.jpg`: the six phone boards at 440 × 912.
   - `boards-wide-bb-1/2.jpg`, `boards-wide-sb-1/2.jpg`: the eight wide boards at 1280 × 800.
   - Each shows the plate under the bottom row, the boxes, the baselines and second base. On wide screens they also
     show first and third on the chalk.
   - Shadows fall to the right, and the chalk is the photo texture.
   - The batter is solid, at the board's scale, and sides right for both views and both batter sides.
   - The field fills the panel, with sky above the wall and the mowed logo.
2. **All text kept, in the same place, apart from the approved changes: PASS.**
   - The before / after pictures show every label, prompt, button and log line on both rows.
   - Moved by the approved changes:
     - Phones: the view button is in the status bar until the first pitch. Its "CATCHER · LOCKED" note row is gone:
       after the first pitch the slot is Windup / Set (change 1).
     - Phones: "+" is last in the strip (3).
     - Wide: Delivery is above Pitch type and "+" is in the box (4); Recent pitches is in the right column (5).
   - The "vs RHB / vs LHB" label that sat under the old silhouette is the same pill in the row under the art.
3. **Softball: PASS.** Dirt infield and the chalk circle (`chalk-ring.png`) in every view and on the field; the ponytail;
   no Windup / Set (the phone slot is empty once the view locks); the live softball palette (navy, pink).
4. **The field saves the same boxes for the same tap points: PASS.**
   - Ten fixed points on the field (in G5's own 500-unit square) were tapped with `elementFromPoint` on today's main
     and on this branch, at 440, 820 and 1280.
   - All six runs give the same boxes: home 15, 1B 23, 2B 25, 3B 17, mound 24, deep CF 7, left corner 4, right corner
     10, shortstop 18, right-centre gap 21.
   - The drawn landmarks sit on those points: the boards' field is G5's geometry at 337 units.
   - The boxes' handlers are unchanged, so the saved `spray_box` follows.
5. **Offline: PASS.**
   - One online load (`kb-shell-v353` caches both textures: `caches.match` true for each).
   - Then the network was cut (Chrome's offline mode), the page reloaded, and a fresh Live Game was started.
   - The chart scene and the field drew with the chalk; both textures came back 200 from the service worker.
   - The header showed the offline dot.
11. **Saved data unchanged: PASS (by construction).**
    - Part A changes only drawing and layout functions: `renderZoneGrid`'s output, `g5Surface`, `g5FieldSvg`,
      `g5FieldFace`, the session layouts, `sizeWideGrid`, the pitch strip and trays.
    - No function that records, scores or syncs a pitch changed. In the diff, the only line naming one is a
      `renderZoneGrid(..., 'handleZoneTap')` call.
    - The 25 boxes keep their `(row, col)` handlers, so the same taps make the same pitches.
    - A game is charted and synced end to end in Part B's check.
12. **Reduced motion, version, log: PASS.**
    - Part A adds no animation (the flip is G5's, already off under reduced motion).
    - The cache is bumped to v353, STATUS.md has the entry, and the pre-push checks run on push.

**Cost** (iPhone-sized, Chrome's 6x CPU slowdown):

| Measure | Before (v352) | After |
|---|---|---|
| `render()` on the chart | median 9.4 ms | median 11.0 ms |
| `render()` on the field | median 8.5 ms | median 8.3 ms |
| render through two frames (layout and paint) | median 21.9 ms | median 15.7 ms |

The differences are within noise. Bytes:
- the tracker 1,074,133 → 1,103,103 (+29 KB; +5.8 KB compressed);
- `tokens.css` +1.1 KB;
- the two textures 105.5 KB, cached once.

## How it's built

- **One stage per chart** (`v1Stage`): the board's art is one SVG scaled by its `viewBox`. Phones (≤500px) use the
  440 × 518 phone boards and everything wider the 740 × 580 wide ones. The 25 boxes sit where the board puts them.
- **The art is generated from the boards** by a script: `V1_SCENE`, six scenes.
  - Chalk divs become SVG polygons filled with the chalk texture.
  - The chalk ring is an `<image>`.
  - Colours are tokens.
- **The batter** is the app's own silhouette path, kept once as `KB_BATTER_D` and drawn solid in `--batter`. Placement
  comes from the boards (`V1_BATTER`; the unboarded sides are the boards' mirrors).
- **The ball-in-play field** is a stage of its own. Its 25 boxes sit on the field's square with the same `G5_BOX`
  layout and handlers. `g5FieldSvg` keeps only its live layers: the shaded area and the gold base under a runner.
- **The flip** turns the whole stage (`v1Flip`).
- **Colours:** `css/tokens.css` gains `--field-*`, `--plate-*` and `--batter`, with softball's wall, stands, dirt infield
  and no mound. The app's chrome keeps its live tokens (question 5).
- **Some art colours stay as literals in the scenes:** the base sides and shadows (`#D2D5CD`, `#B4B8AF`, …), the field's
  foul greens (`#3F8440`, `#387A3A`) and the logo's mowed greens. They are shading inside one drawing, not colours any
  other screen uses.
- **The textures** are `assets/field/chalk-line.png` (61.6 KB) and `assets/field/chalk-ring.png`. The ring was reduced
  to 240 × 240 (44 KB), which looks the same at its drawn sizes; the original stays in `plans/`. Both are precached.
- **`U15`'s "+" is moved, not duplicated:**
  - phones: the pitch strip's last item;
  - wide: the Pitch type box's last grey choice (`pitchTypeTray(p, grid, plus)`);
  - the stacked 501–860 layout keeps it beside Delivery (question 2).
- **Removed as dead:**
  - the chart's in-grid plate and batter (`renderZoneGrid` returns only the boxes for a charting chart; the accuracy
    painter keeps `renderHomePlate` and `renderBatterSilhouette`);
  - the old field drawing's static layers and its logo constant (the report keeps its own copy in `diamond.ts`);
  - `g5Card`;
  - the phone's perspective row and in-grid badge band CSS.

## Deviations and notes

- **The wide boards' Recent pitches table.** The boards draw `# · TYPE · MPH · RESULT` columns. The app's own log rows
  (with their edit buttons and text) moved into the column as they are. Say if you want the table look.
- **The picked box on the boards** is white with an accent border. The app keeps its own target, flash and ball styles
  over the boards' box colours.
- **The wide scoreboard bar** (`#334B45` / `#2B4468` on the boards) and the baseball chrome keep the live tokens
  (question 5).
- **The wide pitcher header** (photo, name, chips) above the scoreboard isn't on the boards. It stays.
  - It pushes the stage down a little.
  - At 1280 × 800, the result buttons, Back and More sit just below the fold, a short scroll. Since Oct 2, the rows under
    the chart aren't counted in the height budget.
- **The phone stage is taller than the old grid** (440 × 518 against a 340 square). Everything below moves down by that.
- **Before the first pitch is saved,** the phone's view button stays in the slot even while that first pitch is still
  being asked about (what happened, ball in play). It locks when the pitch is saved, the same lock as today.
- **Fonts:** the boards ask for Google Fonts. The app uses its own self-hosted Archivo and Big Shoulders, because the
  privacy policy says nothing loads from other hosts.
- **Evidence pictures:** each screenshot is cropped just above the scoreboard, so no test account's name or photo is
  in the public repo. The pictures were scanned for "@" and for the test accounts' names: none.
- **Staging:** the U15 Softball test coach got a baseball profile on Nov 17 (an earlier test). Nothing else was written.
