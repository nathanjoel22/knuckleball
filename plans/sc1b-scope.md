# SC1-B — switch the reads to `session_stats` (scope report, no code)

Written Oct 28 2026, after SC1-A (the server half: `session_stats` written at save; staging; `plans/sc1-preconditions.md`).
SC1-A delivers none of the speed. Every screen still computes from pitch rows. SC1-B is the stage that does, and
it's what F1-A needs before a 100-pitcher roster opens. **Start only after SC1-A is on production.**

## Where the time goes today

- **History, Trends, the report payload and the offline snapshot** all come from one query (`bullpen-tracker.html`
  ~5948):
  - It selects `sessions` with 37 `pitches` columns, `game_events` and `session_notes` embedded.
  - That is every session the caller can read, for the selected pitcher.
  - Trends (`renderTrendsView`) is drawn from that same in-memory list.
  - The cost grows with pitches × sessions. On production that's 2,557 pitches over 115 sessions today. A
    100-pitcher roster at ~60 pitches a pen grows it roughly 6,000 pitches a week.
- **The roster's pitch-count line** comes from `pitcher_workload(ids[])`, which sums pitches.
- **Profile** reads no stats, so there's nothing to switch.
- **The leaderboard** is hidden (`hasLeaderboard: false` since Oct 10). Joel: leave it out.

## The decision Joel has to make first: acceptance 3 vs "keep loading, view offline"

SC1's acceptance 3 is "no pitch rows fetched on History / Trends". On Oct 28 Joel answered "keep loading, I want
someone to be able to view when offline". The two conflict, because these all need the pitches themselves:
- the History card's plot of every pitch (v188);
- building a report;
- the offline snapshot.

**Options:**
- **A. Stats first, pitches behind.**
  - History and Trends paint from `session_stats` at once.
  - Pitches for the same sessions load in the background and go into the offline snapshot as today.
  - It's fast on screen and keeps full offline viewing.
  - It doesn't meet acceptance 3 literally: pitches are still fetched, just not waited for. Data use doesn't drop.
- **B. Pitches on demand.**
  - Pitches load only when a card is opened or a report is made.
  - It meets acceptance 3.
  - Sessions never opened online can't be viewed offline. That goes against Joel's answer.
- **C. Stats for all, pitches for the newest N (recommended, N = 20 per pitcher).**
  - Numbers and Trends come from the rows, for every session.
  - Pitches are fetched (and kept offline) only for the newest N sessions. Older cards fetch theirs when opened.
  - It meets acceptance 3 for everything past N, and keeps offline viewing of recent work.
  - Cost stays flat however long a pitcher's history gets.

## What switches (under C)

1. **History numbers:**
   - pen cards: pitches, strike %, the one accuracy %, velocity avg / min / max, time to home;
   - game cards: the pitching line from `game` (Joel's decision 4: `compute_game_summary`'s rules);
   - the per-type tables.
   - All come from the row's counts (percentages are computed on the client from counts).
   - The card plot stays on pitches when they're loaded. Otherwise it is drawn from `by_type.cells`: one dot per pitch
     at the cell's centre and spread inside the cell. It isn't in pitch order, so the plot looks slightly different;
     needs Joel's OK.
2. **Trends:**
   - strike % and peak velocity per type per session from `by_type`;
   - the per-type 5×5 plot from `by_type.cells`.
   - Fully row-based; no pitch rows.
3. **Roster pitch count:** `pitcher_workload` sums `session_stats.pitch_count` instead of pitches. Stays SECURITY
   INVOKER, so it still counts only what the caller can see.
4. **Reports are not switched.**
   - The payload still needs the session's pitches. Making one fetches that session's pitches, as B would.
   - Reports already sent never change (Known landmine 5).
5. **Fallback:** a session with no row (a logged `session_stats_failures` entry) is computed from its pitches as
   today, fetched for that session only.
6. **`stats_version`:** the client reads only the version it knows. A newer version is computed from pitches until the
   app updates.

## Acceptance (proposed)

1. **No pitch rows past N.** On a pitcher with more than N saved sessions, History and Trends fetch no `pitches` rows
   for sessions past the newest N. Shown from the network log.
2. **Same numbers.** `scripts/sc1-compare.js`-style check: every number on History cards and Trends is the same from
   rows as from pitches, on staging and production data, with only the known interference game differing.
3. **Offline.**
   - In airplane mode after one online load: the newest N sessions open fully (plot, breakdown);
   - all sessions show their numbers and Trends;
   - charting is untouched (design principle).
4. **Report.** A report made from an older card fetches that session's pitches and is identical to one made today.
5. **Roster.** The pitch-count line is the same before and after on every team on staging.
6. **Release.** CACHE_VERSION bumped; STATUS.md entry; the frontend ships with a site deploy (unlike SC1-A).

## Size and risk

- **Size:** frontend only, plus one migration (`pitcher_workload`). About a day of work and a day of checks.
- **Risk:** History is the most-used screen, and the offline snapshot format changes. Old snapshots must still load.
- **Escalate if:**
  - a number can't be matched from the counts;
  - Joel prefers A or B;
  - the plot drawn from cells isn't acceptable.
