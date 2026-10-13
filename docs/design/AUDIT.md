# Knuckleball — Design Audit

> Extracted from the "Audit & roadmap" tab of Jordan's Knuckleball Design Reference (main @ cf346b0, 2026-10-09).

## Audit

All 15 pages and the session report, 5,430 CSS declarations, counted by script on 9 Oct 2026. Emails are left out because they carry almost no styling.

| What | In use | Target | Detail |
|---|---|---|---|
| Font families | 6 | 3 | Teko, IBM Plex Sans, IBM Plex Mono, Black Ops One, plus Georgia (session report) and the system font (report page bar). Target: Teko, Plex Sans, Plex Mono, with the wordmark as a logo file. |
| Font sizes | 34 | 9 | 29 fixed and 5 calculated, including five half-pixel sizes (10.5, 11.5, 12.5, 13.5, 15.5). Target: 10 · 12 · 14 · 16 · 20 · 24 · 32 · 44 · 64. |
| Font weights | 5 | 3 | 400, 500, 600, 700, 800. Weight 800 is asked for 21 times but isn't installed, so it renders as 700. Target: 400 · 600 · 700. |
| Line heights | 12 | 3 | 1, 1.05, 1.1, 1.15, 1.2, 1.3, 1.35, 1.4, 1.45, 1.5, 1.55, 1.6. Target: 1 · 1.25 · 1.5. |
| Letter spacings | 15 | 3 | From −0.01em to 0.18em. Target: 0 · 0.02em · 0.1em. |
| Color values | 104 | ~24 | 64 hex and 40 rgba(). 157 colors are hard-coded inside rules (app 97, session report 34, sign-in 25, report page 1). |
| Color variables | 66 | 1 scheme | Three naming schemes: app, policy pages, and none at all in the session report. |
| Themes | 5 | 2 + teams | Light app, dark sign-in, softball light, softball sign-in, and a hard-coded copy inside the report. Target: two sport themes on one structure, ready for team themes. |
| Spacing values | 35 | 10 | 862 declarations; 48% on a 4px grid. Target: 2 · 4 · 8 · 12 · 16 · 20 · 24 · 32 · 48 · 64. |
| Border radii | 18 | 5 | Every whole pixel from 2 to 10 is used. Target: 4 (cells) · 8 (controls) · 12 (cards, menus, modals) · pill · circle. |
| Shadows | 14 | 4 | Seven drop shadows and seven inset rings. Target: sm · md · lg · xl, plus one focus ring. |
| Breakpoints | 6 | 3 | 360, 500, 600, 700, 860, plus two height rules on the landing page. Target: 360 · 500 · 860. |
| Button styles | 58 | 5 | 224 <button> tags in the templates, 58 classes, 7 families, 12 different radii. Target: Button (primary, secondary, ghost, danger, game × sm, md, lg), Chip, Icon button, Tab, Dock item. |

## Where it spreads

Three views of the drift: font sizes by how often they're used, one color with four names, and the border radii with where each one lives.

### Font sizes · rules per size

(Chart in the reference page: rules per font size. Counts are in the Type Sheet and `design-tokens.json`.)

### One green, five spellings

- `--field-dark` · the app and sign-in pages, 125 uses, as both a background and the main text color
- `--ink` and `--band` · privacy and terms
- `--gg-line` · the Live Game field
- `#0F241B` · typed out in the session report and the sport picker

### Same name, different color

- `--amber` is pink (#F2A7C3) in softball.
- `--border` is dark-on-light in the app and light-on-dark on sign-in pages.
- `--clay` is #96551F in the app and #C17A45 on sign-in pages.
- `--chalk-dim` has two softball values: #BCCBD8 (app) and #C4D3E0 (sign-in).

### Border radius · where each value is used

| Radius | Rules | Where |
|---|---|---|
| 2px | 5 | Brand diamond, legend and pitch-log dots |
| 3px | 2 | Strike-zone cells |
| 4px | 2 | Live Game and scorebook cells |
| 5px | 7 | App inputs, inline edit fields, invite link box |
| 6px | 17 | App buttons, sign-in inputs, selects, roster rows, zone grid frame |
| 7px | 1 | Sign-in primary button (×11 pages) |
| 8px | 23 | Banners, info boxes, forms, velocity strip, scorebook chips |
| 9px | 5 | Live Game field buttons and readouts |
| 10px | 21 | Panels, session cards, brand strip, phone chips, Next Pitch |
| 12px | 5 | Account menu, Live Game panel, chooser buttons, dock items |
| 14px | 5 | Sign-in card, sport cards, modal |
| 16px 16px 0 0 | 1 | Phone bottom sheet |
| 18px | 1 | Coach dock |
| 20px | 9 | Role, offline, status, team, verify badges |
| 22px | 2 | Pitch-type chips, throws toggle, pitch-count badge |
| 999px | 5 | Account button and chips, batter pill |
| 50% | 12 | Headshots, avatars, alert dots, close button |
| 0 | 1 | Live Game velocity arrows |

### Buttons · 58 classes in 7 families

| Family | Classes | Members |
|---|---|---|
| Solid action | 9 | `.btn-primary` (app), `.btn-primary` (sign-in: a second definition in 11 files), `.approve-btn`, `.kind-choice-btn`, danger (inline style, 12×), and four Next Pitch buttons: `.next-pitch-btn`, `.g5-act-next`, `.g5-nextpitch`, `.gg-next` |
| Outline | 15 | `.btn-ghost`, `.sign-out-btn`, `.invite-btn`, `.acct-add`, `.invite-link-copy-btn`, inline add-type, `.kb-btn`, `.back-to-chooser-brand`, `.joinas-btn`, `.ph-act`, `.g5-act`, `.g5-reset`, `.game-panel-undo`, `.gg-book-back`/`-fix`, `.gg-noread` |
| Chips and toggles | 12 | `.type-chip`, `.throws-btn`, `.ttp-btn`, `.deliv-one`, `.pstrip-chip`, `.position-swipe-chip`, `.pb-pill`, batter label, `.velo-cell`, `.scorebook-btn`, `.gg-btn`, `.acct-btn` |
| Text links | 7 | `.undo-btn`, `.invite-regen-btn`, `.row-x-btn`, `.roster-item-remove`, `.velo-slim-reset`, `.back-link`, `.lb-val-btn` |
| Icon | 7 | `.modal-close-x`, `.sess-more`, `.sess-back`, `.runner-diamond-btn`, `.velo-arrow`, `.pstrip-arrow`, `.note-del` |
| Navigation | 6 | `.tab-btn`, `.dock-btn`, `.acct-item`, `.roster-item`, `.roster-toggle-btn`, `.persp-rollup` |
| Card as button | 2 | `.option-card` (sport picker), `.kb-batter` (batter silhouette) |

The three primary buttons disagree with each other: radius 6 / 7 / 10px, text 12 / 14 / 15px, weight 600 / 700 / 700.

## Findings

Ordered by how much each one costs the project going forward.

1. **The first screens and the app look like two products.**Sign-in and sign-up pages still use the dark green theme from before the light refresh. A new user's first five minutes are dark; then the app is light.
2. **There is no shared stylesheet.**Each of the 15 pages carries its own `<style>`. The 11 sign-in pages share 36 rules copied 345 times, and 23 selectors have already drifted apart: `body` exists in 6 versions, `h2.display` in 5, `.option-card` in 4.
3. **Variables are named after colors, not jobs.**In softball, `--amber` holds pink, and `--field-dark` is both a background and the text color. This is the main blocker for team colors: a team theme needs names like accent and on-accent.
4. **Three vocabularies name the same colors.**The app, the policy pages and the session report each describe the palette differently. The report has no variables; its softball version is made by find-and-replace on hex strings.
5. **Type has no scale.**34 sizes, 15 letter spacings, 12 line heights. Font families are retyped in 88 places instead of read from a variable, and two report surfaces use fonts outside the system.
6. **Buttons are rebuilt per feature.**58 classes. Danger is a primary button with an inline red override in 12 places. Next Pitch exists four times; one uses amber instead of gold and hard-coded `#111` text.
7. **Radius and spacing are picked by eye.**Every radius from 2 to 10px appears. Half of all spacing values sit off a 4px grid.
8. **Two small bugs.**`.g5-act` and `.g5-reset` use `var(--ink)`, which the app never defines; they look right only because text color is inherited. Several Live Game rules hard-code `#fff`, `#111` and `#C9A227`, so softball needed hand-written overrides.

### Strengths to build on

- **Contrast is measured.** Most text colors carry their WCAG ratio in a code comment.
- **Built for the mound.** 44px minimum tap targets throughout, and reduced-motion support on every animation.
- **Fonts are self-hosted.** No third-party loads, which keeps the privacy policy's promise.
- **Theming already runs on variables.** The app's sport switch is the mechanism team colors need.

## Roadmap

From documented to standardized to a Figma library, in an order where each phase can ship on its own. Phase 1 needs no design decisions, so it can start before the brand work is finished.

#### Phase 0 · Decide

- Sign-in pages: move to the light app look, or keep dark on purpose as a brand moment. Either way, built from the same tokens.
- Agree the semantic token names (surface, ink, accent, on-accent, danger…) and the targets in the audit table.
- Allow one shared CSS file. It needs no build step, but the repo's CLAUDE.md should say it's allowed.
- Bring the design inspiration board (card 016). It decides the values Phase 2 uses.

#### Phase 1 · Foundation, no visible change

One `css/kb-tokens.css` with semantic names and the old names kept as aliases, loaded by all 15 pages and precached by the service worker. Fix the `--ink` bug, add a real `.btn-danger`, move the hard-coded colors into tokens.

**Done when** before-and-after screenshots of every page match.

#### Phase 2 · Scales

Move font sizes, radii, spacing and shadows onto the agreed scales and bring the sign-in pages into line. This is where the app stops looking generated: a deliberate type scale and spacing rhythm do most of that work.

**Done when** the audit script reports the target counts.

#### Phase 3 · Components

A shared `css/kb-components.css`: Button, Chip, Input, Card, Badge, Banner, Tabs, Modal and Sheet, and the charting grid. A style-guide page in the repo renders every component from the real CSS, replacing this page as the source of truth.

**Done when** no page defines its own button.

#### Phase 4 · Figma library

Import `design-tokens.json` into Figma variables, then build components with the same names and variants as the code. Changes travel one way: edit a token in Figma, export, regenerate `kb-tokens.css`.

**Done when** a new screen can be designed entirely from library parts.

#### Phase 5 · Team colors

A team theme is a small override. The team picks a primary and an accent; the app derives hovers and tints and rejects combinations that fail contrast. Pitch-type palettes and strike/ball colors stay fixed, because they are data and must match the reports.

**Done when** a team can switch on its colors without a code change.

### Repo rules the plan respects

- Only Nate ships to production; Jordan works on staging and opens pull requests.
- No build step, framework or bundler without Nate's approval. A plain shared CSS file needs none.
- No fonts or scripts from other hosts.
- Sent reports are frozen. New styling applies only to new reports.
- Pitch palettes in the tracker and the report function change together or not at all.
- Changing the policy pages needs Nate's approval in the commit message.
