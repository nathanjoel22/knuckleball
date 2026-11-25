# C1 — Charting in parts (Intent, and Outcome with Response), alone or shared between two devices, Nov 25, 2026

**Joel, Nov 24:** "When throwing a bullpen or live game, I want a user to be able to select what parts of the process they are going to chart." One person can call the pitches and another can chart everything else; when one person leaves a part open, someone else who can chart that pitcher can pick it up on a second device and the two pieces are put together into one report.

**Amended Nov 25 (Joel): "Outcome and Response always get done together. they cannot be separated in a live game setting. the rules behind intent remain."** So there are only ever two parts: **Intent**, and **the rest**. The field-only Response screen and the no-flip result mode from the first draft are dropped.

This is the largest change to charting since Live Game. It is built in three stages, each its own pull request:

| Stage | What | Needs a signal? |
|---|---|---|
| **A** | The parts question, and charting either part or both **alone on one device** | No — works offline as charting does today |
| **B** | **Shared charting**: others see the session is live, one of them takes the open part, and the two devices chart the same pitches in step | Yes |
| **C** | Each charter's own save screen, putting the pieces together, the three-hour rule, and reports from partial data | Yes for compiling |

## Two standing rules this packet bends, and exactly how far

1. **"Charting never needs the network; nothing reaches the server before End session & save."** Still true for anyone charting alone (Stage A), whatever parts they chose. Shared charting (Stage B) is the one exception: pitches in progress are sent as they are tapped, into **new live tables that are not `sessions` or `pitches`**. A piece becomes a real saved session only when its charter taps End session & save, through the same one-call save as today.
2. **"Saved sessions are immutable."** Unchanged. A saved piece is never edited. Compiling **creates** the combined session from the saved pieces; it does not rewrite them.

Everything else in force stays in force (see the end).

---

## Stage A — the parts question, and charting alone

### The first start question

Before anything else on the start screen, for bullpens and Live Games, both sports:

**"What parts of charting will you be handling?"**

**Bullpen — two choices:**

- **Intent — Pitch Calling**
- **Outcome — Pitch Locations**

**Live Game — two choices** (Joel, Nov 25):

- **Intent — Pitch Calling**
- **Outcome & Response — Pitch Locations and Results**

Either or both can be chosen; at least one must be. Choosing both means the app behaves exactly as it does today.

**Order of the start questions after it:**

- **Live Game:** parts → radar gun → Starting mid-game? **"Turn on Intent?" and its help button are removed** — choosing Intent is the answer.
- **Bullpen:** parts → What's this pen for? → Relative Accuracy → radar gun.
- Any other start question that exists today keeps its place after these; list them in the report. *Drafting decision:* the Relative Accuracy question is shown only when Intent and Outcome are both chosen on this device, since it needs both.

### What each combination does

**Bullpen**

| Parts chosen | Behaviour |
|---|---|
| Intent + Outcome | Today's bullpen. |
| Intent only | The Intent-only screen below. |
| Outcome only | One tap per pitch: where it landed. Prompt "Select Pitch Outcome", the grid pulsing until tapped. No target, so no accuracy for these pitches. |

**Live Game**

| Parts chosen | Behaviour |
|---|---|
| Intent + Outcome & Response | Today's game with Intent on. |
| Outcome & Response | Today's game with Intent off: location, the result, and for a ball in play the board flips to the field. Nothing about this flow changes. |
| Intent only | The Intent-only screen below. Nothing about the count, outs, innings or runners is charted on this device; say in the report what its scoreboard shows when it is charting alone (the default is blank, never zero). |

Outcome and Response are never separated in a game. There is no field-only mode and no mode where a result is recorded without the field step.

### The Intent-only screen (bullpen and Live Game)

In place of the yellow guide ("Tap where you're aiming" / "Now tap where it actually landed (reset target)"):

- **Bottom row, three buttons, each the size of today's No batter button, left to right:**
  1. **the batter button** — cycles No batter / RHB / LHB as today's pill does (in a Live Game there is no "No batter"; it shows the batter side, and V1's Select Batter Side step for a new batter stays);
  2. **Confirm Pitch** — a reddish pink;
  3. **Next Pitch** — yellow.
- **The row above:** **‹ Back** at the left, sitting directly above the batter button; beside it the yellow instruction **"Tap where you're aiming"**.

The cycle for one pitch:

1. Pick the pitch type (it stays selected until changed, as today) and tap a cell. "Tap where you're aiming" is shown **until a cell is selected, then disappears**.
2. **Confirm Pitch starts pulsing** — the same pulse as the yellow target dot on the grid.
3. Tapping **Confirm Pitch sends the voice call out of the device.** In this mode the audio no longer goes out when the cell is tapped; it goes out on Confirm Pitch.
4. **Next Pitch starts pulsing.** Tapping it starts the next pitch's intent. **The audio must play to its end even if Next Pitch is tapped while it is still speaking.**

**When a pitch becomes final.** A pitch's intent is not final until **Confirm Pitch is tapped on the following pitch**. Until then **‹ Back** steps backwards through what was done (un-confirm, clear the cell, return to the previous pitch). Once the next pitch is confirmed, the earlier one is frozen and cannot be changed. (Joel's text reads "not considered frozen"; taken as "now considered frozen".)

### More Plays

In the normal game flow, on the FC · E · H · O row, **next to Back, a "More Plays" button**, "for any sort of super rare but possible plays". **It is there for everyone charting Outcome & Response** (Joel confirmed Nov 25 that it stays in this build).

Your job in the report: audit the whole Live Game flow as it stands and list every play it cannot record, then propose what goes in More Plays. Start from the plays G6 skipped or left for later and anything already under today's More: hit by pitch, intentional walk, catcher's and batter's interference, infield fly, ground-rule double, wild pitch and passed ball, balk / illegal pitch, pickoff and caught stealing, runner's interference and obstruction, appeal plays, a dropped foul scored as an error, triple play, batting out of order, fan interference. For each: in the flow already / goes in More Plays / cannot be stored without a schema change. Joel approves the list before it is built.

### Stage A data

- The session records which parts were charted. A part not charted leaves its fields **empty**, never a default: a bullpen pitch may have a target and no location (Intent only) or a location and no target (Outcome only); a game pitch charted Intent only has a type and a target and nothing else. Today's checks do not allow that; that is the migration. Propose the smallest change.
- Accuracy, Relative Accuracy, the leaderboard, SR1 baselines and Trends use **only pitches that have both** intent and location. A pen charted Intent only or Outcome only adds nothing to them. Games still never feed them.
- Every reader of a pitch's location, target or result must tolerate the empty case (G6's `hasLocation` helper is the pattern). List them.
- History and the report show what was charted and say plainly which parts were not.

---

## Stage B — shared charting (needs a signal)

### When a session is open to others

If the person who starts a session chooses only one of the two parts, the session is **live and open**: the other part can be taken by someone else. A session where one person chose every part is private to that device, as today.

### Who sees it, and where

*Assumed — Joel did not answer:* **anyone who can already start a session for that pitcher** — his coaches, the pitcher himself, his parents, a coach holding a one-session assignment or a camp roster for him (F2). Nobody else. **One person per part, so at most two devices; the first to tap gets the open part.**

- **At sign-in:** a notice that a live session is in progress for that pitcher.
- **Phone bottom bar:** a red **Live** mark on the Chart button.
- **On the Bullpen or Live Game button** (whichever kind is running): **"In Progress — Chart Now"**.
- Tapping it shows the parts question with only the **open** part selectable. The joiner picks up **at the next pitch**, not mid-pitch.
- No email, no push. Say in the report how soon the marks appear and disappear, and what they cost (polling, or a realtime channel).

### One pitch, two devices

- Both devices in a live session are charting the **same numbered pitches**. The server numbers them.
- **Intent comes first.** "If someone selects to record Intent, then outcome cannot be given until intent is recorded." The second device (Outcome in a pen, Outcome & Response in a game) opens for a pitch when the Intent charter taps **Confirm Pitch**. If nobody is charting Intent, nothing is waited for.
- With an Intent charter, the pitch type comes from them; the other charter does not choose a type.
- **A stuck pitch can be skipped** (Joel, Nov 25). If the call has not arrived after a few seconds, the waiting device offers **"Chart without it"**; that pitch is saved with no intent and both move on. The Intent charter also has **"No pitch"** for a call that was never thrown (the pitcher stepped off, time was called).
- *Assumed:* **Back is locked once someone builds on it.** The Intent charter's Back works until the other charter has recorded their part of that pitch, or until the next Confirm Pitch, whichever comes first.
- A charter may leave (End session & save) while the others go on. *Drafting decision:* the part they held becomes open again from the next pitch.
- If someone tries to start a second session for a pitcher who already has a live one of that kind, offer the open parts instead.
- Pitching changes, Starting mid-game, a new batter (V1's Select Batter Side) and a game that goes to a second pitcher: say in the report how each works when two devices are in the game, and which device owns each.

### Losing signal

"For now, this only works if there is live internet." A device that loses signal **keeps charting its part** on its own. When the signal returns, its offline pitches are matched to the session's pitches **by time** (Joel, Nov 25): each tap carries a timestamp corrected for the difference between the device's clock and the server's, measured while online. A pitch that lines up is kept. **A pitch that cannot be matched is left empty for that part and is not in the report.** "We can only report what we can reconcile." Propose the matching rule and its tolerance in the report, with the cases it gets wrong.

### Stage B data

New live tables (a live session, who holds which part, and each part of each pitch as it is tapped). **No existing policy is widened.** A charter can write only their own part, only for a pitcher they could already chart, and can read the other parts of that live session only while they hold a part in it. Policy count before and after; RLS matrix.

---

## Stage C — saving, compiling, reports

- "Each piece continues as the chart of history until a charter taps End Session and Save for their particular session." Each charter saves their own piece, through today's one-call save, as an ordinary immutable session marked as a piece of the live session.
- **The save screen** (today's Send Report · View Report · Done) changes when the session was shared: it shows **what that charter recorded** — their parts, how many pitches, and any left empty — in the same design. No Send or View there; the report does not exist yet.
- **Compile:** "Once every session that was started has been saved and recorded, then those pieces get compiled together in order to build out the full report." One combined session per live session, built on the server from the saved pieces, pitch by pitch. It is what History, Trends and the report read. The pieces stay as the record of who charted what.
- **Three hours:** "Any sessions that are not ended and saved within three hours of the most recently saved session that it was a part of will be automatically saved as they were and compiled into the report." A scheduled job does it.
- **Never taken:** a part nobody ever charted is simply empty in the combined session.
- The report, the SR1 versions, `session_stats` and the baselines are produced once, from the combined session, and frozen as reports are today. Say who is offered Send / View once it exists.
- A1 export and deletion cover pieces and combined sessions. Deleting a session (P1-15) — say what deleting one piece does after compiling, and before.

---

## Still in force

Service-role key only in Edge Function env vars. No Admin API. Every schema or RLS change by migration, staging first, fresh backup before production, rollback written before deploy. Saved sessions immutable. Games never feed accuracy stats or the leaderboard. Zone numbers are never stored. `auth.users.email_confirmed_at` never read. Report access needs the pitcher verified and the caller verified. A one-session assignment or camp grant (F2) lets a coach chart and nothing else — joining a live session must not show them the pitcher's history. A child's sign-in keeps exactly the rights it has today. **Only Joel ships to production**; no push to main, no merges; merges through the GitHub page after checks. No email address, password or birthday in a commit or fixture.

## Report first, then build

Pull `origin/main`; read `CLAUDE.md`, `STATUS.md`, `plans/v1-field-art-and-guided-flow.md`, `plans/g6-live-game-gaps.md`, `plans/u16-voice-call.md`, `plans/h1-hardening.md`, `plans/sr1-session-reports.md`, `plans/f2-facility-assignments-birthdays-camps.md`, `plans/scale-track.md`. Report, with file and line numbers, before any code or SQL:

1. Every start question today, in order, for each kind and sport, and the new order.
2. For each of the six combinations in Stage A (three in a bullpen, three in a game): the screens, the prompts, what is saved, and what is blank. Mockups or screenshots of the Intent-only screen at 390 px and 1280 px, bullpen and game, before building it.
3. The schema change for parts that were not charted, and every reader that must tolerate an empty target, location or result.
4. What the scoreboard, History card and report show for a game charted Intent only with nobody on the other part.
5. The More Plays audit and proposed list.
6. Voice: how the call is moved to Confirm Pitch in Intent-only mode and kept playing through Next Pitch, on iPhone, Android and desktop.
7. Stage B: the live tables; how devices stay in step (realtime channel or polling), the delay a charter will feel, connection limits and cost at 10, 100 and 1,000 live sessions; the RLS matrix; how the Live marks are driven.
8. The time-matching rule for offline pitches, its tolerance, and three cases it gets wrong.
9. Stage C: how the combined session is built and frozen; the three-hour job; what `session_stats`, baselines and the SR1 report do with empty parts; delete and export.
10. Every "Assumed" and "Drafting decision" above, restated as a yes/no for Joel.
11. Anything here that cannot be built as written, with the closest alternative.

Then build **A, B, C as three pull requests in that order**, each on staging, each stopping for Joel's check. Stage A must be usable on its own.

## Done when

Stage A
1. The parts question is first on both start screens; a bullpen offers Intent and Outcome, a game offers Intent and Outcome & Response; none chosen blocks Start; both chosen behaves exactly as before (same rows saved for the same taps as on main).
2. "Turn on Intent?" is gone; the remaining questions are in Joel's order for each kind.
3. Each of the six combinations charts and saves offline, and reopens after a killed tab at the same step.
4. Intent only: the three buttons and Back are where specified; the instruction disappears on a cell tap; Confirm Pitch then Next Pitch pulse in turn; the voice call starts on Confirm Pitch and finishes after Next Pitch is tapped mid-call; Back undoes until the next Confirm Pitch and not after.
5. A game charted Outcome & Response only saves the same rows as today's Intent-off game for the same taps.
6. A game charted Intent only saves type and target per pitch and nothing else; nothing is shown as zero.
7. More Plays is next to Back on the FC · E · H · O row for anyone charting Outcome & Response, and holds the approved list.
8. A pen charted Intent only or Outcome only changes no accuracy number, leaderboard row, baseline or Trend. Blank is shown as blank, never zero.

Stage B
9. A coach starts a game with Outcome & Response only. A parent signs in on another device: he sees the notice, the red Live mark and "In Progress — Chart Now", and takes Intent; a third person is offered nothing. Someone who cannot chart that pitcher sees none of it. The same with a bullpen (Outcome started, Intent joined).
10. Two devices chart twenty pitches in step: the second device cannot record a pitch before Confirm Pitch on the first; the pitch type shown on the second device is the one the caller chose.
11. A stuck pitch is skipped from the waiting device with "Chart without it" and saved with no intent; "No pitch" on the caller's device releases the other.
12. Back on the Intent device stops working for a pitch the moment another device records against it.
13. One device in airplane mode for six pitches, then back: matched pitches are kept, a deliberately extra one is left empty for that part, nothing else is disturbed.
14. A one-session-assignment coach joins and still cannot read the pitcher's history. Policy count unchanged.

Stage C
15. Each charter's save screen shows what they recorded. When the last piece is saved the combined session appears in History with one report; the pieces are unchanged in the database.
16. A piece left open is saved and compiled three hours after the most recent save.
17. A part nobody took is empty in the combined session and the report says so.
18. Reports, `session_stats` and baselines for a game charted by one person with both parts are identical before and after this packet.
19. Full test suite passes; shell version bumped per stage; `STATUS.md` updated per stage.

## Prompt for Claude Code

```
Save this packet verbatim as plans/c1-charting-parts.md on the branch before anything else; if a copy already exists on main, use that one and tell me if the two differ.

Do the "Report first" section and wait for my answers. Do not write feature code or SQL before I reply.

After I reply: build Stage A, Stage B and Stage C as three separate pull requests, in that order, staging only, stopping after each for my check. Stage A must work on its own, offline, before Stage B starts. Migrations go to staging after a dry run, with the rollback written first. Do not push to main, do not merge, do not deploy to production. Finish each pull request with that stage's numbered "Done when" items, each marked pass or fail with evidence.
```
