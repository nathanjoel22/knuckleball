# V1 — Field art on the charting screens, and a guided Live Game flow, Nov 18, 2026

**Joel, Nov 18: "take all of these images and create a packet to make these updates in knuckleball exactly how they are shown in these photos."** Two things ship from this packet. **Part A** replaces the plain 5×5 chart and the plain field with a drawn ballpark: a real plate on dirt, chalk boxes and baselines, a solid batter, an outfield wall and sky. **Part B** changes how a Live Game at-bat is walked through: the RHB/LHB button goes away, and one yellow prompt tells the charter what to tap next.

Nothing in this packet changes what a saved pitch contains. No schema change, no RLS change, no migration is expected. If you find one is needed, stop and say so.

## The reference bundle

Joel adds a folder to the repo at `plans/v1-field-art/` before you start (it comes from the zip that travels with this packet). Read its `README.md` first. It holds:

- `boards/` — fourteen mockups as markup with exact pixel positions (six drawings, eight wrappers for softball and for a left-handed batter);
- `boards/png/` — a picture of each board, exported by Joel from the design canvas;
- `textures/chalk-line.png` and `textures/chalk-ring.png` — the chalk, cut from a photo Joel took.

The mockups are the specification. Where this text and a mockup disagree, the mockup wins and you tell Joel. Where a picture and its markup disagree, stop and ask.

Mockup sizes are 440×912 (phone) and 1232×860 (iPad and laptop). The app has to hold the same look at every real size in between; say in the report how you will scale it (one `viewBox` scene per screen is the obvious way) and which real breakpoints the two layouts map to.

## Part A — the look

### Where it applies

Every screen that shows the 5×5 chart while charting — **Live Game and bullpen, baseball and softball, catcher's view and pitcher's view, phone and wide** — and the ball-in-play field screen in Live Game. Reports, History, Trends, the Relative Accuracy painter and the profile pages are **not** touched by this packet.

### What must not move

Joel's rule from the mockup rounds: **every piece of text that is on these screens today stays, in the same place, and the artwork fits around it.** The header, the scoreboard, count and outs, the pitch-type strip, the result buttons, Back and More, the velocity strip, the hint line and the Recent pitches log all keep their content. Zone numbers keep the canonical numbering (Amendments 4, 8 and 17): catcher's view reads 1-2-3 across the top, pitcher's view reads 3-2-1. The only layout changes are the ones listed under "Layout changes Joel approved" below.

### The scenes

**Catcher's view (looking out at the field), pitch intent / outcome screen**

- Blue sky, outfield wall with a yellow top rail, mowed outfield stripes, an infield, and a wide dirt area around the plate. The camera is low, close to the catcher's eye line.
- A raised white plate (top `#FAFAF7`, grey front edge `#9FA39A`) sits on lighter dirt **just below the bottom row of the 5×5**. The point of the plate faces the viewer.
- Two chalk batter's boxes, one each side of the plate, set apart from it in proportion to the plate. No umpire's box, no foul poles.
- Chalk baselines start a little **outside** the top inside corner of each batter's box (26 px on the wide mockup, 22 px on the phone) and run out to the edges of the screen, each on its own dirt base path.
- **Baseball:** green infield grass shaped like a diamond (not a crown), its corners reaching toward first and third; a dirt mound.
- **Softball:** skinned (all-dirt) infield, no mound, a chalk pitcher's circle (`chalk-ring.png`).
- **Bases:** raised bags with a lit top, shaded sides, a thin dark contact line and a shadow falling to the **right** (sun over the left-field foul area). Wide screens show first, second and third, for both batter sides. The phone shows second base only. Second base sits back in the dirt behind the infield. First and third are turned so their **outside edge is parallel to the baseline and lies on top of the chalk**; wherever a base and a line meet, the base is drawn on top.

**Pitcher's view (looking in at the backstop)**

- Backstop wall and stands, dirt, the same plate with its flat edge toward the viewer, and the two chalk boxes. No netting grid lines behind the chart, no yellow rail.
- The scene is centred: both boxes the same size.

**Ball in play (Live Game field screen)**

- The same top-down field the app uses today for tap locations — **the tap zones, their numbering and the saved values do not change** — redrawn in the new palette, filling the full width with no white margins, with a band of sky above the wall.
- "the spot" logo mowed into the outfield grass, below the warning track.
- Chalk foul lines from the texture, bases with a drop shadow to the right and drawn over the lines, the same plate.
- Softball: dirt infield and the chalk circle.

### The batter

- The app's own traced silhouette (`renderBatterSilhouette`), as **one solid dark shape, `#0E1110`** — no outline, no shading. Softball adds the ponytail (path in the board files).
- Size is set by the chart, not by the screen: **the bottom edge of the 7-8-9 row sits just below the batter's knees, and the top edge of the 1-2-3 row sits just below the front elbow.** In the mockups that is `scale = strike-zone height ÷ 180` on the 167×504 silhouette.
- The front foot rests **just inside** the inner chalk line of the batter's box.
- Side: catcher's view puts a right-handed batter on the **left**; pitcher's view puts him on the **right** (unchanged from today, Amendments 1 and 16).
- Bullpen with Batter = None: no silhouette, as today.

### Chalk

Every chalk line is the photo texture, not an SVG stroke: straight, even on both edges, the same width along its length apart from perspective taper. Ship the two PNGs as real files (suggest `assets/field/`), add them to the service-worker precache so they work offline, and bump the shell version. The repo is public; the two textures and the board files contain nothing private.

### Colours

All in the board files' `renderVals()`. Baseball: header `#0A1A14`, scoreboard `#050D09`, accent `#F2B741`, wall `#1F4D3A`, grass `#4E9A4B` / `#5BA756`, infield `#57A353`. Softball: header `#0B2540`, scoreboard `#071A2E`, accent `#FF4F9A`, wall `#16385C`. Shared: sky `#BFE3F5`, dirt `#C99C6B`, light dirt `#F6E3C4`. **Use the app's existing design tokens where one already holds the same value; report any colour here that would need a new token rather than hard-coding it.** If softball's live palette differs from these, keep the live one and say so.

### Layout changes Joel approved

1. **Phone — the view button takes the Windup/Set slot.** Before the first pitch of a session, the scoreboard slot that holds Windup/Set shows the perspective button instead ("CATCHER ⇄" / "PITCHER ⇄"). The first pitch locks the perspective, as it does today, and from then on the slot shows Windup/Set. Everything below moves up one row. Softball has no Windup/Set, so the slot is empty once the view locks.
2. **Phone — the chart fills the width.** The 5×5 runs edge to edge; the plate and extra dirt sit below the bottom row.
3. **Phone — "+" (add a pitch type) is the last item in the pitch strip**, or the first and only item when the pitcher has no pitches. A plain dark plus, centred like the pitch labels. **This overlaps U15's "+" item: build it once, here if U15 has not shipped, and say which.**
4. **Wide — Delivery (Windup/Set) sits above Pitch type** and spans the column so "Windup" fits. "+" is the last choice inside the Pitch type box, grey like the others, centred, no white box.
5. **Wide — Recent pitches log in the right column** (empty state before the first pitch).
6. The pitch labels in the softball mockups (FB, RISE, CH, DROP) are stand-ins. The app shows the pitcher's real arsenal.

## Part B — the guided Live Game flow

Applies to **Live Game only**, both sports. Bullpens keep today's flow and their No batter / vs RHB / vs LHB pill.

One yellow prompt (the existing accent pill under the chart) always says what to tap next. With the RHB/LHB button gone it is **centred**. The four strings, exactly:

| Step | Prompt | What pulses | What ends the step |
|---|---|---|---|
| 1 | **Select Batter Side** | The **two outside columns** of the 5×5 (far left and far right), in brand yellow, with the same overlay and rhythm Relative Accuracy uses (`.rel-glow-overlay`, `relGlowPulse`). No silhouette is drawn. | A tap on either outside column. The batter appears on the side that was tapped. |
| 2 | **Select Pitch Type** | The pitch-type choices, **very subtly** — same idea as the Relative Accuracy pulse at roughly a third of its strength. | A pitch type is chosen. |
| 3 | **Select Pitch Intent** | Nothing new. | The intended location is tapped. *Shown only when Intent is on for this game.* |
| 4 | **Select Pitch Outcome** | Nothing new. | The outcome location is tapped; from here everything is today's cadence (What happened?, ball in play, runners, velocity). |

Rules:

- **Step 1 happens once per batter.** The tap that picks a side records nothing as a pitch. The side tapped is where the batter **stands on screen**, so it means RHB or LHB according to the charting perspective (catcher's view: left column = RHB; pitcher's view: right column = RHB). A tap anywhere else during step 1 does nothing.
- **The batter stays** until the plate appearance ends. Joel's words: "until an out or ball in play scenario occurs which necessitates a new batter." Read that as *whenever the app moves to a new batter today* — strikeout, walk, hit by pitch, ball in play, an out that ends the at-bat. A caught stealing that does **not** end the at-bat keeps the batter. A third out on the bases mid-at-bat: do what the app does today about the batter, and report it.
- **Step 2 happens once.** After the first pitch type is chosen it **stays selected for every following pitch and every following batter** until the charter changes it by hand (or by voice, if U16 is live). So the normal rhythm after the first pitch is: (new batter → step 1) → step 3 or 4. The subtle pulse on the pitch choices shows only while no type is selected. A pitching change clears the type, because the new pitcher has his own pitches.
- Intent off: step 2 goes straight to step 4. Intent on: 2 → 3 → 4.
- These four strings replace today's "Tap where the pitch is called", "Now tap where the pitch went" and "Tap where the pitch landed" in Live Game. Hints such as "Select a pitch type first" are no longer reachable in Live Game on any screen size; remove the dead paths rather than leave them.
- **No silent default.** `sessionBatterSide()` returns `'R'` when nothing is set. In Live Game "not chosen yet" must be a real state, saved in the draft so a killed tab comes back to **Select Batter Side**, never to a right-handed batter nobody picked. A pitch can never be saved without a batter side in Live Game.
- **Fixing a wrong side.** With the button gone there has to be a way back. Default: tapping the silhouette returns to step 1 for the current batter and corrects the side on the pitches already charted in this at-bat (they are still in the draft). Report this as question 6; Joel may choose otherwise.
- Undo: undoing the first pitch of an at-bat leaves the batter in place. Undoing back across an at-bat boundary restores the previous batter's side.
- `prefers-reduced-motion`: both pulses become a steady tint.
- Relative Accuracy's own glow still shows in steps 3–4 as it does now; in step 1 only the outside columns glow.

## Still in force

Service-role key never outside Edge Function env vars. No Admin API. Saved sessions immutable. Every schema or RLS change through a migration, staging first, fresh backup before prod — and none is expected here. `auth.users.email_confirmed_at` is never read. **Only Joel ships to production**; you never push to main or merge a PR; merges go through the GitHub page after checks. No email address or password in a commit. `report.html` is not touched; if you do touch its inline script, its CSP hash must be recomputed.

## Report first, then build

Pull `origin/main`; read `CLAUDE.md`, `STATUS.md`, `plans/v1-field-art/README.md`, every board, and `plans/u15-charting-phone-batch.md`, `plans/u16-voice-call.md`, `plans/u14-relative-accuracy-v2.md`, `plans/g6-live-game-gaps.md`. Then report, before writing code:

1. Whether U15 and U16 are on main, and which items of "Layout changes Joel approved" are already there.
2. How the scenes will scale between 440 px and 1232 px and beyond (phone landscape, small laptops), and what happens to the art when the velocity strip or the edit panel is open.
3. Where the art lives in code: one shared scene builder for all four charting contexts, or more than one, and why.
4. Every existing token you will reuse and every new one you need.
5. The cost: added bytes, the two PNGs' weight, and render time on an older phone. If the rotated chalk strips are slow, say what you would do instead that looks the same.
6. How a wrong batter side is corrected (the default above, or a better one).
7. Exactly which events move to a new batter today, and what the app does about the batter on a third out made on the bases.
8. Whether keeping the pitch type selected across pitches and batters changes anything in today's behaviour (`gamePitchType`, `state.selectedType`, the "never save a pitch with no type" guard).
9. Anything in the boards that cannot be built as drawn, with the closest alternative.

Then build in two pull requests, **A (look) first, B (flow) second**, each on staging with before/after screenshots at 390×844, 440×912, 820×1180 and 1280×800, baseball and softball, both views, both batter sides.

## Done when

1. Each of the fourteen boards has a staging screenshot beside it that matches: plate under the bottom row, boxes, baselines, bases, shadows to the right, chalk texture, solid batter, knees and elbow on the right rows, front foot inside the line.
2. All text present before the change is present after it, in the same place, apart from the six approved layout changes.
3. Softball shows the dirt infield, the chalk circle, the ponytail, no Windup/Set, and the live softball palette.
4. The ball-in-play screen saves the same zone values as before for the same tap points (test with fixed coordinates).
5. Offline: with the network off after one load, every scene and both textures draw.
6. Live Game: a new game opens on **Select Batter Side** with no batter drawn and the outside columns pulsing; the four prompts appear in order with Intent on, and step 3 is skipped with Intent off.
7. The pitch type chosen on pitch 1 is still selected on pitch 2 and on the next batter's first pitch; it changes only when tapped (or called by voice); it clears on a pitching change.
8. A new batter after a strikeout, a walk, a hit by pitch and a ball in play each returns to step 1; a caught stealing mid-at-bat does not.
9. Killing the tab during step 1 and reopening returns to step 1. No Live Game pitch is ever saved without a batter side.
10. The RHB/LHB button is gone from Live Game on every screen size and still present, unchanged, in bullpens.
11. Saved pitches, `session_stats`, reports and Trends for a game charted after the change equal those for the same pitches charted before it.
12. Reduced motion shows steady tints. The full test suite passes; shell version bumped; `STATUS.md` updated.

## Prompt for Claude Code

```
Save this packet verbatim as plans/v1-field-art-and-guided-flow.md on the branch before anything else; if a copy already exists on main, use that one and tell me if the two differ.

Then read plans/v1-field-art/README.md and every file under plans/v1-field-art/. If that folder is missing or boards/png/ is empty, stop and tell me.

Do the "Report first" section and wait for my answers. Do not write feature code before I reply.

After I reply: build Part A (the look) as one pull request and Part B (the guided Live Game flow) as a second, in that order, staging only. No migration is expected; if you think one is needed, stop and ask. Do not push to main, do not merge, do not deploy to production. Finish each pull request with the screenshots and the numbered "Done when" list, each item marked pass or fail with evidence.
```
