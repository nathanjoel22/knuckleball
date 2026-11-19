# SR1 · Design reference (Nov 19, 2026)

Companion to `plans/sr1-session-reports.md`. The pictures in `docs/sr1/` are the approved look; this file gives the
values behind them. **Where the packet and a picture disagree on behavior, the packet wins. Where they disagree on
look, the picture wins.** The pitcher, team and numbers in the pictures are made up ("Test Pitcher", "Demo Eagles").

## How to read the pictures

- They are drawings of the report, not screenshots. The phone is drawn at **390px, the real width** (PNGs are 2x),
  so sizes read 1:1 in CSS pixels. Take the nearest step on the report's own scale; don't add new sizes for a
  1–2px difference.
- Order, weight, case, color roles and which surface is dark or light are exact. Pixel values are a guide.
- Every color below is a report token (`--kr-*`, `send-session-report/helpers.ts` `REPORT_VARS`). Don't copy a hex
  value out of a picture: that would break the softball report.
- The pictures show one sport (baseball). Softball uses the same layout with its own `REPORT_VARS`.

## Pictures by stage

| Stage | File in `docs/sr1/` | Shows |
|---|---|---|
| A | `b01-bullpen-coach-summary.png` | bullpen Summary tab, coach: headline, window switch, four numbers with range bars, What stood out, focus card*, 7-day card |
| A | `b02-bullpen-coach-command.png` | Command tab: hit / miss grids per pitch, pitch table, where misses went, batter side |
| A | `b03-bullpen-coach-velocity.png` | Velocity & workload tab: fastball by pitch order, pitch table, delivery |
| A | `b04-bullpen-coach-trends.png` | Trends tab: one small line per number |
| A | `g01-game-coach-summary.png` | game Summary tab, coach: headline, line strip, numbers, by inning, stood out, focus*, rest + 7-day |
| A | `g02-game-coach-location.png` | Location tab: grid by result; The pitches that mattered (kept) |
| A | `g03-game-coach-batters.png` | Batters tab: times through the order, after the first pitch, kept sections listed |
| A | `g04-game-coach-pitch-types.png` | Pitch types tab: table, fastball by inning |
| A | `g05-game-coach-trends.png` | Trends tab: small lines, bullpen-vs-game sections kept as they are |
| A | `g06-game-coach-every-pitch.png` | Every pitch tab: the at-bat log, as today |
| B | `b05-bullpen-coach-1mo-thin.png` | the 1-month window with only 2 pens: "only 2 pens · needs 3" |
| B | `g07-game-coach-college-summary.png` | college: no "Year ago" button; 7-day card under its line |
| C | `b06-bullpen-coach-ll-workload-warning.png` | the 7-day card past the line (warning state) |
| D | `b08-bullpen-player-ll-summary.png` | little league player: "you" wording, two numbers, what went well, no velocity |
| D | `b09-bullpen-player-ll-where.png` | little league player: Where it went |
| D | `b10-bullpen-player-hs-summary.png` | high school player: "you" wording, four numbers, two stood-out items |
| D | `b11-bullpen-parent-ll-summary.png` | little league parent: workload first |
| D | `g09-game-player-ll-summary.png` | little league player, game |
| D | `g10-game-player-hs-summary.png` | high school player, game |
| D | `g11-game-parent-ll-summary.png` | little league parent, game: rest first |
| E | `e01-email-coach-game.png` | coach email: headline, numbers, two items, rest, 7-day line, window, button |
| E | `e02-email-player-ll-bullpen.png` | little league player email |
| later | `b07-bullpen-coach-facility-plan.png`, `g08-game-coach-facility-plan.png` | the facility "Plan for next session" card (not in SR1; see packet section 4) |

\* The yellow "Focus for next session" card is drawn for placement only. It is built in the coach-note packet
after SR1 (packet section 4). SR1 leaves no empty space for it.

Not drawn, so the stage's preconditions report sketches them first: the iPad width of each tab (820px), the
printed pages (Stage F), the session-tag question on the start screen (Stage G), the team settings rows (Stage C)
and the parent contact field (Stage E), and softball versions.

## Color roles → report tokens

| In the pictures | Token | Baseball today |
|---|---|---|
| page background | `--kr-bg` | #F3F5F2 |
| cards, number tiles | `--kr-card` | #FFFFFF |
| card borders, table rules | `--kr-line` | #D5DDD7 |
| strike-zone cells, sunk fills | `--kr-surface` | #E8EDE9 |
| main text | `--kr-ink` | #07140F |
| secondary text | `--kr-ink-dim` | #26342D |
| captions, labels | `--kr-ink-faint` | #56645C |
| header band, tab bar, selected window button | `--kr-brand` | #061A12 |
| text on the header | `--kr-on-dark` / `--kr-on-dark-dim` | #FFFFFF / #C2CEC6 |
| sport tag, selected tab underline | `--kr-accent` | #FFB81C |
| labels on gold-tinted cards | `--kr-accent-ink` | #8A5A00 |
| "within range" band fill, 7-day bar under the line | `--kr-link` at low alpha / `--kr-link` | #16593D |

**New tokens SR1 adds** (both sports in `REPORT_VARS`; softball values proposed in Stage A's preconditions,
contrast checked at 4.5:1 for text):

| Role | New token | Baseball (from the pictures) |
|---|---|---|
| better than his average / above range | `--kr-up` | #1E8A57 |
| worse than his average / below range, warning text | `--kr-down` | #B4511B |
| neutral fact marker ("i") | `--kr-info` | #2F6FD6 |
| normal-range band | `--kr-band` | #BCD9C9 |
| warning card fill / border | `--kr-warn-bg` / `--kr-warn-line` | #FFF1E6 / #F2B48A |
| highlighted table row | `--kr-hl` | #FFF6DD |

The up / down colors carry meaning only together with a sign or an arrow (▲ ▼, "+5", "−1"), never color alone.

## Type

Report fonts as today (`REPORT_FONTS`): Big Shoulders Display for headlines and big numbers, Archivo for text,
Black Ops One for the wordmark.

| Element | Font | Size / weight | Notes |
|---|---|---|---|
| Headline sentence (Summary) | display | 25px / 800, line-height 1.02 | sentence case, not uppercase |
| Tab headline (first line of each other tab) | display | 21px / 800 | a takeaway with a number, sentence case |
| Tab labels | sans | 12.5px / 800, uppercase, 0.04em | gold 3px underline on the open tab |
| Number tile value | display | 28px / 900, tabular figures | |
| Number tile label | sans | 10.5px / 800, uppercase, 0.08em | `--kr-ink-faint` |
| Change line ("+5 pts vs avg 38%") | sans | 11.5px / 700 | `--kr-up` / `--kr-down` / faint when even |
| Window switch buttons | sans | 10.5px / 800 | 32px min height; selected = `--kr-brand` fill, white text |
| Card labels ("WHAT STOOD OUT") | sans | 10.5px / 800, uppercase, 0.12em | |
| Stood-out text | sans | 13.5px / 400, line-height 1.4 | marker square 22px, radius 6px |
| 7-day number | display | 24px / 900 | |
| Captions | sans | 12px | `--kr-ink-faint` |

## Components

- **Header:** today's header, shorter: wordmark + sport tag on one row, name 30px, one meta line (date · session tag
  · team). The tab bar sits directly under it on the same `--kr-brand` band.
- **Tabs:** a row of labels on the brand band, scrollable sideways on a phone when they don't fit. One tab open at a
  time; Summary open on load. The panel below scrolls with the page (no inner scroll box).
- **Window switch:** one bordered row of 4–5 equal buttons (1 mo, 3 mo, 12 mo, Season, Year ago), radius 9px.
  Under it one caption line: "Compared with <first name>'s 3-month average · 11 pens · command pens only · default"
  (the pictures say "his"; packet decision 16 removes gendered pronouns).
- **Number tile:** label, value, change line, then a range bar (track `--kr-line`, band `--kr-band`, dot
  `--kr-ink`, or `--kr-up` / `--kr-down` when outside the band) and "normal 33–44%". With fewer than 5 sessions,
  no bar and no "normal" line; with fewer than 3, the change line reads "only 2 pens · needs 3".
- **What stood out:** a card of up to three rows, each a colored square (▲ up, ▼ down, i info) and one sentence.
  Caption under it: "Always judged against the 3-month default, so it doesn't change with the toggle."
- **7-day card:** label "LAST 7 DAYS", the count, a thin bar with a tick at the guideline, one sentence. Over the
  line: `--kr-warn-bg` fill, `--kr-warn-line` border, label in `--kr-down` with ⚠.
- **Rest card (games):** the brand band as a card: "REST · PITCH SMART AGES 15–16", "4 days · back Fri, Nov 20",
  one line under it.
- **Line strip (games):** six cells IP · P · K · BB · H · R in one bordered row.
- **Footer line:** "Numbers and patterns only: compared with his own sessions, never graded." (see packet decision 4
  for the exact wording rule).

## Motion

None. Tabs switch without animation.
