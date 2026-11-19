# SR1 Stage E · Reader versions · evidence (Nov 19, 2026)

**Where it was tested:**
- Branch `sr1e-reader-versions`, cache `kb-shell-v363`.
- `send-session-report` deployed to **staging** only. No migration.
- The local staging site (report.html and History) in headless Chrome at 390.

Decisions: `plans/sr1e-preconditions.md` (Joel: yes to all).

**Pictures (`plans/sr1e-evidence/`):** `b08`, `b09`, `b10`, `b11`, `g09`, `g10`, `g11`, each the approved picture
(left) beside the built version at 390 (right).
- The demo facility's pen and game were rendered with this branch's code at little league and high school. The level
  and the week were set to the pictures' cases, and the pictures' made-up names swapped in.
- OCR finds no real name.

## Acceptance checks (packet section 6)

1. **Staging: PASS.** Stored reports were made through History:
   - a high-school softball pen (the U15 pitcher's own login);
   - a college demo game (the demo manager);
   - a little league pen (a test parent's player, Little Leaguer, independent, level set to Little League).
2. **Side by side with the pictures: PASS, with these differences:**
   - "today" reads "in this pen / game" (as Stage D).
   - "Best yet" is "best of the last six" (question 4).
   - The parent's rest line names the last game's date ("Sunday's game rest ends Fri, Oct 30").
   - The yellow coach's-focus card is the coach-note packet.
   - **Not drawn, built as the table says:** the college player version (the full report in "you") and the
     little-league Progress tabs.
3. **Reports sent before the stage are unchanged: PASS** (`38f1a1d4…`, `b8c11dae…`). Reports made before Stage E carry
   no `data-kr-versions`, so they show as they always did, whatever the `v` or viewer.
4. **Checks, cache, STATUS, CLAUDE.md: PASS.**
   - The pre-push checks pass, and the cache is `kb-shell-v363`.
   - report.html's CSP hash was recomputed with its own one-liner, and the page loads with no console error.
   - STATUS and CLAUDE.md are in this PR.
18. **Each `v` shows decision 10's version; the little league player version has no velocity; a college `v=parent`
    shows the coach version: PASS.**

    - **The tabs each version shows** (every version's visible labels, at 390):

      | Report | coach | player | parent |
      |---|---|---|---|
      | little league pen | Summary · Command · Velocity & workload · Trends | Summary · Where it went · Progress | Summary · Progress |
      | high school pen | (same) | Summary · Command · Velocity · Progress | → coach |
      | little league game | Summary · Location · Batters · Pitch types · Trends · Every pitch | Summary · Where it went · Progress | Summary · Progress |
      | high school game | (same) | Summary · Location · Batters · Progress | → coach |
      | college game | (same) | the same six, in "you" | → coach |

    - **report.html** (the stored high-school softball pen):
      - no `v` → coach;
      - `v=player` → `kr-as-player`, "Compared with your 3-month average";
      - `v=parent` → coach (no parent version);
      - `v=xyz` → coach.
      - College demo game: `v=parent` → coach; `v=player` → player.
    - **No velocity in the little league player version** (every tab clicked, `document.body.innerText` searched for
      "mph" / "velocity"):

      ```
      pen  Summary: velocity words: ["velocity"] (the note "No velocity on this version…")   Where it went: none   Progress: none
      game Summary: velocity words: ["velocity"] (the same note)                              Where it went: none   Progress: none
      ```

      The parent version's Progress keeps velocity (decision 10). Velocity is hidden from the player version, not
      removed from the file (question 2, accepted).
19. **History shows each viewer their version: PASS.**

    | Viewer | Report | Class on the drawn report | Tabs shown |
    |---|---|---|---|
    | the U15 pitcher's own login | high school pen | `kr-as-player` | Summary · Command · Velocity · Progress |
    | the U15 head coach | the same pen | (none) = coach | Summary · Command · Velocity & workload · Trends |
    | the parent who created Little Leaguer | little league pen | `kr-as-parent` | Summary · Progress (Workload · Last 7 days · How it went) |
    | a linked guardian (Feed Test Coach's parent role) | the same pen | `kr-as-parent` | Summary · Progress |

    The version is set each time a report is drawn, so it follows a role switch.

**Also checked:**
- **Sizes** (the same demo session, main's Stage C code → this branch):
  - pen: 111.2 KB → 121.8 KB (college) / 140.4 KB (little league, three versions);
  - game: 305.5 KB → 315.3 KB (high school) / 352.3 KB (little league).

  All under the packet's "stop if it doubles".
- **Pronouns:** no he / his / him in the stored little league, high school and college reports.

## Staging test data changed (test accounts)

- Little Leaguer (a test parent's player): level Little League, pitch mix Four Seam Fastball and Curveball, one
  command pen.
- The test parent's `email_verified_at` was set directly in staging, so the report gate lets a report be made (the
  test account had never verified).
- The U15 pitcher got one untagged pen; one demo game got a report.

## Production (Joel's)

1. `supabase functions deploy send-session-report --project-ref fkgccjhuimkkbupbanxp` (no migration).
2. Merge (`kb-shell-v363`: report.html and History).

Either order works: report.html and History apply a version only when a report carries it.
