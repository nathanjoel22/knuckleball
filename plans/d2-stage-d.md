# D2 Stage D evidence (Oct 13, 2026), branch `d2-broadcast-rebrand`

Spec: `plans/d2-broadcast-rebrand.md` Stage D. Joel's decision 6: the variable block, each report self-contained.

## What changed (send-session-report; deployed to **staging only**)
- **`helpers.ts`:**
  - `reportVars(sport)` writes ONE `:root` block of `--kr-*` variables into each new report: colors per sport (values = `css/tokens.css`) and the font stacks (Archivo, Big Shoulders Display, Black Ops One, with system fallbacks).
  - S1's softball hex swap (`SOFTBALL_THEME_SWAP`, `themedCss`) is removed.
  - The `--kr-` prefix keeps a report's variables apart from report.html's own tokens (the report is drawn inside that page).
- **`template.ts` / `template_game.ts`:**
  - The stylesheet reads only `--kr-*`.
  - The header is a `--kr-brand` band with the KNUCKLEBALL wordmark (no period), a slanted sport tag ("BASEBALL · BULLPEN", "SOFTBALL · LIVE GAME") and the pitcher's name in Big Shoulders 800 caps.
  - Big Shoulders headings and tile numbers; Archivo body; `--kr-line` rules; 12px card radius.
  - Trend line colors are D2 data colors; Strike % wears the sport's accent.
- **`svg.ts`:**
  - Every theme color is `style="…var(--kr-…)"`, because SVG presentation attributes can't read variables.
  - Chart text is in Archivo; result colors come from `helpers.ts` (swing-and-miss = the sport's accent).
  - The pitch dots keep their white outline as an attribute, so the print rule that darkens dot outlines still applies.
- **`diamond.ts`:** only the figure captions' text colors. The field art is unchanged; it matches the app's field (change both or neither).
- **Georgia is gone** from new reports.
- **CLAUDE.md:** the S1 "byte-identical" line is reworded, and Known landmine 4 now lists three places, the pre-push check and the current values.

## Acceptance
1. **New reports, rendered with the real builders:** a local harness feeds `from_rows.ts` real staging rows, read-only:

   | Report | Session | Pitches |
   |---|---|---|
   | Baseball pen | `b7f500f7` | 26 |
   | Baseball G5 game | `b035593a` | 14 |
   | Softball pen | `6077b34f` | 19 |
   | Softball game | `a04855a2` | 8 |

   Each was drawn through report.html's own draw-into-page path (a scratch copy reading a local file) at 820 px. Print preview (PDF): the pen report is 4 pages, the softball game 8; the header band and colors print.
2. **Self-contained:** every variable a new report uses is defined inside it (all four), and it uses no site token.
3. **Old reports render exactly as before.** Three stored staging reports (two games, one pen), drawn in report.html before D2 (`b86a672`) and now, at 390 and 1180 px: pixel-identical below the viewer's top bar. The one difference is report.html's own footer line under the report, which is in Archivo since Stage B. Nothing stored was touched and `rerender-reports` was not run.
4. **Pitch colors:** each report's pitch-type dots use its own sport's palette, which equals the tracker's (pre-push palette check). The trend lines and result dots use fixed data colors, the same in both sports.
5. **Contrast on the new report:**

   | Pair | Baseball | Softball |
   |---|---|---|
   | Header meta | 11.1 | 10.2 |
   | Header note | 10.4 (gold) | 6.4 (light pink `#FF79B3`; the full pink would be 4.1) |
   | Sport tag text | 10.9 | 5.1 |
   | Faint text on the page | 5.7 | 4.9 |
   | Links | 7.6 | 6.4 |
   | Chart axis labels | 5.7 | 4.9 |

   The axis labels were darkened to the faint-ink color; the old reports' axis grey was about 3:1.

## Not done / for Joel
- **Production deploy of `send-session-report` is Joel's** (the spec). Until then, production reports keep the old look.
- **`rerender-reports` bundles the same builders but was not redeployed.** It's operator-only and is never run without Joel's decision. If it is ever redeployed, it would draw re-rendered reports in the D2 look.
- **The viewer's top bar** is in baseball colors for every report, because report.html doesn't know a report's sport. That's unchanged from before; a softball report's own header is navy.
