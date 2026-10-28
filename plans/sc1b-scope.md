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

## Joel's decisions (Oct 28 2026)

- **Option C.** Scope changes from the review, approved by Joel:
  - prefetch only for the signed-in pitcher's own History and pitchers opened on this device, 20 each;
  - a device-wide ceiling of 200 sessions, oldest evicted first;
  - a roster never prefetches pitchers who were never opened.
- **Correction (mine):** History was never kept on the device. An offline start showed only queued sessions. Joel:
  yes, keep the prefetched History on the device (new: History and Trends open offline).
- **The plot from stats cells:** approved (side-by-side image, staging bullpen 96b7c30a).
- **Game card innings:** today's number, via stats v2.
- **Stats v2 migration:** yes.

## As built (staging, Oct 28 2026; branch `sc1b-reads`, v317)

- **Migration `20261029000000_sc1b_stats_v2`:**
  - a game's `innings`, plus per type `side_strikes` / `delivery_strikes`;
  - pitches with no location left out of the cells;
  - `pitcher_workload` sums `session_stats.pitch_count`;
  - every row recomputed at version 2 (staging: 86 rows, 0 failures; policies 30).
- **"Relative Acc%" column:** History's pen table showed `isRelativelyAccurate`. With no pre-U7 accuracy mode that
  is the exact-target share, so from the row it's `(hits - ra) / n`. Only pens charted in a pre-U7 mode lose it
  (Joel's decision 3: staging has 3, production has 0).
- **Device copy:** IndexedDB, not localStorage. Up to 200 sessions of pitches (~10 MB at 60 pitches a pen) would
  crowd out the outbox and drafts in localStorage, which is Safari's ~5 MB.

### Acceptance results (staging)

1. **No pitch rows past N.** Recorded with Chrome's network log, signed in as the Staging Knights head coach:
   - Team load with nobody tapped: one `sessions` request with stats rows (17 sessions, 5.5 KB) and no pitch rows.
   - Opening that pitcher's History, an old pen, a game and Trends (Live Game splits): 0 pitch requests.
   - Tapping Staging Pitcher (33 sessions): a stats request, then one pitch request for exactly his newest 20 session
     ids.
2. **Same numbers.** `scripts/sc1b-compare.js` ran the app's functions on all 86 staging sessions, rows against
   pitches: 793 checks, **0 differences**.
   - **Known (Joel's decisions):** 3 pre-U7 accuracy mode pens (decision 3) and the interference game's strike %
     (decision 4).
   - **Planted errors:** 4 planted errors (card strike count, a Trends split, a game's innings, a plot box) were all
     caught.
3. **Offline.** With the network cut, the app was reloaded:
   - History came from the device: 33 sessions (20 with pitches), all with stats;
   - the oldest game opened (plot from cells, numbers from the row);
   - Trends showed 32 sessions and 147 pitches;
   - no request to Supabase was tried;
   - a roster pitcher never opened had nothing kept;
   - charting code is unchanged.
4. **Reports.** The payload was built twice, from rows and from pitches, for an old pen, an old game and a recent
   pen: **identical** in all three.
   - A report for an old session fetched exactly that 1 session's pitches first.
   - Nothing was sent or generated.
5. **Roster.** `pitcher_workload` matched before and after for all 30 staging pitchers. As each of the 5 staging
   coaches (RLS on) it matched the old pitch-count formula: 0 differences
   (`supabase/tests/sc1b_workload_rls.sql`).
6. **Release.** CACHE_VERSION v317; STATUS.md entry.

- **Sign-out:** the clear left 0 records on the device and emptied the opened list.
- **Sizes, Staging Pitcher (33 sessions, 147 pitches):**
  - today: 125 KB on every load;
  - v317, not opened: 47 KB;
  - v317, opened: 47 KB + 62 KB of pitches.
  - Small test pens (4.5 pitches each) make the stats rows look large. At 60 pitches a session the full history is
    ~30x the rows.

### Production order (Joel's)

1. Take a backup.
2. Apply `20261029000000_sc1b_stats_v2` (the v316 site ignores the stats, so the database can go first).
3. Run `scripts/sc1b-compare.js` on production, then `supabase/tests/sc1b_workload_rls.sql`.
4. Regenerate `schema.sql`.
5. Merge (v317).
6. Check that v317 is live.

If v317 were somehow live before v2, it would fall back to pitches for every v1 row, so it would be correct, just
slower.
