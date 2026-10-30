# F1-D: the bar and Back (remainder) — preconditions (Oct 29 2026)

Source: `plans/f1-training-facilities.md` v2, "Pitcher bar and Back (F1-D, remainder)", and acceptance check 10.

## What the packet asks for

1. **The bar:** segments Charts · History · Trends · Chat (only with a thread) · Profile, in U13 style, for every
   pitcher in both sports. iPad and laptop get the same items in the current tab placement. Coaches get Chat only at a
   facility.
2. **Back:** a header button left of the title, on every screen deeper than a section's first screen, for both roles,
   in the browser and installed. P2-05's in-app Back folds into it. It returns to the **section root** (Charts → New
   Session; History → list; Chat → thread list; Profile → top), never to browser history, and is never shown inside a
   live session.

## What exists today (checked Oct 29)

1. **The bar is already past the packet.** Joel's later decisions (v310 Oct 26, v320 Oct 29) give phones:
   - pitchers: Home · Charts · Analysis · (Chat) · Profile;
   - coaches: Home · Charts · Analysis · (Chat) · Roster · Profile.

   Analysis is History and Trends on one button. Chat shows only for logins at a facility (F1-C1, decision A), and
   friends and family get no Charts (F1-G). iPad and laptop have the tabs Home · New Session · History · Trends ·
   (Chat) · (Leaderboard) · Profile. The packet's five-item bar (no Home, separate History and Trends) is superseded by
   those decisions.
2. **Screens deeper than a section's first screen:**
   - **Charts:** the chooser (Bullpen / Live Game), then the start questions, then the charting screen. A "‹ Back" to
     the chooser already exists (`renderBackToChooserBtn`); it shows on the start questions and on the charting screen
     until the first pitch.
   - **History:** an opened session card. It expands in place, and only the session card collapses it.
   - **Chat:** an open thread. It has its own back arrow (`chatBack`).
   - **Profile:** one long page. "Add a player", the delete-account steps and the relative-accuracy cell painter open
     inside it or over it, each with its own Close or Cancel.
   - **Coaches:** "Player Profile" (the selected pitcher's page) and the roster list.
   - **Trends** and **Leaderboard** have nothing deeper.
3. **P2-05's installed-mode "‹ Back"** is only on report, privacy and terms. Those are separate pages that go back to
   the app; the app itself has no header Back.
4. **The live session:** the charting screen. Any Back there would risk the pitches being entered, and the packet says
   never show one.

## Questions for Joel

See the session message (A–C). Answers are recorded below once given.

## Joel's answers (Oct 29)

- **A. Yes.** The bar stays as it is (Home · Charts · Analysis · (Chat) · (Roster) · Profile); F1-D doesn't touch it.
- **B. Yes.** One "‹ Back" at the top left on every size, browser and installed. It goes to the section's first
  screen, never to browser history, and is never shown on the charting screen. It replaces the scattered back arrows
  (the chat thread's, Charts' "‹ Back" to the chooser).
- **C. Yes.** Back shows on:
  - the start questions (→ the chooser);
  - an opened History session (→ the list, at that card);
  - an open chat thread (→ the list);
  - Profile's Add a player / accuracy painter (→ the top of Profile);
  - a coach's Player Profile (→ the roster).

  Never on the charting screen, even before the first pitch, and never on a section's first screen.
