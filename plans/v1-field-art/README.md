# V1 field art — reference bundle (Nov 18, 2026)

Source of truth for the look in `plans/v1-field-art-and-guided-flow.md`. Nothing here ships as-is; it is what the charting screens must match.

## textures/
- `chalk-line.png` (80×576, transparent) — one straight chalk line, tiles vertically. The solid band is the middle 56% of the width; the rest is dust. In the boards it is the background of every `<div class="chalk">` strip (`background-size:100% auto; background-repeat:repeat-y`), rotated into place.
- `chalk-ring.png` (480×480, transparent) — the softball pitcher's circle, stretched to an ellipse in the catcher's views (`<div class="chalkring">`, `background-size:100% 100%`).
- In the boards both are referenced as `/_blob/<id>` URLs. Those URLs exist only in the design tool; in the app use these two files.

## boards/
Fourteen mockups. Six are real drawings, eight are thin wrappers that re-use one of the six with a different sport or batter side.

| File | Screen | Size |
|---|---|---|
| `PhoneIntent` | phone, catcher's view, pitch intent | 440×912 |
| `PhoneIntentPitcher` | phone, pitcher's view, pitch intent | 440×912 |
| `PhoneResult` | phone, ball in play (field) | 440×912 |
| `WideIntent` | iPad / laptop, catcher's view | 1232×860 |
| `WideIntentPitcher` | iPad / laptop, pitcher's view | 1232×860 |
| `WideResult` | iPad / laptop, ball in play | 1232×860 |
| `WideIntentLHB` | wrapper: `WideIntent` with a left-handed batter | |
| `SB…` (seven files) | wrappers: the same screens with `sport="Softball"` | |

How to read a board file (it is a template, not a page that runs on its own):
- The markup between `<x-dc>` and `</x-dc>` is the screen. All sizes are inline px; the scene is one `<svg>` plus absolutely positioned `<div class="chalk">` strips and, where bases can touch chalk, a second small `<svg>` on top that holds the bases.
- `{{name}}` is a value returned by `renderVals()` in the script at the bottom of the same file (colors per sport, the grid cells, the batter transform).
- `<sc-if value="{{ flag }}">…</sc-if>` shows its content only when the flag is true (`isSB` softball, `isBB` baseball, `show1B`, `show3B`).
- `<sc-for>` repeats its content over a list from `renderVals()`.
- `<dc-import name="X" sport="Softball">` means "draw board X with these props".
- The batter is the app's own silhouette path (the one in `renderBatterSilhouette`), drawn as one solid `#0E1110` shape with a CSS `clip-path`; softball adds the ponytail path found in the same file.
- `PNG exports of all fourteen boards belong in boards/png/` — Joel adds them from the design canvas; when a PNG and the markup disagree, say so before building.
