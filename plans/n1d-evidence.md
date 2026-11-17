# N1 Stage D · evidence (Nov 17, 2026)

Branch `n1d-getting-started`, cache `kb-shell-v346`. Staging app (local server, staging config); no database change.
Headless Chrome with device emulation at 390, 820, 1180 and 1440. Pictures are in `plans/n1d-evidence/`; I scanned them
for email addresses and found none.

**Emails.** Resend refuses every `example.com` recipient ("Invalid `to` field … example.com", status 422).
- So the "Send your first report" test sent nothing: Send report showed that error.
- Stage B's removal email to `feed-pitcher@example.com` (`plans/n1b-evidence.md`, check 17) was also never delivered.
  It was counted by the sending limit, then refused. The removal itself went ahead, as it always does.

## Every-stage checks

**1. Each role's card**, from the page (`gsState()`):

| Login | Card |
|---|---|
| New staging coach `n1d-coach-…@example.com`, team "N1D Test Team" (signed up this stage) | coach, **0 of 5** (`d1-newcoach-0of5.png`) |
| Pitcher `feed-pitcher` | pitcher, 0 of 5 |
| Parent `u15-parent` | parent, 1 of 3 (Add your player ✓; Join the team; Open the latest report) |
| View-only family | no card (`gsRole()` null) |
| Facility owner (DS1 manager) | owner, 4 of 5 (then 5 of 5, below) |
| U15 head coach | coach, 3 of 5 |

Sizes: the card at 390 (`d6`), 820 (`d7`), 1180 (`d5`, owner) and 1440 (`d8`). Softball: the owner's softball side at 1180
uses the softball tokens.

**2. Offline:** the card draws from data already on the device (History, Home's saved read, `kb:gs` marks). It needs no
read of its own, and the save mark is set when a pen goes into the outbox.

**3. Charting:** two sessions were saved this stage through the app: a game by the U15 coach and a pen by `feed-pitcher`.
Both synced; no menu or bar showed while charting.

**4. Side by side:** `d-getting-started.png` against `d2-newcoach-2of5.png`. Same title, "2 of 5 · Hide", gold bar,
green checks, the first open step bold with its hint and ›, and the others plain with ›. The card sits above the coach's
Home (Stage C), where the drawing shows the number tiles under it.

**5.** `CACHE_VERSION` is `kb-shell-v346`. STATUS.md and CLAUDE.md are in this PR, and the pre-push checks run at push.

**Bar:** at 390, Home and More with the card end above the bar (708 vs 738), for the new coach and the pitcher.

## Stage D checks

**24. Each step ticked by really doing it:**
- **New coach:**
  - Opening Team settings from step 1 → 1 of 5.
  - Copy on the pitcher invite link (step 2's target) → 2 of 5 (`d2`).
- **U15 head coach:**
  - team, share and bullpen were already done (sessions and roster);
  - a one-pitch Live Game, saved → "Chart a live game" ✓, 4 of 5 (`d3`);
  - "Send your first report" could not tick: Resend refused the example.com recipients (above).
  - **Simulated:** the report mark set by hand, to see "All set": "You're all set · 5 of 5" with a full green bar (`d4`).
    After a reload the card was gone from Home. More showed "Getting started · 5 of 5", and tapping it brought the card
    back. Hide hid it.
- **Owner:** opening the Roster → "Look over the facility view" ✓ → 5 of 5, "You're all set".
- **Pitcher `feed-pitcher`:** set throws (Right) and a pitch → "Set your pitch mix and throwing hand" ✓. A 3-pitch solo
  bullpen → "Chart your first bullpen" ✓ and "Join your coach or go solo" ✓ (3 of 5).
  - "Read your first report" stays open for them, correctly: their email isn't verified, so no report can be made.
- **U15 pitcher (verified):**
  - History drew the session's report → "Read your first report" ✓.
  - Tapping "See who can view your charts" opened `help.html#pitcher-visibility`; ‹ Back to Knuckleball → still ✓
    (4 of 5).
- **Parent:** the real state (player ✓, no team, no report). Their steps share the checks above (`teamsN`, the
  report-read mark).
- **Q4:**
  - `feed-pitcher` has setup incomplete (`setupIncomplete` true) and no "Finish setting up your profile" banner.
  - The owner's empty softball facility side, where the owner is head, opened no Welcome popup.
  - The new coach's normal team still opened it.
- **Found and fixed:** step 1's packet rule ("done when the team has a level") was always true, because every team gets
  a level when it's made (`teams.level` NOT NULL; the new team got "college"). It's now done once Team settings is opened
  from the step, or once the team has sessions.

**25.** Adding a sixth pitcher step is one entry (shown, not kept):
```diff
-    { id: 'who', label: 'See who can view your charts', … done: () => gsMarked('who') }
+    { id: 'who', label: 'See who can view your charts', … done: () => gsMarked('who') },
+    { id: 'game', label: 'Chart your first live game', hint: 'Chart, then Live Game', go: "setView('session')", done: () => gsHasSession('game') }
   ],
```

## Staging test data from this stage

- New coach `n1d-coach-…@example.com` with "N1D Test Team" (its verification email was attempted to example.com).
- A one-pitch Live Game for "U15 Softball Pitcher".
- A 3-pitch bullpen for `feed-pitcher`, plus throws Right and pitch mix 4SFB.
- U15 pitcher's report contacts now name the U15 coach's address.
