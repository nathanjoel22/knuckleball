# SR1 Stage D · Workload, rest and team settings · preconditions (Nov 19, 2026)

Read at `c13832a` (main; SR1 A, B and C on production). **Branch:** `sr1d-workload`, from `origin/main`.

**Pictures:** `b06` (the 7-day card over the line), and `g01` / `g07` (rest + 7-day, under and over the line).

**The migration and rollback are written** (section 5) and were dry-run on staging inside transactions that were
rolled back:
- The rollback returned `set_team_level` to its checksum (`3cf009fa…`, the same on both projects) and removed every
  new column.
- `session_workload` returned the demo pitcher's last 7 days (below).
- Staging was checked afterwards: no `pitch_smart_age` column.

## 1. What changes, where it is now

**Database** (new migration `20261125000000_sr1d_workload`):

| What | Now | Stage D |
|---|---|---|
| `teams` | `level` (head coach, `set_team_level`); no age group; no "chosen" flag | + `pitch_smart_age` (baseball only, check) + `level_confirmed_at`; SELECT grants |
| `profiles` | `level` (the pitcher's own, for Independent games) | + `pitch_smart_age` (SELECT / UPDATE grant, the owner's RLS as `level`) |
| `set_team_level` | head only, not archived | also stamps `level_confirmed_at` (choosing = confirming) |
| new `set_team_age_group(team, age)` | — | head only, not archived, baseball only |
| new `sr1_session_age(session)` | — | the team's age group, or the pitcher's own for an Independent game; null if not set (no guessing from the level) |
| new `session_workload(session)` | `pitcher_workload` (rolling 7 days from now; SECURITY INVOKER) | the 7 days up to that session, each session counted exactly as `pitcher_workload` counts it, plus level and age group; SECURITY INVOKER |

Policies are unchanged: public stays 32, storage 12.

**App** (`bullpen-tracker.html`, cache `kb-shell-v361` → `v362`):

| Where | Line now | Stage D |
|---|---|---|
| Account → Team, "Level of play" (`levelSection`) | 15790 | + a "Pitch Smart age group" select (baseball; head coach edits, assistants see it) |
| `setTeamLevel` | 15826 | unchanged; `set_team_level` now also confirms |
| Pitcher settings → "Level" (`renderLevelSection`) | 15461 | + the age group for Independent games (baseball) |
| teams selects | 3885, 3890, 4012, 4015 | `+ pitch_smart_age, level_confirmed_at` |
| `PROFILE_COLS` | — | `+ pitch_smart_age` |
| coach Home (`renderHomeView`) | — | the one-time "Confirm your team's level" card (section 4) |

**Report function** (`send-session-report`):
- `loadComparison` also calls `session_workload`, through the caller's client.
- Summary gets the **7-day card** (every report) and, for games, the **rest card**. Both are already drawn in `b01`,
  `b06`, `g01` and `g07`.
- The rest table and the guidelines are constants in `sr1.ts`, with their source in a comment.

**Where the packet doesn't match the repo, or the world:**

1. **Pitch Smart is baseball only:** MLB / USA Baseball publish no softball table. See question 1.
2. **The packet's "back Fri, Nov 20" needs a rule for counting days.** Pitch Smart says how many days of rest, not
   which day. See question 3.
3. **Pitch Smart's 19–22 band stops at 105** while its daily max is 120, so 106–120 pitches have no row. See
   question 2.
4. **A "unchosen default" flag doesn't exist** (decision 15: "there may be no flag today"). Stage D adds
   `level_confirmed_at`, with no backfill, so every team is asked once.
5. **Facility sides** have a level from the operator's link or the default. The age group sits on each side (a
   team row), and the manager is head of both, so it's the same Account row. No special case.

**The Pitch Smart table** (fetched from mlb.com/pitch-smart/pitching-guidelines, Nov 19, 2026; it goes into
`sr1.ts` as a constant with that source):

| Age | Daily max | 0 days rest | 1 day | 2 days | 3 days | 4 days |
|---|---|---|---|---|---|---|
| 7–8 | 50 | 1–20 | 21–35 | 36–50 | — | — |
| 9–10 | 75 | 1–20 | 21–35 | 36–50 | 51–65 | 66–75 |
| 11–12 | 85 | 1–20 | 21–35 | 36–50 | 51–65 | 66–85 |
| 13–14 | 95 | 1–20 | 21–35 | 36–50 | 51–65 | 66–95 |
| 15–16 | 95 | 1–30 | 31–45 | 46–60 | 61–75 | 76–95 |
| 17–18 | 105 | 1–30 | 31–45 | 46–60 | 61–80 | 81–105 |
| 19–22 | 120 | 1–30 | 31–45 | 46–60 | 61–80 | 81–105 |

**7-day guideline** (packet decision 9): under high school 100 · high school 125 · college 150.

## 2. CLAUDE.md decisions this stage touches

| Recorded now (quoted) | New rule beside it |
|---|---|
| G3: "`teams.level` … head coach sets it" | Unchanged. Choosing it now also stamps `level_confirmed_at`; a team without it is asked once. |
| R6: "Name, throws, uniform and radar gun stay head-only" (pitcher) / teams written only through functions | The age group follows the same rules: a team's through `set_team_age_group` (head only); a pitcher's own on their profile, like `level`. |
| SR1 Stage C: Summary carries the headline, window switch, tiles, What stood out | + the rest card (games) and the 7-day card (every report), as drawn |

## 3. Questions for you

1. **Softball.** Pitch Smart has no softball rows.
   - **Recommendation:**
     - Softball reports show the **7-day count with no guideline and no warning**, and **no rest card**.
     - Softball teams and pitchers aren't asked an age group.
     - The confirm prompt asks softball teams for the level only.
   - **The other choice:** use the baseball guidelines for softball too.
2. **Above the table.** Ages 19–22 at 106–120, and any age above its daily max.
   - **Recommendation:** the rest is the table's top band (4 days; 2 days for 7–8).
   - **Above the daily max,** the card adds one line: "Above Pitch Smart's daily max for ages 15–16 (95)." It's a
     fact, never "can't pitch".
3. **Counting the days.**
   - **Recommendation:** from the game's date in Eastern time (as Stage B's seasons): back on the game date + rest
     days + 1. So 4 days after Sun, Nov 15 is "back Fri, Nov 20", as drawn.
   - **0 days** reads "No rest day needed · back Mon, Nov 16".
   - Pitch Smart's "no three days in a row" isn't checked (not in the packet).
4. **The confirm prompt** (decision 15; packet: "a one-time prompt … shows once … and never after").
   - **Recommendation:**
     - A card at the top of the head coach's Home: "Confirm your team's level". It has Level of play and, for
       baseball, the age group, plus **Save** and **Not now**.
     - **Save** stamps the team, so it's gone on every device.
     - **Not now** hides it on that device.
     - A facility manager sees one card per side.
5. **The wording** (as drawn, no gendered pronoun):
   - **Under the line:** "42 today + 77 in Sunday's game. Guideline for high school: about 125 in 7 days."
   - **Over the line:** "⚠ LAST 7 DAYS · 135 pitches · 77 today + pens of 38 and 20 this week. Above the 125
     guideline for high school. Keeping this pace makes fatigue or injury more likely. A heads-up, not a stop."
   - **Rest card:** "REST · PITCH SMART AGES 15–16 · 4 days · back Fri, Nov 20" with "77 game pitches."
   - **No age group set:** "No Pitch Smart age group set for this team. The head coach sets it in Account → Team."
     (For an Independent game: "… in Pitcher settings → Level.")
   - **Recommendation: yes, as drawn.**
6. **No level set** (an Independent pen whose pitcher never chose a level): **Recommendation:** college (150), as
   Stage B's answer 5.

## 4. Sketches (not drawn)

```
Account → Team (baseball, head coach)            Pitcher settings (baseball)
Level of play                                    Level
[ College            ▾ ]                         [Little League][High school][College]
Extra innings start in the 10th.                 Pitch Smart age group (Independent games)
Pitch Smart age group                            [ 15–16 ▾ ]
[ 15–16              ▾ ]                         Sets the rest days on your own Live Game reports.
Sets the rest days on this team's game reports.

Coach Home, top (until saved; Not now hides it on this device)
┌ Confirm your team's level ─────────────────────────┐
│ Demo Eagles plays at:  [ College ▾ ]               │
│ Pitch Smart age group: [ Choose ▾ ]   (baseball)   │
│ Used for extra innings and the rest days on game   │
│ reports.                     [ Not now ] [ Save ]  │
└────────────────────────────────────────────────────┘
```

The report cards are drawn in `b01`, `b06`, `g01` and `g07`.

## 5. Migration, rollback, RLS

**Files (written, dry-run on staging, rolled back):**
- `supabase/migrations/20261125000000_sr1d_workload.sql`
- `supabase/rollback/20261125000000_sr1d_workload_down.sql`

**New schema:**

```sql
alter table public.teams add column pitch_smart_age text,
  add constraint teams_pitch_smart_age_check check (pitch_smart_age is null
    or (pitch_smart_age in ('7-8','9-10','11-12','13-14','15-16','17-18','19-22') and sport = 'baseball'));
alter table public.teams add column level_confirmed_at timestamptz;
grant select (pitch_smart_age, level_confirmed_at) on public.teams to authenticated;
alter table public.profiles add column pitch_smart_age text, add constraint … (the same seven);
grant select (pitch_smart_age), update (pitch_smart_age) on public.profiles to authenticated;
```

**Functions:** `set_team_level` (+ the stamp), `set_team_age_group`, `sr1_session_age` (DEFINER, the same "may chart
for, coach or follow" check as `sr1_session_level`), `session_workload` (INVOKER).

**The dry run** (demo pitcher's own login, age group set inside the rolled-back transaction):

```
game Nov 5:  level college, age 19-22, 7-day 70 = pen Nov 1 (39) + this game (31)
pen  Nov 1:  level college, age 19-22, 7-day 67 = pen Oct 27 (28) + this pen (39)
```

**Rollback:** drops the three new functions, restores `set_team_level` (checksum checked), and drops the three
columns.

**RLS:**
- No policy changes.
- `session_workload` counts under the caller's own read rules, as `pitcher_workload` does.
- Teams' age group is written only by `set_team_age_group`; clients still have no write path to `teams`.
- A pitcher's own age group goes through the owner's existing profile update rule, like `level`.

## 6. Checks after your yes (packet 15–17, plus every-stage 1–4)

- **`supabase/tests/sr1d_workload.sql`** on staging (rolled back):
  - **Age group:** it saves for a team (head only; an assistant and a softball team are refused) and for a pitcher's
    own profile.
  - **Confirming:** `set_team_level` stamps the confirmation.
  - **Rest dates:** three seeded games, one per age band, at the band edges (13–14 at 50 and 51 pitches;
    15–16 at 75 / 76; 19–22 at 105 / 106).
  - **The 7-day count:** equals `pitcher_workload` for the same pitcher and day. The warning shows one pitch over
    each level's line and not at it.
- **In the app** (staging, 390 and 820): the age group row, the prompt showing once and never after Save, the
  report's rest and 7-day cards beside `b06` / `g01` / `g07`, and the softball report without a guideline.
- **The rest:** old reports hash the same; `kb-shell-v362`; STATUS, CLAUDE.md.
