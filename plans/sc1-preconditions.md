# SC1 — preconditions report (session stats at save time)

Oct 28 2026. Branch `sc1-session-stats` from `origin/main` at c2f5137 (v316). **Nothing built: no code, no SQL
beyond read-only queries.** Waiting for Joel.

## 0. The packet isn't on main

`scale-track.md` was uploaded through the GitHub web UI on Oct 1 2026 (b5e8304, 15:14:26) and deleted 50 seconds
later (931c199, "Delete scale-track.md", same account). It is not on `main` or in `plans/`. This report works from
the Oct 1 copy in GitHub's history (`git show b5e8304:scale-track.md`), its SC1 block only. **Joel: confirm that copy
is the one you mean, or upload the current one to `plans/`.** If you upload a newer one, this report is checked
against it before anything is built.

## 1. Where a session becomes saved, and the hook (incl. change (a))

- **The only path is `public.sync_session(p_session, p_pitches, p_events)`.** It's SECURITY DEFINER, `search_path ''`,
  and the definition is identical on staging and production (md5 5de5c177). The app calls it from the outbox at
  `bullpen-tracker.html:5749`. It inserts the session already saved (`ended_at` set, line 88 of the function), then
  the pitches (111–129), then the events (132–143). It then sets `sealed_at` (146), and for a linked relief game runs
  `r3_apply_relief` (147–148), all in one call. There is no `saved_at` column: SC1's "trigger when `saved_at` goes
  non-null" means `sealed_at` now.
- **Can a session save before its pitches land? No, not since H1.** The pitches come in the same call, so the old
  "finalize after the last pitch syncs" problem (SC1 acceptance 7) is gone. A sealed session can't get new pitches
  (`h1_child_lock`), and a re-send returns `already_saved` and writes nothing. On both projects, 0 sessions are
  unsealed (grace path closed Oct 21).
- **Recommended hook:** call `finalize_session_stats(v_id)` from inside `sync_session`, right after the
  `r3_apply_relief` call. It is then in the **same transaction**. A trigger on `sealed_at` would also be in the same
  transaction, but a direct call is easier to read and runs after the relief charges.
- **What happens if it fails.** PostgREST runs the RPC as one transaction. An error raised in finalize rolls back
  the session, its pitches and its events. The app gets `rpcErr` (line 5752) and keeps the item queued with
  "Not saved: …" (5763–5770), retrying forever. **Charting is unaffected** (offline-first), but **every save on that
  path fails until the stats code is fixed.** A stats bug would become a "nothing saves" outage. Recommendation:
  - Wrap the call in `begin … exception when others then … end` (a savepoint). A failure then leaves no stats row,
    is logged to a small table, and **the save still succeeds**.
  - A missing row is filled by a re-run: the backfill function, run by hand or on a schedule.
  - Screens fall back to computing from pitches when a row is missing. They still have the pitches; see 5.
  - This needs Joel's OK, because it means a saved session can exist briefly without a stats row.
- **Saved rows can still change (not covered by the packet):**
  - **R3:** a game's `exit_runs` / `exit_er` / `exit_bb` / `final_at` change after save, through `r3_apply_relief`
    (a later reliever's save) and `r3_finalize_stale` (pg_cron, 6 hours). A game row must be **recomputed** by both
    functions. Until `final_at` it is provisional (`compute_game_summary` already returns `provisional`).
  - **Deletes don't delete the session row.** `delete_session` tombstones it (sets `deleted_at`) and deletes its
    pitches and events. `a1_purge_profile` does the same, plus `pitcher_id = NULL`. So `ON DELETE CASCADE` never
    fires, and both functions must delete the stats row themselves (or a trigger on `deleted_at` does it).

## 2. Every place that computes stats from pitches today (incl. change (b))

| Where | Function | Reads |
|---|---|---|
| History pen card + breakdown table | `sessionStats` (`bullpen-tracker.html:6078`) | raw pitches |
| History game card | `gameStats` (8209) + exit_* (11449), `gameHistoryTypeTable` (7952) | raw pitches + events |
| History card plot | `renderHistoryPlot` (pitch order matters, below) | raw pitches |
| Live stats while charting | `sessionStats` (10883), `gameStats` (10435) | the draft (stays client-side) |
| Trends (v310) | `renderTrendsView` (11776): per type per session strike %, peak velo; per-type plots; game splits | raw pitches |
| Report pen trends | `sessionStats` over prior pens (12898) | raw pitches |
| Report game trends | `compute_game_summary` RPC once per game (13015) + velocity from pitches | RPC + pitches |
| Leaderboard | `get_team_leaderboard` (SQL, pitch level) | pitches |
| Roster workload line | `pitcher_workload` (SQL, counts pitches per session) | pitches |
| Profile | **nothing**: "Pitch mix" is the declared list (`profiles.pitch_types`); the zone painter reads `accuracy_zones` | — |

**The formulas the SQL must match (bullpen):**
- `pitches` = number of pitch rows.
- `strikes` = `actual_row between 1 and 3 and actual_col between 1 and 3` (`isStrikeCell`, 2411; SQL already has
  `is_strike_cell`).
- **Hits (U14, the one accuracy number)**, `isHit` (3750): `case when accuracy_hit_kind is not null then
  accuracy_hit_kind in ('exact','ra') else target_row = actual_row and target_col = actual_col end`, null counted as
  not a hit. The denominator is **all pitches**. This is the exact expression `get_team_leaderboard` already uses, so
  a pitch in a marked RA cell counts as a hit. Store `exact_hits` and `ra_hits` too, for the "E exact, R RA" line.
- **Drop `relative_accuracy_pct`, as asked.** It only feeds History's "Relative Acc." box and column (11007, 11058,
  11572) for pre-U7B legacy-mode pens (`accuracy_mode` set, no zone). Production has **0** such pitches; staging has
  21 pitches in 3 test sessions. Those 3 sessions lose that box unless the client keeps computing it for them.
  Decision for Joel (recommended: drop it).
- **U7 zone accuracy** (`inAccuracyZone`, shown as "Zone Acc." for older pens): 206 pitches on production. It's a
  separate displayed number, not part of the one accuracy number. Keep it as `zone_hits` / `zone_total` counts, or
  History stops showing it.
- **Velocity, Amendment 10 rule.** A reading counts when `velo is not null and not public.is_default_velo_reading(velo,
  ts)`, meaning not (65 **and** `ts` before 1789965601 s = 2026-09-21 04:40:01 UTC). This is the lockstep pair with
  `isDefaultVeloReading` (4980). Production has 53 such 65s, staging 67. Avg = `Math.round(sum / n)`, plus min and max.
- **Rounding: store counts, never percentages.** The app rounds `Math.round((a/b)*100)` in floating point. SQL
  `round(100.0*a/b)` can differ by 1 on an exact .5. If the row holds integers (pitches, strikes, hits, exact, ra,
  zone hits/total, velo sum/n/min/max) and the app divides exactly as it does now, every percentage matches by
  construction. It also lets the leaderboard sum counts across sessions exactly as it does today.
- **Per type (`by_type`):** the same counts per type, plus velo sum/n/min/max (Trends' peak = max).
- **Per side (`by_side`):** keyed L / R / none.
- **Zone counts:** 25 cells, catcher frame, **per type**. For Live Game, also per type × batter side and per type ×
  delivery. That is enough to redraw the Trends per-type plots and rings exactly, because every dot in one plot has
  the same colour.

## 3. Games: is `compute_game_summary` enough? (change (c))

Identical on both projects (md5 173b7042). STABLE, SECURITY **INVOKER**, returns `{error: …}` instead of raising.

**It already gives:** `pitches`, `pitch_count` (with `pitch_count_adjust`), `strikes`, `strike_pct` (+ denominator),
`runs`, `er` (both including R3 `exit_*`), `exit_runs/er/bb`, `provisional`, `ir`, `irs`, `bb_charged_prev`,
`runners_left`, `in_zone`, first-pitch strike %, `k`, `bb`, `h`, `xbh`, `outs_in_play`, `errors`, `hbp`,
`batters_faced`, `outs_recorded`, `final_inning`.

**Missing for a game row:**
- **WP and BK.** The report counts these from events: WP = distinct (inning, at-bat, balls, strikes) of `wild_pitch`;
  BK = `balk`, or for softball `illegal_pitch` + `balk` (`template_game.ts:159-160`).
- **SF / SAC counts** (`pitches.sacrifice`).
- **1B / 2B / 3B / HR split.**
- **Velocity** (none at all).
- **Per-type table** (count, strike %, velo).
- **Per batter side and per delivery** (Trends splits).
- **Zone counts.**
- **Intent accuracy** (production: 0 game pitches with a target; staging: 43).

Recommendation: finalize stores the function's JSON as-is (reuse, don't fork) and adds only the missing fields beside
it.

**Today's app and the function disagree in two places** (finding, not caused by SC1):
1. **Strike %.** The function leaves `interference` / `other` out of the denominator; History's `gameStats` counts
   every charted pitch. Production has 0 such pitches; staging has 2.
2. **ER.** `gameStats` floors ER at 0; the function doesn't.

Acceptance 4 needs Joel to pick one: recommended, the function's (it is what reports already show).

## 4. RLS for `session_stats`

The policy copies the `pitches` SELECT rule word for word:

`exists (select 1 from public.sessions s where s.id = session_stats.session_id and (is_my_profile(s.pitcher_id) or
is_team_coach(s.team_id) or is_current_coach_of_pitcher(s.pitcher_id, s.started_at)))`

- R4 cross-team reading comes with it for free.
- The helpers (`is_team_coach`, `is_current_coach_of_pitcher`, both SECURITY DEFINER) do the `pitcher_teams` lookup.
  **The policy names neither `teams` nor `pitcher_teams`.**
- No INSERT / UPDATE / DELETE policy; only the SECURITY DEFINER functions write.
- **Policies: 29 on staging, 29 on production → 30 after.** No change to the policies on `sessions` or `pitches`.

## 5. Which screens would read `session_stats`, and the conflict with acceptance 3

- **History.** Card numbers (pen: pitches, strike %, accuracy, velo; game: the pitching line) and the breakdown
  tables can come from the row.
  - **But History can't stop fetching pitches.** Acceptance 3 says "no pitch rows on History". That predates:
    - **v188:** every History card draws a plot of every pitch. Mixed types in one cell are placed in pitch order,
      so counts can't redraw it.
    - **Making and sending a report:** the app builds the payload from the loaded pitches.
    - **The offline snapshot.**
  - So: either History loads stats first and **pitches only when a card is opened or a report is made** (a real
    change to History, and to what works offline), or acceptance 3 is relaxed for History.
    **This is the biggest decision for Joel.**
- **Trends.** Fully from `session_stats` if zone counts per type (and per type × side / delivery for games) are
  stored, as in 2.
- **Leaderboard.** Strike % and accuracy can sum the row's counts. Two differences from today:
  - **Windows.** Today the week / month window is by **pitch `ts`**; rows would bucket by session start. 0 pens on
    production cross midnight Eastern.
  - **Velocity.** The board shows the peak pitch's id and time, and **coaches can exclude single pitches after the
    save** (`leaderboard_exclusions`; 0 rows on both projects today). An immutable row can't follow that.
  - Recommendation: velocity stays on `pitches` (one indexed max per pitcher); strike / accuracy move to the row.
  - Games stay out (`kind = 'bullpen'`); softball and archived teams keep returning empty.
- **Profile.** Reads no stats today. Nothing to switch, and SC1's "Profile pitch mix / accuracy" read doesn't exist.
- **Also could switch:** `pitcher_workload` (the row's `pitch_count`), and the report game trends (one RPC per game
  becomes one select).

## 6. Row counts (read-only, Oct 28 2026)

| | staging (wpsscxwawgiwmifpjpec) | production (fkgccjhuimkkbupbanxp) |
|---|---|---|
| sessions (all) | 85 | 130 |
| saved, not deleted → backfill rows | **83** (55 pens, 28 games) | **115** (68 pens, 47 games) |
| tombstones (get no row) | 2 | 15 |
| saved with 0 pitches | 1 | 0 |
| softball saved | 13 | 4 |
| games with line still open | 0 | 0 |
| pitches / game_events | 495 / 21 | 2,557 / 68 |
| profiles / teams | 38 / 9 | 57 / 11 |
| RLS policies (public) | 29 | 29 |
| `session_stats` exists | no | no |

Also: `sessions.pitch_count` is NULL on every saved session (it is filled only on tombstones), so don't use it as a
check.

## 7. Escalate-if check

- **"Can't be reproduced exactly in SQL."** Every number can be, if counts are stored, not percentages. The game
  strike % and ER rules need one choice (3). History's mixed-type card plot needs pitch order, so it isn't a stat
  (5).
- **"Save hook can't guarantee all pitches have landed."** It can, since H1 (1).
- **"Would need a new policy on sessions or pitches."** No. One new policy, on `session_stats` only.

## Decisions for Joel

1. Confirm the Oct 1 `scale-track.md` is the packet (0).
2. Should a stats failure **block the save** (strict) or **leave the row missing and save anyway**? Recommended: the
   latter (1).
3. Drop relative accuracy (recommended); keep U7 zone accuracy as counts (2).
4. Game strike % / ER: use `compute_game_summary`'s rules everywhere (recommended) (3).
5. History: load pitches lazily when a card is opened, or keep loading them and use the row only for the numbers (5).
6. Leaderboard: velocity stays on pitches; strike / accuracy from the row, windows by session start (5).
7. Timing: the packet put SC1 at 1,000–20,000 accounts; production has 57 profiles and 2,557 pitches.
