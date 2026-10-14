# D3 — Design cleanup: corners, spacing, shadows and report sizes onto the scales (Oct 13, 2026)

**Jordan, Oct 13, 2026.** D2 shipped the Broadcast · Big Shoulders rebrand to production (v232, v233). A recount of production `main` (`67357ff`) against the audit's targets shows the color, font and type-size work is done. Four leftovers remain from D1 and D2's scope:

| What | Target (D1 / D2) | Production today |
|---|---|---|
| **Corner radii** | five tokens: cell 4, segment 9, control 12, dock 18, pill 999 (+ circle 50%) | **56 rules on 10 other values**, almost all in `bullpen-tracker.html` |
| **Spacing** | the 4px scale, `--s-2` … `--s-64` (defined in `css/tokens.css`) | **tokens unused**: 715 padding/margin/gap values, 52% on the scale; 342 off it (6px ×100, 10px ×70, 14px ×46, 5px ×21, 18px ×19 …) |
| **Shadows** | segment, pop, modal + the two rings | **~30 distinct values** (several added by U13's press and drag states) |
| **Report font sizes** | D1's nine steps | **12 rules** in `send-session-report` at 15, 13, 11.5 and 11px (new reports only) |

D3 finishes those. **No color, font or behavior change.** Visible changes are small: corners and gaps move a few pixels. Four stages, each its own PR, staging first. Only Joel ships to production.

**References:** `docs/design/target/DESIGN.md` (radius, spacing and shadow sections), `css/tokens.css` as shipped, D1 (`plans/d1-design-standardization.md`, "The target look"), U13 (buttons, unchanged).

## The 6px step: Option 2 (Jordan, Oct 13; Joel may override at the preconditions review)

6px is the most-used off-scale value (100 uses): the compact gap between chips, tray items and small rows, much of it on the phone charting screen, where space is measured.

| | Option 1: strict ten steps | **Option 2: add `--s-6` (chosen)** |
|---|---|---|
| Scale | 2 · 4 · 8 · 12 · 16 · 20 · 24 · 32 · 48 · 64 | 2 · 4 · **6** · 8 · 12 · 16 · 20 · 24 · 32 · 48 · 64 |
| 6px uses | move to 4 or 8 (tighter or looser everywhere) | stay as they are, now as a token |
| Risk | the phone pen screen shifts; re-measure that the grid and velocity strip still fit under 700px | none from this value |

**Jordan chose Option 2 on Oct 13:** the eleven-step scale with `--s-6`. Option 1 is kept here only in case Joel overrides it. The rest of the mapping is the same under either option: nearest step; a tie rounds **down**, so phone screens never grow.

| Off-scale | → | Uses |
|---|---|---|
| 1, 3 | 2 or 4 (nearest) | 29 |
| 5 | 4 | 21 |
| 7 | 8 | 14 |
| 9 | 8 | 9 |
| 10 | 8 (tie down) | 70 |
| 11, 13 | 12 | 3 |
| 14 | 12 (tie down) | 46 |
| 18 | 16 (tie down) | 19 |
| 22 | 20 (tie down) | 8 |
| 26, 28 | 24 | 8 |
| 30, 36 | 32 | 4 |
| 40 | 32 (tie down) | 4 |

**Exempt (geometry, not spacing):**
- The charting grid's math: `.zone-grid` 3px padding and gaps, and everything computed from them (`--chip`, `--g5c`, `--zg`, the `.g5-*` / `.gg-*` overlays and their 1px margins, `.home-plate*`, `.kb-batter*`, `--kb-pill-*`).
- The velocity strip's cell math.
- Values inside `calc()` or with `env(safe-area-inset-*)`.
- The coach dock's bottom offsets (84, 96).
- `.zone-wrap`'s 115px gutters.
- Any value a code comment says was measured.

Exempt values stay literal, with a one-line comment `/* geometry: <why> */`.

## Stages

### Stage A — corners
Every `border-radius` reads a radius token. Mapping by role:

| Today | Rules | Becomes | Why |
|---|---|---|---|
| 8px | `.invite-link-panel`, `.change-email-form`, `.invite-form`, `.attest-stop`, `.game-panel-header`, `.velo-strip`, `.g5-velo-row .velo-strip-wrap`, `.roster-name-btn:focus-visible` | `--radius-control` (12) | containers, inputs, focus outlines of 12px elements |
| 8px | `.scorebook-btn`, `.position-swipe-chip` | `--radius-control` (12) | buttons (U13) |
| 8px | `.note-item`, `.gg-book-back`, `.gg-book-fix`, `.gg-noread`, `.gg-velo .velo-strip-box::after` | `--radius-segment` (9) | small items nested inside a 12px container |
| 8px | `.gg-book-play` | `--radius-pill` | a label pill |
| 10px | `.sess-head`, `.contacts-panel`, `.notes-block`, `.info-note`, `.info-tip`, `.game-velo`, `.velo-slim`, privacy/terms `.note` | `--radius-control` (12) | containers |
| 10px | `.velo-slim .velo-cell` | `--radius-segment` (9) | nested |
| 10px | `.zone-caption` (the v224 prompt pill), `.position-swipe-badge`, `.gg-seq` | `--radius-pill` | pills and count badges |
| 6px | `.team-select`, `.invite-btn`, `.lb-exclude-panel` | `--radius-control` (12) | input, button, panel |
| 6px | `.roster-item`, `.lb-row` | `--radius-segment` (9) | list rows |
| 6px | `.zone-grid`, `.g5-face`, `.g5-field`, `.gg-book` | `--radius-cell` (4) | the grid and field family (must stay equal to each other) |
| 5px | `.add-type-inline button` | `--radius-control` (12) | button |
| 5px | `.invite-link-text`, `.pitch-log-row`, `.edit-mini` | `--radius-segment` (9) | nested field, rows, inline edits |
| 20px | `.offline-pill`, `.verify-badge`, `.pitch-chip`, `.coach-logged-tag`, `.deleted-tag`, `.team-chip` | `--radius-pill` | badges |
| 22px | `.pitch-count-badge` (44×44) | `--radius-circle` | it's a circle |
| 16px 16px 0 0 | `.sess-sheet` | `var(--radius-control) var(--radius-control) 0 0` | D1: sheets' top corners 12 |
| 14px | `.game-panel-undo` | `--radius-control`, **or delete if dead** (precondition 1) | button |
| 3px | `.g5-shade` | `--radius-cell` (4) | sits on a cell |
| 2px | `.rel-glow-overlay` | `--radius-cell` (4) | overlays a cell |
| 2px | `.brand-mark` | **delete if dead** (the diamond was removed Oct 8) | |
| 2px | `.plr-dot`; report `.legend-dot`, `.dot` | **stay 2px** as `--radius-mark` (new token, chart marks only) | chart marks are data, not restyled (D1) |
| `50%`, `999px` literals | — | `--radius-circle`, `--radius-pill` | |

**Optional (Joel's call):** `.sess-sheet` and modal top corners at `--radius-dock` (18) to read as an iPhone sheet, instead of 12.

### Stage B — spacing (Option 2: the eleven-step scale with `--s-6`)
- Replace literal padding / margin / gap values with `var(--s-N)` per the mapping table, in:
  - `css/components.css` (44 off-scale)
  - `buttons.css` (4)
  - `bullpen-tracker.html` (252)
  - `report.html` (3)
  - privacy / terms (8)
- Exempt values stay literal with their `/* geometry */` comment.
- Add `--s-6: 6px` to `css/tokens.css` (between `--s-4` and `--s-8`). The 100 uses of 6px become `var(--s-6)`.
- Work page by page. The tracker in four passes: chrome and sidebar, Home and History, the bullpen screen, Live Game. The phone pen and Live Game screens are measured before and after each pass.

### Stage C — shadows
- Every `box-shadow` reads tokens (composites of tokens are fine). Keep the five, and add only what U13's states need:
  - `--shadow-lift`: the dragged dock pill and the lifted segment, today `0 10px 22px rgba(0,0,0,.30)` / `0 6px 16px rgba(0,0,0,.35)`. One value.
  - `--ring-focus`: `0 0 0 3px` in the brand mid at 18% (input focus halo, today `var(--brand-mid-ring)`).
  - `--press`: `inset 0 0 0 999px rgba(0,0,0,.04)` (U13 pressed).
- Fold the near-duplicates:
  - `0 10px 26px …0.28` → `--shadow-pop`
  - `0 2px 6px …0.15` and `0 1px 2px …0.10` → `--shadow-segment`
  - `0 4px 12px …0.25` → `--shadow-pop`
  - the inset accent rings 1/2/3px → `--ring-target` (2px) unless the 3px is a measured "selected" state (keep it as `--ring-target-strong`, then name it).
- **No visible change intended** beyond these near-duplicates.

### Stage D — report font sizes (new reports only)
`send-session-report` templates onto the nine steps. Reports are read on phones and printed, so body text rounds **up** to the app's body size. Everything else rounds to the nearest step:

| Rule | Today | Becomes |
|---|---|---|
| `template.ts` `body` | 15 | 16 |
| `.header-meta`, `.type-grid h3`, `.legend-item`, `.data-table`, `.side-stats`, `.side-lists ul`, `template_game.ts .ab-row` | 13 | 12 |
| `.type-grid-stats`, `.report-footer` | 11.5 | 12 |
| `.brand-mark.small`, `diamond.ts .kb-mix` | 11 | 10 |

- **Frozen reports are untouched;** never run `rerender-reports`.
- Deploy `send-session-report` to staging; production is Joel's.

## The packet (paste for Claude Code)

```
ID:              D3
Title:           Design cleanup — corners, spacing, shadows and report font
                 sizes onto the D1/D2 scales; no color, font or behavior change
Spec:            plans/d3-design-cleanup.md on GitHub (pull first; work only
                 from GitHub). References: docs/design/target/DESIGN.md,
                 css/tokens.css as shipped (v233), D1 "The target look", U13.
                 The spec's mapping tables are binding; where a rule isn't in
                 them, apply the same role logic and list it in the report.
Depends on:      production main at or after 67357ff (v233). Spacing scale =
                 Option 2 (Jordan, Oct 13): eleven steps with --s-6; Joel may
                 override to Option 1 at the preconditions review.
Staging only.    No database change. Only Joel ships to production (pages,
                 send-session-report). One PR per stage; pre-push checks
                 finish before every push.

PRECONDITIONS — REPORT before code:
  1. Dead CSS: which of these classes appear in no markup or JS:
     .brand-mark, .game-panel-undo, and any rule in the Stage A table.
     Dead rules are deleted, not remapped.
  2. Every border-radius not reading a token (file:line, selector, value,
     the spec's mapping, or "not in the table" with your proposed role).
  3. Every padding/margin/gap literal: count by file and value; which are
     geometry (exempt) and why; what each off-scale value maps to under
     Option 2 (the eleven-step scale with --s-6).
  4. The phone pen and Live Game screens at 375 and 390: today's y-position
     of the grid's top edge and the velocity strip's bottom edge.
  5. Every box-shadow (file:line) and the token each becomes.
  6. The 12 report font-size rules (file:line) and their new size.
  Build nothing until Joel has read the report (and confirmed Option 2).

STAGE A — corners:
  - Every border-radius reads --radius-cell / -segment / -control / -dock /
    -pill / -circle, or the new --radius-mark (2px, chart marks only). Map
    per the spec's table; delete dead rules.
  - Acceptance: grep shows no literal border-radius outside tokens.css except
    0; screenshots before/after at 390 / iPad / laptop, both sports, of
    sign-in, Home, bullpen, Live Game, History, Roster, Profile, a modal and
    the phone sheet; .zone-grid, .g5-face, .g5-field and .gg-book still
    share one radius.

STAGE B — spacing:
  - Add --s-6: 6px to tokens.css. Literal padding/margin/gap → var(--s-N)
    on the eleven-step scale (ties round down). Geometry stays literal with a
    /* geometry: why */ comment.
  - Tracker in four passes (chrome + sidebar; Home + History; bullpen;
    Live Game), measuring after each.
  - Acceptance: a census shows only scale values outside the exempt list;
    on 375 and 390 the grid top and velocity-strip bottom are within 4px
    of precondition 4 (or Joel approves the difference); nothing wraps,
    clips or overlaps that didn't before (320 / 375 / iPad portrait and
    landscape / laptop, both sports); Joel approves on his phone.

STAGE C — shadows:
  - Every box-shadow reads tokens: --shadow-segment / -pop / -modal,
    --ring-select / -target, plus --shadow-lift, --ring-focus, --press
    (and --ring-target-strong only if precondition 5 shows a measured 3px
    state). Fold the near-duplicates named in the spec.
  - Acceptance: grep shows no literal box-shadow outside tokens.css;
    U13's press, select, drag and lift states look the same (video of the
    dock drag and a tray tap).

STAGE D — report font sizes:
  - The 12 rules per the spec's table (body 16, 13 → 12, 11.5 → 12,
    11 → 10). New reports only; frozen files untouched; never run
    rerender-reports.
  - Acceptance: a new pen and game report per sport on staging (screen +
    print preview); size census of the templates = the nine steps; an old
    report link renders exactly as before.

OUT OF SCOPE: colors, fonts, the type scale (done in D2); component or
  layout redesign; the charting grid's geometry; the Live Game field art;
  the landing page; the logo; re-rendering any sent report.
VERIFICATION: after each stage Joel walks sign-in, Home, bullpen, Live
  Game, History, Roster, Profile and a new report on phone and iPad, both
  sports.
ROLLBACK: revert the stage's PR and bump CACHE_VERSION; Stage D redeploys
  the previous send-session-report.
SIZE: A S · B M · C S · D S.
ESCALATE IF: a mapping changes a measured layout (the phone grid or
  velocity strip moves more than 4px); a rule doesn't fit any role in the
  tables; a shadow can't fold without a visible change to a U13 state;
  anything would touch a sent report.
```

### Standing constraints (in force)

GitHub is the source of truth. Staging first; pre-push checks finish before any push. Frozen reports are never touched. **Only Joel ships to production.**

### Jordan's side (not part of D3)

After D3 ships, Jordan's Claude re-syncs `docs/design/target/` to the shipped `css/tokens.css`: D2's additions (`--bb-*`, `--sb-*`, `--kr-*`, the darkened softball slots 6–8) and D3's new tokens. It then regenerates `design-tokens.json` for the Figma library.
