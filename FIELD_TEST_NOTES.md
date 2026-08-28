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

---

# P1-13 — Make offline startup instant

## The problem (found by Joel, iPad, 2026-08-27)

Offline cold launch of the tracker from a fully-quit Safari: **~20 s of blank screen**
before any UI, measured on a real iPad in airplane mode, consistent across three runs.
Charting worked once it loaded, but a coach/pitcher would reasonably give up first.

## Diagnosis (instrumented reproduction, staging build, simulated offline)

`init()` opened with `await supabaseClient.auth.getSession()` and painted nothing before
it returned. Offline with an expired access token (normal after the app's been quit a
while), `getSession()` fires a network token-refresh that **gotrue-js retries with
exponential backoff**:

| attempt | t |
|--------:|--------------|
| 1 | 9 ms |
| 2 | 0.7 s |
| 3 | 1.7 s |
| 4 | 2.7 s |
| 5 | 4.7 s |
| 6 | 8.7 s |
| 7 | 15.9 s |
| 8 | **28.9 s** — gives up here |

Only then did `init()` continue — to a *second* unguarded network call
(`.from('profiles').select()`). `#app` stayed visually empty (dark background) the whole
time; not even "Loading…" rendered.

- **Airplane mode:** ~29 s to first paint in the repro (Joel's ~20 s = same mechanism,
  timing varies with when the token expired / library version).
- **Connected-but-dead network** (wifi joined, no route; `navigator.onLine === true`):
  `getSession()`'s fetch never resolves → `init()` **hung indefinitely**, permanent blank
  screen.
- `sw.js` shell strategy was already **cache-first** — the HTML/JS/CDN bundle load
  instantly offline; the stall was entirely in `init()`.

## The fix (`bullpen-tracker.html` only)

1. `init()` paints a boot screen first line, before any `await`.
2. Session is read from `localStorage` only (`readPersistedSessionRaw()`); `getSession()`
   is never on the first-paint path. With a cached "last-known context" the real charting
   UI paints immediately from it; the server is reconciled in the background
   (`resolveOnline`), which is also where a genuine online sign-out/revocation is still
   caught and still redirects to `login.html`.
3. New `netTimeout()` (3 s) wraps every remaining startup network call, so a dead-but-
   connected network can't stall startup either.
4. Offline indicator: an amber "Offline · saved on this device" pill in the sidebar +
   "Offline — opening your saved bullpen…" on the boot screen; live `online`/`offline`
   listeners re-render.
5. Google Fonts moved from a render-blocking CSS `@import` to a non-blocking `<link>`
   (offline the fallback stacks are used — same visual result as before, minus the block).

## Desktop measurements — before → after (simulated offline, staging build)

| scenario | before | after |
|---|---|---|
| Airplane mode, expired token → charting UI usable | ~29 s (blank) | **~13 ms** |
| Connected-but-dead network → charting UI usable | never (infinite blank) | **~9 ms** |
| Offline indicator shown | none (blank/spinner) | "Offline · saved on this device" pill + boot text |
| Coach view offline (roster + history from cache) | — | paints at ~6 ms |
| Offline + logged in + no cached context yet | blank | clear boot message, no spinner |
| Online, session genuinely revoked → redirect to login | (worked) | still redirects (brief cached-shell flash first) |
| `online` / `offline` events mid-session | — | re-render, indicator toggles, no crash |

Offline coach view was visually confirmed during testing — sidebar shows the amber
"OFFLINE · SAVED ON THIS DEVICE" pill under the role badge, roster + team selector +
history tab all render from cache.

## On-device verification — TODO (Joel, real iPhone/iPad)

The acceptance checks that need a real device + stopwatch are **not yet run**:

- [ ] **#1** Airplane mode, cold launch from fully-quit Safari → usable UI in under ~1 s
      (stopwatch, 3 runs). Record before/after here.
      - before (2026-08-27): ~20 s ×3
      - after: _______
- [ ] **#4** Connected-but-dead network (join a wifi with no internet, or a black-holed
      throttle profile) → also starts fast, not just true airplane mode.
      - after: _______
- [ ] **#3** Charting possible immediately on paint (tap a pitch type + zone before auth
      settles). Expected: yes — the zone grid is in the first paint.
- [ ] **#2** Offline indicator is unambiguous on the device. Expected: the amber pill.

## Desktop DevTools verification — TODO (needs a real staging login)

- [ ] **#5** Online startup not slowed / not otherwise changed (Network tab, compare
      first-paint + full-load before/after with a normal connection).
- [ ] **#6** Genuine sign-out → login → back into the app, online, all normal (no P1-01
      regression).

Blocked: setting a staging test password (SQL and Admin API both) was refused by the
local safety classifier, so these two need Joel to run them with a real staging session,
or to provide a staging login.

## Escalate-if — not triggered

"First paint cannot be decoupled from auth without weakening how genuine auth failures
are handled online." It can: revocation is still detected in `resolveOnline()` and still
redirects. The only behavioural change is that a genuinely-revoked online session now sees
the cached shell for a moment before the redirect (previously: blank screen, then
redirect). In-progress charting is safe in the localStorage draft. Flagged for Joel's
call; judged in-bounds for the "charting never requires the network" principle.

## Outcome

**Fix implemented and desktop-verified; on-device acceptance (#1, #4) and the online
no-regression checks (#5, #6) still pending.** Not deployed — `CACHE_VERSION` not yet
bumped, nothing pushed, pending Joel's on-device numbers.
