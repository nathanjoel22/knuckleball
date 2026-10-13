# D2 — The Broadcast · Big Shoulders rebrand: new colors, new fonts, the light sign-in (Oct 13, 2026)

**Joel and Jordan, Oct 13, 2026.** The app takes the **Broadcast · Big Shoulders** direction:
- near-black field green (`#061A12`) with a gold accent (`#FFB81C`);
- Big Shoulders Display for headlines and big numbers, Archivo for everything else;
- Joel's Segmented buttons (U13), unchanged;
- flat cards;
- a scoreboard-style status bar;
- slanted section tags;
- sign-in pages in the light look under a dark angled header.

Softball keeps every rule with navy (`#0B2540`) and rally pink (`#FF4F9A`).

**Decisions (Jordan, Oct 13):**
1. **Reports:** newly generated reports get the new branding. Reports already sent keep theirs.
2. **Softball palette:** changes too (there are no softball users yet).
3. **Gold:** `#FFB81C` replaces amber `#E8A83D` app-wide.

**Out of this packet:** the landing page. Its video and content aren't settled; it gets its own packet later.

**References (add to GitHub under `docs/design/target/`):**
- `DESIGN.md`: the target style reference.
- `css-variables.css`: loadable, the proposed `css/tokens.css` values.
- `design-tokens.json`: W3C format, for Figma.
- `tailwind-v4.css`: reference only, never loaded.

The visual source is Jordan's "Knuckleball Directions" page: the Broadcast · Big Shoulders direction, its Site and Brand guide views.

## How D2 relates to D1

D1 (`plans/d1-design-standardization.md`) was written when colors were to stay the same. D2 keeps D1's structure and replaces its look:

| D1 | With D2 |
|---|---|
| **Stage 1:** tokens, invisible, the rename map | **Unchanged, and it comes first.** D2 uses D1's token names everywhere. |
| "Colors do not change" (Joel, Oct 9) | **Superseded** by the Oct 13 decision. |
| **Stage 2:** the nine-step type scale with Teko / Plex / Mono; Georgia kept in reports | The **nine sizes stay**. The **faces change** to Big Shoulders Display + Archivo. New reports drop Georgia. Built as **D2 Stage B** (one type pass, not two). |
| **Stage 3:** components (U13 + the rest), sign-in pages to the light look (option b) | **Built as D2 Stage C** with the D2 look below. U13's shapes and behavior don't change. |
| Reports keep Georgia; the frozen-file rule | New reports get the new look (**D2 Stage D**). The frozen-file rule stands: nothing already sent is touched or re-rendered. |

**Order:**
1. D1 Stage 1 (as written)
2. D2 Stage A (colors)
3. D2 Stage B (fonts and type)
4. D2 Stage C (components and pages)
5. D2 Stage D (new reports)

Each stage is its own PR and goes to staging alone. Stage D's edge-function deploy to production is Joel's.

## The target, in one table

| | Baseball | Softball |
|---|---|---|
| Page / card / soft fill | `#F3F5F2` / `#FFFFFF` / `#E8EDE9` | `#F4F7FB` / `#FFFFFF` / `#E6F1FA` |
| Ink / dim / faint | `#07140F` / `#26342D` / `#56645C` | `#0B2540` / `#2C4560` / `#5A6E84` |
| Brand (strip, status bars, sign-in header) | `#061A12`, deep `#030D09` | `#0B2540`, deep `#06172A` |
| Accent (fill only) / accent text | `#FFB81C` / `#8A5A00` | `#FF4F9A` / `#B0175A` |
| Text on accent | ink `#07140F` | navy `#0B2540` (white on pink fails, 3.1:1) |
| Danger / warning / success | `#C42B21` / `#9A5B00` / `#1E7F4A` | same |
| Strike / ball flash | `#188A4E` / `#E0443A`, white letter | same |
| Focus | 2px `#16593D` | 2px `#1F5C99` |
| Pitch slots 1–8 | `#FFB81C #22B573 #FF6B35 #E63946 #3D8BFF #B15CFF #F2E14C #00B8C4` | `#FF4F9A #2F9BFF #7A3FB8 #FF9F1C #00A99D #8E6CFF #D2553F #7D8794` |
| Display face | Big Shoulders Display 700/800/900, uppercase headings | same |
| Text face | Archivo 400/600/700/800; tabular figures for aligned digits | same |
| Radii | D1's five: cell 4, segment 9, control 12, dock 18, pill 999 (+ 50%) | same |
| Shadows | segment, pop, modal; cards flat | same |

Every value, with its contrast ratio, is in `docs/design/target/css-variables.css`.

## Stages

### Stage A — colors (visible: colors only)
- Put the reference file's values into D1's `css/tokens.css`, both sports.
  - D1's names win where they differ from the reference file. List every mismatch in the report.
  - The `@font-face` rules at the bottom of the reference file belong to Stage B, in `vendor/fonts/fonts.css`. They are not part of Stage A.
- Pitch palettes, in the same commit:
  - `SPORTS.baseball.palette` and `SPORTS.softball.palette` in `bullpen-tracker.html`;
  - `SPORT_PALETTE_HEX` / `TYPE_PALETTE_HEX` in `send-session-report/helpers.ts`, same order.
  - D1's palette check must pass.
  - `readableTextOn()` keeps choosing the label color; check slot 7 (`#F2E14C`) and slot 1 on white.
- `buttons.css` already reads tokens. Confirm:
  - `--btn-accent` = `--ink` (Joel's decision E);
  - `--btn-soft` = `--surface`;
  - `--btn-on-primary` = `--on-accent` (navy in softball).
- Remaining literals become tokens: any `#C9A227`, `#111`, `#E8A83D`, `#F5C365`, `#0F241B`, `#F1ECDD` left in rules after D1 Stage 1. `--accent-game` = `--accent` (one gold).
- **Not changed:** the Live Game field art (`.gg-field --gg-*`, the mower stripes) and Joel's Home tile drawings (they keep tinting from tokens).

### Stage B — fonts and the type scale (this is D1 Stage 2 with the new faces)
- **Self-host** four files in `vendor/fonts/` (variable fonts, latin + latin-ext). Get them from the Google Fonts CSS with a modern browser user agent:
  `https://fonts.googleapis.com/css2?family=Archivo:wdth,wght@62..125,100..900&family=Big+Shoulders+Display:wght@100..900&display=swap`
  Save as `Archivo-var-latin.woff2`, `Archivo-var-latin-ext.woff2`, `BigShouldersDisplay-var-latin.woff2`, `BigShouldersDisplay-var-latin-ext.woff2`.
- **Licenses:** add `OFL-archivo.txt` and `OFL-bigshoulders.txt` from:
  - `https://raw.githubusercontent.com/google/fonts/main/ofl/archivo/OFL.txt`
  - `https://raw.githubusercontent.com/google/fonts/main/ofl/bigshouldersdisplay/OFL.txt`
- **`@font-face` rules** go into `vendor/fonts/fonts.css`, copied from the reference file. Archivo declares `font-stretch: 62% 125%`.
- **Precache** the four files in `sw.js`; bump CACHE_VERSION.
- **Face mapping:**

| Today | Becomes |
|---|---|
| Teko 600 (headings, names) | Big Shoulders 800, uppercase |
| Teko 400/500 (stat numbers, ranks, uniform numbers, pitch counter) | Big Shoulders 700, `tabular-nums` |
| Teko 700 (strike/ball flash letter) | Big Shoulders 800 |
| IBM Plex Sans (everything) | Archivo, same weights; 800 is now real, not synthesized |
| IBM Plex Mono (velocity, zone numbers, pitch log, leaderboard values, scorebook codes, invite link) | Archivo 700 with `.tnum` |
| Black Ops One (wordmark) | unchanged |

- **Sizes:** D1's nine steps (64 / 44 / 32 / 24 / 20 / 16 / 14 / 12 / 10). 64 is the index page only.
  - Uppercase labels are Archivo 700, 10px, 0.1em, width 90%.
  - Small titles are Archivo 800, width 85%, uppercase.
- **Remove the old faces** only when a grep shows no rule names them: Teko, IBM Plex Sans, IBM Plex Mono and their `@font-face` and precache entries. Net offline download drops from about 430 KB to about 240 KB.
- **Width check.** Archivo runs a little wider than Plex Sans. At 320 / 375 / iPad / laptop, check:
  - the four page tabs (U9's measured "Player Profile" swap);
  - the phone status bar (one line);
  - the pitch tray (3½ types visible);
  - the velocity strip;
  - Live Game field captions;
  - roster names.

### Stage C — components and pages (this is D1 Stage 3 with the D2 look)
- **U13 stays exactly as built;** only tokens feed it.
- **`css/components.css`** per `DESIGN.md` → Components:

| Component | D2 look |
|---|---|
| Card / panel | White, 1px `--border`, 12px radius, 20px padding (16 on phones), no shadow |
| Brand strip | `--brand-bg`, 12px radius, white wordmark, `--on-dark-faint` tagline |
| Scoreboard | The phone session status bar and the bullpen count bar: `--brand-bg-deep`, cells split by 1px `--brand-line`, Big Shoulders numbers over 10px uppercase labels. **Existing content only; no new stats.** |
| Slanted tag | Gold, `skewX(-14deg)`, Archivo 800 12px uppercase. Used for the sign-in role tag, Home section labels, and the report's sport tag only |
| Badges | Pills, Archivo 700, 10–11px, uppercase |
| Banner | Warning tint, 1px `--warning-line`, 12px radius |
| Input | 44px, 12px radius, 1.5px `--border-strong`, focus in `--brand-mid` |
| Strike-zone grid frame | `--brand-bg` (cells, zone numbers and target as today, in tokens) |
| Coach dock | `--dock-bg` |
| Chooser | Becomes a tray (D1's drafting decision) |

- **Sign-in pages (all 11, then `index.html`):**
  - The light look. A full-width `--brand-bg` header whose bottom edge falls 28px across the width (`clip-path`), holding:
    - the wordmark;
    - the tagline;
    - the slanted tag (e.g. "BASEBALL SIGN IN" from `?sport=`);
    - a Big Shoulders 800 44px uppercase title with its last word in `--accent`.
  - The form sits below on `--bg`, with a full-width primary button and links in `--brand-mid`.
  - Remove the glows and the dark card. Remove D1's temporary `html[data-theme="dark"]` scope once the last page is converted.
  - **Keep today's flow:** sport still comes from `?sport=`. The mockup's sport tray on the form belongs to the landing-page packet (when "Which sport?" moves). It is **not** built here.
- **`index.html` ("Which sport?"):** the light page, the 64px Big Shoulders title, and two cards in fixed sport colors:
  - baseball: `#061A12` with gold;
  - softball: `#0B2540` with pink.
- **`privacy.html` / `terms.html`:** tokens, fonts and the wordmark, **only with Joel's approval written in the commit message** (CLAUDE.md rule).
- Delete per-page CSS as each page converts, sign-in pages first (D1).

### Stage D — new session reports
- **`send-session-report`:**
  - `template.ts`, `template_game.ts`, `svg.ts` (chart labels), `connect.ts`, `diamond.ts` (text only; the field art stays): Georgia becomes the Archivo / Big Shoulders stacks with system fallbacks.
  - Colors take the new values: a `--brand-bg` header band with the wordmark and the slanted sport tag, Big Shoulders headings and tile numbers, `--surface-border` rules.
- **Softball:**
  - **Preferred:** give the report CSS its own `:root` variable block plus a softball block, retiring `themedCss`'s hex find-and-replace (D1 called this optional).
  - **If the hex swap stays:** rebuild `SOFTBALL_THEME_SWAP` from the new values and prove no swap target is also a swap source. A chained replace would recolor twice.
- **`report.html`:** load `css/tokens.css` and `vendor/fonts/fonts.css`. The top bar uses `--brand-bg` and Archivo; drop the system-font stack.
  - The CSP covers scripts only, so same-origin CSS and fonts need no CSP change.
  - Recompute the hash only if the inline script changes.
- **Frozen reports stay frozen:**
  - Never run `rerender-reports`.
  - A report sent before D2 must render exactly as before (its own CSS, Georgia).
- **CLAUDE.md update:**
  - "Baseball reports must stay byte-identical" (S1) refers to sport theming. D2 deliberately changes new reports' styling (Oct 13 decision). Reword it.
  - Update Known landmine 4 (palette sync) with the new values.

## The packet (paste for Claude Code)

```
ID:              D2
Title:           Broadcast · Big Shoulders rebrand — new colors, Big Shoulders
                 Display + Archivo, flat components, light sign-in under a dark
                 angled header, new session reports; four stages, four PRs
Spec:            plans/d2-broadcast-rebrand.md on GitHub (pull first; work only
                 from GitHub). References: docs/design/target/DESIGN.md,
                 css-variables.css (values + contrast), design-tokens.json;
                 tailwind-v4.css is reference only, never loaded. D1
                 (plans/d1-design-standardization.md) and U13 still bind except
                 where this spec says "superseded". Where they disagree on
                 color, fonts or the report look, this spec wins; on token
                 names, D1 wins; on buttons, U13 wins.
Depends on:      D1 Stage 1 merged (tokens.css with D1's names). Joel's open
                 staging work merged first (D1 decision 3).
Staging only.    No database change. Only Joel ships to production (pages,
                 send-session-report deploy). One PR per stage; pre-push checks
                 finish before every push.

PRECONDITIONS — REPORT before code:
  1. The token names D1 Stage 1 shipped vs the reference file: every name in
     one but not the other, and how you'll map it.
  2. Every remaining hard-coded color in rules (file:line), after D1 Stage 1.
  3. Every element using Teko, Plex Sans, Plex Mono, Georgia or the system
     stack (count by file), and which D2 face each gets per the mapping table.
  4. Text that is tight today at 320/375 (tabs, status bar, pitch tray, velo
     strip, field captions, roster names): current width vs available.
  5. send-session-report: how themedCss swaps softball today; whether any new
     swap target equals a swap source; which approach you propose.
  6. The palette check D1 added, and where readableTextOn() is used.
  Build nothing until Joel has read the report.

STAGE A — colors:
  - tokens.css gets the reference values, both sports (D1 names). Pitch
    palettes in bullpen-tracker.html and helpers.ts, same commit, same order.
    Remaining literals → tokens; --accent-game = --accent. Field art and the
    Home drawings untouched.
  - Acceptance: grep shows none of the old theme hexes (#0F241B, #E8A83D,
    #F5C365, #C9A227, #234B6E, #F2A7C3, #E27BA2) outside docs/ and field art;
    the palette check passes; screenshots of every screen, both sports, 390 /
    iPad / laptop; the contrast pairs in css-variables.css hold (list them).

STAGE B — fonts and type (D1 Stage 2 with new faces):
  - Self-host the four woff2 files + two OFL texts (URLs in the spec); @font-face
    in vendor/fonts/fonts.css; precache; CACHE_VERSION.
  - Apply the face mapping table; D1's nine sizes; uppercase display
    headings and names; tabular figures where digits align.
  - Remove Teko / Plex Sans / Plex Mono files, @font-face and precache entries
    once a grep shows nothing names them.
  - Acceptance: font census = Big Shoulders Display, Archivo, Black Ops One
    only (plus frozen reports); size census = nine steps; airplane-mode load
    of every page shows the new fonts; nothing wraps or clips at 320/375/iPad/
    laptop (precondition 4's list, screenshots); Joel approves on his phone.

STAGE C — components and pages (D1 Stage 3 with the D2 look):
  - U13 untouched. css/components.css per DESIGN.md: flat cards, brand strip,
    scoreboard (existing content only), slanted tag, badges, banner, input,
    grid frame, dock, chooser tray.
  - 11 sign-in pages then index.html: light page, dark angled header with
    wordmark / tagline / slanted tag / Big Shoulders title (last word gold),
    form below; sport still from ?sport= (no new sport tray); glows and dark
    card removed; D1's dark scope removed at the end.
  - privacy/terms only with Joel's approval in the commit message.
  - Acceptance: D1 Stage 3's acceptance; every sign-in page renders from the
    shared files with no page-specific color, font or button CSS; side-by-side
    screenshots against Jordan's mockup (sign-in, charting phone); offline
    passes; CACHE_VERSION.

STAGE D — new session reports:
  - Templates + svg/connect/diamond text: new fonts and colors, brand header
    with wordmark and sport tag. Softball via a variable block (preferred) or
    a rebuilt, collision-free hex swap. report.html loads tokens.css and
    fonts.css; top bar in brand colors.
  - Frozen reports untouched; never run rerender-reports. CLAUDE.md: reword
    the S1 byte-identical line and landmine 4.
  - Acceptance: on staging, a new pen report and a new game report for each
    sport (screenshots, print preview); an old report link renders exactly as
    before; report pitch colors equal the tracker's.

OUT OF SCOPE: the landing page and hero film; the logo symbol / favicon / app
  icon; team colors (T1); the Live Game field art; Home tile drawings; emails;
  re-rendering any sent report; dark mode; behavior or layout changes beyond
  the components listed.
VERIFICATION: after each stage Joel walks sign-in, Home, bullpen, Live Game,
  History, Roster, Profile and a new report on phone and iPad, both sports.
ROLLBACK: revert the stage's PR and bump CACHE_VERSION; Stage D also
  redeploys the previous send-session-report.
SIZE: A S · B M · C L · D M.
ESCALATE IF: a text pair fails WCAG AA (4.5:1 text, 3:1 large/icons); a font
  can't be served offline; anything wraps or clips that didn't before; D1's
  names can't hold a D2 value without a second meaning; the report softball
  swap can't be made collision-free; any step would touch a sent report.
```

### Standing constraints (in force)

GitHub is the source of truth. Staging first; pre-push checks finish before any push. Self-hosted fonts only; nothing from other hosts (privacy policy). Frozen reports are never touched. Pitch palettes change in the tracker and `helpers.ts` together. **Only Joel ships to production.**
