# D1 — Design standardization: one token file, one type scale, one set of components (Oct 13, 2026)

**Joel, Oct 13, 2026.** Standardize the whole app on the design references: the **Knuckleball Type Sheet** (Oct 9, counted from `main` v194), the **Knuckleball Button Directions** (style 5, Segmented; packet U13) and Jordan's design audit (`DESIGN.md`, `AUDIT.md`, `css-variables.css`, `design-tokens.json`, from `main` @ `cf346b0`). Three stages, each its own PR, each shippable alone. Stage 1 changes nothing visible.

**Colors do not change** (Joel, Oct 9). Baseball keeps green and gold; softball keeps its current theme. D1 renames and consolidates color variables; it never changes what a user sees.

## What exists today (from the references)

- **Fonts:** four self-hosted app faces under `vendor/fonts/` — Black Ops One (wordmark only, Joel's pick Oct 8), Teko (headings, big numbers), IBM Plex Sans (default), IBM Plex Mono (aligned numbers) — plus Georgia in the emailed reports (system font, so frozen reports render forever). Jordan counted 6 families; the two extras are presumably fallbacks or leftovers. Precondition 1 settles it.
- **Sizes:** 30 font sizes in `bullpen-tracker.html` (7 are half-pixel steps), 12 in the report templates. Proposed scale: **8 steps** — 44 / 32 / 24 / 20 / 16 / 14 / 12 / 10 px.
- **Colors:** 104 distinct values; variables named after colors, not jobs (softball's pink lives in `--amber`). Target ~24 job-named tokens per theme.
- **Radii:** 18 values → 5. **Spacing:** 35 values → 10. **Buttons:** 46–58 styles → eight roles (U13).
- **Structure:** no shared stylesheet; each page carries its own CSS; the 11 sign-in pages have drifted; two Live Game buttons read a variable that doesn't exist; four separate Next Pitch buttons.

## The standard

### Tokens (Stage 1) — `css/tokens.css`, one file, loaded by every page

| Group | Tokens | Rule |
|---|---|---|
| Color, by job | `--bg`, `--surface`, `--surface-raised`, `--line`, `--ink`, `--ink-dim`, `--ink-faint`, `--brand-bg`, `--brand-fg`, `--accent`, `--accent-ink`, `--accent-soft`, `--danger`, `--danger-soft`, `--success`, `--warning`, `--focus`, plus the pitch-type palette (`--pt-fb` … one per type, same order as `TYPE_PALETTE_HEX`) and the field palette (`--field-grass`, `--field-grass-infield`, `--field-dirt`, `--field-line`, `--field-fence`) | ~24 per theme. **Names say the job, never the color.** Softball redefines the same names under `[data-sport="softball"]`; today's `--amber` holding pink goes away. Dark mode, if any page has it, redefines under the same pattern. |
| Type faces | `--f-mark` (Black Ops One), `--f-display` (Teko), `--f-body` (IBM Plex Sans), `--f-mono` (IBM Plex Mono); reports keep Georgia in their own templates | Every `font-family` in the app resolves to one of these four. No other family anywhere. |
| Type scale | `--t-44`, `--t-32`, `--t-24`, `--t-20`, `--t-16`, `--t-14`, `--t-12`, `--t-10` with paired line-heights (1 / 1 / 1 / 1.2 / 1.3 / 1.4 / 1.4 / 1.4) | The Type Sheet's ladder. 16px on inputs so iPhone doesn't zoom. |
| Radius | `--r-4`, `--r-8`, `--r-12`, `--r-16`, `--r-full` | Five values. Trays and buttons use `--r-12`; segments `--r-8`(9px rounded to 8); chips/pills `--r-full`. |
| Spacing | `--s-2`, `--s-4`, `--s-6`, `--s-8`, `--s-12`, `--s-16`, `--s-20`, `--s-24`, `--s-32`, `--s-48` | Ten values; gap and padding only from these. |
| Shadow | `--sh-1` (segment lift), `--sh-2` (raised card), `--sh-3` (sheet/modal) | Three. |
| Motion | `--m-fast` 150ms, `--m-spring` 300ms `cubic-bezier(.34,1.56,.64,1)` | Reduced motion zeroes both. |

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
                 Jordan's DESIGN.md / AUDIT.md / css-variables.css /
                 design-tokens.json (in the repo under docs/design/). Where they
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
  - css/tokens.css per spec: job-named colors with [data-sport="softball"]
    overrides (values = today's exact colors, both sports), four face tokens,
    eight size tokens, five radii, ten spacings, three shadows, two motion
    tokens; prefers-reduced-motion zeroes motion.
  - Every page and report.html loads it; sw.js precaches it; CACHE_VERSION.
  - Replace every reference to a color-named variable with the job-named one
    (--amber → --accent etc.); delete the old names. Fix the two dangling
    variables.
  - Acceptance: pixel-diff screenshots of every page, both sports, 390/iPad/
    laptop, before vs after: identical except the two fixed buttons. Zero
    color-named variables remain (grep). Offline load passes.

STAGE 2 — type scale:
  - Every font-size in the app → nearest step below from the eight tokens;
    grid/field cells per precondition 5 (exception token only if needed).
  - Faces per spec (Teko/Plex/Mono/Black Ops One rules). Wordmark on privacy and
    terms only after Joel approves.
  - Report templates → the same eight steps; Georgia kept; frozen files
    untouched; CSP hash recomputed only if report.html's inline script changes.
  - Acceptance: a font-size census shows exactly the eight tokens (plus the
    grid exception if granted); no half-pixel sizes; screenshots before/after
    on 390/375/iPad/laptop, both sports, every page; nothing clipped; Joel
    approves the look on his phone.

STAGE 3 — components:
  - Build U13 exactly as written, on the Stage 1 tokens.
  - One Next Pitch component (variants: grid row, velocity strip, diamond box
    17); the other three deleted.
  - css/components.css: card, input, chip, status bar, dock, modal/sheet, tray
    — one class each; per-page CSS removed page by page, sign-in pages first.
  - Acceptance: U13's acceptance in full; per-page <style> blocks reduced to
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
