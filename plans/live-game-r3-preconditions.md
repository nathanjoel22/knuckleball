# Live Game R3 preconditions report (Oct 21, 2026)

Packet: `plans/live-game-r3-review.md` (Jordan, Oct 21). Branch `live-game-r3` from `main` at `34bfd82` (v281).
Nothing has been built. Line numbers are `bullpen-tracker.html` on that commit unless named.

**Where the packet and production differ (the packet reviewed v265, before the ship).** Production has migrations
`20261019000000_pitch_count_runs`, `20261020000000_live_game_r1`, `20261021000000_live_game_r2` and
`20261022000000_runners_left`, and 29 policies (H1 grace closed). So A1 and A4 become **new migrations** applied to both
projects alike (no staging-only drops, no edits to shipped migration files); "policies stay at 34" means 29; Stage B
can't fold into R2; `20261022000000` is taken (`20261023000000` too, by the grace close).

Data today (read-only, both projects): `pitches.hbp_swing` set on **0** rows; `sessions.pitch_count_adjust < 0` on
**0** rows; games with `runners_left > 0`: production **0**, staging 2.

---

## Stage A

### A1 · `hbp_swing`

- **Where it lives:** the column and `pitches_hbp_swing_check` (from `20261020000000`); `sync_session`'s pitch insert
  in all three later migrations (current body: `20261022000000_runners_left.sql:129,138`); `schema.sql`; the tracker's
  sync payload (`:5634`), History's `.select(...)` (`:5873`), the History mapper (`:5945`), the pitch record (`:7143`)
  and the log label (`:7691`). Nothing in `supabase/functions` reads it.
- **Old devices are safe on the write side:** `sync_session` reads pitches with
  `jsonb_populate_recordset(null::public.pitches, …)`, which ignores keys the table doesn't have, so a queued item
  from v≤280 that still carries `hbp_swing: null` syncs fine after the drop.
- **The read side is the risk, and the packet's order flips:** any app still on v≤280 names `hbp_swing` in History's
  select, so dropping the column first breaks History on those devices until they reload. **Proposal:** Stage A's
  site release stops sending and selecting it; the column is **dropped in Stage B's migration**, which ships later,
  so devices have had days to update. A device still on old code then gets one History error, and a reload fixes it.
- **Migration:** `sync_session` re-created without `hbp_swing`; the CHECK and column dropped. Rollback re-adds the
  column (NULL everywhere) and the old `sync_session`. `supabase/tests/live_game_r1.sql` stays as history (it tests
  the shipped migration); the new test checks the column is gone and an old-shaped payload with `hbp_swing` still
  saves.

### A2 · Editor redo — **a replay is practical**

- **Today** (`saveEditGameRow`, `:7860`): changes type, velocity, contact, Hit / Error / FC (with `hitType`),
  fielders and earned runs, then saves the draft. Nothing downstream is recomputed.
- **What makes a replay possible:**
  - every pitch and event already stores `ledgerBefore` (`:7806`), and there's a `gameLedgerRestore` (`:7774`);
  - the ledger has only three call sites (`:7158` pitches, `:7487` passed ball / wild pitch, `:7575` walk events),
    and their options can all be rebuilt from the saved record: error / interference → batter taint + one phantom
    out; `chargedPrev` → batter inherited; passed ball → all unearned;
  - the runners on base after each record can be read from the next record's `runnersBefore` (the live `s.runners`
    for the last one).
- **The plan:** restore the ledger to the edited record's `ledgerBefore`, then re-run `gameLedger` for it and every
  later record in `seq` order. Each record's own stored outs and inning are kept; only the runner meta, phantom outs
  and the run split are recomputed. A play whose earned runs were set by hand gets a client-only `erHand` flag
  (the editor sets it) and keeps that value.
- **One thing to fold in first:** after a + Ball walk, `g5CloseWalkEvent` (`:9420`) moves dragged runners and counts
  their runs **outside** `gameLedger`. For the replay to see one code path, that logic moves into `gameLedger` (no
  behaviour change; the Release 2 suite proves it).
- **Sacrifice:** there are two rules in the file. The live one (`g5Commit`, `:9547`): fewer than two out, a fly **or
  line drive** caught with a run scoring → SF; a bunt out moving a runner with nobody out on the play → SAC. The old
  one (`commitFieldPlay`, `:8366`, the pre-G5 flow): fly only, no outs check. The editor re-derives with the live
  rule, pulled into one `gameSacrifice(pt, outsBefore)` used by both the play and the editor. (`commitFieldPlay`
  looks unreachable since G5; removing it is out of scope, so it's left alone and noted here.)
- **Not needed:** the fallback message.

### A3 · Replaced runner on an FC (9.16(g))

- **Today** (`gameLedger`, `:7783`): the batter's meta is `{ u: batterTaint, i: batterInherited }`, and
  `batterInherited` is only the E3 walk (`chargedPrev`). An inherited runner put out on the play just drops away.
- **The fix:** in `gameLedger`, for a play where the batter reaches (1B–3B or scores), count the inherited runners put
  out on it (`runner_advances` with `to = 0` from a runner whose meta has `i`). If at least one is, the batter takes
  `i` (with Stage B, that runner's **owner**). His `u` stays his own (he reached on an error or he didn't). One batter
  can replace one runner, so a double play with two inherited runners out passes one flag.
- **Scope:** batted balls where the batter reaches. Runners put out on a caught stealing, pickoff and so on don't
  transfer (there's no batter reaching in their place).
- **Proof:** a check in the Release 2 headless suite (inherited runner on 1B, 6-4 FC, batter scores later → the run
  is inherited, not the reliever's), plus a double-play case (no batter reaches → nothing passes).

### A4 · Corrections never cut the pitch count

- **Today:** `gamePitchCountAdj` (`:7749`) counts +K / +B events (+1), −K / −B acts (−1) and the top-bar Balls /
  Strikes taps (`a.pc`, ±1, set at `:7293` from `GAME_ADJUST`'s `pc: 1`).
- **The change:** only +K / +B count. −K / −B and the top-bar Balls / Strikes adjust move the count shown and nothing
  else. A draft already in progress when the new app loads is recomputed from its own acts, so it follows the new rule.
- **Migration:** `sessions_pitch_count_adjust_check` → `between 0 and 999` (and bullpens 0, as now). Both projects
  have no negative rows, so it validates.
- **One trap: a queued session from an old app.** A device on v≤280 can hold an outbox item with a negative
  adjustment. Under the new CHECK, `sync_session` would refuse it, and the outbox keeps refused items forever.
  **Proposal:** `sync_session` stores `greatest(0, …)` of what it's sent, so old items still save (at a pitch count
  that is never below the pitches charted, which is the rule).
- **Tests:** `pitch_count_runs.sql` stays as history; the new test inserts −10 directly (refused) and through
  `sync_session` (saved as 0). Headless: ball → +K → −K → top-bar Balls −1 → pitch count 2, count shown moved.
- **Docs:** CLAUDE.md's "Live Game charting now" says "+K / −K / +B / −B (a missed pitch: ±1 pitch count …)"; updated.

### Stage A migration

`20261024000000_live_game_r3a`: the A4 CHECK and `sync_session` (clamp, and no `hbp_swing` in the column list). The
column drop waits for Stage B (A1 above). Rollback and test as usual. Policies 29.

---

## Stage B

### What exists today

- **The hand-off** (`saveGameHandoff`, `:6407`): kept on the device in `kb:gameHandoff` for 5 minutes; carries team,
  pitcher, sport, inning, outs, count, runners (bitmask), opponent, runner meta `{u, i}` and phantom outs. **No
  session id, no owners.** `gameStartInherited` (`:6522`) marks every runner `i: true` and carries `u`.
- **`sessions.runners_left`** is already on production as a **count (0–3)**, not a bitmask (B1 assumed a new
  bitmask). The game report reads it as "runners left".
- **Reports are not sent at save** (B5 assumed they are). A coach taps Send report / View report
  (`sendSessionReport` `:12611`, `viewSessionReport` `:12655`) whenever he likes; the first one freezes the file.
- **The outbox doesn't stop on a refusal** (`syncOutbox`, `:5553`): a later item syncs even if an earlier one failed.
  So a reliever can reach the server before his starter does.
- `pg_cron` is on both projects (A1's daily deletion job).

### B1 · Columns (proposal)

On `sessions`: `final_at timestamptz` (full lock), `exit_runs`, `exit_er`, `exit_bb` (smallint, NULL for games saved
before), `relieved_session_id uuid` (FK → sessions, games only), and `left_owners jsonb`: who each runner on base
belonged to when he came out, e.g. `{"1": "<session id>", "3": "<session id>"}`. **`runners_left` stays the shipped
count**; `left_owners` carries what B1 wanted the bitmask for, plus the owner. `final_at` is set at save when no
runner of his own is left on.

On `pitches` and `game_events`: `charged_runs jsonb`, one entry per inherited run that scored on the play,
`{"s": "<owner session id>", "u": true|false}`; and `charged_prev` gains its owner the same way
(`charged_prev_session uuid`). Today's `inherited_runs` count stays (the report and `compute_game_summary` read it).
That's B3's "inherited-unearned count", kept per runner instead of as a second count.

### B2 · The writer and its checks

One `SECURITY DEFINER` function, `apply_relief_charges(v_relief_id)`, called at the end of `sync_session` for a game
with `relieved_session_id` set. For each owner session named in the relief session's saved `charged_runs` and
`charged_prev_session`, it adds the runs, earned runs and walks to that session's `exit_*`. **Checks, all refused
otherwise:**
- owner and relief sessions are both games, same team, same sport, different pitchers;
- the owner was saved before the relief session started, and within 6 hours of it;
- the owner isn't `final_at`;
- the owner had runners left (`runners_left > 0`), and the total `exit_runs` across all his relievers never exceeds
  that count;
- **who may link:** the relief session's charter is a coach of the team, or the same login that charted the owner.
  A pitcher charting himself can't add runs to a teammate's line.

The H1 lock refuses any API change to `final_at`, `exit_*`, `relieved_session_id` and `left_owners` (the
tombstone's pattern: only the server's own functions), and every change at all once `final_at` is set except the
tombstone and `report_*`.

**If the owner isn't on the server yet** (his item failed or is still queued), `sync_session` refuses the relief
session with `relieved_not_saved`, which keeps it queued and retried. Nothing is lost; it saves on the next sync
after his.

### B3 · Owners on the hand-off

The hand-off gains the starter's session id and `left_owners`-shaped meta: each base's `{u, i, s}`, where `s` is the
runner's owner (the starter for his own runners, or whoever owned an inherited runner he passed on). The reliever's
draft saves `relieved_session_id` from it. With A3, a batter who replaces an inherited runner takes that runner's `s`.
So a second reliever who inherits the starter's runner still charges the starter.

### B4 · Full lock, one rule

B4's two cases (the inning ended; every runner out or scored) reduce to one check at the reliever's save: **is any
runner owned by the starter still on base?** (`left_owners`). If the inning ended, the bases were cleared at the third
out, so none is. If none: the starter's `final_at` is set. If some: the next reliever's hand-off carries them, and
his save decides.

### B5 · The two gaps (Joel to confirm)

- **"Who was pitching?"** The packet lists "the team's games saved today that aren't `final_at`", which needs the
  network, and charting can't (binding design principle). **Proposal:** the list is this device's own saved and
  queued games from the last 6 hours, plus the team's open games from the server **when online**, plus "Not
  charted". Offline with nothing on the device shows only "Not charted".
- **6-hour full lock:** a `pg_cron` job every 15 minutes sets `final_at` on games past 6 hours (same pattern as A1's
  job). Recommended over "the next read", which would need every reader to write.
- **The starter's report:** since reports are sent by a tap, not at save, the rule becomes: **while his game isn't
  `final_at`, Send report / View report say "Waiting for the runners he left on" and stay off**, and become available
  at full lock (at most 6 hours). His bullpens and games that left the bases empty are unaffected.

### B6 · Stats

`compute_game_summary` adds `exit_*` to `runs` / `er` / `bb` and returns `provisional: true` while `final_at` is NULL
(games saved before Stage B: treated as final). The History card reads the same columns (added to History's select).
The report: the pitching line includes them, plus a line under it ("2 runs charged after he left"). The at-bat log's
"R1 scores (charged to <starter>)" goes in the **reliever's** report, from `charged_runs`. The game report payload is
client-built (known landmine 5); the starter's `exit_*` come from his saved session row, not from the client's
arithmetic, and `from_rows.ts` reads the same.

### B7 · Proof

As the packet lists, plus: a reliever synced before his starter (`relieved_not_saved`, then saved); the linker check
(a pitcher's own relief session linking to a teammate → refused); `exit_runs` above `runners_left` → refused.

### Stage B migration

`20261025000000_live_game_r3b`: the B1 columns, the H1 lock, `sync_session`, `apply_relief_charges`,
`compute_game_summary`, the cron job, and A1's `hbp_swing` drop. Rollback and test. Policies 29.

---

## Small items

- **`docs/cf-logo-mown.md`:** line 3 says "design #1 … Strikeout" but the comment over the drawing (line 25) says
  "design #2". Fix the comment.
- **`.15` comments** (`send-session-report/index.ts:5,55`): updated. Also: staging's `REPORT_SITE_ORIGIN` is
  `http://192.168.1.68:8000`, but the Mac is on **`.19`** today, so emailed staging report links don't open. Either
  update the secret (staging only) or reserve an address in the router (the packet's "Later").
- **Stage C 3–4** happened for the shipped work; they repeat for Stage A's and B's migrations, in the same order
  (migrations, then site, then `send-session-report`).

## Decisions for Joel

1. **A1:** drop `hbp_swing` in Stage B's migration, not Stage A's (old apps' History). 
2. **A4:** `sync_session` clamps an old queued negative adjustment to 0 instead of refusing it.
3. **B1:** keep `runners_left` as the shipped count; add `left_owners` and per-run `charged_runs`.
4. **B2:** only a coach of the team, or the starter's own charter, can link a relief session.
5. **B5:** "Who was pitching?" works offline from the device's own games; online adds the team's open games.
6. **B5:** the 6-hour lock is a `pg_cron` job.
7. **B5:** a starter's report waits (buttons off) until his game is final, at most 6 hours.
8. **Two migrations:** Stage A (`20261024000000_live_game_r3a`) and Stage B (`20261025000000_live_game_r3b`).
