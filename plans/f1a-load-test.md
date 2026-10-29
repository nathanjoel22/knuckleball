# F1-A — load test (staging, Oct 29 2026)

**Threshold (packet):** roster and History under 2 s on Wi-Fi. **Met** for every person on both devices.

## What was loaded

The **"LoadTest Training Center"** facility on staging, made through `facility-signup.html` with a one-time link.

**People:**
- **Pitchers:** 100 parent-created players, "LoadTest 001–100". They were added by 12 parent logins (9 each, because a
  login holds at most 10 profiles) and joined through the pitcher invite link ("Join as:"). Three real staging pitchers
  joined too: Staging Pitcher (also on Staging Knights), Testing Gas and Babe Ruth. That's 103 on the baseball side.
- **Coaches:** coach A (15 pitchers) and coach B (5) joined through the coach invite link. 83 pitchers have no coach.
- **New:** three pitchers are marked New, as a QR join will mark them in F1-B.

**Sessions:**
- 20 for each LoadTest player, saved through `sync_session` as the manager: 2,000 sessions, 400 of them Live Games.
- 119,811 pitches.
- 2,000 stats rows, 0 stats failures.

**Scripts:**
- part 1, the people: `supabase/scripts/f1a_loadtest_seed.sql`;
- part 2, the sessions, 12 players per run: `supabase/scripts/f1a_loadtest_sessions.sql`;
- undo: `supabase/scripts/f1a_loadtest_cleanup.sql`. It's a dry run by default; its dry run reported 2,000 sessions,
  103 roster rows, 16 profiles plus the players, and 15 logins.

Every script refuses to run anywhere but staging.

## How it was timed (simulated, Joel's decision F)

- **Browser:** the test Chrome, driven over the DevTools protocol.
- **Network:** Wi-Fi emulated (30 ms latency, 30 Mbps down, 15 up).
- **Phone:** 390×844 with the CPU slowed 4×.
- **iPad:** 1024×1366 with the CPU slowed 2×.

**First load** = a device holding nothing but the sign-in: no app cache, no saved copy, no History copy. It is timed
from opening the app until:
- **for a coach:** every roster pitcher is on screen **and every pitch-count line has arrived** (`pitcher_workload`);
- **for the pitcher:** all 20 sessions are loaded with their pitches.

**Returning** = the same, opened again straight after.

**History** = tapping a pitcher with 20 sessions until all 20 cards are drawn with numbers. That includes their stats
rows and the prefetch of their newest 20 sessions' pitches.

**Trends** = opening the tab until it's drawn.

## Results (ms)

| Device | Who | First load | Returning | History | Trends |
|---|---|---|---|---|---|
| phone | manager (103 pitchers) | **1714** | 1676 | 1090 | 214 |
| phone | coach A (15 pitchers) | 973 | 1198 | 674 | 89 |
| phone | pitcher (own History, parent-created player) | 999 | 106 | 34 | 113 |
| iPad | manager (103 pitchers) | 1526 | 1505 | 681 | 75 |
| iPad | coach A (15 pitchers) | 1204 | 1236 | 741 | 46 |
| iPad | pitcher | 933 | 102 | 26 | 48 |

**Notes on these numbers:**
- **Returning coach roster:** the roster itself paints from the device's copy at once (about 150 ms). The time shown is
  until the fresh pitch counts arrive.
- **Pitcher:** their History opens from the device copy (IndexedDB, SC1-B), so returning and History are instant.

**Server side, as the real person with read rules on (`pitcher_workload`, the roster's pitch-count line):**
- the manager: 103 pitchers / 2,049 sessions in **424 ms**;
- coach A: 15 pitchers / 314 sessions in **143 ms**.

That's about 0.2 ms per visible session, against 0.1 ms before F1-A, because of the facility check on each row.

## To watch

- **The manager's phone first load (1.7 s) is the closest to the 2 s line.** Most of it is `pitcher_workload`, which
  reads every visible session to find each pitcher's last outing.
- At ~60 sessions per pitcher (a full season) the manager's call would be roughly 1.3 s on the server.
- **If that line is crossed,** the fix is in `pitcher_workload` (look back only as far as the 30-day window plus the
  last session), not in the read rules. Not needed at today's size, so not done.
- **Not found slow:** neither SC1-B's reads (History is 0.7–1.1 s with 20 sessions of pitches) nor the new facility
  queries (groups and members are two small reads).
