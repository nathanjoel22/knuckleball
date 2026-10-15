# U14 preconditions report (Oct 15, 2026)

Packet: `plans/u14-relative-accuracy-v2.md` (GitHub 9323b7d). Branch `u14-relative-accuracy`. Nothing has been built.
Production read-only; staging read-only. Line numbers are for `bullpen-tracker.html` at origin/main 9323b7d unless a file is named.

## 1. Today's relative accuracy (RA) data model

| What | Where | Detail |
|---|---|---|
| Profile switch | `profiles.relative_accuracy_enabled boolean NOT NULL DEFAULT false` | Read into `p.relativeAccuracy` (1902; PROFILE_COLS 3005; roster selects 3098, 3434). Pitcher writes it directly (9938); a coach writes it with `coach_set_relative_accuracy` (9934). |
| Zones | table `accuracy_zones (pitcher_id, pitch_type, batter_side 'R'/'L', cells text[], updated_at, updated_by)`, PK (pitcher, type, side) | `cells` are catcher-frame `'row-col'` strings. CHECK `cardinality(cells) <= 49` (from the 7×7 plan). FK pitcher → profiles ON DELETE CASCADE. One policy, FOR ALL: `is_my_profile(pitcher_id) OR is_coach_of_pitcher(pitcher_id)`. Trigger `accuracy_zones_stamp`. Written by the painter: upsert 9984, delete 9996. Cached for offline use with the roster snapshot (3133, 3407). |
| Per-pitch result | `pitches.in_accuracy_zone boolean`, `pitches.accuracy_zone_cells text[]`, `pitches.accuracy_mode text` | Set at tap 2 (4874–4896): when RA is on for the session and a zone exists for (type, side), `in_accuracy_zone` = actual cell ∈ cells, with the cells copied onto the pitch. `accuracy_mode` is the retired pre-U7 mode (CHECK ring / nothingUp / nothingLow / nothingAway / nothingInside); new pitches write NULL. |
| Who saves them | `sync_session` | Explicit column list: sessions insert (line 52 of its body) has no RA column; the pitches insert (63–70) carries `accuracy_mode, batter_side, in_accuracy_zone, accuracy_zone_cells`. The outbox builds the rows at 5235–5257. A new column needs both the client payload and `sync_session` changed (a migration), which is routine. |

Today, the zone hit and the exact hit are **separate**: `in_accuracy_zone` is true only when the pitch lands in a painted cell. The target counts only if it was painted too.

## 2. Every place accuracy is computed or shown

All of these read **stored per-pitch results** (`in_accuracy_zone`) or compare the stored target and actual cells. **Nothing recomputes from today's zones.** The escalation clause "a stat recomputes from current zones" is not triggered.

| Place | Code | What it shows |
|---|---|---|
| Live session screen | `sessionStats` 5643–5689; phone status line 9278 (`Acc n%` = exact); stat boxes 9322–9324 / 9372–9374 | Accuracy (exact) and, when any pitch was zone-scored, "Relative Acc. (n)" = zone hits / zone-scored pitches |
| History card | 9815–9903 | Per-type table: `accuracyPct` (exact). Meta line: "Relative Acc. (n)" + "Exact hit" when zoned, else "Accuracy" |
| Profile | none | No accuracy number is shown on Profile |
| Leaderboard | DB `get_team_leaderboard`, lines 61–79 of its body | **Recomputes exact from coordinates** (`target = actual`); ignores zones |
| Pen report payload | trends 10965–10971 (`commandPct` = zone % if any zone, else exact %); "Bullpen to game" 11010–11045 (same rule pooled) | |
| Pen report | `send-session-report/compute.ts` 31–42, 59–80, 95–109; `template.ts` 69 ("Command % (zone)" / "(exact hit)"), 121, 167 | |
| Game report | `template_game.ts` / `compute_game.ts` | **No accuracy of game pitches at all.** Only "Bullpen to game" shows pen command % (`connect.ts` 66–68, `compute_game.ts` 243–253) |
| Re-render path | `from_rows.ts` 52–107 | Same rules as the app (used only by the operator re-render) |
| SC1 stats | not built | — |

## 3. Session start screens

- **There is already a start screen** (Joel, Oct 12; `renderStartQuestions` 6088–6113, `startSessionNow` 6046–6061), shown before the first pitch for both kinds and both sports:
  - Bullpen: "Will you be using a radar gun today?" and **"Would you like to use relative accuracy?"** (a U13 `segTray`, Yes/No), defaulting to the profile switch (6034).
  - Live Game: radar, **Intent** (Yes/No), opponent. **No RA question.**
- The answer lives only on the device draft (`s.relAccuracyToday`, 6050; read by `sessionRelAccuracy` 3392–3397). **It is not stored on the session row.**
- `sessions` stores at start: `team_id`, `kind`, `sport`, `charting_perspective`, `opponent` (games). Radar and Intent are device-only too.
- The start screen comes before pitch 1, so "locked after pitch 1" is automatic. The charting screen shows no RA indicator today; the spec's read-only pill would be new.

## 4. Production counts (read-only, Oct 15)

| | |
|---|---|
| Profiles with the switch on | **11** |
| Pitchers with any painted zone | **7** (33 zone rows, none empty) |
| Zone rows with more than 4 cells | **6** (max 5) |
| Pitches with `in_accuracy_zone` set | **208** (151 true); old `accuracy_mode` pitches: 0 |

The reset list (pitcher, team, switch, zones painted, most cells in one zone):

| Pitcher | Team | Switch | Zones | Max cells |
|---|---|---|---|---|
| charlie nagy | (no team) | on | 6 | 5 |
| Cy Young | Blue Bombers | on | 3 | 4 |
| Fireball Ferguson | Blue Bombers | on | 8 | 5 |
| Jeremy Penczak | Cairn University Baseball | on | 0 | — |
| Joshua Feliciano | Cairn University Baseball | on | 1 | 4 |
| Lenny Cicchiello | Cairn University Baseball | on | 0 | — |
| Mason McDonald | Cairn University Baseball | on | 0 | — |
| Paul Cornerpainter | Blue Bombers | on | 8 | 5 |
| Randy Rocketarm | (no team) | on | 6 | 3 |
| Shohei Ohtani | (no team) | on | 0 | — |
| Stacy Softball (softball) | Sledgehammer Softball | on | 1 | 4 |

(Cy Young is scheduled for account deletion on Oct 21–22.)

## 5. Is zone accuracy used separately from exact?

- **The leaderboard uses exact only**, recomputed in SQL; it has never read zones.
- Everywhere else shows both: zone % (over zone-scored pitches) and exact %. Pen reports and trends pick one "Command %": zone if any pitch was zone-scored, else exact.

## 6. How old sessions pick their accuracy logic

- **Per pitch:** `inAccuracyZone` true/false means zone-scored; null means not. `accuracyMode` set means the retired mode (none on production).
- **Per session or block:** "has zone" = any pitch zone-scored (`sessionStats` 5651; `compute.ts` 31, 95).
- So "branch on `accuracy_hit_kind`" fits cleanly: a pitch with a hit kind uses the new rule; one without keeps exactly today's path. Report trend rows are per session, so a U14 session can carry its own one number beside older sessions' numbers.

## Escalations and questions for Joel

1. **Leaderboard (the escalation clause is triggered).** It ranks **exact** accuracy today. Under "one number" it would count RA hits, so a pitcher who marks four easy cells outranks one who marks none. A single week would also mix old (exact) and new (exact + RA) sessions. Options:
   - (a) the leaderboard stays exact-only (labelled "Exact accuracy"). **Recommended:** it compares pitchers to each other, and RA cells are each pitcher's own choice.
   - (b) it reads the one number.
2. **Live Game has no target unless Intent is on.** Without a called spot there is nothing to be exact *to*, and no cell to score RA against. Proposal: in Live Game the RA question appears only when Intent is Yes; with Intent off, game pitches stay as today (no accuracy).
3. **The game report has no accuracy section today.** Adding per-side, per-type exact/RA grids to games is a new section, not a change. Proposal: only for Intent games with RA on (or Intent games in general, exact-only when RA is off). Your call.
4. **"RA off … as today" doesn't match the report.** Today each side block has **one** grid with all pitches and no per-type grids. For U14 sessions with RA off, either:
   - (a) the new per-type grids, exact hits only (**recommended**: the same shape whether RA is on or off);
   - (b) keep today's block unchanged.
5. **Where "the pitcher's last answer" lives.** The profile switch can't simply be dropped: the default needs a home, and a coach may chart on another device.
   - Proposal: keep `profiles.relative_accuracy_enabled` but remove it from Profile's screen and repurpose it as the remembered answer. Starting a session writes the answer back (best effort, online; the device remembers it offline). The reset sets it to false = "first time: No".
   - Nothing else reads it except `coach_set_relative_accuracy`, which stays as the coach's write path.
6. **The painter today only appears when the switch is on** (10035–10050). With the switch gone, the painter always shows, with the "n of 4" counter.
7. **Today's start question is bullpen-only and stored only on the device.** U14 adds `sessions.ra_on` through `sync_session` (no blocker) and the read-only pill on the charting screen (new).

## Joel's answers (Oct 15, 2026)

1. **Leaderboard:** relative accuracy is part of overall accuracy from now on -- "we count whatever you call accurate as accurate", the leaderboard included. (It has been hidden since Oct 10, `hasLeaderboard: false`; its formula changes anyway.)
2. **Live Game:** agreed -- the RA question only with Intent on.
3. **Game report:** agreed -- exact / RA grids for Intent games.
4. **Pen report:** agreed -- U14 sessions always get the per-type grids (exact only with RA off).
5. **Last answer:** agreed -- `profiles.relative_accuracy_enabled` stays as the remembered answer, off Profile's screen.

## Corrections found while building

- Item 2 / escalation 4: the pen and game reports DO already have per-type grids (U11, "Location by pitch type"), but with both batter sides mixed and every pitch in its type color. U14's exact / RA grids are new, inside each batter-side block, and the U11 section is unchanged.
- Most staging bullpen pitches (189 of 285) have no batter side (charted with no batter). A U14 pen like that gets its exact / RA grids in a "No batter" block, scored with the vs-RHB cells as the app does.
