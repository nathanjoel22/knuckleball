# D1 — Design standardization: one token file, one type scale, one set of components (Oct 13, 2026)

**Joel, Oct 13, 2026.** Standardize the whole app on **one target look: direction #5, "Segmented," from the Knuckleball Button Directions page.** Jordan's `DESIGN.md`, `css-variables.css`, `design-tokens.json` and `tailwind-v4.css` describe **what exists today**; they are the inventory D1 starts from, **not the target**. Wherever today's values (6px buttons, 22px pill chips, amber-filled toggles, outlined ghost buttons, four Next Pitch buttons, the dark sign-in card) differ from style 5, style 5 wins. The references: the **Knuckleball Type Sheet** (Oct 9, counted from `main` v194), the **Knuckleball Button Directions** (style 5, Segmented; packet U13) and Jordan's design audit (`DESIGN.md`, `AUDIT.md`, `css-variables.css`, `design-tokens.json`, from `main` @ `cf346b0`). Three stages, each its own PR, each shippable alone. Stage 1 changes nothing visible.

**Colors do not change** (Joel, Oct 9). Baseball keeps green and gold; softball keeps its current theme. D1 renames and consolidates color variables; it never changes what a user sees.

## The target look (style 5, applied to everything)

| Element | Style 5 rule |
|---|---|
| **Any pick-one group** (tabs, filters, mode choosers, Yes/No, Throws R/L, batter side, time-to-plate, view toggles, the pitch-type strip) | one soft **tray**: `--surface` fill, 12px radius, 3px padding, 44px tall; choices are **segments** (transparent, 9px radius, 38px, weight 600, `--ink`); the selected one is a **white raised segment** with shadow `0 1px 3px rgba(0,0,0,.18)` and an inset 3px underline in `--accent` (pitch strip: the pitch's slot color). Slides 150ms. No filled-pill "selected" state anywhere. |
| **Primary button** (one per region) | `--btn-primary` fill, `--btn-on-primary` text, 12px radius, 44px min, weight 600, 15–16px. Baseball: accent/ink as today. Softball: Rose/white as today. |
| **Secondary** | `--surface` fill, `--ink` text, 12px radius. Replaces today's outlined `.btn-ghost` (73 buttons): **no outlined buttons remain.** |
| **Tertiary** | transparent, `--ink` text, same hit area. |
| **Icon buttons** (steppers, strip arrows, menu, close) | 44×44, 12px radius, `--surface` fill. |
| **Danger** | `--surface` fill, `--danger` text; one class. |
| **Chooser** (Bullpen / Live Game) | a two-segment tray at the chooser's size (72px tall segments), not two green blocks. *(Drafting decision; say if the big green buttons should stay.)* |
| **Cards / panels** | white, 1px `--border`, **12px radius** (today 10), card shadow. Inputs 12px radius (today 5–6), 44px tall, 16px text. |
| **Chips that are not choices** (badges: COACH, offline, pending, team) | stay pills (`--radius-pill`), unchanged. |
| **Bottom menu tray** (coach dock) | the one draggable tray (U13 §"bottom menu tray"); keeps its dark translucent look. |
| **Sign-in pages** | same components on the dark scope: trays `rgba(255,255,255,.10)`, segments 80% `--on-dark`, selected segment white with `--ink`; primary button as above. Dark page kept (open question below). |
| **Not restyled** | grid cells, diamond boxes, scorebook cells, chart marks, field art. |

Radii collapse to **5**: `--radius-cell` 4 (grid, field, scorebook), `--radius-segment` 9, `--radius-control` 12 (buttons, trays, inputs, cards, menus, sheets' top corners), `--radius-dock` 18, `--radius-pill` 999 (+ `50%` circles). Shadows collapse to **3** plus the two selection rings. Spacing to the ten in the table below.

## What exists today (from the references)

- **Fonts:** four self-hosted app faces under `vendor/fonts/` — Black Ops One (wordmark only, Joel's pick Oct 8), Teko (headings, big numbers), IBM Plex Sans (default), IBM Plex Mono (aligned numbers) — plus Georgia in the emailed reports (system font, so frozen reports render forever). Jordan counted 6 families; the two extras are presumably fallbacks or leftovers. Precondition 1 settles it.
- **Sizes:** 30 font sizes in `bullpen-tracker.html` (7 are half-pixel steps), 12 in the report templates. Proposed scale: **8 steps** — 44 / 32 / 24 / 20 / 16 / 14 / 12 / 10 px.
- **Colors:** 104 distinct values; variables named after colors, not jobs (softball's pink lives in `--amber`). Target ~24 job-named tokens per theme.
- **Radii:** 18 values → 5. **Spacing:** 35 values → 10. **Buttons:** 46–58 styles → eight roles (U13).
- **Structure:** no shared stylesheet; each page carries its own CSS; the 11 sign-in pages have drifted; two Live Game buttons read a variable that doesn't exist; four separate Next Pitch buttons.

## Reconciled with Jordan's DESIGN.md (Oct 13)

Joel pasted `DESIGN.md` (audited from `main` @ `cf346b0`, Oct 9). It settles several preconditions and changes a few lines above:

- **Six families, resolved:** the four app faces, Georgia (frozen reports) and the system-UI stack on `report.html`'s top bar and loading state. Nothing dead. Precondition 1 becomes a confirmation. Also: Plex Sans **800** and Plex Mono **700** are used but not self-hosted (the browser fakes them) — Stage 2 drops both to 700/600.
- **The scale needs a ninth step.** Jordan counts 34 sizes (the Type Sheet's 30 are `bullpen-tracker.html` only) including **64px** on the landing page's "Which sport?" and six `calc()` sizes on the Live Game field. Scale is now **64 / 44 / 32 / 24 / 20 / 16 / 14 / 12 / 10**; `--t-64` is for the landing display only; the `calc()` sizes on the field are G5's and stay.
- **Current token names → D1 names (Stage 1 rename map).** Values do not change.

| Today (app / auth / legal) | D1 | Note |
|---|---|---|
| `--page-bg` / — / `--bg` | `--bg` | |
| `--card-bg` / `--field-panel` / `--card` | `--card` | `--field-panel-2` → `--card-2` |
| `--surface`, `--surface-border` / — / `--line` | `--surface`, `--surface-border` | |
| `--border`, `--border-strong`, `--border-on-dark` | unchanged; `--border-on-dark` goes away (dark scope redefines `--border`) | |
| `--field-dark` (text) / `--field-dark` (page) / `--ink`, `--band` | `--ink` **and** `--brand-bg` | one value, two jobs today; two tokens so T1 can brand the strip without recoloring text. In the dark scope `--bg` takes the value. |
| `--ink-dim`, `--ink-faint`, `--ink-rgb` | unchanged | |
| `--chalk`, `--chalk-dim`, `--chalk-faint` / `--band-ink` | `--on-dark`, `--on-dark-dim`, `--on-dark-faint` | text on the brand strip and status bars; in the dark scope `--ink` carries the chalk value |
| `--amber`, `--amber-bright`, `--amber-rgb` / `--accent` | `--accent`, `--accent-bright`, `--accent-rgb` | softball already re-points to pink |
| `--accent-text` | `--accent-ink` | softball = `--ink` (never pink text) |
| `--primary-bg`, `--primary-fg`, `--primary-bg-hover` | `--btn-primary`, `--btn-on-primary`, `--btn-primary-hover` | U13's button tokens |
| `--kind-btn`, `-hover`, `-active` | `--chooser`, `--chooser-hover`, `--chooser-active` | |
| `--game-gold`, `.gg-field --gg-gold` | `--accent-game` (one name; `.gg-field` reads it) | Live Game only |
| `--gold` | `--rank-1` (= `--accent`); `--silver` → `--rank-2`, `--bronze` → `--rank-3` | |
| `--red`, `--red-bg`, `--ball` | `--danger`, `--danger-bg`, `--ball` | U13's danger class reads `--danger-*`; the 12 inline `style="background:var(--red-bg)…"` go in Stage 3 |
| `--clay`, `--clay-dim`, `--warn-tint` | `--warning`, `--warning-line`, `--warning-tint` | auth's `#C17A45` lives in the dark scope |
| `--success`, `--strike` (literals today) | adopted as named | |
| `--glow-a`, `--glow-b` (auth) | unchanged, dark scope only | |
| `--font-*`, `--text-NN`, `--radius-*`, `--shadow-*`, `--focus-ring`, layout, `--dock-*`, `--scrim*`, `--pitch-N`, `.gg-field --gg-*` | unchanged (Jordan's names) | `--pitch-N` must equal `SPORTS[sport].palette` and `helpers.ts`; Stage 1 adds a check |
| Scoped layout math (`--kb-*`, `--velo-visible`, `--chip`, `--g5c`, `--zg`, `--kbh`, `--kbo`, `--flash-*`) | untouched | component geometry, not design tokens |
| Session report `template.ts` (no variables; softball by hex find-and-replace in `themedCss`) | untouched in Stage 1 | Stage 2 changes sizes only; giving the template a variable block is optional and its own small PR |

- **Stage 1 stays invisible, so Stage 1 does not consolidate radii, spacing or shadows.** It names what exists. Stage 3 collapses radii, spacing and shadows to the style-5 set in "The target look" above. The 6px `.btn` and 22px chip radii becoming 12px/9px, outlined ghost buttons becoming soft-filled secondaries, and amber-filled toggles becoming raised white segments are Stage 3 visible changes, part of U13.
- **`ui` 12px is the most-used size (94 rules) and is today's button size.** U13 raises standalone buttons to 15–16px with 44px height. That is a visible change, already in U13's acceptance; noted here so the Stage 2 screenshots aren't flagged as drift.
- **The coach dock already has a sliding pill** under the active item. U13's draggable bottom tray builds on that element rather than replacing it.
- **Focus ring:** Jordan records `2px solid var(--amber-bright)` (3px on sign-in). D1 keeps 2px via `--focus`; U13's 3px applies to trays only.

- **`design-tokens.json` and `tailwind-v4.css` (seen Oct 13):** consistent with the rename map; nothing new to reconcile. Two notes. (1) Jordan's duration tokens (`fast` 150ms, `base` 220ms, `slow` 250ms, `flip-half` 325ms, `flash` 1400ms) are adopted as `--duration-*`; D1 adds only `--ease-spring` for U13's bottom tray and keeps his `--ease-dock`. (2) The Tailwind file is a reference export for design tools only. **It is not loaded and no build step is added** (CLAUDE.md forbids one without Joel's approval). The DTCG JSON is what Figma imports; keep it in sync with `tokens.css` by hand at the end of each stage.

**Open question for Joel (not decided here):** the 11 sign-in pages run the **older dark theme** (field-green page, chalk text). Jordan's top finding is that new users see a different product before they reach the light app. Options: (a) keep them dark and only standardize their tokens and components, or (b) move them to the light app theme in Stage 3. D1 assumes **(a)** because "colors stay as they are" — say so if you want (b).

## The standard

### Tokens (Stage 1) — `css/tokens.css`, one file, loaded by every page

**Start from Jordan's `css-variables.css` and keep his names** wherever they already say the job (`--surface`, `--ink-dim`, `--ink-faint`, `--border`, `--border-strong`, `--success`, `--strike`, `--ball`, `--scrim`, `--warn-tint`, `--dock-*`, `--font-display/-sans/-mono/-wordmark/-report/-system`, `--text-NN`, `--radius-*`, `--shadow-*`, `--focus-ring`, `--tap-min`, `--app-max`, `--sidebar-w`, `--bp-*`, `--pitch-1…8`, the `.gg-field` set). Rename only the ones named after a color or a place, per the map below. The result is **one naming scheme** instead of today's three (app, auth, legal).

Three rules that make the file loadable (Jordan's is a reference, not loadable, because the app and the auth pages reuse names with different meanings):

1. **A name always means the same job.** `--bg` is always the page background, `--ink` always the main text color. The auth pages' dark look is expressed as a scope, `html[data-theme="dark"]` (set on the 11 sign-in pages), that redefines `--bg: #0F241B; --card: #183527; --card-2: #1F4230; --ink: #F1ECDD; --ink-dim: #B7C2B4; --ink-faint: #7C8C82; --border: rgba(241,236,221,.12); --border-strong: rgba(241,236,221,.22); --warning: #C17A45` plus `--glow-a/-b`. Same names, correct meaning, no second vocabulary.
2. **Sport is a scope too:** `html[data-sport="softball"]` redefines the same names with today's softball values (Jordan's block, renamed). Dark + softball = both scopes, as today.
3. **The legal pages' scheme** (`--ink`, `--bg`, `--card`, `--line`, `--accent`, `--band`, `--band-ink`) is already job-named and is the closest to the target; D1 adopts `--bg`, `--card`, `--ink`, `--accent` from it and maps `--line → --surface-border`, `--band → --brand-bg`, `--band-ink → --on-dark`.

Everything else in Jordan's file comes across as is. The `--text-NN` inventory (27 names) and `--radius-*` (13) and `--shadow-*` (7) are **Stage 1 inventories**, not the target; Stage 2 collapses `--text-*` to nine and Stage 3 collapses radius/shadow.

Stage 1 **maps every existing value to the nearest token without moving a pixel on purpose**: a size of 13.5px becomes `--t-14` only in Stage 2; in Stage 1 the token file is loaded and the per-page CSS still wins, so nothing changes. The deliverable is the file, the sport switch, and the removal of the two dangling-variable bugs.

### Type (Stage 2)

- Every `font-size` in `bullpen-tracker.html` and the other 14 pages moves to the nearest step **below** (Type Sheet rule). The 8–9.5px uses inside the 5×5 grid and the field boxes are checked one by one first; if 10px doesn't fit, those cells keep a documented exception token `--t-grid` and nothing else may use it.
- Teko only on headings, names, big numbers, flash letters and uniform numbers; Plex Sans everywhere else; Mono only where digits align (zone numbers, velocity, leaderboard values, scorebook codes); Black Ops One only on the wordmark. Wordmark goes on privacy and terms too (Joel to approve — it's on the sheet as pending).
- Reports: the 12 report sizes collapse to the same 8 steps in `template.ts` / `template_game.ts`; Georgia stays; frozen reports untouched.

### Components (Stage 3) — U13 is Stage 3

Buttons are built exactly per `plans/u13-segmented-buttons.md` on top of the Stage 1 tokens: eight roles, one danger class, 44px minimum, segmented trays, the bottom menu tray draggable and nothing else. The four Next Pitch buttons become one component with placement variants. Jordan's remaining component list (cards, inputs, chips, status bar, dock) gets the same treatment: one class per component in `css/components.css`, per-page CSS deleted as each page is converted.

### Pages

All 15 pages plus `report.html` load `css/tokens.css` and `css/components.css`. The 11 sign-in/sign-up pages are converted first in Stage 3 because they drifted most and new users see them first. Service worker caches both files; CACHE_VERSION bumps per stage.

## Decisions made in drafting (Joel may override)

1. **Three PRs, not one.** Stage 1 (tokens, invisible) → Stage 2 (type scale, visible but small) → Stage 3 (components = U13 + the rest). Each has before/after screenshots and ships to staging alone.
2. **Jordan's Phase 0 questions are answered here:** colors stay; the type scale is the Type Sheet's eight steps; tokens are job-named with a sport switch; Jordan's `css-variables.css` is the starting draft for Stage 1, renamed to the job names above where it differs.
3. **Branch order:** Joel's open staging work merges to `main` first, then Stage 1 branches from `main`. Jordan and Claude Code do not run Stage 1 against a `main` that staging is about to overwrite.
4. **Reports** get the token names but keep Georgia and their frozen-file rule; `report.html`'s CSP hash is recomputed only if its inline script changes.

---

## The packet (paste for Claude Code)

```
ID:              D1
Title:           Design standardization — one token file, one type scale, one
                 component set; three stages, three PRs; no color changes
Spec:            plans/d1-design-standardization.md on GitHub (pull first; work
                 only from GitHub). References: docs/type-sheet-reference.html
                 (Type Sheet), docs/button-directions-reference.html (style 5),
                 Jordan's DESIGN.md, css-variables.css, design-tokens.json and
                 tailwind-v4.css under docs/design/ (Joel is adding them);
                 AUDIT.md follows. tailwind-v4.css is reference only — never
                 loaded, no build step. The rename map in the spec ("Reconciled
                 with DESIGN.md") is binding for Stage 1. Where they
                 disagree, this spec wins; where this spec is silent, the Type
                 Sheet wins on type and U13 wins on buttons.
Depends on:      Joel's open staging work merged to main (ask before branching).
                 U13 (plans/u13-segmented-buttons.md) is Stage 3 of this packet.
Staging only.    No database change. Only Joel ships to production. One PR per
                 stage; pre-push checks complete before every push.

PRECONDITIONS — REPORT, with file and line numbers, before any code:
  1. Font families actually loaded or named anywhere (all 15 pages, report.html,
     both report templates, sw.js precache): the four app faces, Georgia, and
     whatever makes Jordan's count six. Which are dead.
  2. Every CSS custom property defined today, per page, with its value in each
     sport; which are named after colors; where softball re-points them.
  3. The two Live Game buttons reading a nonexistent variable (file:line), and
     the four Next Pitch buttons (file:line, which screen each serves).
  4. Every font-size, radius, spacing and shadow value with counts (Jordan's
     numbers re-run on the current main after Joel's staging merge).
  5. The 8–9.5px font-size uses: each one, where it sits, whether 10px fits.
  6. How pages load CSS today and what sw.js precaches; cost of adding two
     shared files (offline P1-01 checks).
  7. Which pages have any dark-mode handling.
  Build nothing until Joel has read the report.

STAGE 1 — tokens (no visible change):
  - css/tokens.css = Jordan's css-variables.css made loadable: his names kept,
    the rename map applied, one meaning per name, html[data-theme="dark"]
    scope for the 11 auth pages, html[data-sport="softball"] scope as today;
    values = today's exact colors. Plus --motion-fast/--motion-spring with
    prefers-reduced-motion zeroing them.
  - Every page and report.html loads it; sw.js precaches it; CACHE_VERSION.
  - Apply the spec's rename map exactly (--amber → --accent, --field-dark →
    --ink + --brand-bg, --red-bg → --danger-bg, etc.); delete the old names;
    tokenize the strike/sent literals; add --pt-1…8 with a check that they
    equal SPORTS[sport].palette and helpers.ts. Fix the two dangling
    variables. Radii, spacing and shadows are NOT consolidated in Stage 1.
  - Acceptance: pixel-diff screenshots of every page, both sports, 390/iPad/
    laptop, before vs after: identical except the two fixed buttons. Zero
    color-named variables remain (grep). Offline load passes.

STAGE 2 — type scale:
  - Every font-size in the app → nearest step below from the nine tokens
    (64 only on the landing display); drop synthesized Plex Sans 800 and Plex
    Mono 700 to the self-hosted 700/600;
    grid/field cells per precondition 5 (exception token only if needed).
  - Faces per spec (Teko/Plex/Mono/Black Ops One rules). Wordmark on privacy and
    terms only after Joel approves.
  - Report templates → the same eight steps; Georgia kept; frozen files
    untouched; CSP hash recomputed only if report.html's inline script changes.
  - Acceptance: a font-size census shows exactly the nine tokens (plus the
    grid exception if granted); no half-pixel sizes; screenshots before/after
    on 390/375/iPad/laptop, both sports, every page; nothing clipped; Joel
    approves the look on his phone.

STAGE 3 — components:
  - Build U13 exactly as written, on the Stage 1 tokens.
  - One Next Pitch component (variants: grid row, velocity strip, diamond box
    17); the other three deleted.
  - css/components.css in the style-5 look (spec "The target look"): tray +
    segment, primary/secondary/tertiary/icon/danger buttons, card, input,
    badge, status bar, dock, modal/sheet — one class each; every pick-one
    group in the app becomes a tray; no outlined or filled-pill selected
    states remain; per-page CSS removed page by page, sign-in pages first.
  - Acceptance: U13's acceptance in full; every tab/filter/toggle/chooser in
     the app is a tray (list them, screenshot each); zero .btn-ghost; per-page
     <style> blocks reduced to
    page-only layout (report sizes); the 11 sign-in pages render from the
    shared files with no page-specific color, font or button CSS; before/after
    screenshots; offline passes; CACHE_VERSION.

OUT OF SCOPE: any new color or palette; dark mode (unless precondition 7 shows
  it exists — then keep it working, don't extend it); logo/branding (T1);
  behavior changes; the diamond and grid cell visuals (G5/G1b own them);
  re-rendering frozen reports.
VERIFICATION: Joel walks bullpen, Live Game, History, Roster, Profile, sign-in
  and a report on his phone and iPad after each stage, both sports.
ROLLBACK: revert the stage's PR; bump CACHE_VERSION.
SIZE: Stage 1 M · Stage 2 M · Stage 3 L.
ESCALATE IF: any Stage 1 screenshot differs; a page can't load the shared files
  offline; a size can't be mapped without clipping; a token name in Jordan's
  files can't be reconciled with U13/T1/G5 assumptions; report.html's CSP
  needs more than a recomputed hash.
```

### Standing constraints (in force)

Colors stay as they are (Joel, Oct 9). GitHub is the source of truth. Pre-push checks complete before any push. Strict escaping; CSP hash recomputed if report.html's inline script changes. Frozen reports are never touched. **Only Joel ships to production.**
