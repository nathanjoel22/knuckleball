# G6 — Live Game gaps: Joel's 26 calls (Oct 20, 2026)

**Source.** The decision sheet *What Live Game can't record yet* (artifact `001eeb02-a6a9-4741-99b5-466f1e8f7049`, Oct 20, 2026): 42 plays checked against the code on `live-game-back-more` (staging, v259). Joel marked every card: **26 Include, 15 Skip, 1 Later.** This document turns the 26 into one packet, built and shipped in **four stages**. Where the sheet and this document differ, this document wins; where this document and a later decision of Joel's differ, his decision wins (record it in STATUS.md as always).

**Branch note (Oct 20).** `live-game-back-more` is **not on GitHub** — main is v250 (Oct 17); the newest Live Game branches on GitHub are `live-game-no-clock` (v234) and `u14-relative-accuracy` (v245). The sheet was checked against v259, which has runs, the same-device pitching-change hand-off and the Oct 19 "+K / +B count as pitches" rule — none of which main has. **Joel pushes `live-game-back-more` to GitHub before Claude Code starts; G6 branches from it** (`g6-live-game-gaps`). Everything below that names a function, a column or a line was read on main v250 (`bullpen-tracker.html`, `supabase/schema/schema.sql`, `send-session-report/compute_game.ts` / `template_game.ts`); the preconditions report reconciles it against v259.

## Joel's calls

| Call | Cards |
|---|---|
| **Include (26)** | A1 *(note: "move HR from its current location to be included in this flow")*, A2, A3, A4, A5, A6, A7, A8, B1, B2, B3, B4, B6, B7, C1, C2, C4, C8, E1, E2, E3, E4, E5, E6, E7, F5 |
| **Skip (15) — out of scope; build nothing for them** | B5 foul-tip K choice · B8 WP/PB on the pitch · C3 error details · C5 infield fly · C6 runner reasons on hits/errors · C7 ground-rule double · D1 throw-overs · D2 throwing errors on pickoffs/steals · D3 defensive indifference · D4 rundowns/obstruction/appeals · D5 mound visits · F2 score/W-L-S · F3 how the game ended · F4 pitch-count limits · F6 batter side per batter |
| **Later (1)** | F1 hitters, lineup, pinch hitters — not in G6 |

## Standing constraints (in force)

- One Live Game flow for both sports (S2); the softball differences stay exactly as they are (no Set/Windup, no ⏱, Illegal pitch instead of Balk, fastpitch field, 7 innings).
- Charting never needs the network. Everything rides H1's one-call `sync_session()`; nothing reaches the server before *End session & save*.
- Saved sessions and sent reports are immutable. Old games keep their data and render exactly as before; frozen reports are never touched.
- Games never feed accuracy stats or the leaderboard.
- Outs only when recorded; the charter's taps are the truth (G5 rules 1 and 3). Nothing below pre-fills an out.
- "One definition" (G2): a number History shows comes from the same definition the report uses. Stage 1 (A7) makes that true again.
- GitHub is the source of truth; staging first; a fresh backup before any production migration; only Joel ships.

---

## Data — two additive migrations

### Migration 1 · `g6_game_plays` (ships with Stage 1)

- `pitches.actual_row` and `pitches.actual_col`: **drop NOT NULL and the `DEFAULT 0`**; add CHECK `pitches_location_matches_kind`: a bullpen pitch has both; a game pitch has both **or neither** (neither = a missed pitch, A8). Nothing existing changes (every row has both).
- `pitches.play_flags text[] NULL`, game-only; each element one of `missed_pitch`, `dropped_third`, `hbp_on_swing`, `runner_hit_by_ball` (CHECK: `play_flags <@ array[...]`). NULL on every existing row.
- `sync_session`: carry `play_flags`; NULL `actual_row`/`actual_col` pass through (its explicit column list, the way U14 added `accuracy_hit_kind` in `20261015010000_u14_relative_accuracy_v2.sql`).
- `compute_game_summary` changes in Stage 1 below. Policies unchanged — count before and after. Rollback written before deploy: restore the defaults and NOT NULL (after `select count(*) ... where actual_row is null` shows 0 on production — if not 0, stop and show Joel), drop the column and the checks.

### Migration 2 · `g6_game_start_state` (ships with Stage 3)

- `sessions.start_inning smallint`, `start_outs smallint` (0–2), `start_balls` (0–3), `start_strikes` (0–2), `start_runners smallint` (0–7 bitmask, 1st=1 2nd=2 3rd=4), `handoff_from uuid NULL references public.sessions(id)`, `inherited_runs_scored smallint` — all game-only (extend `sessions_game_fields_check`, or a sibling CHECK). **All NULL means what every existing game means today: started at the top of the 1st, nobody on, 0-0, no outs.** Locked once saved (`sessions_h1_lock` — add them to its list); `sync_session` writes them.
- `pitches.earned_runs smallint NULL` and `game_events.earned_runs smallint NULL` (CHECK `0 ≤ earned_runs ≤ runs_scored`), written **by the client at save** (E1); `sync_session` carries both.
- `compute_game_summary` gains the Stage 3 numbers (below). Policies unchanged. Rollback written before deploy.

---

## Stage 1 — Saving the wrong thing today (A1–A8, plus the Bunt chip from B6)

Ships first and on its own: these fix numbers that are being saved wrong in games charted on this branch, and saved games never change. Includes Migration 1, a `compute_game_summary` change, `send-session-report` and the app.

### A1 · Singles, doubles, triples — and HR moves into this flow (Joel's note)

Today only HR saves a `hit_type`; every other hit is `hit` with no base, so the report's 1B/2B/3B/HR split and XBH count only homers. After **H** the flow becomes:

1. **H** → *How was it hit?* (GB · Pop · LD · Fly · Bunt — unchanged)
2. → **new step *Which base?*** on the field: **1B on box 23, 2B on box 25, 3B on box 17** (the bases themselves are the buttons, drawn as today's base labels), **HR on box 7** (the fence). The old *HR?* box on the location step (box 13 / 14, `G5_HR_BOX`, `g5HrBox`, `g5HrAsk`) is **removed**: HR is chosen here, with the other hit types.
3. → *Location*: 1B/2B/3B shade fair ground (IF/OF chooser as today for GB/Pop/LD; Fly = outfield, Bunt = infield); **HR shades the area over the fence (`G5_OVER_FENCE`) and all fair ground** — a tap over the fence is an over-the-fence homer (`spray_field` NULL, as today); a tap inside the fence is an **inside-the-park homer (C1)**: `spray_field = 'OF'`.
4. → *Bases* (not for HR: everyone scores, bases empty, as today) — **pre-filled with the runners as they were plus the batter on the base he hit to**; a runner standing on that base, and anyone forced ahead of him, moves up one base in the pre-fill (the forced chain, same shape as `forcedWalkAdvances`). The pre-fill satisfies the "Next blocked until the batter is placed" rule (`g5NeedsBatter`) — the charter corrects anything by dragging. **Pre-fill only; the charter's taps are the truth.** *Drafting decision for Joel:* G5 rule 3 said "the charter adds the batter"; with the base known this pre-fill saves a tap on most hits. Strike it if unwanted.

Stored: `hit_type` 1B/2B/3B/HR on every hit (the column exists). Reports and History: the 1B/2B/3B/HR column, XBH and `is_xbh` work from the data; at-bat log ending "1B · LD · box 22"; History's game card shows H with XBH as the report does.

### A2 · Fielder's choice

*Hit, out or error?* gains **FC on box 11** (`G5_HOE` has H 13 · O 12 · E 14). FC → *How was it hit?* → location → bases **pre-filled with the runners as they were and the batter on 1B** (no out pre-filled — the charter drags the retired runner to Out, or taps + Out; a "safe all round" FC is legal and stays an FC). Stored `in_play_outcome = 'fc'` (already in the CHECK), no hit, no error; a strike for strike %; the runner's out from the bases screen (`outs_on_play`, `runner_advances`). `compute_game_summary` counts `fc`; the report's pitching line shows FC beside E; the log ending is "FC · GB · box 18". Next is blocked until the batter is placed, as for H and E.

### A3 · A two-strike foul bunt is a strikeout (reverses G1b decision 11)

Charted with the **Bunt chip (B6, below)** on: at two strikes, **F → Foul Tip** = strike three: result `foul`, `bb_type 'bunt'`, `outs_on_play 1`, `batter_to 0`, at-bat over (the rule already in `applyGameResultProgression`'s foul case via `extra.bunt`, reached today only by the retired `chooseFoulBunt`). **F → Foul Out** stays an out in play (a caught foul bunt is not a strikeout — OBR 9.15(a)); it saves `bb_type 'bunt'` so the report can say "Foul out (bunt)".

Count it as a K in **every copy of the K rule** — `gameStats()` in the tracker, `isK` in `compute_game.ts`, `is_k` / `is_regular_k_out` in `compute_game_summary` — as `result = 'foul' and bb_type = 'bunt' and strikes_before >= 2`, and in `pitchEndsAtBat` / `atBatEndingLabel` ("K (foul bunt)"). Keep the three copies byte-equivalent and cross-referenced in comments, as they are today.

### A4 · Who went where on every play (runner moves)

`g5FinishPitch` nulls `batterTo`, `runnerAdvances` and `runsScored` ("runs and runner paths aren't tracked") — v259 restored the run total; the list of moves is still thrown away except for outs. Fix: **the bases screen tracks who is on each base, not just which bases are occupied.** `g.lineup = { 1: who, 2: who, 3: who }`, `who` ∈ `r1` / `r2` / `r3` (the runner who started this play on that base) / `batter`; plus `g.scored[]` and `g.out[]`. Every action already on the screen updates it:

- drag, or tap a runner then a base, then **Safe** → he is on that base; **Out** → `g.out` (adds the out, as today); dropped on **home** and Safe → `g.scored` (a run, as on v259);
- a tap on an empty base with the batter not yet placed → the batter is on it (today's `g5Base`);
- **+ Out** stays for an out the charter can't attribute to a runner — it adds to `outs_on_play` with no move;
- a tap on an occupied base selects that runner (as the between-pitch field does); tapping it again deselects. **There is no toggle-off**: a runner leaves a base only by advancing, scoring or being put out.

At commit (`g5Commit` → `recordGameResult`), derive from the lineup, the one way: `runner_advances` = `{from, to}` for every runner who moved (to = base, 4 scored, 0 out; unmoved runners omitted — the column comment), `batter_to` (0 / 1–3 / 4), `runs_scored`, `outs_on_play` (runner outs + batter out + unattributed + Out taps), `runners_after` as today. The walk pre-fill (`g5WalkMask`) and A1/A2's pre-fills are expressed in the same lineup. Between-pitch events (`commitAdjustEvent`) already store one `{from, to}` — unchanged. **This is the data E1 (earned runs) and E2 (inherited runners) are computed from; do not build Stage 3 on anything else.**

### A5 · A reliever's innings pitched

At save (`endSession`, ~5230): `gameOutsRecorded = (inning − 1) × 3 + outs` counts every earlier inning as this pitcher's. Replace with **the outs this session recorded: Σ `outs_on_play` over its own pitches and events** (every out already lands there — the batter's O, a strikeout, a runner called Out, + Out, caught stealing). `compute_game_summary` keeps reading the counter (`outs_source: 'counter'`), so old sessions are untouched; its derived fallback (`regular_k_outs + ...`) also adds events' `outs_on_play`. Verify on staging with a hand-off in the 4th: the reliever's IP is his own outs ÷ 3.

### A6 · The final inning after a third out

`gameFinalInning = state.activeSession.inning` at save — after the third out `s.inning` has already moved on. Replace with **the inning of the last pitch or event recorded** (max `inning` / `inning_before` over the session's rows; a session with no rows keeps the current inning). The sheet notes this was found by reading code, not on a phone: **acceptance confirms it on a phone** (end a game right after a third out; the report says the inning he actually pitched).

### A7 · History's game card and the report must agree

History's card and the in-session strip use `gameStats(pitches)` (K/BB/H from pitches only; no R); the report uses `compute_game_summary` (K/BB counting auto strike three, auto ball four and IBB) — and R (v259) is on one and not the other. Fix:

- `compute_game_summary` returns **`r`** = Σ `runs_scored` over pitches **and** events (the tiebreak runner, a steal of home, a balk all score through events).
- One client function `gameLine(pitches, events)` replaces `gameStats` everywhere it is shown (the session strip, the History card, `gameHistoryTypeTable`'s neighbours): pitches, strikes, strike %, **K, BB, H, R, outs, IP**, with definitions byte-equivalent to the SQL (K: strike three looking / swinging / foul tip, foul bunt (A3), legacy `dropped_third`, auto strike three; BB: ball four, auto ball four, IBB; H: in-play hit; R and outs: Σ over pitches and events). History's query (`.select('... pitches(...), session_notes(...)')` ~5746) **adds `game_events(event_type, at_bat_index, inning_before, balls_before, strikes_before, outs_on_play, runs_scored, runner_advances, seq)`**, and the per-profile offline snapshot carries them, so History offline shows the same numbers.
- The report's tiles and pitching line gain **R** from the SQL.

Acceptance: one staging game containing a + Strike strike three, an IBB, a foul-bunt K, a run on a steal of home and two on hits — the in-session strip, History's card and the report show identical K / BB / H / R / IP.

### A8 · Clock violation vs a missed pitch (Joel's rule call)

On v259, + Strike / + Ball add one to the pitch count (Oct 19: for pitches missed while charting). A real clock violation is not a pitch. **Split them:**

- **+ Strike / + Ball stay the fast buttons and mean *missed pitch*** (Joel's Oct 19 intent — the common case at charting pace): a pitch row with `result` `strike_looking` / `ball`, the selected pitch type (no type selected → today's "Pick this pitch's type" hint; there is no "unknown" type), **no location** (`actual_row`/`actual_col` NULL — Migration 1), `play_flags ['missed_pitch']`, count and bases as for any pitch (ball four walks, strike three is a K and asks about a dropped third per B1). Counts in pitch count, strike %, count splits, the at-bat log ("missed — ball"); **never on a location chart, a zone %, the in-zone tile or an Intent score** — one helper on each side (`hasLocation(p)` in the tracker; the same name in `helpers.ts`), used by every grid drawer, History's heat map, `renderHistoryPlot`, `from_rows.ts`. `is_strike_cell(NULL, NULL)` must return false, not error.
- **Clock violation** moves under *More* (Stage 2's tray; in Stage 1 a plain button beside + Strike / + Ball, both sports): the existing `auto_strike` / `auto_ball` events, no pitch, exactly today's `g5AddCount` behaviour (ball four walks, strike three is a K, listed under Other events).

*Drafting decision for Joel:* if he would rather the fast buttons be the clock violation and *Missed pitch* live under More, swap the two — the data stays the same.

### B6 · The Bunt chip (needed by A3; the rest of B6)

A **Bunt** chip at the left of the result row under the chart (K ꓘ B F IP), also shown between pitches so it can be set when the batter squares; highlighted when on; **clears after the next recorded pitch.** With it on: **F** = foul bunt (`bb_type 'bunt'` on the foul row — the precedent `chooseFoulBunt` set; at two strikes, A3), **K (swing)** = missed bunt (`strike_swinging` + `bb_type 'bunt'`), **IP** skips *How was it hit?* with Bunt chosen; **B** and **ꓘ** ignore it (a called strike with the bat pulled back is a strike). The report's by-type and count tables don't change; the at-bat log says "foul (bunt)" / "swing (bunt)"; `pitches_g1b_fields_check` already allows `bb_type` on any game row.

### Stage 1 · report and SQL summary

`compute_game_summary`: `is_k` + foul-bunt K; new `r`, `fc`, counts of hit types from `hit_type`; derived outs fallback includes events. `compute_game.ts`: `isK`, `pitchEndsAtBat`, `atBatEndingLabel` (1B/2B/3B/HR, FC, foul-bunt K, missed pitch, inside-the-park HR), `hasLocation`. `template_game.ts`: R tile and column, FC column, HR (inside the park) label. `from_rows.ts` builds the same. `diamond.ts` untouched. Frozen reports untouched; CACHE_VERSION bumped; `send-session-report` deployed to staging with the branch.

---

## Stage 2 — What a pitch can be, and the play itself (B1–B4, B7, C1, C2, C4, C8)

No migration (`play_flags` and every column used here already exist after Stage 1). App + report.

### The More tray (B2, B3, B4, B7, A8's clock violation)

One **More** button under the chart, both sports, available between pitches and once a location is tapped. Its tray: **Intentional walk** · **Clock violation → Strike / Ball** · **Catcher's interference** · **Batter's interference** · **HBP on the swing**. The first two are no-pitch events and leave any pending location tap alone (as + Strike / + Ball do today); the last three are pitches and are greyed with "Tap where the pitch went first" until a location is tapped. The G1b code is still in the file and is reused, not rewritten: `commitNoPitchEvent('intentional_walk')`, `recordGameResult('interference', {})`, `chooseBIOutcome` / `chooseBIRunnerOut` (`batter_interference`: Batter out, or Runner out → which base), `applyGameResultProgression`'s `hbp` / `interference` / `batter_interference` cases, `GAME_RESULT_LABELS`. The dead `choosePlusCode` / `PLUS_GRID_*` / `gameResultMenu` paths are either wired to the tray or deleted — nothing stays dead.

- **B2 IBB:** batter to 1st, forced runners up, then the **runners question** (G5 rule 2 — a walk asks it), pre-filled with the forced chain; stored as the `intentional_walk` event; BB in every line (already in the SQL and `eventEndsAtBat`).
- **B3 CI:** result `interference`; batter to 1st, forced chain, runners question; excluded from strike % as today (`EXCLUDED_FROM_PCT`); the log says "Catcher's interference"; the pitching line gets a CI count beside HBP.
- **B4 BI:** result `batter_interference`; *Batter out* (out, runners hold, at-bat over) or *Runner out → base* (that runner out, same batter, count continues) — exactly the G1b branches. BI is neither a strike nor a ball: keep it out of strike % (add it to `EXCLUDED_FROM_PCT` and the SQL's `counts_toward_pct` in lockstep).
- **B7 HBP on the swing:** `strike_swinging` + `play_flags ['hbp_on_swing']`; at two strikes a K; counts as a strike and a swing, never as an HBP; the log says "K — hit by the pitch on the swing".

### B1 · Dropped third strike

After **K** (swing) or **ꓘ** (looking) at two strikes, when the rule allows the batter to run — **first base empty, or two outs** — the result row is replaced by one prompt: **"Dropped third strike?" · No · Reached · Thrown out** (No is also what Next / the next tap means, so the common case costs nothing). *Reached* → the runners question pre-filled with the batter on 1st and the forced chain (a dropped third is "the same forced chain as a walk" — the existing comment); *Thrown out* → the out, no runners question (G5 rule 2). Stored on the strike row: `play_flags ['dropped_third']`, `batter_to` 1 (or where he was placed) / 0, `outs_on_play` 0 / 1, `runners_after`. **A K for the pitcher either way** (OBR 9.15(a)); K vs ꓘ is kept because the result stays `strike_swinging` / `strike_looking`. The legacy result value `dropped_third` is never written again; readers keep handling it for old rows. Readers take outs from `outs_on_play`, never from "strike three". Log: "K (dropped third — reached)".

### C1 · Inside-the-park home run

Built by A1 (HR's location step shades fair ground as well as over the fence): `hit_type 'HR'`, `spray_box` inside the fence, `spray_field 'OF'`, everyone scores. The at-bat log and spray charts label it "HR (inside the park)"; the pitching line's HR column counts it. Dragging the batter home on a 1B/2B/3B stays allowed (A4) and is stored as tapped (`batter_to 4`, the hit type as chosen) — the charter's taps are the truth.

### C2 · Sacrifice fly and sacrifice bunt — derived, never tapped

The rule in the retired code (~7811, "Decision 13"), widened to every caught ball in the air: **fly / line drive / pop out + batter out + a run scored = SF; bunt + batter out + a runner advanced = SAC**, computed at commit from A4's lineup and stored in `pitches.sacrifice` (exists). Report: the log ending "SF · box 20" / "SAC · 1-3"; `compute_game_summary` counts `sf` and `sac`; the pitching line shows them; nothing else changes (no AB/BA exists in this report).

### C4 · Fielders and play notation (reverses G5's "fielders not modeled")

For **O, E and FC only**, after the location tap, an **optional** step *Who fielded it?*: the nine positions drawn on the field where they stand — **C 15 · P 24 · 1B 23 · 2B 22 · SS 18 · 3B 17 · LF 19 · CF 20 · RF 21** (the same map `from_rows.ts` / the report use to place old games). Tap in order (6 then 3); **Skip ›** or **Next ›** continues to the bases screen. Stored: `fielders` = "6-3" (position numbers, the existing column), `fielder` = the first position's code. Notation everywhere the play is named (log, History, report): ground out "6-3", fly/pop out "F8", line out "L8", unassisted "3U", error "E6", FC "FC 6-4", foul out "F2"; without fielders, today's wording. **One skip-tap per out when Joel doesn't want it** — he asked for the step knowing that; if it proves too slow at charting pace, escalate rather than removing it.

### C8 · Runner hit by a batted ball

On the bases screen of a **hit** (entry H), when runners are on: a **Hit by ball** button beside + Out → pick the runner (if more than one) → he is out (`runner_advances {from, to: 0}`, `outs_on_play` +1), the batter is placed on 1st and `hit_type` is forced to **1B** (the award), `play_flags ['runner_hit_by_ball']`. Log: "1B · runner on 2nd out (hit by the ball)".

### Stage 2 · report

At-bat log and *Other events* carry every new wording above; the pitching line adds CI and FC (Stage 1) columns; the SQL counts `ci`, `bi`, `sf`, `sac`, `dropped_third_reached`. Frozen reports untouched; CACHE_VERSION bumped; function deployed to staging with the branch.

---

## Stage 3 — Runs and the pitching line (E1–E7)

Migration 2 ships with this stage. The hand-off and the start state come first (E4), because E1–E3 are computed from them.

### E4 · Starting mid-game: any device, any time (replaces the 5-minute, same-device hand-off)

The Live Game start screen (the Oct 12 start questions) gains **"Starting mid-game?"** (default No). Yes → **inning, outs (0–2), count (balls 0–3, strikes 0–2), runners (1B · 2B · 3B toggles)**, and **"Taking over from"**: a drop-down of this team's saved game sessions **today, same opponent** (synced ones from History; "— none —" when the starter charted on another phone and hasn't synced). The same-device hand-off (v259) keeps working and simply **pre-fills this screen** from the previous session's end state with the previous session selected — with no time limit; one tap confirms. Stored: `start_*`, `handoff_from` (a real FK: the reliever's outbox item waits behind the starter's until that one has synced — the outbox already sends in order; a refusal keeps it queued with its reason, per H1). The session's live state begins from the start state; its first at-bat index is 1 as today (the at-bat in progress counts as the reliever's first batter unless E3 reassigns it). `runners_before` on the first row shows the inherited runners; A4's lineup marks them `r1`/`r2`/`r3` with `inherited = true` so E2 can follow them.

### E1 · Earned and unearned runs (ERA)

Computed **once, at save, by the client**, written onto the rows that scored them (`pitches.earned_runs`, `game_events.earned_runs`), summed by `compute_game_summary` (`er`); History and the report show **ER** and **ERA** (= ER × 9 ÷ IP for baseball, **ER × 7 ÷ IP for softball**; "—" at 0 IP). The one definition lives in the tracker (`earnedRunsForSession(session)`), replayed half-inning by half-inning over A4's lineup with OBR 9.16 made deterministic and **the benefit of every doubt given to the pitcher** (9.16(f)):

1. Each runner's *reach reason* is known from the play that put him on: hit, walk (incl. IBB, auto ball four), HBP, FC, **error**, **catcher's interference**, **dropped third strike** (treated like an error — no WP/PB is recorded, B8 skipped), **tiebreak placement** (unearned by rule), or **inherited** (E2 decides who is charged).
2. *Should-be outs* for the half-inning = outs actually recorded + batters who reached on an error (+ a dropped third strike reached).
3. A run is **unearned** when the runner reached on an error / CI / dropped third / tiebreak placement; **or** the move that scored him was an error play or a passed ball; **or** at the moment he scored, should-be outs were already 3 or more (the inning should have been over).
4. Every other run is earned: hits, walks, HBP, steals, wild pitches, balks / illegal pitches, sacrifices, FCs.

The report's ERA line carries a one-line note: "Earned runs are figured by Knuckleball's fixed rule (errors, passed balls, interference and dropped third strikes are unearned; the pitcher gets the benefit of every doubt)." Old games: a game saved before Stage 3 has `earned_runs` NULL on every row → `compute_game_summary` returns `er_source: 'none'` and the report shows ER and ERA as "—", never 0.00.

### E2 · Inherited runners

From E4's start state: runs scored by inherited runners are **not charged to the reliever** — `sessions.inherited_runs_scored` (computed at save from the lineup chain), `compute_game_summary` returns `r`, `r_charged` (= r − inherited_runs_scored), `inherited_runners` (popcount of `start_runners`), `inherited_runs_scored`; the pitching line reads "R 4 (1 inherited, not charged)". **The starter's side:** when the starter's report is generated *after* a linked reliever session (`handoff_from`) has synced, the SQL adds the inherited runs that scored to the starter's `r_charged` and the line says "+1 scored after he left"; a starter's report generated before that stays as it is (reports are frozen — stated in the note). A runner removed without the batter's action (caught stealing, pickoff) is not counted against either (9.16(g)) — he never scores.

### E3 · Pitching change in the middle of an at-bat (OBR 9.16(h))

With E4's start count: if the reliever's **first** plate appearance ends in a **walk** and the start count was **2-0, 2-1, 3-0, 3-1 or 3-2**, the walk and the batter faced are charged to the previous pitcher — the reliever's BB and BF exclude it (`compute_game_summary`: `bb_charged_to_previous` 0/1, applied to `bb` and `batters_faced`), the at-bat log marks it "BB (charged to the previous pitcher)"; the starter's line adds it under the same linked-and-generated-later condition as E2. **Any other result, and a walk from any other count, is the reliever's.** A strikeout is always credited to the pitcher who threw strike three (no transfer).

### E5 · WP and BK in the pitching line

`compute_game_summary` counts `wp` (wild_pitch events) and `bk` (balk events; softball: `illegal_pitch` events, shown as **IP**); the pitching line adds the two columns (sport label); they stay listed under Other events too.

### E6 · Runner reasons and runs by play in the at-bat log

Every at-bat row shows what the runners did on its last play and between its pitches: "R1 → 3B", "R2 scored", "R1 out (caught stealing)", "DP", "+1 run"; runs appear as a running total per inning ("2 runs in the 4th"). From `runner_advances`, `runs_scored`, `outs_on_play`, `play_flags` and the events already stored. Old rows with no moves show nothing new.

### E7 · More count splits

*Results by count* adds **Three-ball counts (3-0, 3-1, 3-2)** and **Two-strike counts (0-2, 1-2, 2-2, 3-2)** rows (same shape; the 20-pitch section threshold stays), and a line under *By inning*: **Leadoff batter reached** — n of m innings (the first at-bat of each inning this pitcher started; reached = hit, walk, HBP, error, FC, CI, dropped third; a session that started mid-inning skips that inning).

---

## Stage 4 — Fixing an earlier at-bat during the game (F5)

No migration. The Live Game session log gains **Edit** on every pitch row, like bullpens (`startEditDraftRow` / `saveEditDraftRow` — type and velocity today), plus for games: **the location** (re-tap on a small chart), **the result** (B · ꓘ · K · F · IP), and for a ball in play **H / O / E / FC, hit type, contact, spray box and the fielders**. Saving **replays the game from that row**: the live state is rebuilt by re-applying, in order, every later row's recorded result and its bases as tapped (`runners_after` and the lineup moves are kept; they are the truth), rewriting each later row's *before* snapshot (count, outs, inning, at-bat index, `runners_before`) and the derived columns (`outs_on_play`, `batter_to`, `runner_advances`, `runs_scored`, `sacrifice`). **Pitch order never changes** (Track G note: count stats depend on true order). If the replay hits an impossible state (a later row's runners_after names a base that is now empty, four strikes, four outs) the editor refuses with the reason and changes nothing — the charter can Undo back instead. **Remove** works the same way (replay from the removed row). Saved games stay locked; nothing here touches a saved session (H1).

---

## The packet (paste for Claude Code — after `live-game-back-more` is on GitHub)

```
ID:              G6
Title:           Live Game gaps — Joel's 26 Include calls from the Oct 20 sheet, in
                 four stages: (1) what saves wrong today, (2) what a pitch can be
                 and the play itself, (3) runs and the pitching line, (4) editing an
                 earlier at-bat during the game
Spec:            plans/g6-live-game-gaps.md on GitHub (pull first; work only from
                 GitHub). The sheet's cards A1-F6 are summarized there; this file
                 is the spec, not the sheet.
Branch:          g6-live-game-gaps, from live-game-back-more (Joel pushes it first;
                 if it is not on GitHub, stop and say so). One branch, four
                 stages, each shipped on its own with its own STATUS.md entry.
Depends on:      G5 (field), the Oct 12-13 runner moves and Intent, G3 (events,
                 level of play), H1 (one-call save and locks), U14, S2. Staging
                 only; only Joel ships to production.
Out of scope:    every Skip card (B5, B8, C3, C5, C6, C7, D1-D5, F2, F3, F4, F6)
                 and F1 (Later). Bullpens: untouched. Frozen reports: untouched.
                 No new event types. No post-hoc editing of a saved session.

PRECONDITIONS -- REPORT, with file and line numbers, before any code or SQL
(Build nothing until Joel has read the report):
  1. v259 vs main: list every Live Game change on live-game-back-more that main
     v250 does not have (runs, the hand-off, the Oct 19 + Strike / + Ball
     rule, count fixes, anything else), with how each is stored. In
     particular: how a + Strike / + Ball "pitch" is stored on v259 (a pitch
     row? with what location and type?), and how runs reach pitches.runs_scored
     / game_events.runs_scored.
  2. The bases screen as built (g5Base, g5Propose, g5MoveResult, g5ShownBases,
     g5NeedsBatter, g5FinishPitch): what is kept per move today and where it is
     dropped; confirm runner_advances / batter_to are nulled and which outs
     keep their moves.
  3. The save path: endSession's gameFinalInning / gameOutsRecorded, the outbox
     mapper's column list, sync_session's column lists, the H1 lock lists.
  4. compute_game_summary as it stands on staging (not just the migration
     files): every number it returns and who reads it (History card, trend
     points, from_rows.ts, index.ts).
  5. gameStats() and every place it is displayed; History's session query and
     the offline snapshot shape (do events ride along today?).
  6. The G1b code still in the file that Stage 2 reuses: choosePlusCode,
     chooseDroppedThirdOutcome, chooseBIOutcome/chooseBIRunnerOut,
     commitNoPitchEvent, applyGameResultProgression's hbp / interference /
     batter_interference / dropped_third / foul(bunt) cases, chooseFoulBunt,
     GAME_RESULT_LABELS -- and whether v259 already has an HBP button and
     where.
  7. Every reader of pitches.actual_row / actual_col in the tracker and the
     function (grids, heat maps, zone %, in-zone %, Intent scoring,
     is_strike_cell), for A8's NULL location.
  8. The hand-off on v259: what it carries, the 5-minute / same-device limits,
     where the reliever's session starts.
  9. Game counts on staging and production (sessions, pitches with hit_type,
     rows with actual_row null -- expect 0).
  10. Any place the four stages' flows would exceed the field's 25 boxes or
      collide with existing taps (A1's Which base? on 23/25/17/7, A2's FC on
      11, C4's positions) at 375 / 390 / iPad / laptop widths.

BUILD, in this order; stop for Joel's check after each stage:
  Stage 1  Migration 1 (g6_game_plays) + compute_game_summary (foul-bunt K, r,
           fc, hit-type counts, events in the derived outs) -> staging after a
           dry run; then the app: A1 (Which base? step, HR moved, inside-the-
           park location, pre-fill), A2 (FC), A3 (foul-bunt K in all three
           copies), A4 (lineup on the bases screen; derive runner_advances /
           batter_to / runs_scored / outs_on_play at commit), A5 (outs
           recorded = sum of own rows), A6 (final inning = last row's
           inning), A7 (gameLine() + events in History's query and snapshot +
           R everywhere), A8 (+ Strike / + Ball = missed pitch rows with NULL
           location + play_flags; Clock violation = the auto events; hasLocation
           on both sides), B6 (Bunt chip). Then compute_game.ts /
           template_game.ts / from_rows.ts per "Stage 1 - report and SQL
           summary". Bump CACHE_VERSION; deploy the function to staging.
  Stage 2  The More tray (IBB, Clock violation, CI, BI, HBP on the swing),
           B1 dropped third (prompt only when 1B is empty or two outs), C1
           labels, C2 SF/SAC derived at commit, C4 fielders step (optional,
           O/E/FC only, positions on the field), C8 Hit by ball; the report
           wording and the SQL counts. No migration.
  Stage 3  Migration 2 (g6_game_start_state) -> staging; E4 start-mid-game
           screen + hand-off any time; A4 lineup marks inherited runners; E1
           earnedRunsForSession() at save -> earned_runs on rows; E2 / E3 in
           compute_game_summary and the report; E5 WP/BK; E6 log detail; E7
           splits.
  Stage 4  F5 row editor with replay-from-row; refuse impossible states.

ACCEPTANCE (both sports unless stated; stored rows shown with SQL; every check
numbered in the evidence file plans/g6-evidence.md):
  Stage 1
  1.  A1: single / double / triple / over-the-fence HR / inside-the-park HR
      charted on a phone: each row stores hit_type and spray_box; HR over the
      fence has spray_field NULL, inside the park 'OF'; the old HR? box is
      gone; the bases screen opens pre-filled with the batter on his base and
      forced runners moved up; the report's 1B/2B/3B/HR column, XBH and the
      log endings are right; History's card shows H and XBH.
  2.  A2: FC with a runner on 1st -- in_play_outcome 'fc', the runner dragged
      to Out gives outs_on_play 1 and runner_advances [{from:1,to:0}], the
      batter on 1st; no hit, no error; FC in the pitching line.
  3.  A3: Bunt chip on, two strikes, F -> Foul Tip: result foul, bb_type bunt,
      outs_on_play 1; K in the session strip, History and the report; F ->
      Foul Out: an out in play labelled "Foul out (bunt)", not a K.
  4.  A4: a single with runners on 1st and 3rd, R1 dragged to 3rd, R3 home:
      runner_advances [{1->3},{3->4}], batter_to 1, runs_scored 1,
      runners_after 5; a double play by drag (R1 out, batter out): outs_on_play
      2, both moves stored; a walk's forced chain stored the same way.
  5.  A5: a session started by hand-off in the 4th with 1 out: after 4 of its
      own outs, game_outs_recorded = 4 (IP 1.1), not the inning arithmetic.
  6.  A6: end a game right after a third out in the 5th, on a phone:
      game_final_inning 5; the report says 5 innings.
  7.  A7: the game in the spec's A7 paragraph -- strip, History card and
      report identical on K / BB / H / R / IP, online and offline (the card
      from the snapshot).
  8.  A8: + Strike then + Ball: two pitch rows with actual_row / actual_col
      NULL, play_flags {missed_pitch}, the selected type, counted in pitches
      and strike %, absent from every grid, heat map and zone %; Clock
      violation -> auto_strike / auto_ball events, no pitch row; ball four
      by either path walks and asks the runners question.
  9.  B6: F with the chip at one strike -> foul row with bb_type bunt and no
      out; K (swing) with the chip -> strike_swinging + bunt; IP with the chip
      skips How was it hit?; the chip is off after each pitch.
  10. compute_game_summary before / after on an existing production-shaped
      game (copied to staging): every number identical except the new keys;
      policies 34 before and after; schema.sql regenerated after the
      production run.
  11. Offline: a full inning using every new step, kill the browser, Resume at
      the same screen; save offline, reconnect -> one sync_session call with
      the new columns; P1-01 checks 1-3 pass.
  Stage 2
  12. More: IBB between pitches -> intentional_walk event + the runners
      question; CI / BI / HBP on the swing greyed until a location is tapped,
      then stored as specified (interference; batter_interference with
      Batter out or Runner out -> base; strike_swinging + hbp_on_swing, a K
      at two strikes); none counts toward strike % except HBP on the swing.
  13. B1: strike three with 1B empty -> the prompt appears; with a runner on
      1st and fewer than two outs it does not; Reached -> batter_to 1,
      outs_on_play 0, play_flags {dropped_third}, forced chain pre-filled; K
      counted; Thrown out -> outs_on_play 1; the log reads as specified.
  14. C2: fly out with R3 scoring -> sacrifice 'SF'; bunt out with R1 to 2nd ->
      'SAC'; a bunt out with nobody advancing -> NULL.
  15. C4: ground out 6-3 tapped on SS then 1B -> fielders '6-3', fielder 'SS';
      fly out CF -> 'F8'; error on SS -> 'E6'; Skip stores NULL and today's
      wording; the step never appears on a hit or a strikeout.
  16. C8: a single with R2 hit by the ball -> hit_type 1B, R2 out,
      play_flags {runner_hit_by_ball}, batter on 1st.
  17. Report: every Stage 2 wording present on a staging game; frozen reports
      byte-identical; History cards unchanged for old games.
  Stage 3
  18. E4: start mid-game in the 6th, 2 outs, 3-1, runners on 1st and 2nd,
      taking over from a synced session -> start_* and handoff_from stored and
      locked after save; the same-device hand-off pre-fills the screen with
      no time limit; another phone with no synced starter leaves
      handoff_from NULL.
  19. E1: three hand-built half-innings on staging, hand-scored first by Joel
      (one with an error extending the inning, one with a passed-ball run,
      one clean) -> earned_runs per row and er / era match the hand score;
      softball ERA uses 7.
  20. E2: a reliever inheriting R1 and R3, R3 scores on his first pitch ->
      inherited_runs_scored 1, r 1, r_charged 0; the starter's report
      generated afterwards shows "+1 scored after he left"; one generated
      before stays frozen.
  21. E3: a reliever at 3-1 walks the first batter -> bb_charged_to_previous 1,
      his BB and BF exclude it, the log says so; at 1-2 a walk is his.
  22. E5-E7: WP / BK (IP for softball) columns; the log's runner lines and
      runs per inning; the two new count rows and the leadoff line, with
      counts hand-checked against SQL on one game.
  Stage 4
  23. F5: in the 5th, change a 2nd-inning single to an error -> the row
      becomes an error, hit totals drop, later rows' before-snapshots are
      rewritten and identical to a fresh charting of the same sequence
      (diff the two sessions' rows); an edit that would strand a later
      runners_after is refused with the reason; a saved session shows no
      Edit anywhere.
VERIFICATION: after each stage, Joel charts a real inning on his phone and
  iPad on staging (both sports) using that stage's new taps, and reads the
  report; production only after a fresh backup, migration before the site,
  function deployed, two reloads on a phone, STATUS.md entry.
ROLLBACK: per stage: git revert + CACHE_VERSION bump; the stage's down
  migration (written before deploy; Migration 1's restores NOT NULL only after
  proving no NULL locations exist on production); function: check out the
  previous send-session-report directory and redeploy.
SIZE: L (Stage 1), L (Stage 2), L (Stage 3), M (Stage 4).
ESCALATE IF: v259's + Strike / + Ball storage or its runs storage cannot be
  reconciled with Migration 1 without touching existing staging rows; A4's
  lineup cannot be kept through Resume / Undo without changing the draft
  shape in a way an in-progress game would not survive; A8's NULL location
  breaks any reader that cannot be reached (an old frozen report never
  reads live rows -- so none expected); C4's extra step slows charting at
  real pace (Joel's call, not a quiet removal); E1's rule produces a result
  Joel's hand score disagrees with (bring the case, don't bend the rule);
  the starter's report cannot read a linked reliever session -- compute_game_
  summary runs under the caller's RLS, and the STARTER himself (a different
  pitcher) cannot see the reliever's rows: show the options (e.g. one
  SECURITY DEFINER helper that returns only the inherited-run and charged-
  walk counts for a session linked by handoff_from) rather than widening a
  policy; F5's replay needs anything beyond the rows' own recorded inputs.
```

### Drafting decisions for Joel (strike any you don't want)

1. **A1 pre-fill** puts the batter on his base and moves forced runners up; G5 rule 3 said the charter adds the batter.
2. **A8**: the fast + Strike / + Ball buttons mean *missed pitch*; *Clock violation* lives under More. Swap if you'd rather.
3. **B1**: the dropped-third prompt appears only when the rule allows the batter to run (1B empty, or two outs); otherwise strike three is simply a K.
4. **C4**: one *Skip* tap on every out, error and FC you don't want to name fielders on.
5. **E1**: a dropped third strike the batter reaches on is scored like an error (unearned), since no WP/PB is recorded (B8 skipped).
6. **E2/E3**: the starter's report picks up runs and a walk charged to him only when it is generated after the reliever's session has synced and was linked at the start screen; a report already generated stays frozen.
