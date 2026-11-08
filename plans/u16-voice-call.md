# U16 — Voice call: the app speaks the pitch and its location

**Written Nov 8, 2026 from Joel's spec; numbering and Live Game intent settled by Joel the same day.** Status: 📦 **approved for build.** Repo copy: `plans/u16-voice-call.md`. Standing constraints apply (only Joel ships to production; no third-party loads; frozen reports untouched; pre-push checks finish before any push; neutral wording).

## Goal

When the charter taps the intended pitch, the phone says it out loud: the pitch type, then the location by its area name, batter-side aware, so the pitcher hears the call the way a PitchCom earpiece would deliver it. **Bullpens: on by default.** **Live Games: on whenever the game was started with "Turn on Intent?" = Yes** (the existing question on the Live Game start screen); a game charted outcome-only has nothing to call and stays silent. Both sports, every device.

## What is spoken

**Form:** `<pitch type> <area name>`, e.g. "Slider low and in", "Fastball middle up extra", "Changeup middle away plus". Pitch types use the full stored name (U3), not the on-screen abbreviation. Nothing else is spoken: no count, no velocity, no batter side, no pitch number.

**The grid (Joel, Nov 8: keep the canonical numbering — 1-2-3 is the top row; rows never flip; columns are batter-relative).** Drawn here in the catcher's view against a right-handed batter (batter on the left, "in" is the left column); the numbers and names travel with the batter side, so against a lefty or in the pitcher's view the columns mirror and 1 is still up and in.

```
        ┌──────┬──────┬──────┬──────┬──────┐
        │  10  │  11  │  12  │  13  │  14  │   above the zone  → "extra"
        ├──────┼──────┼──────┼──────┼──────┤
        │  15  │  1   │  2   │  3   │  16  │   up
        ├──────┼──────┼──────┼──────┼──────┤
        │  17  │  4   │  5   │  6   │  18  │   middle
        ├──────┼──────┼──────┼──────┼──────┤
        │  19  │  7   │  8   │  9   │  20  │   low
        ├──────┼──────┼──────┼──────┼──────┤
        │  21  │  22  │  23  │  24  │  25  │   below the zone  → "extra"
        └──────┴──────┴──────┴──────┴──────┘
         in side column (15,17,19 + corners 10, 21) → "plus"
         away side column (16,18,20 + corners 14, 25) → "plus"
```

**Spoken names, inner nine (canonical, Amendment 8 as amended Oct 29):** 1 up and in · 2 middle up · 3 up and away · 4 middle in · 5 middle middle · 6 middle away · 7 low and in · 8 middle low · 9 low and away.

**Outer ring:** every outer cell is named after the inner cell it touches, plus one word. The three cells **above the up row** (11, 12, 13) and the three **below the low row** (22, 23, 24) add **"extra"**: 12 → "middle up extra"; 22 → "low and in extra". The **five cells on the in side** (10, 15, 17, 19, 21) and the **five on the away side** (14, 16, 18, 20, 25), corners included, add **"plus"**: 17 → "middle in plus"; 18 → "middle away plus"; 10 → "up and in plus"; 25 → "low and away plus". So "extra" means over or under the zone and "plus" means off the plate to either side. Full table of 25 cells × 2 batter sides goes in `plans/u16-speech-table.md`.

**Batter side.** "In" and "away" are batter-relative, so the same physical cell is "low and in" against a right-handed batter and "low and away" against a left-handed one. The speech uses the **same single label function** the grid labels use (D8, `zoneNumberFor` and its name table), extended to the ring; no second copy of the mapping (Amendment 4). Perspective never changes the words.

**Softball:** identical words, identical rules.

## When it speaks

- **Bullpen:** immediately on the **target (intent) tap**, after the pitch type is selected. Not on the actual-location tap. Re-tapping a different target before the actual tap speaks the new call and cuts off the old one.
- **Live Game with Intent on:** on the intent tap (the signaled type and area), before outcome and response. With Intent off: silent and no Voice control shown.
- **Never** on History, Profile, reports or the painter.

## Controls

- A **Voice: On / Off** item in the session's 9-dot menu. Bullpens open On; Live Games open On when Intent is on. Remembered per device (local storage), not per account — it's about the room the charter is in.
- System volume and the phone's silent switch behave as the OS decides; the app does not override them. iOS speech follows the ringer switch on some versions; the Help page gets one line about it.

## How it is built (constraints)

- **Web Speech API (`speechSynthesis`) only**, on-device voices, no network, no third-party script or audio files, so it works in an offline bullpen. `en-US`; the first local voice for that language, no voice menu in v1; rate 1.1, pitch 1.0; `cancel()` before each new utterance so calls never queue.
- Speech starts from inside the tap handler (a user gesture). The preconditions report says whether iOS needs a one-time silent warm-up utterance on the first tap of a session.
- **Installed shells (W1):** Capacitor's WebView exposes the same API; confirm on the Android internal-testing build and note it for the iOS shell once it's on a device.
- No stored data changes. The spoken string is derived at tap time and not saved.

## Acceptance

1. Bullpen, phone, Voice on: select Fastball, tap cell 5 → "Fastball middle middle" within ~300 ms; tap 12 → "Fastball middle up extra"; tap 17 → "Fastball middle in plus"; the four corners say the diagonal neighbor + "plus".
2. Flip the batter to LHB: the same physical in-side cell now says "… away" and the same physical away-side cell says "… in"; flip perspective behind the pitcher: words unchanged for the same physical cell (the U5 proof, with audio).
3. Re-tap a different target before the actual tap: the second call plays and the first is cut off; the actual-location tap is silent.
4. Live Game started with Intent = No: no speech, no Voice item in the menu; with Intent = Yes: speaks on the intent tap only.
5. Voice Off silences everything for that device and survives a reload; another device is unaffected.
6. Airplane mode: bullpen speech still works.
7. Softball bullpen and softball Live Game with Intent: identical behavior.
8. Full name spoken for each of the 12 pitch types; `plans/u16-speech-table.md` lists every cell × side string and matches this packet.
9. CACHE_VERSION bumped; STATUS.md entry; no migration, no function change.

## Decisions (Joel, Nov 8)

1. **Numbering:** canonical stays — 1-2-3 is the top row, 7-8-9 the bottom row. The Nov 8 dictation that reversed them is withdrawn; the spoken names for the low row are "low and in", "middle low", "low and away".
2. **"low and away"**, not "low and outside" (consistent with 3, 6 and 9 all using "away").
3. Voice toggle in the 9-dot menu, remembered per device.
4. Speech on the intent tap, never the actual tap.
5. **Live Game intent already exists** ("Turn on Intent?" on the start screen), so the Live Game half ships with the bullpen half; no dependency on later bridge work.

---

## Paste into Claude Code

> Save this packet verbatim as `plans/u16-voice-call.md` on the branch before anything else; if a copy already exists on main, use that one and tell me if the two differ. Pull `origin/main` first and work only from what GitHub has. Read `CLAUDE.md`, `STATUS.md`, `plans/` and the packet. This is **U16: the app speaks the intended pitch type and location on the target tap — bullpens on by default, Live Games when the game was started with Intent = Yes — using on-device speech, with the canonical area names and the extra/plus ring rules in the packet.** Branch `u16-voice-call` from `main`. No database or function change. Standing rules apply: no third-party loads or audio files; frozen reports untouched; pre-push checks finish before any push; only Joel ships to production; neutral wording.
>
> **Before writing code, produce a preconditions report and stop for Joel:** (1) the single zone-label function and its name table today (file, lines), confirming 1 is up and in and that 3 and 6 read "up and away" / "middle away" (if the strings still say "out", list where — fixing them is in scope as Amendment 17); (2) whether the outer ring has names or numbers anywhere today; (3) where the bullpen target tap and actual tap are handled, and where the Live Game intent tap is handled when "Turn on Intent?" = Yes, so speech hooks one place each; (4) whether `speechSynthesis` on iOS Safari, Android Chrome and the Capacitor Android build needs a warm-up utterance on the first gesture, and what the silent switch does; (5) the 9-dot menu's structure for the Voice item and the local-storage pattern other per-device settings use; (6) the 12 pitch types' stored full names.
>
> **Then, on approval, build:** the name table extended to the 25 cells per batter side (one function, no second mapping), the speech hook on the target/intent tap with cancel-before-speak, the Voice item, `plans/u16-speech-table.md` with every cell × side string, acceptance checks 1–9 on staging on a real phone, CACHE_VERSION bump, STATUS.md entry, push, PR, and stop before production.
