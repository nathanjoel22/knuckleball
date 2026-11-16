# N1 · Design reference (Nov 16, 2026)

Companion to `plans/n1-navigation-and-home.md`. The pictures in `docs/n1/` are the approved look; this file gives
the values behind them. **Where the packet and a picture disagree on behavior, the packet wins. Where they
disagree on look, the picture wins.** Example names and numbers in the pictures come from the demo facility.

## How to read the pictures

- They are drawings, not screenshots of the app. Phones are drawn 272px wide and stand for a 390px phone, so
  **multiply every size below by 1.4 for the real screen**, then take the nearest step on the app's own type and
  spacing scales (`css/tokens.css`). The iPad is drawn 700px wide and stands for 1180px (multiply by 1.7).
- Proportions, order, weight, case, color roles and which surface is dark or light are exact. Pixel values are a
  guide.
- Every color below is an app token. Do not copy a hex value out of a picture; that would break the softball
  theme and Stage G.

## Pictures by stage

| Stage | File in `docs/n1/` | Shows |
|---|---|---|
| A | `a-phone-bar.png` | the five-item bar, the pitcher chip, Chat icon with a count, the Chart chooser |
| A | `a-more-screen.png` | More: grouped rows, Sign out on its own |
| A | `a-sign-out-sheet.png` | the Sign out sheet, with the unsynced line |
| B | `b-sidebar-ipad.png` | the sidebar with sections, and the facility owner's Home beside it (Stage C) |
| B | `b-remove-sheet.png` | a removal sheet |
| C | `c-home-pitcher.png` | pitcher Home: line score, button, coach's note, last session with its zone plot |
| C | `c-home-parent.png` | parent Home: player chip, sentence + line score, note, latest report |
| C | `c-home-coach.png` | coach Home: three numbers, button, roster line score, needs your attention |
| C | `c-line-score.png` | the line score at full size |
| D | `d-getting-started.png` | the getting-started card on a coach's Home |
| E | `e-history-zones.png` | History bars with the small heat picture |
| E | `e-zone-large.png` | the dot plot at full size |
| E | `e-recap.png` | the recap screen |
| F | `f-pitcher-card.png` | the pitcher card |
| F | `f-milestones.png` | milestone banner, weekly run, recent list |
| G | `g-sidebar-standard.png`, `g-sidebar-facility.png` | the menu in Knuckleball's colors and in a facility's |

Not drawn, so the stage's preconditions report sketches them first: the sidebar as an icon rail (501 to 860px),
the roster page with its pitcher page, the Manage group, the color picker in Stage G, and softball versions.

## Color roles → app tokens

| In the pictures | Token |
|---|---|
| page background | `--bg` |
| light card | `--card`, 1px `--surface-border` |
| soft fill (secondary button, small pills, rest of a progress bar) | `--surface` |
| text, dim text, faint text / small caps labels | `--ink`, `--ink-dim`, `--ink-faint` |
| dark card, sidebar, pitcher card body, recap background | `--brand-bg` |
| scoreboard surface (line score block, recap stat tiles, card stat tiles) | `--brand-bg-deep` |
| scoreboard cell, team switcher in the sidebar, card art panel | `--brand-bg-2` |
| text on dark, dim, faint | `--on-dark`, `--on-dark-dim`, `--on-dark-faint` |
| gold fills (primary button, active menu item, totals cells, tags, medals) | `--accent`, text on it `--on-accent` |
| gold text on dark (counted days, recap numbers, callout line) | `--accent` |
| gold text on light (small labels) | `--accent-ink` |
| bottom bar | `--dock-bg`, `--dock-fg`, active item `--accent` |
| destructive button, Sign out row text | `--danger-bg` (fill), `--danger` (text) |
| "Open report ›" link text | `--brand-mid` |
| rest-day cell, done check | `--success` (text and the check's fill); the rest-day cell's pale fill is `--success` at about 15% |
| pitch chips and plot dots | `colorForType(pitcher, type)`, label color from `readableTextOn` |

## Type

- **Display:** Big Shoulders Display, uppercase, weight 800 to 900, line-height about 1. Used for page titles,
  big numbers, the line score digits, names on the card and recap, sheet titles.
- **Text and UI:** Archivo. Buttons 700. Row titles 600. Body 400 to 500.
- **Small caps labels** ("THIS WEEK · PITCHES", "NEEDS YOUR ATTENTION"): Archivo 700, uppercase,
  letter-spacing .12em, `--ink-faint` (on dark: `--on-dark-faint`). Drawn at 9px, so about 12px real.
- **Wordmark:** Black Ops One, unchanged.
- All digits that line up use `font-variant-numeric: tabular-nums`.

## Shared pieces

```css
/* values as drawn (272px phone); scale by 1.4 */
.card        { background: var(--card); border: 1px solid var(--surface-border); border-radius: 12px; padding: 10px; gap: 6px; }
.card.dark   { background: var(--brand-bg); border-color: var(--brand-bg); color: var(--on-dark); }
.btn         { background: var(--accent); color: var(--on-accent); font-weight: 700; border-radius: 10px; padding: 9px 8px; text-align: center; }
.pill        { font-size: 9px; font-weight: 700; border-radius: 999px; padding: 2px 7px; background: var(--surface); }
.pill.new    { background: var(--accent); }                      /* "New", "3 new", counts */
.pill.warn   { background: rgba(var(--accent-rgb), .3); color: var(--accent-ink); }   /* "21 days" */
.tag         { background: var(--accent); color: var(--on-accent); font-weight: 700; letter-spacing: .14em;
               text-transform: uppercase; padding: 3px 10px; transform: skewX(-10deg); }   /* slanted tag: recap label, RHP */
.list-row    { display: flex; align-items: center; justify-content: space-between; gap: 8px; padding: 6px 0;
               border-top: 1px solid var(--surface-border); }    /* first row has no top border */
.list-row .title { font-weight: 600; }  .list-row .meta { color: var(--ink-faint); font-size: 10px; }
```

Use the app's existing button, tray and card classes where they already give this look (`css/components.css`,
`buttons.css`); the block above describes the result, not new class names to add.

## Stage A

**Bar** (`a-phone-bar.png`): today's dock (`--dock-bg`, 18px radius, floating 10px off the edges), five equal
items, icon above an 8.5px label (12px real), 600 weight. Active item: icon and label in `--accent`. Keep the
existing glide pill and drag behavior. Icons are inline SVG, 18px, stroke 1.8, round caps and joins, no fill:

```html
<!-- viewBox 0 0 24 24, fill none, stroke currentColor -->
<!-- Home    --> <path d="M3 11l9-7 9 7v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/>
<!-- Chart   --> <rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 4V2.5h6V4M9 10h6M9 14h6M9 18h3"/>
<!-- History --> <path d="M4 20V10M10 20V4M16 20v-8M21 20H3"/>
<!-- Roster  --> <circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c.6-3.6 3.2-5.5 6.5-5.5s5.9 1.9 6.5 5.5M16 5a3.3 3.3 0 0 1 0 6.4M18 14.8c2 .7 3.2 2.4 3.6 5.2"/>
<!-- More    --> <path d="M4 7h16M4 12h16M4 17h16"/>
<!-- Chat    --> <path d="M4 5h16v11H9l-5 4z"/>
<!-- Help    --> <circle cx="12" cy="12" r="9"/><path d="M9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.7.4-1 1-1 1.7M12 17h.01"/>
```

Keep an existing `DOCK_ICONS` drawing where one already means the same place.

**Top right:** Chat icon (18px) with a gold count badge at its top-right corner (13px circle, 8px bold digits),
then the avatar circle (24px, `--surface` fill, 1px border, 9px bold initials). 8px between them.

**Pitcher chip:** a pill on `--card` with a 1px border, 24px avatar inside its left end, the name at 600, a small
"▾". Left-aligned above the page content.

**More** (`a-more-screen.png`): the title "MORE" in display type, then one card holding three groups. Each group:
a small-caps label, then rows of 8px vertical padding with a 1px top rule, a "›" at the right in `--ink-faint`.
"Getting started" carries a `--surface` pill with the progress ("3 of 5"). Sign out is a second, separate card,
one row, text in `--danger` at 600.

**Sheets** (`a-sign-out-sheet.png`, `b-remove-sheet.png`): the page behind dims (`--scrim`). The sheet rises from
the bottom: `--card`, 18px top corners, 14px padding, a display-type title (20px drawn), one short paragraph, then
two full-width buttons stacked: the safe choice first on `--surface`, the destructive one below on `--danger-bg`
with white text. The safe choice is never the red one. Use the app's existing sheet pattern for motion and focus.

## Stage B

**Sidebar** (`b-sidebar-ipad.png`): `--brand-bg`, full height, 14px/12px padding, text `--on-dark-dim`.

- Wordmark at the top in `--on-dark`.
- Team switcher: a `--brand-bg-2` block, 10px radius, team name at 600 in `--on-dark`, the sport under it small
  and dim, "▾" at the right.
- Items: icon + label, 600, 7px/6px padding, 8px radius. **Active item: `--accent` fill, `--on-accent` text.**
- History's children (Sessions, Trends) are indented to line up with the labels, weight 500, no icon.
- Section label ("FACILITY"): small caps, `--on-dark-faint`.
- Counts sit at the right of their row as gold pills ("3 new", "2").
- Foot, pushed to the bottom with a hairline above it (`rgba(255,255,255,.1)`): Help, then the account row with
  the avatar, the name and "▸".

## Stage C

**Line score** (`c-line-score.png`, and inside the three Home pictures). The signature piece; match it closely.

```css
.linescore       { background: var(--brand-bg-deep); color: var(--on-dark); border-radius: 12px; padding: 10px; gap: 6px; }
.linescore .grid { display: grid; gap: 3px; text-align: center;
                   grid-template-columns: repeat(7, 1fr) 6px 1.25fr 1.25fr;   /* seven days, a gap, P, S */
                   font-family: 'Big Shoulders Display'; font-weight: 800; font-variant-numeric: tabular-nums; }
.linescore .hd   { font-family: Archivo; font-size: 8px; font-weight: 700; letter-spacing: .1em; color: var(--on-dark-faint); }
.linescore .c    { background: var(--brand-bg-2); border-radius: 4px; font-size: 17px; line-height: 1.5; color: var(--on-dark-dim); }
.linescore .c.hit   { color: var(--accent); }                               /* a day with pitches */
.linescore .c.tot   { background: var(--accent); color: var(--on-accent); } /* P and S totals */
.linescore .c.today { outline: 1.5px solid var(--accent); outline-offset: -1.5px; }   /* shows "–" until charted */
/* one row per pitcher (coach, owner): a name column first, no S column */
.linescore .grid.team { grid-template-columns: 5.5fr repeat(7, 1fr) 6px 1.4fr; }
.linescore .grid.team .c    { font-size: 13px; line-height: 1.7; }
.linescore .grid.team .name { text-align: left; padding-left: 6px; color: var(--on-dark); overflow: hidden; white-space: nowrap; }
```

- Header row inside the block: a small-caps label at the left ("THIS WEEK · PITCHES"), the date range at the
  right. Day letters S M T W T F S above the cells; "P" and "S" above the totals.
- A zero day shows "0" in the dim color, not a blank.
- The roster version uses last names; a long name is cut with no wrap. Rows are tappable and at least 44px tall
  on the real screen even though the drawing is tighter.
- For a table this must also read correctly to a screen reader: real row and column headers, not only a grid of
  spans.

**Pitcher Home** (`c-home-pitcher.png`), top to bottom with 8px gaps (11px real): line score, full-width gold
"Chart today", the note card, the last-session card.

**Coach's note:** `--card` with a 4px `--accent` bar down its left edge and square left corners (0 12px 12px 0);
a small-caps line "COACH ORTIZ · NOV 10"; the note in 13px 600 inside curly quotes. On a parent's Home the label
reads "FOR NOAH · FROM COACH ORTIZ · NOV 10".

**Last session:** the plot (92px drawn) at the left; at the right the title at 700, a faint meta line
("31 pitches · 58% accuracy"), the pitch chips, then "Open report ›".

**Parent Home** (`c-home-parent.png`): the player chip; then the line score block with a sentence above the
cells in display type, sentence case, about 19px drawn ("Noah threw 68 pitches in 2 sessions this week.").

**Coach Home** (`c-home-coach.png`): three equal tiles in a row. Each: small-caps label, then a display number
(26px drawn); "2 of 5" sets "of 5" small beside the number. **The first tile is dark** (`--brand-bg`); the other
two are light cards. Then "Start a session", the roster line score, then "Needs your attention": rows with a
title, a faint second line, and a pill at the right (gold "New", pale-gold "21 days").

**Owner Home** (`b-sidebar-ipad.png`): a display title ("THIS WEEK AT THE LAB"), the three tiles all light, then
two columns: "Needs your attention" at the left, the roster line score at the right.

## Stage D

`d-getting-started.png`: a light card at the top of Home. Header row: "GET STARTED" in display type (18px drawn)
and, at the right, small caps "3 OF 5 · HIDE". A 6px progress bar: `--surface` track, `--accent` fill, fully
rounded. Steps as rows: a 16px circle at the left (done: filled green with a white check; not done: a 1.5px
`--ink-faint` ring), the label, a "›" on steps not yet done. **The next step to do is bold with a faint hint
line under it.** Done steps keep normal weight and are not struck through.

## Stage E

**History picture** (`e-history-zones.png`): 46px square (64px real) at the left of each session's bar, 6px
radius. A 5×5 grid on `--surface`; the inner 3×3 on `--card` with a 1.6px `--ink` frame; thin grid lines. Each
cell that has pitches is filled with one green (`--brand-mid`) at an opacity from .18 to 1.0 by its share of the
busiest cell. No dots, no numbers.

**Dot plot** (`e-zone-large.png`): what `renderHistoryPlot` already draws. Use it as it is.

**Recap** (`e-recap.png`): the whole screen is `--brand-bg` with `--on-dark` text.

```css
.recap-label { /* "FINAL · BULLPEN" */  /* the slanted .tag above, 10px drawn */ }
.recap-name  { font-family: 'Big Shoulders Display'; font-weight: 800; text-transform: uppercase; font-size: 30px; line-height: 1; }
.recap-stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 6px; }
.recap-stats > div  { background: var(--brand-bg-deep); border-radius: 8px; padding: 8px 4px; text-align: center; }
.recap-stats b      { display: block; font-family: 'Big Shoulders Display'; font-weight: 900; font-size: 34px; line-height: .95;
                      color: var(--accent); font-variant-numeric: tabular-nums; }
.recap-stats span   { font-size: 8.5px; letter-spacing: .1em; text-transform: uppercase; color: var(--on-dark-faint); }

@media (prefers-reduced-motion: no-preference) {
  .recap-label        { animation: recap-slide .5s ease-out both; }
  .recap-stats > div  { animation: recap-rise .45s ease-out both; }
  .recap-stats > div:nth-child(2) { animation-delay: .12s; }
  .recap-stats > div:nth-child(3) { animation-delay: .24s; }
  @keyframes recap-slide { from { transform: translateX(-30px) skewX(-10deg); opacity: .2; } to { transform: skewX(-10deg); opacity: 1; } }
  @keyframes recap-rise  { from { transform: translateY(10px); opacity: .3; } to { transform: none; opacity: 1; } }
}
```

- The three numbers count up from 0 over 700ms with `requestAnimationFrame`, a "%" kept on the one that has it.
  Under reduced motion they show their final value at once and nothing slides.
- Top row: wordmark at the left, date and time at the right in small caps.
- Middle: the dot plot on a dark ground (outer `--brand-bg-2`, zone a shade lighter, white 1.6px frame, faint
  white grid lines) at the left; at the right one line per pitch type: its chip, then "18 · 67%" (count, accuracy)
  in `--on-dark-dim`; under them the callout in `--accent` at 700, only when true.
- Bottom, pinned: "Send report" (gold), "View report" (`rgba(255,255,255,.12)` fill, white text), then "Done" as
  plain centered faint text.

## Stage F

**Card** (`f-pitcher-card.png`): 250px wide drawn; keep it a fixed-proportion card, not full width.

```css
.pcard      { background: var(--brand-bg); color: var(--on-dark); border: 3px solid var(--accent); border-radius: 16px;
              padding: 10px; gap: 8px; box-shadow: 0 10px 26px rgba(var(--ink-rgb), .28); }
.pcard .art { height: 150px; border-radius: 10px; position: relative; overflow: hidden; display: grid; place-items: center;
              background: repeating-linear-gradient(115deg, rgba(255,255,255,.05) 0 14px, transparent 14px 28px), var(--brand-bg-2); }
.pcard .no  { font-family: 'Big Shoulders Display'; font-weight: 900; font-size: 120px; line-height: .8; color: rgba(255,255,255,.14); }  /* uniform number, behind */
.pcard .ini { position: absolute; font-family: 'Big Shoulders Display'; font-weight: 900; font-size: 54px; }                             /* initials, or the photo */
.pcard .hand{ position: absolute; top: 8px; right: 8px; /* the slanted .tag: "RHP" / "LHP" */ }
.pcard .fac { position: absolute; bottom: 8px; left: 10px; font-size: 9px; letter-spacing: .12em; text-transform: uppercase; color: var(--on-dark-dim); }
.pcard .name{ font-family: 'Big Shoulders Display'; font-weight: 900; text-transform: uppercase; font-size: 28px; line-height: .95; }
.pcard .stats      { display: grid; grid-template-columns: repeat(4, 1fr); gap: 4px; text-align: center; }
.pcard .stats > div{ background: var(--brand-bg-deep); border-radius: 6px; padding: 5px 2px; }
.pcard .stats b    { display: block; font-family: 'Big Shoulders Display'; font-weight: 800; font-size: 20px; line-height: 1; color: var(--accent); }
.pcard .stats span { font-size: 8px; letter-spacing: .08em; text-transform: uppercase; color: var(--on-dark-faint); }
```

- Order: art panel, name, pitch chips, four stat tiles, then a foot row with the wordmark at the left and
  "knuckleballonline.com" at the right in faint text.
- With a headshot, the photo fills the art panel (cover) and the number stays visible as a small slanted tag
  beside the hand tag. With no uniform number, the big digits are simply absent.
- With no velocity readings there are three tiles, not four with a dash.
- The shared PNG (after J2) is this card alone at 3× on a transparent or `--brand-bg` ground, drawn to a canvas.

**Milestones** (`f-milestones.png`):

- Banner: `--brand-bg` card, a 44px gold medal circle at the left (display type, e.g. "1K", with an inner ring
  `inset 0 0 0 3px rgba(var(--ink-rgb), .18)`), a bold title and a dim second line.
- Weekly run card: "4 WEEKS RUNNING" in display type, small caps "ON PLAN" at the right, then seven equal cells
  for the week. A day with a session: `--accent` fill showing the pitch count. **A rest day: pale green fill with
  "Rest" in green.** Today, before a session: `--surface` with "Today". One faint line under it: "A week counts
  when you chart at least once. Rest days keep the run going."
- Recent list: rows with a 28px medal, a title and a faint date line.

## Stage G

`g-sidebar-standard.png` and `g-sidebar-facility.png` are the same menu with two sets of values:

| | Standard | Example facility |
|---|---|---|
| sidebar ground (`--brand-bg`) | `#061A12` | `#10233F` |
| menu text (`--on-dark-dim`) | `#C2CEC6` | `#C5D3E2` |
| active item and crest (`--accent`) | `#FFB81C` | `#F26B3A` |
| text on the accent (`--on-accent`) | `#07140F` | `#FFFFFF`, picked by contrast |

Header block: a 34px rounded square crest in the accent (the logo, or initials in display type), the facility
name beside it in display type, uppercase, white; under the name "POWERED BY KNUCKLEBALL" in 8px small caps at
75% opacity; a hairline under the block. The standard menu shows the Knuckleball crest and name with no
"Powered by" line.
