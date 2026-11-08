# U16 preconditions report (Nov 8, 2026)

Written against: production v337 (U15), `origin/main` 168408d. Branch `u16-voice-call`. The packet had no copy on main; it's
saved verbatim as `plans/u16-voice-call.md`. Line numbers are `bullpen-tracker.html` unless a file is named.

**Status: approved (Joel, Nov 8 2026: "yes to all"): all eight decisions in C as recommended.**

## A. Answers to the six questions

1. **Zone labels and names today:**
   - **The number:** `zoneNumberFor(cRow, cCol, batterSide)` (2588). It takes the stored catcher-frame cell, returns 1-9 for
     the strike zone (rows / cols 1-3 of the 5×5 grid) and null for the ring. 1 is up and in for both sides (confirmed:
     row 1 is the top zone row; the column counts from the batter's side).
   - **The names are only in the report function, not in the app.** `supabase/functions/send-session-report/helpers.ts:145`
     `ZONE_NAMES`, keyed by the report's own `zoneNumber` (helpers.ts:132):
     `1 up and in · 2 middle up · 3 up and out · 4 middle in · 5 middle middle · 6 middle out · 7 low and in · 8 middle low · 9 low and away`.
   - **"out" is still there in two strings:** 3 = "up and out", 6 = "middle out". They show in the pen report's per-zone list
     (`template.ts:163`) and the game report's zone list (`template_game.ts:308`), and in reports rebuilt by `from_rows.ts`.
2. **The outer ring has no numbers and no names anywhere** (app, reports, plans). `zoneNumberFor` / `zoneNumber` return
   null for every ring cell. Numbers 10-25 would exist only in `plans/u16-speech-table.md`; nothing on screen shows them.
3. **Where the taps are handled. Each is one place:**
   - **Bullpen:** `handleZoneTap` (5734). Its first branch (5739, `!state.pendingTarget`) is the target tap; everything after
     it is the actual tap. The target is kept in screen columns and converted at the actual tap (`perspectiveCol`, 5752), so
     the speech converts the same way, once, before naming.
   - **Live Game with Intent on:** `handleGameZoneTap` (7580). Its intent branch (7600, `si.intent && !si.gameTarget`) is the
     intent tap; the rest is where it went. Intent is `activeSession.intent`, set from "Turn on Intent?" (7368).
   - **Changing the call:** in both, the second tap always records where the pitch went. The call is changed with
     **Reset target** (`resetTarget`, 5811) or, in a game, ‹ Back (`resetGameTarget`, 7637), then a new target tap. That's the
     path for acceptance 3 ("re-tap a different target").
4. **Speech on each platform.** This is what I expect from what I know; none of it has been tried on a device yet.
   - **iOS Safari and the home-screen app:** `speechSynthesis` works offline with built-in voices. The first `speak()` must be
     inside a tap, and ours is. A warm-up is usually not needed; I'd add one only if the phone test loses the first call.
     The silent switch: Safari's web audio is muted by it on recent iOS. Confirm on your iPhone; the Help line says what we
     find.
   - **Android Chrome:** works offline with the phone's installed Google voices. Some Chrome voices are online-only
     (`localService: false`), so the app picks a local one. The voice list can arrive a moment late (`voiceschanged`);
     until then it speaks with just `lang = 'en-US'`.
   - **The installed Android app (Capacitor):** **Android's WebView does not provide `speechSynthesis`**, so voice won't work
     in the Play Store build as it is. It needs a native text-to-speech plugin: a new dependency and a new app build (C6).
     The iOS shell (WKWebView) has it.
5. **The 9-dot menu and per-device settings:**
   - **The menu:** `renderSessionSheet` (11495), **phones only**: title, perspective chips, opponent (game), End session &
     save, Discard, Close. The Voice item goes after the perspective chips. iPad and laptop have no such menu (C5).
   - **Per-device settings:** a plain `kb:` localStorage key read with `lsGet` (3498) and written in try/catch (`kb:install`,
     `kb:sport`). The setting would be `kb:voice` = `off` / absent (absent = On).
6. **Pitch names (the stored full names):**
   - **Baseball, 13:** Four Seam Fastball, Two Seam Fastball, Cutter, Sinker, Changeup, Vulcan Changeup, Curveball, Slider,
     Knuckleball, Sweeper, Slurve, Forkball, Splitter.
   - **Softball, 8:** Fastball, Change-up, Drop ball, Rise ball, Curveball, Screwball, Drop curve, Off-speed.
   - Older arsenals can hold free-text names; they are spoken as stored.

## B. Where the packet differs from the code

1. **"The same single label function … and its name table":** the app has the function but no name table; the only table is
   the report's, and it still says "out" for 3 and 6.
2. **Acceptance 9 "no function change"** can't hold if Amendment 17 fixes the report's strings (C1).
3. **"12 pitch types":** baseball has 13, softball 8.
4. **"Fastball middle middle":** baseball has no plain "Fastball"; it would say "Four Seam Fastball middle middle".
   Softball's Fastball says exactly that.
5. **"Re-tapping a different target":** a second tap is always the actual tap; changing the call is Reset target / ‹ Back,
   then a new tap (A3).
6. **"No batter" bullpens** (the batter toggle's third choice) have no side; the packet doesn't say what to speak (C4).
7. **"Every device" and the 9-dot menu:** the menu exists only on phones (C5), and the Android app can't speak yet (C6).

## C. Decisions needed before building

1. **Amendment 17: fix "out" → "away" in the report.**
   - Recommended: yes. Change the two strings in `helpers.ts` and deploy `send-session-report` (staging, then production
     after your merge). From then on, new reports say "up and away" / "middle away". Reports already sent never change.
   - Alternative: leave the report alone for now. The app would then say "away" while new reports still say "out".
2. **The app's name table.** The app can't import the report function's file (one is a web page, the other runs on the
   server), so the app gets its own table beside `zoneNumberFor`. One new function, `zoneAreaName(cRow, cCol, side)`, names
   all 25 cells: the ring cell's inner neighbour + "extra" / "plus". Recommended: add a pre-push check that the app's nine
   names equal the report's, like the colour-palette check.
3. **Spoken pitch names:** recommended the full stored names, as the packet says (so "Four Seam Fastball …"). Alternative: a
   short spoken name for long ones ("Four seam", "Two seam").
4. **"No batter" bullpens:** recommended speak as against a right-handed batter, the same rule the accuracy scoring uses.
   Alternative: say only the height ("up", "middle", "low" + extra), no in / away.
5. **The Voice switch on iPad and laptop.** Recommended: a small "Voice: On / Off" chip beside the perspective chips in the
   left column. It uses the same per-device setting.
6. **The installed Android app.** Recommended: v1 ships for the browser and the home-screen app. Where speech isn't
   available, the Voice item is hidden and nothing breaks. A native text-to-speech plugin for the app shell comes later, as
   its own step (a new dependency and a new Play build).
7. **One setting for both modes:** recommended one `kb:voice` per device, On by default, used by bullpens and Intent games
   alike. In a game without Intent it's hidden and silent.
8. **The actual tap:** it is silent. Recommended: it doesn't cut off a call still being spoken, so the call finishes.

**Testing note.** Acceptance 1-9 need audio on a real phone, which I can't hear. I'll prove the spoken strings and the
timing on staging in Chrome (the exact text handed to `speechSynthesis` for every cell, side and perspective). The phone
listening checks (iPhone, silent switch, airplane mode, Android Chrome) go on your list.

Apply order once built: site only (CACHE_VERSION bump). If C1 = yes, also deploy `send-session-report` (staging first). No
migration.
