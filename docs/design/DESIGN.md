# Knuckleball — Style Reference
> Scorebook on the infield grass. Teko numerals and an amber accent sit on mist-green paper, under a dark field-green brand strip.

**Theme:** light app, dark sign-in pages, two sport themes (baseball green and amber; softball slate blue and pink)

**Source:** knuckleballonline.com, audited from the live `main` branch at commit `cf346b0` (2026-10-09). Every value below is in production today. Where the site disagrees with itself, this file records the most-used value and lists the others under *Drift*. It describes the current state. It is not a proposal.

Knuckleball is a charting tool used on the side of a bullpen mound, often on a phone with no signal. The visual language matches that use: big tap targets (44px minimum), dense numeric readouts, and a strike-zone grid at the center of every screen. The charting app uses a light theme: a pale green page (`#F7FAF8`), white cards and pale green panels, with dark field-green ink (`#0F241B`) for text. One dark element stays on every screen, the field-green brand strip that holds the KNUCKLEBALL wordmark. Amber (`#E8A83D`) is the one accent. It marks the primary action, the active tab, the selected velocity and the leaderboard gold. Numbers use Teko, a condensed scoreboard face. UI text uses IBM Plex Sans and data uses IBM Plex Mono. The wordmark is Black Ops One. Sign-in and sign-up pages still use the older dark theme: field-green background, chalk-colored text, amber buttons. The softball theme keeps the same layout and swaps green for slate blue and amber for pink.

## Tokens — Colors

### Brand and ink

| Name | Value | Token | Role |
|------|-------|-------|------|
| Field Dark | `#0F241B` | `--field-dark` | Brand strip, dark status bars, primary text everywhere in the app; page background on sign-in pages. The most-used color (125 `var()` uses) |
| Field Panel | `#183527` | `--field-panel` | Card background on dark sign-in pages |
| Field Panel 2 | `#1F4230` | `--field-panel-2` | Hover and info-box background on dark sign-in pages |
| Ink Dim | `#2E4A40` | `--ink-dim` | Secondary text on light (9.7:1 on white) |
| Ink Faint | `#527065` | `--ink-faint` | Labels, meta, captions on light (5.4:1 on white) |
| Chalk | `#F1ECDD` | `--chalk` | Text and icons on the dark brand strip and dark pages |
| Chalk Dim | `#B7C2B4` | `--chalk-dim` | Secondary text on dark |
| Chalk Faint | `#7C8C82` | `--chalk-faint` | Taglines, hints and placeholders on dark |

### Accent and action

| Name | Value | Token | Role |
|------|-------|-------|------|
| Amber | `#E8A83D` | `--amber` | The single accent: primary button fill, active tab underline, selected velocity, focus selection, leaderboard gold |
| Amber Bright | `#F5C365` | `--amber-bright` | Primary hover; focus outline; badge text on dark |
| Game Gold | `#C9A227` | `--game-gold`, `--gg-gold` | Live Game only: Next Pitch button, sequence badges, pending runner paths |
| Kind Green | `#3D7A57` | `--kind-btn` | The Bullpen / Live Game chooser buttons (hover `#2E6345`, pressed `#245036`) |

### Surfaces and lines (light app)

| Name | Value | Token | Role |
|------|-------|-------|------|
| Page Mist | `#F7FAF8` | `--page-bg` | Page background |
| Card White | `#FFFFFF` | `--card-bg` | Cards, the charting grid cells, inputs |
| Surface Green | `#E8F3EC` | `--surface` | Sidebar, strike-zone cells, pitch-log rows, hover rows |
| Surface Line | `#CFE6D7` | `--surface-border` | Grid frame, selected rows, report rules |
| Border | `rgba(15,36,27,0.10)` | `--border` | Card and divider hairlines |
| Border Strong | `rgba(15,36,27,0.22)` | `--border-strong` | Inputs, chips, ghost buttons |
| Border on Dark | `rgba(241,236,221,0.16)` | `--border-on-dark` | The one light-on-dark hairline (brand strip, report bar) |
| Game Panel | `#F7F5EF` | `--game-panel-bg` | Live Game drop-down panel |
| Game Chip Line | `#9DBBA9` | `--game-chip-border` | Live Game chips and scorebook buttons |

### Status

| Name | Value | Token | Role |
|------|-------|-------|------|
| Ball Red | `#C0453B` | `--red` | Errors, destructive text links, roster alert dots, the "ball" flash |
| Red Solid | `#A83A31` | `--red-bg` | Solid destructive buttons (5.4:1 with chalk text) |
| Clay | `#96551F` | `--clay` | Warnings, hints, offline and pending notes (app). Sign-in pages still use the old `#C17A45` |
| Clay Dim | `#8A5732` | `--clay-dim` | Warning banner borders |
| Strike Green | `#2E8B57` | literal | The "strike" flash on the grid |
| Sent Green | `#6FA287` | literal | "Sent" and "Saved" confirmations |
| Silver | `#7C8B85` | `--silver` | Leaderboard 2nd place |
| Bronze | `#A8621F` | `--bronze` | Leaderboard 3rd place |

### Softball theme (`html[data-sport="softball"]`)

| Name | Value | Replaces |
|------|-------|----------|
| Slate | `#234B6E` | Field Dark |
| Slate Panel | `#2B5A82` / `#336896` | Field Panel / Field Panel 2 |
| Slate Dim | `#3A5A78` | Ink Dim |
| Slate Faint | `#5F7A91` | Ink Faint |
| Sky Mist | `#F7FAFD` | Page Mist |
| Sky Surface | `#EAF4FB` | Surface Green |
| Sky Line | `#BFDCEF` | Surface Line |
| Blush | `#F2A7C3` | Amber (as the accent fill) |
| Blush Bright | `#F7C3D7` | Amber Bright |
| Rose | `#E27BA2` | Primary button and Kind Green (hover `#D4688F`, pressed `#C2567D`), white text |
| Rose Gold | `#E98DB0` | Game Gold |

Rule from the code: pink is a fill, never text on a light background. `--accent-text` falls back to Slate in softball.

### Data colors (fixed, not themed)

Pitch types are colored by **slot**: a pitcher's 1st through 8th pitch type. The same arrays live in `bullpen-tracker.html` (`SPORTS[sport].palette`) and `send-session-report/helpers.ts`, and must match exactly.

| Slot | Baseball | Softball |
|------|----------|----------|
| 1 | `#E8A83D` | `#E27BA2` |
| 2 | `#6FA287` | `#7FB8E0` |
| 3 | `#C17A45` | `#6C5B7B` |
| 4 | `#C0453B` | `#F6B26B` |
| 5 | `#7C9CBF` | `#4FA3A5` |
| 6 | `#B98CCB` | `#9B8ADB` |
| 7 | `#D4C15B` | `#B36B5E` |
| 8 | `#4FA8A8` | `#8C8C8C` |

Field art (Live Game, `.gg-field`): fence `#B9D1C4`, grass `#C7DCBD`, infield `#B4C8AC`, dirt `#C9A97C`, mound `#B8956A`, mower stripes `#8CBA5A` / `#6FA548` (fair) and `#60963C` / `#548A35` (foul), base on `#F4C430`.

## Tokens — Typography

### Teko — display numbers and headings
- **Substitute:** Oswald, Bebas Neue
- **Weights:** 600 for headings, 700 for the B/K flash letter, 400 implied for stat numbers
- **Sizes:** 20, 24, 28, 30, 32, 34, 36, 38, 42, 44, 64px
- **Line height:** 1
- **Letter spacing:** 0.01em (`.display`), 0.02em on buttons
- **Role:** page titles ("Which sport?"), pitcher names, stat numbers, pitch counter, uniform numbers, leaderboard ranks, the Bullpen / Live Game chooser
- **Files:** self-hosted, `vendor/fonts/Teko-{400,500,600,700}`

### IBM Plex Sans — UI and body
- **Substitute:** Inter, Source Sans 3
- **Weights:** 400, 500, 600, 700, 800 (800 is used but not self-hosted; the browser synthesizes it from 700)
- **Sizes:** 10, 11, 11.5, 12, 12.5, 13, 13.5, 14, 15, 15.5, 16px
- **Line height:** 1.45 body, 1.5 notes, 1.6 policy pages
- **Letter spacing:** 0.1em on uppercase labels, 0.14–0.18em on taglines
- **Role:** everything that is not a number or the wordmark
- **Files:** self-hosted, `vendor/fonts/IBMPlexSans-{400,500,600,700}`

### IBM Plex Mono — data values
- **Weights:** 400, 500, 600 (700 used on scorebook codes, synthesized)
- **Sizes:** 10, 12, 16px
- **Role:** velocity cells, zone numbers, pitch-log values, leaderboard values, invite links

### Black Ops One — wordmark only
- **Weight:** 400
- **Sizes:** 20, 22, 24, 26, 32px
- **Letter spacing:** 0.02em, all caps "KNUCKLEBALL", no diamond or period
- **Role:** the logo, on every page except privacy and terms

### Off-system fonts (in production, outside the four families)
- **Georgia, serif:** the frozen session report (`send-session-report/template.ts`) body and headings
- **System UI stack** (`-apple-system, BlinkMacSystemFont, "Segoe UI"…`): the report page's top bar and loading state (`report.html`)

### Type Scale

| Role | Family | Size | Weight | Line height | Letter spacing | Where |
|------|--------|------|--------|-------------|----------------|-------|
| display-xl | Teko | 64px | 600 | 1 | 0.01em | Landing "Which sport?" (desktop) |
| display-lg | Teko | 44px | 600 | 1 | — | Pitcher name header, empty states |
| display-md | Teko | 38 / 34px | 600 | 1 | 0.01em | Sign-in and sign-up titles |
| stat-lg | Teko | 32px | 400 | 1 | — | Stat readouts (count, strike %) |
| stat-md | Teko | 24px | 400–600 | 1 | 0.02em | Pitch counter, session meta, chooser buttons |
| stat-sm | Teko | 20px | 400 | 1 | — | Roster uniform numbers, leaderboard rank |
| wordmark | Black Ops One | 22–32px | 400 | 1 | 0.02em | KNUCKLEBALL |
| report-h1 | Georgia | 28px | 700 | 1.5 | — | Session report title |
| report-h2 | Georgia | 19px | 700 | 1.5 | — | Session report sections |
| body-lg | Plex Sans | 16px | 700–800 | 1.2 | — | Phone session controls, sheet titles |
| body | Plex Sans | 14px | 400–600 | 1.45 | — | Roster names, inputs, notes |
| body-sm | Plex Sans | 13px | 400 | 1.5 | — | Sign-in body copy, report tables |
| ui | Plex Sans | 12px | 600 | 1.2 | — | App buttons, tabs, meta, status lines (the most-used size, 94 rules) |
| label | Plex Sans | 10–11px | 600 | 1.2 | 0.1em, uppercase | Field labels, stat labels, badges |
| tagline | Plex Sans | 10–11px | 400 | 1 | 0.14–0.18em, uppercase | "ALWAYS A STEP AHEAD" |
| data-lg | Plex Mono | 16px | 600 | 1 | — | Velocity cells, leaderboard values |
| data-sm | Plex Mono | 10–12px | 600–700 | 1 | — | Zone numbers, pitch-log, scorebook codes |

**Drift:** 34 distinct font sizes are in use, including five half-pixel sizes (10.5, 11.5, 12.5, 13.5, 15.5px) and six `calc()` sizes on the Live Game field.

## Tokens — Spacing & Shapes

**Base unit:** none declared. 88% of spacing values fall on a 2px grid and 48% on a 4px grid.

**Density:** compact. Panels pad 22px, chips 10×16px, list rows 12px. Tap targets hold at 44px minimum height throughout.

### Spacing Scale (most-used values, all padding, margin and gap)

| Value | Uses | Typical use |
|-------|------|-------------|
| 4px | 91 | Label-to-control gaps, chip gaps |
| 6px | 109 | Form field gaps, small row gaps |
| 8px | 126 | Button rows, list gaps (the most common) |
| 10px | 79 | Chip rows, banner gaps |
| 12px | 64 | Row padding, phone layout gaps |
| 14px | 70 | Card internal gaps, button side padding |
| 16px | 44 | Section padding on phones, banner padding |
| 20px | 35 | Card head padding, wide-layout column gap |
| 24px | 26 | `.main` gap, body padding on sign-in pages |
| 32px | 6 | Session layout gap, modal top padding |
| 40px | 3 | Desktop `.main` side padding |

35 distinct pixel values are in use in all. The rest (1, 2, 3, 5, 7, 9, 11, 13, 18, 22, 26, 28, 30, 34, 36, 38, 44, 48, 60, 80, 84, 96, 115px) appear 1 to 35 times each.

### Border Radius

| Name | Value | Where |
|------|-------|-------|
| dot | 2px | Brand diamond, legend and pitch-log dots |
| cell | 3–4px | Strike-zone cells, Live Game cells, scorebook cells |
| input-sm | 5px | App text inputs, inline edit fields, invite link box |
| control | 6px | App `.btn`, select, roster rows, zone grid frame, sign-in inputs |
| btn-signin | 7px | Sign-in `.btn-primary` |
| tile | 8px | Banners, info boxes, velocity strip, scorebook and position chips |
| tile-game | 9px | Live Game field buttons |
| card | 10px | `.panel`, session cards, brand strip, phone chips and actions |
| menu | 12px | Account menu, Live Game panel, chooser buttons, dock items |
| card-signin | 14px | Sign-in card, landing sport cards, modal |
| sheet | 16px 16px 0 0 | Phone bottom sheet |
| dock | 18px | Coach dock |
| badge | 20px | Role, offline, status and team badges |
| chip | 22px | Pitch-type chips, throws toggle, pitch-count badge |
| pill | 999px | Account button, batter pill, account chips |
| circle | 50% | Headshots, avatars, alert dots, close button |

18 distinct values, 171 declarations.

### Shadows

| Name | Value | Use |
|------|-------|-----|
| card | `0 1px 3px rgba(15,36,27,0.06)` | `.panel`, session cards |
| raised | `0 2px 6px rgba(15,36,27,0.15)` | Chooser buttons, Live Game field buttons |
| popover | `0 10px 26px rgba(15,36,27,0.22)` | Account menu |
| panel-drop | `0 10px 26px rgba(15,36,27,0.28)` | Live Game drop-down panel |
| modal | `0 8px 32px rgba(15,36,27,0.35)` | Profile modal |
| dock | `0 6px 24px rgba(0,0,0,0.22)` | Coach dock |
| notice | `0 18px 50px rgba(10,20,40,0.45)` | One-time notices (age box, "Who's charting?") |
| select-ring | `inset 0 0 0 2px var(--amber)` | Typical velocity, painted zone, leaderboard "me" (1px) |
| target-halo | `0 0 0 4px rgba(232,168,61,0.28)` | Pulsing target dot |

Focus: `outline: 2px solid var(--amber-bright); outline-offset: 2px` (3px on sign-in pages).

### Layout

- **App max width:** 1320px (`#app`), sidebar 280px fixed, main padding 32px 40px
- **Breakpoints:** ≤360 (small phone), ≤500 (phone), 501–860 (iPad portrait), ≥861 (iPad landscape and laptop), plus 600 (report) and 700 (Live Game walkthrough)
- **Content widths:** sign-in card 380px, landing 760px, policy pages 760px, report 820px, profile 560px, leaderboard 640px, modal 560px
- **Charting grid:** 5×5, 52px cells and 3px gaps on desktop (278px), up to 340px on phones, up to 560px on wide screens

## Components

### Primary Button (app)
**Role:** the one primary action per screen: End session & save, Save, Send report.

Background `var(--amber)` `#E8A83D`, text `#0F241B`, border none, radius 6px, padding 9px 14px, Plex Sans 12px weight 600. Hover `#F5C365`. Disabled opacity 0.5. Softball: background `#E27BA2`, white text. Markup `.btn.btn-primary` (53 buttons).

### Primary Button (sign-in pages)
**Role:** Log in, Create account, Join team.

Same amber fill with larger metrics: radius 7px, padding 12px 14px, 14px weight 700, letter spacing 0.02em, full card width. Defined separately in 11 page files.

### Ghost Button
**Role:** secondary actions: Contacts, Profile, Cancel, Back.

Transparent, 1px `rgba(15,36,27,0.22)` border, text `#2E4A40`, radius 6px, padding 9px 14px, 12px weight 600. Hover: border and text darken to ink. Markup `.btn.btn-ghost` (73 buttons, the most common button).

### Danger Button
**Role:** Delete, Discard.

There is no danger class. It is a `.btn.btn-primary` with an inline `style="background:var(--red-bg);color:var(--chalk);"`, repeated 12 times.

### Chooser Button
**Role:** "What will we be charting today?" Bullpen or Live Game.

Background `#3D7A57`, white text, Teko 24px weight 600, radius 12px, min height 72px, width 280px (220px side by side at ≥861px), shadow raised.

### Next Pitch Button
**Role:** advances Live Game to the next pitch.

Gold fill (`#C9A227`, softball `#E98DB0`), ink text, weight 800, uppercase. Four versions exist: `.next-pitch-btn` (radius 10, 16px), `.g5-act-next` (radius 10, literal colors), `.g5-nextpitch` (radius 6, amber not gold, `#111` text), `.gg-next` (radius 9).

### Pitch-Type Chip
**Role:** pick the pitch type before charting.

Pill, radius 22px, min 44×44px, padding 10px 16px, 14px weight 600, 1.5px border `--border-strong`, text `--ink-dim`. Selected: filled with that pitch's slot color, ink or white text chosen for contrast at runtime. Phone version (`.pstrip-chip`) is a grid-square tile, radius 10px, 12px weight 800 caps.

### Toggle Chip
**Role:** Throws (R/L), batter side, Set/Windup, time to plate.

`.throws-btn`: same pill as the pitch chip, selected = amber fill. `.ttp-btn`: radius 20px, 12px weight 700. `.deliv-one` (phone): radius 10px, 16px weight 700, 1.5px ink border, selected = ink fill with chalk text.

### Tabs
**Role:** New Session · History · Leaders · Player.

Plex Sans 12px weight 600, uppercase, `--ink-faint`, padding 10px 3px, 4px gap, 2px bottom border. Active: ink, weight 700, amber underline.

### Brand Strip
**Role:** top of the sidebar: wordmark, tagline, role and offline badges.

Background `#0F241B`, radius 10px, padding 16px 18px, wordmark Black Ops One 24px chalk, tagline 10px uppercase 0.14em `--chalk-faint`.

### Badge
**Role:** role (COACH), offline, "Logged by coach", pending, deleted, verify, team.

10px uppercase, letter spacing 0.05–0.1em, padding 2–3px 7–9px, radius 20px. Amber family on dark: text `#F5C365`, fill amber at 12%, border amber at 30%.

### Panel and Session Card
**Role:** the main content containers.

Background white, 1px `--border`, radius 10px, padding 22px (18px on tablets, 14px in the 501–860 range), shadow card. Session card head padding 16px 20px, hover `--surface`.

### Text Input
**Role:** all form fields.

App: white, 1px `--border-strong`, radius 5px, padding 8px 10px, 14px. Sign-in: `#0F241B` fill, radius 6px, padding 11px 12px, chalk text, amber focus border. Field labels are 10–11px uppercase, 0.1em, `--ink-faint`.

### Banner
**Role:** verify email, unsaved draft, outbox, archived team.

Clay tint `rgba(193,122,69,0.12)`, 1px `--clay-dim` border, radius 8px, padding 12px 16px, 12px `--ink-dim` text.

### Strike-Zone Grid
**Role:** the charting surface.

5×5 grid, 3px gaps and 3px padding on `--surface-border`, outer radius 6px. Cells white, radius 3px. The inner 3×3 strike zone is `--surface` with a `--border-strong` line. Zone numbers Plex Mono 10px at 35% ink. Target cell: 2px amber outline and amber 16% fill, with a pulsing amber dot. Strike and ball flash `#2E8B57` / `#C0453B` with a Teko 24px letter.

### Velocity Strip
**Role:** pick the pitch speed (40–105 mph baseball, 25–85 softball).

Horizontal snap scroller, 7 cells visible (5 on phones), radius 8px, cells Plex Mono 16px weight 600, min height 48px. Typical speed: 2px inset amber ring. Selected: amber fill.

### Coach Dock
**Role:** phone navigation for coaches (Home, Charts, Roster, Profile).

Fixed bottom bar, inset 10px, radius 18px, `rgba(15,36,27,0.72)` with 14px backdrop blur, shadow dock. Items 10px weight 700 under 24px stroke icons; a white 18% pill slides under the active item.

### Modal and Sheet
**Role:** profile setup, one-time notices, the phone session menu.

Overlay `rgba(15,36,27,0.55)`. Panel white, radius 14px, padding 32px 24px 24px, max width 560px, shadow modal. Phone sheet: radius 16px 16px 0 0, full-width buttons at 48px min height.

### Sport Card (landing)
**Role:** "Which sport?" Baseball / Softball.

Radius 14px, padding 36px 26px, 1.5px border, Teko 30px title, icon in a 56px circle. Hover lifts 3px and turns the border to the sport's accent. Each card wears its own sport's colors on a white page.

## Do's and Don'ts

### Do
- Keep every tap target at least 44px tall. Charting happens one-handed on a mound.
- Use Teko for numbers people read at a glance: counts, percentages, uniform numbers.
- Keep amber for one primary action per screen, plus selection states.
- Put light text only on the dark brand strip, status bars and sign-in pages.
- Check contrast against white and against `--surface`; the code comments record a ratio for nearly every text color.
- Change theme colors through the `html[data-sport]` variables, never in individual rules.
- Keep the pitch-type palettes identical in the tracker and the report function.

### Don't
- Don't put pink (softball accent) text on a light background.
- Don't use amber as a small icon or thin line on light backgrounds; it falls below 3:1.
- Don't add a hex value inside a rule. Add or reuse a variable.
- Don't load fonts or scripts from third-party hosts; the privacy policy promises none.
- Don't drop a stat below 10px.
- Don't put anything on the charting grid that intercepts taps (`pointer-events:none` on overlays).

## Surfaces

| Level | Light app | Sign-in (dark) | Softball light |
|-------|-----------|----------------|----------------|
| 0 Page | `#F7FAF8` | `#0F241B` with amber and clay radial glows | `#F7FAFD` |
| 1 Panel | `#E8F3EC` (sidebar) | `#183527` (card) | `#EAF4FB` |
| 2 Card | `#FFFFFF` + card shadow | `#1F4230` (info boxes) | `#FFFFFF` |
| Strong | `#0F241B` brand strip and status bars | — | `#234B6E` |

## Elevation

Most separation comes from fills and 1px hairlines, not shadows. Cards carry a faint 1–3px shadow. Larger shadows appear only on things that float above the page: the account menu, the Live Game panel, the modal, the coach dock and the one-time notices. Selection uses inset rings instead of raised shadows, so a selected cell never shifts the grid.

## Imagery

No photography. Imagery is drawn: the batter silhouette beside the grid, a drawn home plate, the Live Game field (mower-striped grass, dirt, bases) in SVG, and small mask icons for pitch outcomes (ball, foul, looking, swinging). Pitcher headshots are 64px circles (40px on phones) with initials as the fallback. The sport cards use small baseball and softball illustrations.

## Layout

The app is a sidebar-and-main layout up to 1320px. The sidebar (280px) holds the brand strip, team picker and roster. The main column holds the pitcher header, tabs and the active view. Below 860px the sidebar stacks above the main column. Between 501 and 860px it collapses into one wrapped row. At 500px and below, charting switches to a dedicated phone layout: a dark session header, a pitch-type strip and the grid capped at 340px. Coaches get the bottom dock. Sign-in pages are a single centered 380px card.

## Agent Prompt Guide

**Quick color reference:** page `#F7FAF8` · card `#FFFFFF` · panel `#E8F3EC` · line `#CFE6D7` · ink `#0F241B` · ink-dim `#2E4A40` · ink-faint `#527065` · accent `#E8A83D` · on-dark text `#F1ECDD` · error `#C0453B` · warning `#96551F`

1. *"Build a Knuckleball stat card: white card, 1px rgba(15,36,27,0.10) border, 10px radius, 22px padding. Three stats in a row, each a Teko 32px number in #0F241B over a 10px uppercase IBM Plex Sans label at 0.1em in #527065."*
2. *"Add a primary action: amber #E8A83D fill, #0F241B text, IBM Plex Sans 12px weight 600, 9px 14px padding, 6px radius, hover #F5C365. Only one per screen."*
3. *"Add a sidebar brand strip: #0F241B fill, 10px radius, 16px 18px padding, KNUCKLEBALL in Black Ops One 24px #F1ECDD, tagline 10px uppercase 0.14em #7C8C82."*
4. *"Make a pitch-type chip row: pills, 22px radius, 44px min height, 1.5px rgba(15,36,27,0.22) border, 14px weight 600 #2E4A40; selected chip fills with the pitch's slot color."*
5. *"Theme it for softball: set data-sport='softball' on html. Ink becomes #234B6E, panels #EAF4FB, the primary button #E27BA2 with white text. Never use pink as text."*

## Similar Brands

- **GameChanger:** scorekeeping on a field-green base. Knuckleball deliberately avoids its field picture.
- **Rapsodo / TrackMan reports:** dense pitch data with colored pitch-type keys.
- **Old-style scorebooks:** cream paper, diamond cells and handwritten codes, echoed in the Live Game scorebook cells.

## Quick Start

### CSS Custom Properties

```css
:root {
  --page-bg: #F7FAF8; --card-bg: #FFFFFF; --surface: #E8F3EC; --surface-border: #CFE6D7;
  --field-dark: #0F241B; --ink-dim: #2E4A40; --ink-faint: #527065;
  --chalk: #F1ECDD; --chalk-dim: #B7C2B4; --chalk-faint: #7C8C82;
  --amber: #E8A83D; --amber-bright: #F5C365;
  --red: #C0453B; --red-bg: #A83A31; --clay: #96551F; --clay-dim: #8A5732;
  --border: rgba(15,36,27,0.10); --border-strong: rgba(15,36,27,0.22);
}
html[data-sport="softball"] {
  --page-bg: #F7FAFD; --surface: #EAF4FB; --surface-border: #BFDCEF;
  --field-dark: #234B6E; --ink-dim: #3A5A78; --ink-faint: #5F7A91;
  --amber: #F2A7C3; --amber-bright: #F7C3D7;
  --primary-bg: #E27BA2; --primary-fg: #FFFFFF;
}
```

### Tailwind v4

```css
@import "tailwindcss";
@theme {
  --color-page: #F7FAF8; --color-card: #FFFFFF; --color-surface: #E8F3EC; --color-line: #CFE6D7;
  --color-ink: #0F241B; --color-ink-dim: #2E4A40; --color-ink-faint: #527065;
  --color-accent: #E8A83D; --color-accent-bright: #F5C365;
  --font-display: "Teko", sans-serif; --font-sans: "IBM Plex Sans", sans-serif;
  --font-mono: "IBM Plex Mono", monospace; --font-wordmark: "Black Ops One", "Teko", sans-serif;
  --radius-control: 6px; --radius-card: 10px; --radius-chip: 22px;
}
```

The site has no build step, and its `CLAUDE.md` bans adding one without approval. The Tailwind block is a reference for design tools and a possible future, not something to install today.
