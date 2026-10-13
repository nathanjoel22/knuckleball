# D1 preconditions report (Oct 13, 2026)

**Read-only audit for `plans/d1-design-standardization.md` (the v2 text).** No code has changed. Branch `d1-design-standardization`, built on top of `live-game-oct12` (the staging work Joel is reviewing; it becomes `main` when he ships it, so D1 is audited against it, not against today's production `main`).

Jordan audited production `main` @ `cf346b0` (Oct 9). Where today's numbers differ from his, it's because U13, the type scale (v195) and the Oct 10–13 work have landed since.

**References used (all on GitHub, Oct 13):**
- `docs/design/DESIGN.md`, `AUDIT.md`, `css-variables.css`, `design-tokens.json` and `tailwind-v4.css`;
- `docs/type-sheet-reference.html` (`89edb68`);
- `docs/button-directions-reference.html`.

**Joel's decision on the spec's open question:** **(b)**. The 11 sign-in / sign-up pages move to the light app look in Stage 3.

---

## 1. Font families

| Family | Where | Status |
|---|---|---|
| Teko | app (10 rules), landing, sign-in, legal pages | live: headings, big numbers |
| IBM Plex Sans | app (default), every sign-in page, buttons.css (inherit) | live: body |
| IBM Plex Mono | app (8 rules), accept-invite (1) | live: aligned numbers |
| Black Ops One | wordmark on app, landing, sign-in pages | live: wordmark only |
| Georgia | `template.ts` (2), `svg.ts` (4 chart labels) | live: frozen reports |
| `-apple-system, BlinkMacSystemFont, 'Segoe UI'…` | `report.html` (top bar and loading state, 3 places) | live: the report viewer's own chrome |

- **The six families are all in use; none are dead.** This confirms Jordan's count: the four app faces, Georgia and the system-UI stack.
- **`@font-face` (`vendor/fonts/fonts.css`)** declares only the four app faces. Weights: Plex Sans 400/500/600/700, Plex Mono 400/500/600, Teko 400–700.
- **Synthesized weights:** `font-weight:800` appears 24× in the app. Where it lands on Plex Sans / Plex Mono, the browser fakes the bold, which Stage 2 drops to 700 / 600 per the spec. The sign-in pages have none.

## 2. Custom properties (values in each sport)

- **The app** (`bullpen-tracker.html`) defines **56**, 17 of them named after colors:
  - `--amber*` (which holds **pink** in softball), `--field-dark` (both the text color and the brand strip), `--chalk*`, `--clay*`, `--red*`, `--gold/--silver/--bronze`, `--game-gold`, …
  - Softball re-points **37** of them under `html[data-sport="softball"]`.
- **The 10 sign-in pages** (accept-invite, coach-signup, guardian-consent, join, join-coach, login, parent-signup, pitcher-signup, reset-password, verify-email) define the **same 15 variables with identical values** (checked name by name); 13 are color-named; softball re-points 10.
  - `index.html` carries 13 of them (no `--amber-rgb`, no `--red`).
  - So their *colors* haven't drifted; their *components* have (§3, §4).
- **`privacy.html` / `terms.html`:** 9 variables, already mostly job-named (`--bg`, `--card`, `--ink`, `--accent`, `--band`, `--band-ink`). No softball block.
- **`report.html`:** 10 variables, 7 color-named, no softball block. The frozen report itself has no variables (softball by hex swap in `themedCss`).
- **`buttons.css`** (U13, staging): 10 job-named `--btn-*` tokens that point at each page's own variables.

The full table, every variable with its baseball and softball value, is in the appendix. Jordan's rename map in the spec covers every color-named variable listed there; I found **no name the map misses.**

## 3. The two dangling variables, and the four Next Pitch buttons

**Dangling `var(--ink)`:** two rules on production `main`. `--ink` is never defined in the app, so the browser falls back to the inherited text color.
- `bullpen-tracker.html` line 1573 (production `main`): `.g5-act`, the Live Game **+ Out / + Strike / + Ball / ‹ Back** buttons under the field.
- line 1600: `.g5-reset`, the in-chart velocity **Reset**.
- **Both are already fixed on staging:** U13 replaced those rules with the shared button roles.
- **Stage 1 adds a real `--ink`.** Under the rename map it is the main text color, so nothing reads an undefined name again.

**Next Pitch, on staging today:**

| Class | In markup | CSS | Serves |
|---|---|---|---|
| `.g5-nextpitch` | 1 (line ~8844) | yes | in the chart's last row after velocity (radar on) |
| `.g5-act-next` | 1 (`g5FieldActions`) | (U13 → `btn-primary`) | "Next ›" under the field on the runners question (radar on) |
| `.next-pitch-btn` | **0** | 2 rules | dead (pre-G5 panel) |
| `.gg-next` | **0** | 2 rules | dead (G1b-r3 in-grid) |

So two live buttons in two places, and two dead CSS classes. Stage 3 makes one Next Pitch component, used in two places, and deletes the dead CSS. (The spec's third variant, "diamond box", is the radar-off **Next pitch** box 24 on the field, `g5CellInner`; that's a field box, so it stays a charting target.)

## 4. Counts (all 15 pages + `buttons.css`; staging)

**Font sizes: 34 distinct** (Jordan: 34).
- **The app** uses exactly the 8-step scale (10/12/14/16/20/24/32/44), plus:
  - `10px !important` ×3 and `14px !important` ×1;
  - **six `calc(var(--g5c) * …)` sizes** for the field-box captions. They scale with the box, so they're geometry, not type; see §5.
- **The other 14 pages** still carry the old sizes:
  - half-pixels: 11.5 ×21, 12.5 ×10, 13.5 ×2, 15.5 ×2;
  - odd steps: 11, 13, 15, 18, 19, 22, 26, 28, 30, 34, 36, 38, 40, 42;
  - the landing's **64px** "Which sport?".
- **Per page:**
  - sign-in pages: 8–10 sizes each (all 10, 11, 11.5, 12, 12.5, 13, 14, 22, 34/38);
  - index: 11;
  - privacy / terms: 7;
  - report.html: 2.
- **Report templates: 12 distinct** (0.6em, 10.5, 11, 11.5, 12, 12.5, 13, 14, 15, 19, 26, 28) plus `svg.ts` chart labels at `font-size="8"` (SVG user units, scaled with the chart).

**Radii: 16 distinct.**
- `8px` ×31, `6px` ×19, `10px` ×18, `50%` ×15, `14px` ×14, `2px` ×14, `20px` ×8, `9px` ×7, `12px` ×7, `5px` ×5, `999px` ×4;
- singles: `3px`, `4px`, `18px`, `22px`, `16px 16px 0 0`.

**Shadows: 28 distinct.** Top:
- `0 1px 3px rgba(ink,.06)`;
- U13's segment lift `0 1px 3px rgba(0,0,0,.18) + inset -3px` underline;
- assorted `inset 0 0 0 2–3px` rings;
- modal and dock drops.

**Spacing: 35 distinct px values** in padding / margin / gap. Most used: 6 ×99, 8 ×93, 10 ×80, 4 ×71, 14 ×55, 12 ×44, 16 ×39, 20 ×30, 3 ×28, 2 ×25, 24 ×25. The long tail is 1, 5, 7, 9, 11, 13, 18, 22, 26, 28, 30, 34, 36, 38, 40, 44, 48, 60, 80, 84, 96, 115.

## 5. Sizes under 10px

- **None left in the pages.** The app's 8–9.5px uses went to 10px in v195 (Oct 9), and the field captions were checked then and fit at 320px.
- **Field-box captions:** six `calc(var(--g5c) * 0.11–0.30)` sizes. They scale with the box, so they're geometry, like the spec's own "untouched" list (`--g5c`, `--chip`, …). **Recommend:** leave them as calc, don't map them to the scale, and document them. No `--t-grid` exception token is needed for the pages.
- **Reports:**
  - `svg.ts` lines 63, 166, 205, 210: `font-size="8"` zone numbers and axis labels inside SVG charts. These are drawing units that scale with the chart, not CSS px.
  - `template.ts` line 337: `.header-num{font-size:0.6em}`, the uniform number beside the name.
  - **Recommend:** treat both as chart geometry and leave them. Frozen reports are never touched anyway.

## 6. How pages load CSS, and the offline cost

| Page(s) | Loads | Inline `<style>` |
|---|---|---|
| `bullpen-tracker.html` | `fonts.css` (preload, non-blocking), `buttons.css` | 1,705 lines |
| 10 sign-in pages + index | `@import vendor/fonts/fonts.css` inside `<style>` (blocking), `buttons.css` | 68–157 lines each |
| privacy / terms | `@import fonts.css` | 27 lines |
| `report.html` | `buttons.css` | 54 lines |

- **The service worker** precaches all 15 pages, `fonts.css`, `buttons.css` (7.5 KB), Black Ops One, `supabase.js`, the two config files and the 5 Home icons.
- **Adding `css/tokens.css` and `css/components.css`** means two more same-origin files, each a few KB (tokens about 3–5 KB, components replacing most of `buttons.css` plus the per-page component CSS).
  - Both go in the precache list, so the offline cost is one extra cache entry each.
  - Loaded as plain `<link rel="stylesheet">`, like `buttons.css`, which already passes offline.
- **Stage 1** loads `tokens.css` on every page; the P1-01 offline checks re-run then.

## 7. Dark mode

**None anywhere:** no `prefers-color-scheme`, no `data-theme`, no `color-scheme` on any page. The sign-in pages' dark green is a fixed theme, not dark mode. Per (b) it goes away in Stage 3. The spec's `html[data-theme="dark"]` scope is then needed only during Stages 1–2.

---

## Escalations / decisions before code

1. **Stage 3 vs U13.** U13 is already built on staging (v196–v226). Stage 3 restyles on top of it and then removes per-page CSS, rather than rebuilding U13.
2. **Option (b) means Stage 3 changes the sign-in pages' colors** (dark → light). That's a deliberate exception to "colors stay", recorded Oct 13. The spec's Stage 1 dark scope stays only until then.
3. **The ninth step (64px)** exists only on `index.html`'s "Which sport?". The spec keeps it there.
4. **Stage 1 base:** this branch is stacked on `live-game-oct12`. If Joel ships that to production first, D1 rebases onto `main` with no conflicts expected. If not, D1's PRs target `live-game-oct12`'s merge.

---

## Appendix: every variable, baseball and softball (staging)

### The app (bullpen-tracker.html)

| Variable | Baseball | Softball |
|---|---|---|
| `--page-bg` | `#F7FAF8` | `#F7FAFD` |
| `--card-bg` | `#FFFFFF` | `#FFFFFF` |
| `--surface` | `#E8F3EC` | `#EAF4FB` |
| `--surface-border` | `#CFE6D7` | `#BFDCEF` |
| `--field-dark` | `#0F241B` | `#234B6E` |
| `--ink-dim` | `#2E4A40` | `#3A5A78` |
| `--ink-faint` | `#527065` | `#5F7A91` |
| `--chalk` | `#F1ECDD` | same |
| `--chalk-dim` | `#B7C2B4` | `#BCCBD8` |
| `--chalk-faint` | `#7C8C82` | `#8094A6` |
| `--border-on-dark` | `rgba(241,236,221,0.16)` | same |
| `--clay` | `#96551F` | same |
| `--clay-dim` | `#8A5732` | same |
| `--red` | `#C0453B` | same |
| `--red-bg` | `#A83A31` | same |
| `--amber` | `#E8A83D` | `#F2A7C3` |
| `--amber-bright` | `#F5C365` | `#F7C3D7` |
| `--game-chip-border` | `#9DBBA9` | `#9FC3DD` |
| `--game-gold` | `#C9A227` | `#E98DB0` |
| `--game-panel-bg` | `#F7F5EF` | `#F4F8FC` |
| `--gold` | `var(--amber)` | same |
| `--silver` | `#7C8B85` | same |
| `--bronze` | `#A8621F` | same |
| `--border` | `rgba(15,36,27,0.10)` | `rgba(35,75,110,0.10)` |
| `--border-strong` | `rgba(15,36,27,0.22)` | `rgba(35,75,110,0.22)` |
| `--amber-rgb` | `232,168,61` | `242,167,195` |
| `--ink-rgb` | `15,36,27` | `35,75,110` |
| `--primary-bg` | `var(--amber)` | `#E27BA2` |
| `--primary-fg` | `var(--field-dark)` | `#FFFFFF` |
| `--primary-bg-hover` | `var(--amber-bright)` | `#D4688F` |
| `--kind-btn` | `#3D7A57` | `#E27BA2` |
| `--kind-btn-hover` | `#2E6345` | `#D4688F` |
| `--kind-btn-active` | `#245036` | `#C2567D` |
| `--accent-text` | `var(--amber)` | `var(--field-dark)` |

### The 11 sign-in / sign-up pages (login.html shown; the others carry the same block)

| Variable | Baseball | Softball |
|---|---|---|
| `--field-dark` | `#0F241B` | `#234B6E` |
| `--field-panel` | `#183527` | `#2B5A82` |
| `--field-panel-2` | `#1F4230` | `#336896` |
| `--chalk` | `#F1ECDD` | same |
| `--chalk-dim` | `#B7C2B4` | `#C4D3E0` |
| `--chalk-faint` | `#7C8C82` | `#9FB5C9` |
| `--clay` | `#C17A45` | same |
| `--amber` | `#E8A83D` | `#F2A7C3` |
| `--amber-bright` | `#F5C365` | `#F7C3D7` |
| `--red` | `#C0453B` | same |
| `--border` | `rgba(241,236,221,0.12)` | same |
| `--border-strong` | `rgba(241,236,221,0.22)` | same |
| `--glow-a` | `rgba(232,168,61,0.08)` | `rgba(242,167,195,0.10)` |
| `--glow-b` | `rgba(193,122,69,0.08)` | `rgba(127,184,224,0.10)` |
| `--amber-rgb` | `232,168,61` | `242,167,195` |

### privacy.html / terms.html

| Variable | Baseball | Softball |
|---|---|---|

### report.html (the report viewer)

| Variable | Baseball | Softball |
|---|---|---|
| `--page-bg` | `#F7FAF8` | same |
| `--surface-border` | `#CFE6D7` | same |
| `--field-dark` | `#0F241B` | same |
| `--ink-dim` | `#2E4A40` | same |
| `--ink-faint` | `#527065` | same |
| `--chalk` | `#F1ECDD` | same |
| `--chalk-dim` | `#B7C2B4` | same |
| `--amber` | `#E8A83D` | same |
| `--red` | `#C0453B` | same |
| `--border-on-dark` | `rgba(241,236,221,0.16)` | same |

