# SR1 Stage E · Reader versions · preconditions (Nov 19, 2026)

Read at `049e2dc` (main: SR1 A–D on production, v362). **Branch:** `sr1e-reader-versions`, from `origin/main`.

**Pictures:** `b08` (little league player, pen), `b09` (little league player, Where it went), `b10` (high school
player, pen), `b11` (little league parent, pen), `g09` (little league player, game), `g10` (high school player,
game), `g11` (little league parent, game).

**No migration.** Stage E is the report function, report.html and History.

## 1. What changes, where it is now

| Where | Now | Stage E |
|---|---|---|
| `send-session-report/template.ts`, `template_game.ts`, `sr1.ts` | one coach version | the same file also carries its level's player (and, for little league, parent) Summary and tab set. Shared tabs are written once; only what differs is added (section 3). |
| the report's level | `session_baselines().level` / `session_workload().level`, already read at save | decides which versions the file carries (`data-kr-versions` on `.page`) |
| `report.html` (L104 script, CSP hash L12) | shows the stored file | reads `&v=coach\|player\|parent` and puts `kr-as-<v>` on `#kb-report` when the file carries that version; otherwise coach. The CSP hash is recomputed (the file's own one-liner). |
| History (`feedReportHost`, tracker L16705) | draws the file in a shadow root | puts the viewer's class on the `.kr-body` it draws into (section 3) |
| `sw.js` | `kb-shell-v362` | `v363` (report.html and the tracker change) |

**How the switch works, with no script in a stored report:**
- **The selector:** one class on an ancestor (`kr-as-player` / `kr-as-parent`; none = coach) shows that version's
  pieces and hides the coach's. The rules are inside the stored file, so they work in report.html and in History's
  shadow root alike.
- **Tabs:** every version keeps Summary as tab 1, with its own content inside. Its other tabs are the shared panels
  plus, for little league, two new panels (Where it went, a velocity-free Progress).
- **No-shadow fallback:** as today, the file draws unstyled (everything visible).

**Where the packet doesn't match the repo:**

1. **"No velocity anywhere" for a little league player is a display rule.** The one stored file still holds the
   coach version's velocity, hidden by CSS from the player version (the packet's "one stored file holds the versions
   … nothing is fetched later"). Anyone reading the file's source could see it. See question 2.
2. **High school parents:** decision 10 says "email summary only" (Stage F). A `v=parent` link or a parent in History
   still needs to show something. See question 1.
3. **Softball:** Stage D left softball without the rest and 7-day cards (Joel). The little league parent version
   leads with them, so softball's opens with "How it went".
4. **Softball's "High school & up"** follows the high school row (Stage B answer 4). College softball sits there
   until softball gets a college level.

## 2. CLAUDE.md decisions this stage touches

| Recorded now (quoted) | New rule beside it |
|---|---|
| Reports "content frozen at save time … Anyone with the link can view" | Unchanged. A link's `&v=` picks which of the frozen versions shows; the file is the same. |
| SR1 C: "No he / his / him in report text" | Player versions speak in "you" ("your normal range", "Your best command pen of the last six"). Coach and parent versions keep the first name. |
| SR1 D: the 7-day card's wording | A little league player's reads "That's more than the 100 guideline. Talk with your coach about rest." (packet). Under the line: "Guideline: about 100 in 7 days." |

## 3. What differs by version and level (for your yes)

Who sees which version **in History**:
- **player:** a pitcher's own login, or a teen's own sign-in;
- **parent:** a parent viewing their player, or a linked parent or family member;
- **coach:** coaches and facility staff.

**On report.html:** `&v=`; no `v` or an unknown one → coach.

| | **Coach** (every level) | **Player · little league** (`b08` `b09` `g09`) | **Parent · little league** (`b11` `g11`) | **Player · high school** (`b10` `g10`) | **Player · college** |
|---|---|---|---|---|---|
| Tabs, pen | Summary · Command · Velocity & workload · Trends | Summary · Where it went · Progress | Summary · Progress | Summary · Command · Velocity · Progress | as coach |
| Tabs, game | Summary · Location · Batters · Pitch types · Trends · Every pitch | Summary · Where it went · Progress | Summary · Progress | Summary · Location · Batters · Progress | as coach |
| Headline | Stage C's rules, first name | "you": pen "18 of your 42 pitches hit your spot." + "Your best pen of the last six!" when true; game "You pitched 5.0 innings and struck out 5!" | first section is **workload** (pen: "42 pitches in this pen" + the last game's rest date; game: the rest card), then the 7-day card, then **How it went**: one line ("18 of 42 pitches hit the spot, Sam's best pen of the last six." / "5 innings, 5 strikeouts, 2 walks against Demo Hawks.") | Stage C's rules in "you" ("Your best command pen of the last six: …, led by your fastball.") | Stage C's rules in "you" |
| Window switch | yes | yes | no | yes | yes |
| Tiles | 4 | **2**: pen On the spot · Strike %; game Strike % · 1st-pitch strike | pen: Strikes · On the spot · Pitches, each with one word vs 3 months ("steady", "above usual", "below usual", "best yet" when best of the last six); game: the line strip | 4 incl. velocity | 4 |
| Stood out | up to 3 | **What went well**: only the ▲ items, in "you"; none → the best pitch's line ("Your fastball hit your spot 14 of 25 times.") | none | the top **2**, in "you" | up to 3, in "you" |
| Velocity | yes | **none anywhere** in the version; a line at the end: "No velocity on this version. Your coach and parents can see it." | yes (in Progress) | yes | yes |
| 7-day / rest (baseball) | as Stage D | the kid's wording above; rest card on games | first, as drawn | as Stage D | as Stage D |
| Footer | "… compared with Sam's own sessions …" | "… compared with your own sessions …" | as coach | as player | as player |

- **The new little league panels:**
  - **Where it went** (`b09`): the hit / miss grids per pitch type, then one line per pitch ("Fastball: 14 of 25 on
    your spot."), plus a misses-one-way item in "you" when there is one.
  - **Progress:** the Trends lines without velocity (pen: on the spot, strike %, pitches; game: strike %, first-pitch
    strike %).
- **High school and college have no parent version.** A parent in History, or `v=parent`, gets the coach version
  (question 1).
- **Drawn but not in SR1:** the yellow "Coach's focus" card (the coach-note packet).

## 4. Questions for you

1. **A parent of a high school or college player** (no parent version): **Recommendation:** the coach version, as
   the packet says for college.
2. **The little league player's velocity is hidden, not removed** (one file per report): **Recommendation:** accept.
   Their coach and parents see it anyway, and the version is about what the player reads.
3. **What went well with nothing above range:** **Recommendation:** fall back to the best pitch type's on-the-spot
   line, so the card always has one true, positive fact.
4. **"Best yet":** the app only knows the last six pens. **Recommendation:** "Your best pen of the last six!" and "best
   yet" only as the parent tile's word for that same fact. Never a claim about all-time.
5. **History's Copy Report URL:** **Recommendation:** keep copying the plain link (the coach version), as today.
   Stage F's emails carry `&v=` per recipient.
6. **Softball little league parent** (no workload cards): **Recommendation:** How it went first, then the tiles.

## 5. Checks after your yes (packet 18–19, plus every-stage 1–4)

- **report.html:** a little league, a high school and a college report, each `v` screenshotted beside `b08`–`b11` /
  `g09`–`g11`.
  - The little league player version's shown text has no velocity: `innerText` contains no "mph" and no tile or
    column with velocity.
  - A college `v=parent` shows the coach version, and an unknown `v` does too.
- **History:** a pitcher's own login sees the player version, a parent the parent version, a coach the coach version.
- **The rest:**
  - sizes before and after (stop if a new report more than doubles);
  - no he / his / him;
  - old reports hash the same;
  - CSP hash recomputed (the page loads);
  - `kb-shell-v363`, STATUS, CLAUDE.md.
