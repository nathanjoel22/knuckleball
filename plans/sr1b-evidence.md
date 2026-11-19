# SR1 Stage B · History baselines · evidence (Nov 19, 2026)

**Where it was tested:**
- Branch `sr1b-baselines`.
- Migration `20261124000000_sr1b_baselines` on **staging** only (`--project-ref wpsscxwawgiwmifpjpec`), recorded in
  staging's migration history.

**Nothing on screen changes in Stage B,** so there are no pictures and no cache bump.

Decisions: `plans/sr1b-preconditions.md` (Joel: yes to all).

## Acceptance checks (packet section 6)

1. **Staging: PASS.** Run as each pitcher's own login, a coach, and a stranger (below). No page changed, so there's
   nothing to compare at 390 or 820.
2. **Side by side with the picture:** none for Stage B.
3. **Sent reports unchanged: PASS.** Stage B writes nothing: no table, column, row or report file changes. The
   report function isn't touched.
4. **Checks, STATUS, CLAUDE.md: PASS.**
   - The pre-push checks pass.
   - No `.html` changed, so there's no cache bump.
   - STATUS.md has an entry, and CLAUDE.md gains a "History baselines" note, both in this PR.
7. **The SQL test passes, and the compare script matches sums made by hand for every window: PASS.**
   - **The SQL test** (`supabase/tests/sr1b_baselines.sql`, staging, rolled back): its fixture pens are dated around
     an anchor pen on Thu Nov 19 2026, noon Eastern.

     ```
     8 level high_school season 2026-11-15
     1m n2 avg null
     3m n4 avg 50.0 range null
     12m n6 range [50.0, 50.0]
     season n1 (Nov 14 23:30 ET left out)
     year ago n1
     12m avg {"velo": 80.0, "velo_n": 60, "pitches": 10.0, "spot_pct": 50.0, "strike_pct": 50.0}
     type Fastball 12m n6
     9 tagged 12m n1 1m n0
     game 1m n1 fp null
     college season 2026-09-01 n4 year ago absent
     no level -> college
     stranger: not_found level hidden:true
     coach 12m n2 = coach-readable 2 (pitcher sees 6)
     policies 32->32
     hard fails 0
     ```

   - **The compare script** (`node scripts/sr1b-compare.js wpsscxwawgiwmifpjpec <4 demo pitchers>`):
     - It reads every saved session, its pitches and `session_baselines()`, signed in as each pitcher, read-only.
     - It then recomputes every window from the **pitches** (not `session_stats`), using the app's own `isStrikeCell`,
       `isDefaultVeloReading` and `GAME_STRIKE_RESULTS`.
     - It compares exact half-up rounding for averages, and linear-interpolated 10th / 90th percentiles.

     ```
     14345e15: 27 pens, 10 games; 183 windows (22 with an average, 0 with a range)
     f0648036: 15 pens, 8 games; 92 windows (48 with an average, 23 with a range)
     2c212a14: 9 pens, 7 games; 64 windows (29 with an average, 14 with a range)
     34ba161c: 9 pens, 7 games; 64 windows (27 with an average, 12 with a range)
     1796 checks, 0 differences
     ```

     One is mostly pens (14345e15, the staging test pitcher, whose many 3-pitch pens fall under the 10-pitch rule).
     The other three are demo pitchers with games. The game windows' first-pitch strike % matched the pitches
     every time, which confirms the rebuild from the stored rounded percentage.
8. **2 sessions → `n` 2 and no average; 4 → an average and no range; 5+ → both: PASS** (the 1m / 3m / 12m lines above).
9. **A tagged pen counts only same-tag pens; the session is never in its own baseline: PASS.**
   - The tagged anchor's 12m window counts one pen: the other command pen.
   - The untagged anchor counts all six pens (tagged included), never itself, never the pen after it, and never the
     5-pitch pen.
   - The compare script checks the same rules for every session.

**Also checked:**
- **Reach:** a stranger gets `not_found`, and the level is hidden too. A coach whose team the pitcher joined Nov 1
  counts exactly the sessions that coach can read (2 against the pitcher's own 6). The `n` shows the difference.
- **Policies:** 32 public and 12 storage, after.
- **The dry run:** the migration was first applied inside a rolled-back transaction on staging, and returned
  baselines for a demo pen and game.

## Deviations

- **One argument:** `session_baselines` takes the session id rather than (pitcher, kind, tag). The session supplies
  all three, plus the anchor time and the level.
- **On the spot:** returned for bullpens only. A game's pitches have a target only with Intent.

## Production (Joel's)

1. Backup.
2. `supabase db push --project-ref fkgccjhuimkkbupbanxp`: runs only `20261124000000_sr1b_baselines`.
3. Merge. Nothing calls the function until Stage C, so the order doesn't matter for the site.

Afterwards, a read-only check: `node scripts/sr1b-compare.js fkgccjhuimkkbupbanxp <two real pitcher ids>` should show
0 differences. Its output shows only short ids, with no names.
