# FIELD_TEST_NOTES.md — P0-04 on-device field test

This is the factual record of the P0-04 on-device field test. It is the input for P0-06
(offline app shell) and P2-05 — a future session with no memory of this test should be able
to read this and know exactly what failed and what still needs polish.

## Test conditions

- **Device:** iPhone 14
- **Browser:** Chrome, normal (non-private) tab
- **Date:** 2026-08-25
- **Account:** coach account, charting for a test pitcher

## What happened, by step

1. **Online — logged in, started a session, charted 5 pitches.**
   Worked normally.

2. **Airplane mode turned on.**
   Was able to continue charting pitches normally. Charted up to 18 total (5 from step 1 +
   13 more offline).

3. **Charted 13 more pitches offline.**
   Worked fine — no issues charting while offline.

4. **Killed the browser, reopened, navigated to the tracker.**
   **FAILED.** The page would not load at all — Chrome's offline error page (and the dino
   game) appeared instead of the app. The app shell itself was never cached, so with no
   network available, the browser had nothing to re-fetch and render. This is a different
   failure mode than a failed *save* — the app couldn't even be *opened* offline.

5–8. **Not tested.**
   Could not proceed through the remaining steps of the P0-04 checklist in sequence,
   because step 4's failure meant the app was not reachable at all at that point in the test.

## Recovery

Reconnected to wifi, loaded the tracker again, and the P0-03 restore prompt appeared with
all 18 pitches intact. This confirms the session *data* survived correctly in localStorage
throughout the outage — the only problem was that the app itself could not be opened while
offline. P0-03's autosave/restore behavior is not in question here; this is strictly an
app-shell-availability gap.

## Rough edges noted while charting at real bullpen pace

None observed. Charting itself (pitch type selection, two-tap target/actual entry, velocity
entry) felt fine at pace, both online and during the offline charting in steps 2–3.

## Outcome

**P0-04 did not pass.** Root cause: the app has no offline app shell, so once the browser/tab
is killed while offline, the tracker page cannot be reloaded until connectivity returns — even
though the in-progress session data itself is safe (per P0-03's localStorage draft, confirmed
intact on recovery). This gap is now scoped as task **P0-06**. P0-04 must be re-run in full,
including steps 5–8, once P0-06 ships.
