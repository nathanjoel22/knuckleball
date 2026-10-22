# Center-field logo, mown into the grass (Live Game field)

Mark: design #1 from Jordan's Knuckleball Mark Concepts ("Strikeout" — home plate in true 17-inch proportions, the scorebook K from the Black Ops One wordmark, and the spot). Demo: `docs/cf-logo-mown-demo.html` / `.png`.

**How it reads as mown, not painted:** inside the mark the existing mower stripes are re-cut at 90° to the field's stripes and half the width, with a 5% shade and a 10% hairline edge. No new colors: it uses the field's own `--gg-stripe-*` greens, so it themes with softball automatically. The plate is cut as a band (outer plate minus an inset plate) so the inside stays field grass with the K cut into it; the spot is "cut shorter" — a 22% white overlay, not gold (gold is a fill for actions and selection, DESIGN.md).

## Drop into the field SVG (`.gg-field`)

```svg
<defs>
  <!-- existing field stripes (keep yours; shown for the angle reference) -->
  <pattern id="gg-stripes" patternUnits="userSpaceOnUse" width="24" height="24"
           patternTransform="rotate(45 HX HY)">
    <rect width="24" height="12" fill="var(--gg-stripe-a)"/>
    <rect y="12" width="24" height="12" fill="var(--gg-stripe-b)"/>
  </pattern>

  <!-- cross-cut stripes for the mark: same greens, turned 90°, half the pitch -->
  <pattern id="gg-stripes-x" patternUnits="userSpaceOnUse" width="14" height="14"
           patternTransform="rotate(135 HX HY)">
    <rect width="14" height="7" fill="var(--gg-stripe-a)"/>
    <rect y="7" width="14" height="7" fill="var(--gg-stripe-b)"/>
  </pattern>

<!-- the secondary mark, Strikeout: home plate (true 17-inch proportions) cut as a band, the K inside -->
<symbol id="kb-plate" viewBox="0 0 100 100">
  <path fill-rule="evenodd" d="M2 2H98V50L50 98L2 50Z M9 9H91V47.1L50 88.1L9 47.1Z"/>
  <path transform="translate(26 16) scale(0.03466)" d="M0 0H442V1327H0Z M510 1139V494L820 0H1280Z M823 1327L673 1018L935 625L1301 1327Z"/>
</symbol>
<!-- the spot, "cut shorter" -->
<symbol id="kb-plate-lit" viewBox="0 0 100 100">
  <circle cx="67.9" cy="38.2" r="5.6"/>
</symbol>

  <mask id="kb-cf-mask">
    <rect width="100%" height="100%" fill="#000"/>
    <use href="#kb-plate" x="LX" y="LY" width="LSIZE" height="LSIZE" fill="#fff"
         transform="rotate(45 CX CY)"/>
  </mask>
</defs>

<!-- after the outfield grass/stripes are drawn, before the fence line and any markers -->
<g class="kb-cf-logo" mask="url(#kb-cf-mask)">
  <rect width="100%" height="100%" fill="url(#gg-stripes-x)"/>
  <rect width="100%" height="100%" fill="rgba(0,0,0,.05)"/>
</g>
<use href="#kb-plate" x="LX" y="LY" width="LSIZE" height="LSIZE" transform="rotate(45 CX CY)"
     fill="none" stroke="rgba(0,0,0,.10)" stroke-width="1"/>
<use href="#kb-plate-lit" x="LX" y="LY" width="LSIZE" height="LSIZE" transform="rotate(45 CX CY)"
     fill="rgba(255,255,255,.22)"/>
```

## Placement (values from the G5 geometry)

With home at `(HX, HY)` and fence radius `R` (the arc through the 8/9/10/21 corner):

- Center of the mark: `CX = HX + 0.74·R·cos(−45°)`, `CY = HY + 0.74·R·sin(−45°)` — dead center field, inside the fence, above the dirt.
- Size: `LSIZE = 0.40·R`; `LX = CX − LSIZE/2`, `LY = CY − LSIZE/2`.
- `rotate(45 CX CY)` keeps the mark upright on screen because the whole field is drawn rotated −45°. If the field isn't rotated in a given view, drop that transform.
- The rotate on both patterns must use the same `HX HY` the field's stripes use, so the cross-cut is exactly perpendicular.

## Rules

- Draw it under the fence line, the bases, markers and the baseball marker, over the grass; it must never intercept taps (`pointer-events:none` on `.kb-cf-logo` and the two `<use>`s).
- Softball: nothing to do — the pattern reads the softball `--gg-stripe-*` values.
- Reports: the same fragment in `diamond.ts` if the game report draws the field; frozen reports untouched.
- Don't add a gold or white fill to the cells; the mown look depends on it being grass.
