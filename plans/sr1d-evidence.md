# SR1 Stage D · Workload, rest and team settings · evidence (Nov 19, 2026)

**Where it was tested:**
- Branch `sr1d-workload`, cache `kb-shell-v362`.
- Migration `20261125000000_sr1d_workload` on **staging** only, recorded in staging's migration history.
- `send-session-report` deployed to staging.
- The local staging site in headless Chrome at 390.

Decisions: `plans/sr1d-preconditions.md`.
- Joel: "leave softball alone, pitch count rules don't apply there". Softball gets no age group, no rest card and no
  7-day card. The confirm prompt still asks softball teams for the level only.
- Questions 2–6 as recommended.

**Pictures (`plans/sr1d-evidence/`):** `b06`, `g01`, `g07`, each the approved picture (left) beside the built Summary
at 390 (right).
- The demo sessions were rendered with this branch's code. The pictures' made-up names were swapped in, and OCR finds
  no real name.
- The week is set to the pictures' cases:
  - `b06` / `g01`: high school, ages 15–16, 135 pitches;
  - `g07`: college, ages 19–22, 70 pitches, under the line.

## Acceptance checks (packet section 6)

1. **Staging, 390: PASS.**
   - **Baseball head coach** (the demo facility's manager): the confirm card on Home; the age group in Account → Team.
   - **Softball head coach** (U15 Softball Test): the level-only card.
   - **Baseball pitcher's own login** (a demo pitcher): Pitcher settings → age group.
   - **Reports** made through History's "Create report" for a demo game and pen.
2. **Side by side with the pictures: PASS, with these differences:**
   - "today" in the 7-day sentence reads "in this pen" / "in this game", because a report is read days later.
   - The rest card's second line is "N game pitches." The picture's "(decision 5)" note was a design note.
   - The yellow focus card is the coach-note packet, not SR1.
3. **Reports sent before the stage are unchanged: PASS** (`38f1a1d4…`, `b8c11dae…`, the same hashes as before Stage A).
4. **Checks, cache, STATUS, CLAUDE.md: PASS.**
   - The pre-push checks pass, and the cache is `kb-shell-v362`.
   - STATUS has an entry and CLAUDE.md a "Workload, rest and level" section, both in this PR.
   - No new served file.
15. **The age group saves for a team (head only) and a solo pitcher; the confirm prompt shows once and never after:
    PASS.**
    - **The database** (`supabase/tests/sr1d_workload.sql`, staging, rolled back, 0 fails):

      ```
      15a head sets 15-16:15-16 | softball team:baseball_only | not a group: check constraint
      | confirmed before:no  level set -> confirmed:true | stranger:not authorized | pitcher own:17-18
      | pitcher on team:not authorized
      ```

    - **In the app:**
      - The demo manager (head, never confirmed) saw "Confirm your team's level" with Level of play and Pitch Smart
        age group. Saving College / 19–22 stored `level = college`, `pitch_smart_age = 19-22` and a confirmation
        stamp, and the card was gone after a reload.
      - The softball head coach saw the card with the level only. **Not now** hid it on that device; the team stays
        unconfirmed in the database.
      - A demo pitcher's Pitcher settings show the age group: saved 19–22, then set back to "not set".
      - An assistant (Feed Test Coach) sees no card.
16. **Rest dates at the band edges: PASS** (`deno run scripts/sr1d-check.ts`, through the report's own code, 0
    fails):

    ```
    13-14, 50 / 51 pitches: 2 / 3      15-16, 75 / 76: 3 / 4      19-22, 105 / 106 (above the table): 4 / 4
    7-8, 20 / 21: 0 / 1                17-18, 80 / 81: 3 / 4
    4 days after Sun, Nov 15: "Fri, Nov 20"     0 days: "Mon, Nov 16"
    over the daily max says so, never "can't"   softball: no rest card, no 7-day card
    ```

    **A stored report:** the Oct 17 demo game (Sat, 34 pitches, ages 19–22) reads "1 day · back Mon, Oct 19".
17. **The 7-day count equals `pitcher_workload`; the warning shows just over the line: PASS.**
    - **The database:** `session_workload` 83 = `pitcher_workload` 83 (a pen of 30 six days back plus the game's 50
      with +3; the 40 eight days back left out). A pen saved after the game leaves it at 83. A stranger gets
      `not_found` and no age group.
    - **The report:** for each level, the line minus one and the line itself show no warning, and the line plus one
      shows it (99 / 100 / 101, 124 / 125 / 126, 149 / 150 / 151). The wording never says "can't".
    - **Stored reports:** "34 pitches · 34 in this game, nothing else in the last 7 days. Guideline for college:
      about 150 in 7 days."

**Also checked:**
- Policies 32 public / 12 storage.
- The migration and rollback were dry-run together first. The rollback returned `set_team_level` to its checksum and
  dropped every new column.

## Staging test data changed (test accounts)

- The demo facility's baseball side: level confirmed (College, unchanged), age group 19–22.
- Two demo sessions gained reports (Oct 17 game, Oct 27 pen).

## Production (Joel's)

1. Backup.
2. `supabase db push --project-ref fkgccjhuimkkbupbanxp`: runs only `20261125000000_sr1d_workload`.
3. `supabase functions deploy send-session-report --project-ref fkgccjhuimkkbupbanxp`.
4. Merge (`kb-shell-v362`).

**The database must go first:** the report function and the app read the new columns and functions.
