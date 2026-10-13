# Knuckleball — Style Reference (target: Broadcast · Big Shoulders)
> Ballpark signage on the mound. Big Shoulders capitals and a gold accent over near-black field green, with hard switches between dark and light.

**Theme:** light app with dark brand surfaces (brand strip, status bars, sign-in header); two sport themes (baseball field green and gold; softball navy and rally pink)

**Status:** the target system Jordan and Nate chose on 2026-10-13 ("Broadcast · Big Shoulders"). It replaces the as-built reference from 2026-10-09 (`../DESIGN.md`). Token names follow Nate's packet D1 (`plans/d1-design-standardization.md`, rename map); buttons follow his U13 Segmented style, unchanged. The loadable token file is `css-variables.css` in this folder (the proposed `css/tokens.css`).

Knuckleball is charted beside a bullpen mound, often on a phone with no signal, so the app stays light, dense and built for one thumb: 44px targets, numbers read at a glance, the strike-zone grid at the center of every charting screen. The brand lives in a few strong places. A near-black field green (`#061A12`) carries the brand strip, the status bars, the sign-in header and the report header. Gold (`#FFB81C`) is the only accent: the one primary action per screen, the selected value, section tags. Headlines, names and every big number are set in Big Shoulders Display, tall upright capitals drawn from ballpark and city signage. Everything else is Archivo, one variable family that covers text, labels, buttons and aligned data. Surfaces are flat: separation comes from fills, 1px lines and the hard edge between dark and light, never from soft shadows on cards. The few places the brand gets loud (the sign-in header, the landing page later) use an angled bottom edge and a slanted, broadcast-style section tag. Softball keeps every rule and swaps the colors: navy for the field green, rally pink for the gold.

## Tokens — Colors

### Surfaces

| Name | Value | Token | Role |
|------|-------|-------|------|
| Page | `#F3F5F2` | `--bg` | Page background |
| Card | `#FFFFFF` | `--card` | Cards, panels, grid cells, inputs |
| Card 2 | `#F8FAF8` | `--card-2` | Nested wells, zebra rows |
| Surface | `#E8EDE9` | `--surface` | The soft fill: trays, secondary buttons, sidebar, strike zone |
| Surface Line | `#D5DDD7` | `--surface-border` | Rules, selected rows |
| Line | `rgba(7,20,15,0.10)` | `--border` | Card and divider hairlines |
| Line Strong | `rgba(7,20,15,0.24)` | `--border-strong` | Inputs, chart frames |

### Ink

| Name | Value | Token | Role |
|------|-------|-------|------|
| Ink | `#07140F` | `--ink` | Primary text (17.2:1 on the page) |
| Ink Dim | `#26342D` | `--ink-dim` | Secondary text (13.0:1 on white) |
| Ink Faint | `#56645C` | `--ink-faint` | Labels and captions (6.2:1 on white, 5.3:1 on Surface) |

### Brand (dark)

| Name | Value | Token | Role |
|------|-------|-------|------|
| Night | `#061A12` | `--brand-bg` | Brand strip, status bars, sign-in header, report header, dark bands |
| Night Deep | `#030D09` | `--brand-bg-deep` | Scoreboard cells, footer |
| Night Raised | `#0A2A1D` | `--brand-bg-2` | Raised areas on dark, chooser hover |
| Turf | `#16593D` | `--brand-mid` | Focus ring, links on light (8.3:1 on white) |
| Turf Soft | `#7FC9A1` | `--brand-soft` | Avatars, secondary chart marks |
| On Dark | `#FFFFFF` | `--on-dark` | Text on Night |
| On Dark Dim | `#C2CEC6` | `--on-dark-dim` | Secondary text on Night (11.1:1) |
| On Dark Faint | `#86978C` | `--on-dark-faint` | Labels on Night (5.9:1) |

### Accent

| Name | Value | Token | Role |
|------|-------|-------|------|
| Gold | `#FFB81C` | `--accent` | Primary action, selection, section tags, target cell. A fill only: 1.8:1 as text on white |
| Gold Bright | `#FFC94F` | `--accent-bright` | Hover on primary |
| Gold Ink | `#8A5A00` | `--accent-ink` | Accent-colored text on light (5.9:1 on white) |
| On Gold | `#07140F` | `--on-accent` | Text on gold (10.9:1) |

### Status

| Name | Value | Token | Role |
|------|-------|-------|------|
| Danger | `#C42B21` | `--danger` / `--danger-bg` | Danger text on the soft fill (4.8:1); solid destructive fill with white text (5.7:1) |
| Warning | `#9A5B00` | `--warning` | Warnings, hints, offline (5.4:1 on white); line `#C77700`, tint gold at 16% |
| Success | `#1E7F4A` | `--success` | Sent, Saved (5.0:1 on white) |
| Strike | `#188A4E` | `--strike` | Strike flash on the grid, white letter |
| Ball | `#E0443A` | `--ball` | Ball flash on the grid, white letter |
| Rank 2 / 3 | `#7C8B85` / `#A8621F` | `--rank-2` / `--rank-3` | Leaderboard medals (gold = `--accent`) |

### Softball (`html[data-sport="softball"]`, same names)

| Name | Value | Token |
|------|-------|-------|
| Navy | `#0B2540` | `--ink`, `--brand-bg` |
| Navy Deep / Raised | `#06172A` / `#12345A` | `--brand-bg-deep` / `--brand-bg-2` |
| Navy Dim / Faint | `#2C4560` / `#5A6E84` | `--ink-dim` / `--ink-faint` |
| Sky Page / Surface / Line | `#F4F7FB` / `#E6F1FA` / `#CFE0EE` | `--bg` / `--surface` / `--surface-border` |
| Harbor | `#1F5C99` | `--brand-mid` |
| Rally Pink | `#FF4F9A` | `--accent` (navy text on it, 5.1:1; never pink text on light) |
| Pink Ink | `#B0175A` | `--accent-ink` (6.7:1 on white) |

### Pitch types (data colors, by slot 1–8)

A pitcher's first through eighth pitch type takes slots 1 through 8. The arrays live in `bullpen-tracker.html` (`SPORTS[sport].palette`) and `send-session-report/helpers.ts` (`SPORT_PALETTE_HEX`) and must match exactly, in order. New reports use these; frozen reports keep the colors they were made with.

| Slot | Baseball | Softball |
|------|----------|----------|
| 1 | `#FFB81C` | `#FF4F9A` |
| 2 | `#22B573` | `#2F9BFF` |
| 3 | `#FF6B35` | `#7A3FB8` |
| 4 | `#E63946` | `#FF9F1C` |
| 5 | `#3D8BFF` | `#00A99D` |
| 6 | `#B15CFF` | `#8E6CFF` |
| 7 | `#F2E14C` | `#D2553F` |
| 8 | `#00B8C4` | `#7D8794` |

The Live Game field art (fence, grass, dirt, mower stripes, `.gg-field --gg-*`) is unchanged; D1 and G5 own it.

## Tokens — Typography

### Big Shoulders Display — headlines and big numbers
- **Weights:** 700 (numbers), 800 (headings), 900 (the largest display)
- **Sizes:** 64 (index "Which sport?" only), 44, 32, 24, 20
- **Line height:** 1 · **Letter spacing:** 0.01em · **Case:** uppercase for headings and names; numbers as they are
- **Role:** page titles, the pitcher's name, stat numbers, the pitch counter, uniform numbers, leaderboard ranks, the strike/ball flash letter, report headings
- **Source:** Google Fonts, SIL Open Font License, self-hosted (variable, 2 files, ~65 KB)

### Archivo — text, labels, buttons, data
- **Weights:** 400 body, 600 buttons and UI, 700 labels and data, 800 small titles
- **Sizes:** 20, 16, 14, 12, 10
- **Width:** 100% for text; 85–90% for uppercase labels and small titles (variable `font-stretch`)
- **Data:** tabular figures (`font-variant-numeric: tabular-nums`, class `.tnum`) where digits must line up: velocity cells, zone numbers, pitch log, leaderboard values, scorebook codes. Replaces IBM Plex Mono.
- **Source:** Google Fonts, SIL Open Font License, self-hosted (variable with width axis, 2 files, ~176 KB)

### Black Ops One — the wordmark only
- KNUCKLEBALL, all caps, 0.02em, on every page (privacy and terms after Nate approves). Unchanged from Oct 8.

### Type Scale (D1's nine steps)

| Role | Family | Size | Weight | Line height | Letter spacing | Where |
|------|--------|------|--------|-------------|----------------|-------|
| display-xl | Big Shoulders | 64 | 900 | 1 | 0.01em, caps | Index "Which sport?" |
| display | Big Shoulders | 44 | 800 | 1 | 0.01em, caps | Pitcher name, sign-in title, empty states |
| stat | Big Shoulders | 32 | 700 | 1 | tabular | Stat readouts, scoreboard numbers |
| stat-sm | Big Shoulders | 24 / 20 | 700 | 1 | tabular | Pitch counter, session meta, uniform numbers, ranks |
| title | Archivo | 20 / 16 | 800, width 85% | 1.2 | caps | Card and section titles |
| body | Archivo | 16 | 400 | 1.5 | — | Running text, inputs, notes |
| body-sm | Archivo | 14 | 400–600 | 1.45 | — | Roster names, segments, secondary text |
| ui | Archivo | 16 / 14 | 600 | 1.2 | — | Buttons (16), segments (14), per U13 |
| meta | Archivo | 12 | 500–600 | 1.3 | — | Meta lines, status messages |
| label | Archivo | 10 | 700, width 90% | 1.2 | 0.1em, caps | Field labels, stat labels, badges |
| data | Archivo | 16 / 12 / 10 | 700 | 1 | tabular | Velocity (16), pitch log (12), zone numbers (10) |
| tag | Archivo | 12 | 800, width 85% | 1 | 0.14em, caps | Slanted section tag |

## Tokens — Spacing & Shapes

**Base unit:** 4px. **Density:** compact in the app (cards pad 20px, 16px on phones), generous on dark bands. **Tap targets:** 44px minimum.

### Spacing Scale
`2 · 4 · 8 · 12 · 16 · 20 · 24 · 32 · 48 · 64` (`--s-2` … `--s-64`). Element gap 8, card padding 20 (16 on phones), section gap 24 in the app.

### Border Radius (D1's five)

| Name | Value | Where |
|------|-------|-------|
| cell | 4px | Grid, field and scorebook cells |
| segment | 9px | A segment inside a tray |
| control | 12px | Buttons, trays, inputs, cards, menus, the top corners of sheets |
| dock | 18px | Coach dock |
| pill | 999px | Badges (choices are never pills) |
| circle | 50% | Avatars, dots |

**Angled edge:** the sign-in header's bottom edge falls 28px across its width (`--cut`). Later, the landing page's dark bands.

### Shadows (three, plus two rings)

| Name | Value | Use |
|------|-------|-----|
| segment | `0 1px 3px rgba(0,0,0,.18)` | The selected segment (U13) |
| pop | `0 10px 26px rgba(ink,.22)` | Menus, the Live Game panel |
| modal | `0 8px 32px rgba(ink,.35)` | Modal, one-time notices |
| ring-select | `inset 0 -3px 0 var(--btn-accent)` | The selected segment's underline |
| ring-target | `inset 0 0 0 2px var(--accent)` | Target cell, typical velocity |

Cards and panels have **no shadow**: white on the page with a 1px line. Focus: `2px solid var(--brand-mid)`, offset 2px (gold would fail 3:1 on white).

### Layout
- App max width 1320px; sidebar 280px; breakpoints 360 / 500 / 860 (unchanged)
- Sign-in: a full-width dark header with the wordmark and title, a light form below (max 420px)
- Report: max 820px; dark header band, light body

## Components

The button set is U13 (Segmented), already built on staging; D2 changes only the tokens it reads. Everything below uses the tokens above, so softball and future team themes need no component changes.

### Tray and segment
**Role:** every pick-one group: tabs, filters, Throws, batter side, perspective, Windup/Set on wide screens, the pitch-type strip, the sport choice.
`--surface` tray, 12px radius, 3px padding, 44px tall. Segments transparent, 9px radius, 38px, Archivo 600 14px, `--ink`. Selected: white, `--shadow-segment`, `--ring-select` (pitch strip: the pitch's slot color); slides 150ms. On dark: tray `rgba(255,255,255,.10)`, segments 80% white, the selected one stays white with ink text.

### Buttons
**Primary:** gold fill, ink text, 12px radius, 44px min, Archivo 600 16px, sentence case. One per screen region. Softball: rally pink with navy text.
**Secondary:** `--surface` fill, ink text. **Tertiary:** transparent, ink text, same hit area. **Icon:** 44×44, `--surface`. **Danger:** `--surface` fill, `--danger` text (one class). **Disabled:** `#F1F3F2` / `#A7B0AA`. **On dark:** secondary turns `rgba(255,255,255,.12)` with white text.

### Brand strip
**Role:** top of the sidebar (wide) and the phone session header.
`--brand-bg`, 12px radius, 16px 18px padding. Wordmark Black Ops One 24px white; tagline Archivo 700 10px caps 0.14em `--on-dark-faint`; role badge as a slanted tag.

### Scoreboard (status bar)
**Role:** the phone session status bar and the bullpen count bar.
`--brand-bg-deep` bar, 12px radius, 52px tall; cells separated by 1px `--brand-line`; each cell a Big Shoulders 700 24–28px number over an Archivo 700 10px caps label in `--on-dark-faint`. Existing content only (pitches, count, inning, perspective); no new data.

### Slanted section tag
**Role:** the sign-in role tag ("BASEBALL SIGN IN"), Home section labels, the report's sport tag.
`--accent` fill, `--on-accent` text, Archivo 800 12px, width 85%, caps, 0.14em, padding 6px 12px, `transform: skewX(-14deg)` with the label counter-skewed.

### Card / panel
White, 1px `--border`, 12px radius, 20px padding (16px on phones), no shadow. Title: Archivo 800 width 85% 16px caps.

### Input
44px tall, 12px radius, 1.5px `--border-strong`, white, Archivo 16px, `--ink`. Focus: border `--brand-mid` plus a 3px ring of it at 18%. Label: the 10px caps label above.

### Badge
Pill, 24px tall, Archivo 700 10–11px caps 0.08em. Status colors: gold (role), warning tint (pending, offline), `--surface` (team, deleted), danger tint (unsaved).

### Banner
`--warning-tint` fill, 1px `--warning-line`, 12px radius, 12px 16px, Archivo 14px `--ink-dim`.

### Strike-zone grid
Frame `--brand-bg` (3px padding, 3px gaps, 4px radius cells); cells white; the inner 3×3 strike zone `--surface`; zone numbers Archivo 700 10px tabular at 35% ink. Target cell: `--ring-target` and gold at 18%, with a pulsing gold dot. Flash: `--strike` / `--ball` with a Big Shoulders 800 24px white letter.

### Velocity strip
Cells Archivo 700 16px tabular, 44px tall, 12px radius on the strip; typical speed `--ring-target`; selected gold fill with ink text. Arrows are icon buttons.

### Coach dock
`--dock-bg` with 14px blur, 18px radius; items Archivo 700 10px under 24px stroke icons; the active item rides a `--dock-pill` (the U13 draggable tray).

### Sign-in page
Light page. A full-width `--brand-bg` header with an angled bottom edge (`--cut`): wordmark, tagline, the slanted role tag, and a Big Shoulders 800 44px title with its last word in gold ("WELCOME / BACK."). Below, the form on `--bg`: the sport tray, inputs, a full-width primary button, links in `--brand-mid`. No glows, no dark card.

### Session report (new reports only)
Same tokens and fonts: `--brand-bg` header band with the wordmark and the slanted sport tag, Big Shoulders headings and tile numbers, Archivo body, `--surface-border` rules, the new pitch palette. Reports already sent stay as they are.

## Do's and Don'ts

### Do
- Keep gold to one primary action per screen region, plus the selected value and section tags.
- Set every number a coach reads at a glance in Big Shoulders; set aligned digits in Archivo with tabular figures.
- Switch hard between dark and light; the dark green is a surface, not a gradient.
- Keep every tap target at 44px or more.
- Change colors only in `tokens.css`; components read tokens.
- Change the pitch palettes in the tracker and the report function together.

### Don't
- Don't set gold or pink as text on light backgrounds; use `--accent-ink`.
- Don't add drop shadows to cards or panels.
- Don't build a button or pick-one control outside the Segmented set.
- Don't set body text or buttons in Big Shoulders or in all caps.
- Don't use the slanted tag for anything but section and role labels.
- Don't load fonts or scripts from other hosts.

## Surfaces

| Level | Baseball | Softball |
|-------|----------|----------|
| Page | `#F3F5F2` | `#F4F7FB` |
| Soft fill | `#E8EDE9` | `#E6F1FA` |
| Card | `#FFFFFF` + 1px line | `#FFFFFF` + 1px line |
| Brand | `#061A12` | `#0B2540` |
| Scoreboard | `#030D09` | `#06172A` |

## Elevation

Flat. Cards sit on the page with a 1px line; dark brand surfaces sit directly against light ones with a hard edge. Shadows exist only for things that float (menus, the Live Game panel, modals) and for the selected segment.

## Imagery

Drawn, not photographed, inside the app: the batter silhouette, the home plate, the Live Game field, Nate's Home tile icons (tinted with the theme), the result icons. The landing page will add the hero film and the app's own charts as graphics (not part of this guide yet).

## Agent Prompt Guide

**Quick reference:** page `#F3F5F2` · card `#FFFFFF` · soft fill `#E8EDE9` · ink `#07140F` · ink-faint `#56645C` · brand `#061A12` · gold `#FFB81C` · gold text `#8A5A00` · danger `#C42B21` · fonts Big Shoulders Display (display, numbers) + Archivo (everything else)

1. *"A Knuckleball stat card: white, 1px rgba(7,20,15,.10) line, 12px radius, 20px padding, no shadow. Three stats in a row: Big Shoulders Display 700 32px numbers in #07140F over Archivo 700 10px uppercase labels at 0.1em in #56645C."*
2. *"A primary action: gold #FFB81C fill, #07140F text, Archivo 600 16px, 44px tall, 12px radius, hover #FFC94F. One per screen region."*
3. *"A pick-one tray: #E8EDE9 tray, 12px radius, 3px padding; segments 38px, 9px radius, Archivo 600 14px; the selected one white with 0 1px 3px rgba(0,0,0,.18) and a 3px inset underline in #07140F."*
4. *"A sign-in header: full-width #061A12 with the bottom edge angled 28px; KNUCKLEBALL in Black Ops One 24px white; a gold slanted tag 'BASEBALL SIGN IN'; title in Big Shoulders Display 800 44px uppercase, last word gold."*
5. *"Softball: set data-sport='softball' on html. Navy #0B2540 replaces the green, rally pink #FF4F9A the gold, with navy text on pink."*

## Quick Start

The loadable token file is `css-variables.css` (proposed `css/tokens.css`). Tailwind v4 equivalents: `tailwind-v4.css` (reference only; the site has no build step). Figma import: `design-tokens.json` (W3C Design Tokens format).
