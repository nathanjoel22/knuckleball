# SR1 Stage G · Print · evidence (Nov 19, 2026)

**Where it was tested:**
- Branch `sr1g-print`. No cache bump: no `.html` file changed.
- `send-session-report` deployed to **staging** only (version 87). No migration.
- Chrome (headless, Save as PDF on Letter paper):
  - demo reports rendered with this branch's code;
  - one real stored staging report, printed through the local staging site's `report.html`.

Decisions: `plans/sr1g-preconditions.md` (Joel: yes to all).

**Files (`plans/sr1g-evidence/`):**
- `pen-coach-pages.jpg`, `game-coach-pages.jpg`, `staging-pen-pages.jpg`: every printed page, side by side.
- The PDFs:
  - `pen-college-coach`, `game-hs-coach`;
  - `pen-hs-player`, `pen-ll-player`, `game-ll-parent`;
  - `staging-pen-coach`, `staging-pen-player` (the stored staging report through report.html, `&v=player` for the
    second).
- Demo names are swapped as in Stages C–F. A scan of the PDFs' text finds no real name, only "Test Pitcher", "Demo
  Eagles", "Demo Hawks" and the staging test pitcher.

## Acceptance checks

1. **Staging: PASS.**
   - The U15 softball pitcher's own login (390, iPhone size) charted a 12-pitch command pen. It synced, and its
     report was made by the app (`e899d736…`, file `c701c6b9…`).
   - That report was printed through `report.html?r=…`, as coach and as player (`&v=player` → `kr-as-player`).
   - Softball tokens throughout.
2. **Side by side with the pictures:** there are none for Stage G (the packet). The printed pages match section 3's
   sketch, with these differences:
   - Command runs to three pages in the demo pen (four types, both batter sides): the "by batter side" grids are tall.
   - A game's Batters and Every pitch tabs run to several pages each, as the sketch allowed.
   - The coach game's Summary ends with the 7-day card on page 2.
3. **Reports sent before the stage are unchanged: PASS.**

   ```
   25629f55… (Stage F test)  last-modified Thu, 19 Nov 2026 19:25:18 GMT  sha256 43451c8f119b13fb…  print titles: 0
   ab6c9953… (Stage E)       last-modified Thu, 19 Nov 2026 19:08:15 GMT  sha256 705c530312452fd5…  print titles: 0
   ```

   - Both were stored before this deploy, and nothing rewrites them.
   - Printed through report.html, `25629f55…` still gives 1 page, the open tab only (as before).
4. **Checks, cache, STATUS, CLAUDE.md: PASS.** Pre-push checks pass. No cache bump (only the function changed).
   STATUS and CLAUDE.md are in this PR.
22. **Printing gives one page per tab, nothing split inside a card: PASS (Chrome); Safari on iPhone: Joel's.**

    | Report · version | Pages | Tabs printed, each from a new page |
    |---|---|---|
    | demo pen · coach (college) | 6 | Summary · Command (3) · Velocity & workload · Trends |
    | demo pen · college player | 6 | the same, in "you" |
    | demo pen · high school player | 6 | Summary · Command · Velocity · Progress |
    | demo pen · little league player | 3 | Summary · Where it went · Progress |
    | demo pen · little league parent | 2 | Summary · Progress |
    | demo game · coach (high school) | 18 | Summary · Location · Batters · Pitch types · Trends · Every pitch |
    | demo game · high school player | 15 | Summary · Location · Batters · Progress |
    | demo game · little league player | 4 | Summary · Where it went · Progress |
    | demo game · little league parent | 5 | Summary · Progress |
    | staging pen · coach / player | 5 / 5 | Summary · Command (2) · Velocity (& workload) · Trends / Progress |

    - **Read in the print media, for every version:**
      - the tab row and the window switch are `display: none`;
      - only that version's panels show, as the table above;
      - pages 2 onward carry the title, e.g. "COMMAND · TEST PITCHER · BULLPEN · NOV 1, 2026 · COMPARED WITH 3
        MONTHS". A high school player's reads VELOCITY and PROGRESS, a little league parent's PROGRESS.
      - The little league player's printed pages hold no velocity: the only match is the note "No velocity on this
        version".
    - **No split inside a card, tile row, chart, table row or at-bat line** (checked on every page image):
      - A tall older section (the Command tab's "By batter side") may continue onto the next sheet, between its blocks.
      - The first build kept those sections whole, which left page 3 of the demo pen nearly blank. Now they continue
        between blocks; the blocks themselves still never split.
    - **The window:** whatever is chosen on screen prints (3 months by default) and is named in every page title.
    - **Safari on iPhone (Share → Print):** Joel, on the staging report links below.

**On screen, nothing changed (10 reports, 108 views):**
- Each version of each demo report was rendered with main's code and with this branch at 390.
- Every visible tab was clicked under the 1-month, 3-month and season windows. The page text and height were identical
  every time.
- The print titles exist on screen but are hidden.
- **History:** the report drawn in its shadow root shows the tab row. The three print titles are `display: none`, and
  only Summary is open.

**Size:** each new report grows by about 2.5 KB (pen 122.9 → 125.4 KB) to 3.3 KB (game 316.3 → 319.6 KB): the CSS,
plus one title line per tab.

## Found, not changed (for Joel)

- **Report dates are in UTC.** The report header's date (`penDate` / `gameDate`) is formatted on the server without a
  time zone, so it's UTC.
  - A session charted after about 7–8 pm Eastern shows the next day: the staging pen charted at 7:30 pm on Nov 19
    reads "Nov 20, 2026".
  - It predates SR1: v360's templates did the same.
  - The window captions and rest dates already use Eastern time.
  - A small fix (Eastern, like the rest) is a separate change. Reports already sent keep their date.

## Staging test data

- The U15 softball pitcher has one more command pen (12 pitches, `e899d736…`) with a Stage G report.

## Production (Joel's)

1. `supabase functions deploy send-session-report --project-ref fkgccjhuimkkbupbanxp` (no migration).
2. Merge (no cache bump).

Either order works: the function alone changes only new reports.
