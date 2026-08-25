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

## Outcome (first run, 2026-08-25)

**P0-04 did not pass.** Root cause: the app has no offline app shell, so once the browser/tab
is killed while offline, the tracker page cannot be reloaded until connectivity returns — even
though the in-progress session data itself is safe (per P0-03's localStorage draft, confirmed
intact on recovery). This gap was scoped as task **P0-06**. P0-04 was re-run in full once
P0-06 shipped — see below.

---

## Re-test — full checklist, after P0-06 (2026-08-25)

Same device and conditions as above (iPhone 14, Chrome, coach account), run after P0-06's
offline app shell shipped.

1. **Logged in on the device.** Worked normally.
2. **Started a session.** Worked normally.
3. **Airplane mode ON mid-session.** No issues.
4. **Charted 10+ more pitches offline.** Worked fine, no issues charting at pace.
5. **Attempted to save while offline.** Saw the expected loud failure message; charted data
   remained intact on screen (no data loss, no silent failure).
6. **Airplane mode OFF, retried save.** Save succeeded.
7. **Verified session in the coach dashboard.** Session appeared correctly with all pitches.
8. **Sent the report.** Sent successfully.
9. **Verified the PDF email.** Arrived and was correct (right pitcher, right pitch count).

**Rough edges noted:** none observed — tap targets, charting flow, etc. all felt fine at pace.

## Outcome (re-test)

**P0-04 passed in full**, including the steps that couldn't be reached on the first attempt.
The P0-06 offline app shell fix resolved the original blocker; zero data loss was observed
across the full airplane-mode cycle, from mid-session network loss through save, retry,
dashboard verification, and report email.
