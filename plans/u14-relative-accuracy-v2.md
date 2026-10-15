# U14 — Relative accuracy, version 2: ask at the start, four cells max, one accuracy number (Oct 15, 2026)

**Joel, Oct 15, 2026.** Relative accuracy (RA) changes in three ways, for both bullpens and Live Game, both sports:

1. **It's a question at the start of every session:** "Turn on Relative Accuracy?" **Yes / No.** It is no longer a background switch in Profile.
2. **A pitcher may mark up to four additional cells** he is fine hitting, per pitch type and per batter side. Not unlimited: four per pitch per side.
3. **There is no separate RA metric.** A pitch that lands in one of those cells is a **hit**, the same as landing the exact target, and it raises the pitcher's one accuracy number. Reports show, per pitch type and per batter side, **exact hits** (landed the target cell) in one color and **RA hits** (landed a marked cell) in another.

**Old charts don't change.** Every saved session keeps rendering as it did; frozen reports are untouched. This applies to sessions charted from the day it ships.

**Reset:** every pitcher who has RA zones painted today has them **cleared** and his RA switch turned off. Joel tells those pitchers himself and they mark their new cells. Past pitch rows are not touched (saved sessions are immutable).

## How it works

### The question
- Appears on the session start screen (after pitch type / before the first pitch; Live Game: after the opponent/perspective setup), as a two-segment tray **Yes / No** (U13). Default = the pitcher's answer last time; first time = No.
- Stored on the session (`sessions.ra_on boolean NOT NULL`). Changeable only before the first pitch; after that the pill shows the answer read-only (changing it mid-session would make the session's pitches mean two things).
- With **No**, charting is exact-only, as with RA off today. With **Yes**, tap 1 lights the pitch type's marked cells for the current batter side (as today's RA does); a pitch type with no cells marked for that side behaves as exact-only for that pitch, and the screen says so once.

### Marking cells (Profile, as U7 built it, with the cap)
- Per pitch type, per batter side, catcher-frame cells, D8 labels, RHB/LHB toggle: unchanged from U7.
- **Cap: four cells per pitch type per side.** The fifth tap does nothing and the grid says "4 of 4"; a counter shows "2 of 4" as you go. Enforced in the database too (array length ≤ 4).
- The exact target (tap 1) is chosen per pitch, so the marked cells are the **additional** cells; if the target happens to be one of the marked cells, the pitch is scored exact.
- Pitcher and his coaches can edit, as U7 decided. The Profile "Relative Accuracy" switch is **removed** (the session question replaces it); the zone painter stays.

### Scoring (one number)
- Each pitch stores `accuracy_hit_kind`: `exact` (landed the target cell), `ra` (landed a marked cell for that pitch type and batter side, with the cells copied onto the pitch as U7 does), or `miss`. With RA off, only `exact` / `miss`.
- **Accuracy % = (exact + ra) / pitches.** Everywhere: the live counter, History, Profile, the leaderboard (if it reads accuracy; precondition 5 confirms), reports. No "zone accuracy %" line anymore for new sessions.
- Old sessions keep their stored `in_accuracy_zone` / `accuracy_mode` logic and render as before. The display code branches on whether the pitch has `accuracy_hit_kind`.

### Reports (new sessions with RA on)
- In each per-side block (vs RHB, vs LHB), **one small location grid per pitch type** showing where hits landed: **exact hits in `--brand-mid`**, **RA hits in `--brand-soft`** (softball: Harbor and the matching soft blue), misses as faint hollow marks so counts reconcile; a legend "Exact · RA" once per block; headline per type: `12 hits of 18 — 9 exact, 3 RA`. Pitcher's view (U12).
- RA off: the per-type grids show exact hits only, no legend, as today.
- Frozen reports and sessions charted before U14: unchanged.

### Reset migration
- Lists every pitcher with any painted zone or the switch on (name, team, count of zones) in a report for Joel **before** running; then clears the zones and the switch. Past `pitches` rows untouched.

## Decisions made in drafting (Joel may override)

1. The question defaults to the pitcher's previous answer, so a pitcher who always wants it on taps once.
2. Locked after the first pitch of a session.
3. The Profile switch goes away; the painter stays in Profile. (If Joel wants the switch kept as the default for the question, say so.)
4. Misses are drawn faintly on the per-type grids so the three counts add to the pitch count; Joel asked only for exact and RA, so strike the misses if unwanted.
5. Colors: dark turf for exact, soft turf for RA (one hue, two weights, so the pair reads as "hit, two ways"); gold stays reserved for actions and selection per DESIGN.md.

---

## The packet (paste for Claude Code)

```
ID:              U14
Title:           Relative accuracy v2 — session-start question, ≤4 marked cells
                 per pitch per side, one accuracy number, per-type exact/RA
                 report grids; reset existing zones
Spec:            plans/u14-relative-accuracy-v2.md on GitHub (pull first; work
                 only from GitHub). Screens per docs/design/target/DESIGN.md;
                 the Yes/No is a U13 tray.
Depends on:      U7 (zones, in_accuracy_zone, accuracy_zone_cells), U2a (batter
                 side), U12 (pitcher's view), D2 (tokens), G5 (Live Game start
                 screen), H1 (immutability). All shipped.
Staging only.    One migration; send-session-report change; fresh production
                 backup before the migration. Only Joel ships to production.

PRECONDITIONS — REPORT, with file and line numbers, before any code:
  1. Today's RA data model: profiles' switch, the zone tables/columns per pitch
     type per side, pitches.in_accuracy_zone / accuracy_zone_cells /
     accuracy_mode and their check constraints; who writes them (tracker,
     sync_session).
  2. Every place accuracy is computed or displayed: live counter, History,
     Profile, leaderboard (get_team_leaderboard), both report templates,
     SC1 stats if built. Which read stored per-pitch results vs recompute.
  3. The session start screens for bullpen and Live Game (both sports): where
     the question fits before the first pitch; what sessions already stores at
     start (perspective, opponent, team).
  4. Counts on production: pitchers with the switch on; pitchers with any
     painted zone; zones with more than 4 cells; pitches with
     in_accuracy_zone set (for the record — not to be changed).
  5. Whether the leaderboard or any stat uses zone accuracy separately from
     exact accuracy today.
  6. How History and reports decide which accuracy logic to apply per session
     (so old sessions keep their rendering).
  Build nothing until Joel has read the report.

MIGRATION u14_relative_accuracy_v2:
  - sessions.ra_on boolean NOT NULL DEFAULT false (existing rows false).
  - pitches.accuracy_hit_kind text NULL CHECK (exact|ra|miss); NULL on every
    existing row (they keep in_accuracy_zone / accuracy_mode).
  - Zone cells: CHECK array_length ≤ 4 on NEW/updated zone rows (existing
    rows are cleared by the reset below, so the constraint can be strict).
  - Reset: a script that first OUTPUTS the list (pitcher, team, zones, cell
    counts) for Joel, then clears all zones and switches. Run on staging
    first; on production only after Joel has the list. pitches untouched.
  - Drop/retire the profile switch column only if nothing else reads it;
    otherwise leave it false. Policy count before/after.

CLIENT:
  - Start question (spec) on bullpen and Live Game, both sports; default =
    pitcher's last answer; locked after pitch 1; stored on the session via
    sync_session.
  - Profile: switch removed; painter capped at 4 with "n of 4"; coach edit
    path unchanged.
  - Charting: tap 1 lights marked cells when ra_on and cells exist; tap 2
    writes accuracy_hit_kind (+ cells copy as today); accuracy % =
    (exact+ra)/pitches on the live counter.
  - History / Profile / leaderboard: one accuracy number for U14 sessions;
    old sessions unchanged (branch on accuracy_hit_kind).
  - Offline: ra_on and hit kinds travel in the outbox payload; P1-01 checks.
  - CACHE_VERSION bump.

REPORTS (send-session-report, both templates):
  - Per-side blocks: per-pitch-type grid with exact (--brand-mid) and RA
    (--brand-soft) hits, faint misses, one legend per block, headline
    "H hits of N — E exact, R RA"; pitcher's view. RA off: exact only.
  - Sessions without accuracy_hit_kind render exactly as before (byte-
    compare one old staging session's report before/after).
  - Frozen reports never touched.

OUT OF SCOPE: changing how exact hits are judged; the 7×7 grid; recomputing
  any old session; per-pitch RA questions; changing leaderboard rules beyond
  reading the one number.

ACCEPTANCE (both sports; SQL shown):
  1. Bullpen and Live Game start screens show the Yes/No tray; default
     follows the last answer; locked after pitch 1; sessions.ra_on stored.
  2. Profile painter stops at 4 per pitch per side ("4 of 4"); a direct insert
     of 5 cells is refused by the database.
  3. Charting with RA on: marked cells light on tap 1 for the right pitch type
     and side; tap 2 stores exact / ra / miss correctly in all three cases
     (target hit; marked cell hit; neither) and when the target is itself a
     marked cell (→ exact). RA off: exact / miss only.
  4. Accuracy % on the live counter, History, Profile and leaderboard equals
     (exact+ra)/pitches for a U14 session, hand-checked against SQL; an old
     session's numbers are unchanged before/after deploy.
  5. Report for a U14 session with RA on: per-type grids per side with two
     colors and the legend; counts reconcile; a U14 session with RA off shows
     exact-only grids; an old session's report is byte-identical.
  6. Reset: the list was produced and given to Joel; after the run, zero
     zones and zero switches on; pitches row counts and in_accuracy_zone
     values unchanged (before/after checksum).
  7. Offline: a RA-on pen charted in airplane mode syncs with hit kinds
     intact.
  8. Screens match DESIGN.md / U13; screenshots at 390/iPad, both sports.
VERIFICATION: Joel charts one RA-on pen and one RA-on half-inning on staging
  with a pitcher who has 4 cells marked for a slider vs RHB; reads the report.
ROLLBACK: git revert; down migration drops ra_on and accuracy_hit_kind and the
  length check; zones cleared by the reset are not restored (Joel's
  instruction) — keep the pre-reset list in the repo's evidence folder.
SIZE: M–L.
ESCALATE IF: any stat recomputes accuracy from current zones instead of the
  stored result; sync_session can't carry ra_on; the leaderboard's rules
  change meaning under the one-number rule; the reset would touch pitches.
```

### Standing constraints (in force)

Saved sessions immutable; per-pitch results stored at tap 2, never recomputed from current settings. Coordinates in catcher frame; zone numbers never stored; one label function. Frozen reports untouched. Every schema change via migration, staging first, fresh backup first; policy count reported. Screens from `tokens.css` and the U13 set. GitHub is the source of truth. **Only Joel ships to production.**
