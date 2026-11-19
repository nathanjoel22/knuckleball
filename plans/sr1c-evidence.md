# SR1 Stage C · The new report: tabs and the four layers · evidence (Nov 19, 2026)

**Where it was tested:**
- Branch `sr1c-report-tabs`.
- `send-session-report` deployed to **staging** only (no migration, and no page change, so no cache bump).
- The local staging site in headless Chrome at 390 and 820.

Decisions: `plans/sr1c-preconditions.md` (Joel: Q1 answered, 2–9 yes).

**Pictures (`plans/sr1c-evidence/`):**
- **Built, rendered and compared:** each file is the approved picture (left) beside the built screen at 390 (right).
  - `b01`–`b05` (pens) and `g01`–`g07` (games).
  - `pen-summary-820.jpg` is the iPad width.
- **Names:** the screens are demo-facility sessions with the pictures' made-up names swapped in ("Test Pitcher",
  "Demo Eagles", "Demo Hawks"), so no real name reaches the public repo. OCR-checked: none left.

## Acceptance checks (packet section 6)

1. **Staging, 390 and 820, both sports: PASS.**
   - **Softball:** the U15 pitcher's own login charted a 12-pitch command pen. Its report was made by History and
     opened in History's shadow root at 390.
   - **Baseball:** the demo manager's History made a Live Game report (Nov 5 game), opened in report.html at 820.
     The demo pen and game were also rendered at 390 for the pictures.
2. **Side by side with the pictures: PASS, with the differences below.** The order, surfaces, type roles and colour
   roles follow each picture.
   - **Every picture:**
     - The date keeps its year.
     - The game header has no "#21" because the demo players have no number.
   - **Drawn but not built in SR1 Stage C:**
     - the yellow focus card and the facility plan card (the coach-note packet);
     - the 7-day and rest cards (Stage D).
   - **`b01` / `b05`:**
     - The tile's "Pitches" change is grey, not green: more pitches isn't better, and nothing is graded.
     - The demo team is college, so there's no "Year ago" (`b05` shows the 1-month thin window, "1 pen" in the
       caption and "only 1 pen · needs 3" on the tiles of a thinner pitcher). The softball report (high school & up)
       shows "Year ago".
   - **`b02`:**
     - The pitch table says "vs avg" and follows the window (packet).
     - Below the drawn cards, today's per-batter-side blocks (with the U14 grids) and the location chart are kept,
       in their current style.
   - **`b03`:** the table is today's velocity depth and pitch mix merged (avg · range · mix). The delivery card
     carries the windup / stretch split and times to home.
   - **`b04`:** the velocity line is the pens' average of all pitches, labelled "Avg mph", because the Trends history
     the app sends has no per-type speed. Pens under 10 pitches are left out, as in the baselines.
   - **`g02`–`g06`:** every section today's game report has is kept inside its tab, in its current style, after the
     drawn cards. The full pitching line opens Every pitch (question 6).
   - **`g07`:** the demo team is college, so `g01` and `g07` are the same screen: no "Year ago", with the
     college-only window buttons.
   - **Softball:** the softball report shows the navy band, pink tag and underline, the blue window button and the
     softball tile colours, with no baseball colour.
3. **Reports sent before the stage are unchanged: PASS.** The two staging reports hashed before Stage A still hash
   the same (`38f1a1d4…`, `b8c11dae…`). Nothing re-renders a stored report.
4. **Checks, cache, STATUS, CLAUDE.md: PASS.**
   - The pre-push checks pass.
   - No `.html` changed, so there's no cache bump.
   - STATUS.md has an entry, and CLAUDE.md gains "Reports, answer-first", both in this PR.
10. **Tabs switch in report.html and History (phone and iPad), two reports at once, and the fallback: PASS.**
    - **report.html (820, a game):** labels Summary · Location · Batters · Pitch types · Trends · Every pitch. Each
      click shows exactly its panel (1 → 6).
    - **History (390, softball pen, shadow root):** real taps on Command → panel 2, Trends → 4, Summary → 1, "1 mo" →
      the 1-month tiles, "Season" → the season tiles.
    - **No shadow root, two new reports in one page:**
      - `attachShadow` was removed and the softball pen and the baseball game drawn side by side: radio groups
        `kt-902652b6`, `kw-902652b6`, `kt-df1a4007`, `kw-df1a4007`.
      - Switching the pen's tab and window left the game's inputs unchanged, and the reverse.
      - Every tab and window id is unique. The ids that repeat are the field drawing's SVG gradients
        (`kbsun`, `kbpl`, …), which today's game reports already repeat 8 times within one report.
11. **Each window changes the tiles; the numbers match Stage B's function: PASS.** The Nov 5 demo game, as its
    coach:

    | Window | `session_baselines()` avg (n) | Tile |
    |---|---|---|
    | 3 mo | strike 73.6, first-pitch 73, in zone 63.6 (3 games), no range | −6 pts vs avg 74% · +7 pts vs avg 73% · −3 pts vs avg 64%, no bar |
    | 12 mo | strike 70.2, first-pitch 70.1, in zone 58 (5 games); ranges 66.7–80.2, 59–88.6, 52.6–70.8 | −2 vs 70% normal 67–80% · +10 vs 70% normal 59–89% · +3 vs 58% normal 53–71% |

    The captions read "… 3-month average · 3 games · default" and "… 12-month average · 5 games". College: no Year
    ago button.
12. **What stood out: PASS** (synthetic pens through `buildReportHtml`; output kept in the scratchpad):

    ```
    above range: 1 item(s)        above: On the spot 100% (12 of 12), above Sam's normal range (20–30%).
    below range: 1 item(s)        below: Strikes 0% (0 of 12), below Sam's normal range (80–90%).
    misses one way: 1 item(s)     below: Curveball: 6 of 6 misses went up. Only 2 of 8 hit the spot.
    fastball fade: 1 item(s)      note:  4SFB dropped 3 mph over the last 10 (80 → 77).
    everything at once: 3 item(s) (misses, on the spot, pitches; the fade is the smallest and drops out)
    no hand set: 1 item(s)        below: Curveball: 6 of 6 misses went to the right. …
    ```

13. **No he / his / him in a softball and a baseball stored file: PASS.** Text without the stylesheet, word-matched: 0
    and 0. The two runner lines in the pitching line now read "when the pitcher came out" and "in this line's R".
14. **Sizes: PASS.** The same sessions were rendered with main's code and with this branch's:
    - the demo pen 112,503 → 111,196 bytes;
    - the demo game 298,196 → 305,452 bytes (+2.4%).

    Far under the packet's "stop if it doubles". The preconditions' "29 KB / 68 KB" were small staging test sessions,
    not like for like.

## Deviations (also in STATUS)

- **The B1 / G2 "best / toughest of the last six" headlines need 3+ earlier same-kind (same-tag) sessions of 10+
  pitches.** The demo data reached the other rules, so the pictures show B3 / G3 headlines; the rules are in
  `template.ts` / `template_game.ts` (`penHeadline`, `gameHeadline`).
- **The no-shadow fallback** draws a report without its stylesheet, as it did before Stage C. Every panel shows, and
  the radio buttons are visible. Nothing collides.
- **Printing** shows the open tab only until Stage G.
- **The tile's change** is measured from the average as shown (so "+1 vs avg 75%" can't happen). Ranges are whole
  numbers for % and pitches, one decimal for mph.

## Production (Joel's)

1. `supabase functions deploy send-session-report --project-ref fkgccjhuimkkbupbanxp` (no migration; Stage B's
   function is already on production).
2. Merge.

New reports made after the deploy use the new layout; every report already made stays as it is.
