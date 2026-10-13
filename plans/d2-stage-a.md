# D2 Stage A evidence (Oct 13, 2026), branch `d2-broadcast-rebrand`, v228

Spec: `plans/d2-broadcast-rebrand.md` Stage A, with Joel's answers in `plans/d2-preconditions.md`.

## Acceptance

**1. Grep.** No old theme hex (`#0F241B #E8A83D #F5C365 #C9A227 #234B6E #F2A7C3 #E27BA2`) is left in any app page outside the Live Game field art (`.gg-field --gg-*`, `bullpen-tracker.html` 148 and 1525).

These are left by rule:
- `send-session-report` templates: Stage D restyles the reports.
- `docs/` reference files.

**2. Palette check.** The 16 colors are identical, in order, in `SPORTS[sport].palette`, `helpers.ts` `TYPE_PALETTE_HEX` / `SPORT_PALETTE_HEX` and `css/tokens.css` `--pitch-1..8`. `.githooks/pre-push` now runs this on every push. Tested both ways: it passes on the real files and rejects a one-character change in `--pitch-7`.

**3. Screenshots.**
- App: 38 states × baseball and softball × 390 / 820 / 1180 px (114).
- Pages: 14 pages × 2 sports × 390 / 820 / 1180 px (84).
- The 390 px shots were taken in a 390 px frame, so the phone layout is real.
- Spot-checked:
  - phone bullpen (baseball);
  - softball Live Game field step (phone);
  - coach Home (iPad);
  - softball sign-in;
  - "Which sport?".

**4. Contrast (WCAG 2.1; AA = 4.5:1 text, 3:1 large text and marks).**

Light app, from the target file:

| Pair | Baseball | Softball |
|---|---|---|
| ink on page | 17.2 | 14.5 |
| faint text on white | 6.2 | 5.3 |
| faint text on soft fill | 5.3 | 4.6 |
| faint on brand | 5.9 | 5.5 |
| accent text on white | 5.9 | 6.7 |
| text on the primary button | 10.9 | 5.1 (navy on pink) |
| danger on soft fill | 4.8 | (same) |
| white on danger | 5.7 | (same) |
| warning on white | 5.4 | (same) |
| success on white | 5.0 | (same) |
| links / focus on white | 8.3 | 6.9 |
| white on strike / ball flash | 4.4 / 4.2 | (same; large 24 px bold letters) |

New in Stage A:

| Pair | Ratio |
|---|---|
| throws tag `--accent-ink` on the sidebar | 5.0 (baseball) / 5.9 (softball) |
| account chips | 15.2 / 13.6 |
| Live Game panel labels | 11.1 |

Dark sign-in look (temporary until Stage C; the target has no dark scope, so these are my values):

| Pair | Baseball | Softball |
|---|---|---|
| white on card | 15.4 | 12.6 |
| dim on card | 9.5 | 8.3 |
| faint on card | 5.0 | 5.8 (`#9FB2C6`; the light app's `#8A9BB0` would be 4.4) |
| error text `#FF7A6E` on card | 6.1 | 5.0 (the light app's red would be 2.7 there) |
| role tag (bright accent) on card | 10.1 | 5.2 |
| text on the primary button | 10.4 | 5.1 |

**Filled pitch chips** (`.pitch-chip`, the pitcher header and profile; label ink or white, picked by `readableTextOn()`):

| Sport | Result |
|---|---|
| Baseball | all 8 pass, the lowest slot 4 at 4.5 |
| Softball | all 8 pass after Joel's option (b): slots 3 and 6–8 with white text, the lowest 4.6 |

**Escalation: three softball chips fail.** With the target softball palette, slot 6 `#8E6CFF` (4.2), slot 7 `#D2553F` (4.1, white) and slot 8 `#7D8794` (4.3) are under 4.5:1 for their 10 px bold labels, whichever label color is used. Today's softball chips are 1.5–3.3, so this is better than now but still short of AA.

**Resolved (Joel, Oct 13): option (b).** `#8E6CFF`→`#7A53FF`, `#D2553F`→`#CD4730`, `#7D8794`→`#6C7684` (5–7 points darker, same hue). White labels 4.66 / 4.63 / 4.60; as marks on white 4.7 / 4.6 / 4.6. The options were:


- **(a)** Accept these three for now.
- **(b)** Darken those three softball colors slightly. That changes Jordan's palette, in all three places.
- **(c)** Make filled chips white with a colored dot, as U13 did for the trays.

## Deviations
- `readableTextOn()` was restored (decision 7 reversed): the filled chips use it, which the preconditions report missed.
- The notice backdrop is `--scrim` (the sport's dark) per the approved mapping. It was navy for both sports (Joel, Oct 2); the CLAUDE.md line is updated.
- Dark sign-in values that aren't in the target: card-2 `#113726` / `#1A426E`, error red `#FF7A6E`, softball faint `#9FB2C6`, glows from the new accents.
