# SR1 Stage B · History baselines · preconditions (Nov 19, 2026)

Read at `a127cc9` (main; Stage A live on production, v361). **Branch:** `sr1b-baselines`, from `origin/main`.

**Nothing changes on screen in Stage B.** It adds one database function that Stage C's report will call when a report
is made.

**The migration and rollback are written** (section 5) and were dry-run on staging inside a transaction that was
rolled back:
- The function returned baselines for a demo pitcher's pen and game (below).
- Staging was checked afterwards: neither function exists there.

## 1. What Stage B adds, and what it reads

**New (no table, column or policy changes; public stays 32, storage 12):**

| What | Kind | Job |
|---|---|---|
| `session_baselines(session)` | SECURITY INVOKER, reads `session_stats` | every window's baselines for one saved session |
| `sr1_session_level(session)` | SECURITY DEFINER, small | the level the comparison uses (season dates, "a year ago") |

**What it reads, as it is now:**
- **`session_stats`** (SC1 migration `20261028000000`, v2 rows; Stage A added `purpose`).
  - Every saved session on both projects has its row: 0 missing, 0 in `session_stats_failures`.
  - Every row is `stats_version` 2.
  - The earliest is Jul 1, 2026.
- **Bullpen strike %:** `strikes / pitches`, where a pen's "strike" is a pitch landing in the zone (`is_strike_cell`).
- **Game strike %:** the summary's own numbers, `game.strikes / game.strike_pct_denominator`, so it matches the
  report's line.
- **Per pitch type:** `by_type`'s `n`, `strikes`, `hits`, `velo_n`, `velo_sum`, and for games `pct_n` (the strike-%
  denominator).
- **Levels:**
  - `teams.level`: baseball `little_league` / `high_school` / `college`; softball `little_league` /
    `high_school_up`.
  - `profiles.level` for an independent session.
  - **On production:** 11 baseball teams are `college` and 4 `high_school`; 8 softball teams are `high_school_up`.
    53 of 56 baseball pitcher profiles have no level set.

**Where the packet doesn't match the repo:**

1. **First-pitch strike % isn't stored as a count.** A game's row keeps `first_pitch_pitches` and the rounded
   `first_pitch_strike_pct`, not the number of first-pitch strikes. The function rebuilds the count as
   `round(pct × pitches / 100)`. That's exact whenever a game has fewer than 100 first pitches, which is every game
   (one per batter).
   - The compare script checks this against the pitches themselves for every game.
   - The alternative is a new stats field, which means recomputing every stats row. Not needed.
2. **The packet's function takes "a pitcher, a session kind and an optional tag".** The function needs the session
   itself: the windows end at its start, it must leave itself out, and its team gives the level. So it takes one
   session id and reads the pitcher, kind, tag and start from that row.
3. **"On the spot" for games:** a game's pitches have a target only when Intent was on, so on-the-spot is returned
   for bullpens only. That matches the packet's game tiles, which don't include it.
4. **Two of the first three for strikes** (Stage C's fourth game tile) **has no stored count**, so there's nothing for
   Stage B to pool. See question 3.

## 2. CLAUDE.md decisions this stage touches

| Recorded now (quoted) | New rule beside it |
|---|---|
| Landmine 5: "the underlying pitches/history in the report payload are still client-supplied … accepted limitation" | Unchanged for everything already in a report. The packet adds **one** server-side read on purpose: the baselines, from `session_stats` through `session_baselines`, under the caller's own read rules. The existing client-supplied history keeps feeding the Trends charts. |
| R4: `pitcher_workload` is "SECURITY INVOKER, so it counts what the caller can see" | `session_baselines` follows the same rule (packet recommendation). |

## 3. Questions for you

1. **Whose sessions count.**
   - **The packet's recommendation:** the reach of whoever makes the report, like `pitcher_workload`. A coach never
     gets a number built from sessions they can't open, and the report shows `n`.
   - **What that means in practice:** reports are made by the pitcher (all their own sessions) or the recording
     team's coaches (that team's sessions, plus the pitcher's independent pens; a facility pitching coach, their
     group). So the same pen can rest on more sessions when the pitcher makes the report than when the coach does.
   - **Recommendation: as the packet says.**
2. **Tiny sessions.** Test pens and a quick 3-pitch "game" count as whole sessions.
   - **On staging:** they widen a demo pitcher's normal range to "3 to 38 pitches" and strikes up to 100%.
   - **On production:** 16 of 156 pens and 8 of 133 games have fewer than 10 pitches.
   - **Recommendation:** a session counts in a baseline only with **10+ pitches**, one constant beside the others
     (`c_min_pitches`). The session being reported is still compared, whatever its size.
3. **Two of the first three for strikes** (Stage C's fourth game tile) has nothing stored to compare against.
   - **Recommendation:** in Stage C, that tile shows the game's own number with no "vs average" and no range.
   - **Later:** if you want it compared, a later stage adds the count to the stats (a recompute, with the SC1
     compare scripts).
   - **The other choice:** do that now, inside Stage B.
4. **Softball's season and "a year ago".** Softball's levels are Little League and "High school & up", so a college
   softball player sits under "High school & up".
   - **Recommendation:** treat High school & up as **through high school** (season from Nov 15, "a year ago" shown).
   - It changes when softball gets a college level.
5. **No level set.**
   - **When it happens:** an independent pen whose pitcher never chose a level (53 of 56 baseball pitchers on
     production).
   - **Recommendation:** use the sport's last level, **college** for baseball (season from Sep 1, no "a year ago")
     and High school & up for softball. That's the rule the app already uses for a Live Game's first extra inning.
   - Stage D's "confirm the level" prompt covers teams; a pitcher can set theirs in Pitcher settings.
6. **Season dates use Eastern time** (a session at 11 pm Pacific on Nov 14 counts as Nov 15).
   - **Recommendation:** Eastern, one constant. Teams are all in the US, and the difference is a few hours a year at
     one boundary.

## 4. What the function returns (sketch)

```
session_baselines(<a pen>) →
{ session, kind: "bullpen", purpose: "command" | null, level: "college", season_start: "2026-09-01",
  min_avg: 3, min_range: 5,
  windows: {
    "1m":     { from, to, n: 8,  avg: { strike_pct: 83, spot_pct: 60.2, velo: 77.2, velo_n: 65, pitches: 11 },
                range: { strike_pct: [79.8, 100], spot_pct: [61.2, 66.7], velo: [77.1, 77.4], pitches: [3, 31.3] },
                types: { "Four Seam Fastball": { n: 8, avg: {…, velo: 80.6}, range: {…} }, "Slider": { n: 2, avg: null, range: null } } },
    "3m": …, "12m": …, "season": …,
    "year_ago": …            ← not for college
  } }
```

- **Rules:**
  - `avg` is null below 3 sessions, and `range` below 5 (shown as `null`). The type rows follow the same rules.
  - A **game** has `strike_pct`, `fp_strike_pct`, `in_zone_pct`, `velo`, `pitches`, and no `spot_pct`.
  - A tagged pen counts only pens with the same tag; an untagged pen counts all pens. The session itself never
    counts, nor anything that started after it.
- **The real output** (staging dry run, demo pitcher "f0648036", college team) is above with 3-pitch test pens
  included. Question 2 would drop them.

## 5. Migration, rollback, RLS

**Files (written, dry-run on staging, rolled back):**
- `supabase/migrations/20261124000000_sr1b_baselines.sql`: both functions in full, with the starting values as
  constants at the top: 3, 5, 10th / 90th, Eastern time, and 10 pitches if question 2 is yes.
- `supabase/rollback/20261124000000_sr1b_baselines_down.sql`: drops both functions. Nothing stores their output.
  After Stage C, roll C back first.

**RLS:**
- **`session_baselines`:** no policy changes. It's SECURITY INVOKER, so `session_stats`' existing read rule (the same
  as `pitches`) decides which sessions count.
- **`sr1_session_level`:** SECURITY DEFINER only because a linked guardian or a teen's own sign-in can't read the
  `teams` row. It returns a level only when the caller may chart for, coach, or follow that pitcher (`can_chart_for`,
  `coach_sees_pitcher`, `is_linked_to`, `is_current_coach_of_pitcher`), and null otherwise.
- **Who can call them:** both are revoked from `anon` and granted to `authenticated`.

## 6. Checks after your yes (packet 7–9)

- **`supabase/tests/sr1b_baselines.sql`** on staging (rolled back), with fixture pens and games at known dates:
  - **The window rules:** 2 sessions → `n` 2 and no average; 4 → an average and no range; 5+ → both.
  - **What's left out:** a tagged pen counts only same-tag pens; the session itself and anything later never
    count.
  - **Dates:** the season starts (Nov 15 / Sep 1) at their edges, "a year ago" absent for college, sessions under 10
    pitches left out (if yes).
  - **Reach:** a coach of another team counts only what they can read, and the `n` shows it.
- **`scripts/sr1b-compare.js`** (in the style of `sc1-compare.js`): for two demo pitchers (one mostly pens, one with
  games), every session, every window. The function's pooled numbers and percentiles are recomputed from the pitches
  themselves, not from `session_stats`. It shows 0 differences, or stops.
- **The rest:** policies 32 / 12 before and after, and a STATUS entry plus a CLAUDE.md line in the PR. No `.html`
  changes, so there's no cache bump.
