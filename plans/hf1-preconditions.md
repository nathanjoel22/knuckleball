Written against: STATUS 2026-11-05 · Staging test data removed, production v327

# HF1 · History as a feed (Nov 5, 2026)

## 1. Goal (Joel's request)
History reads like Trends: scroll, and each session's report is right there. No more tapping a button to open a report.
Remove the comment box (Chat is the direction). Phones get a "Back to top" button. "View report" becomes **Copy Report
URL**: it copies the link and opens nothing; the pasted link opens the same report. Emailing reports is unchanged.

## 2. What existed (checked Nov 5)
- A History card opened on tap: plot, pitch-type table, coaches' notes box, "Email this report" (Send report + View
  report), Delete. View report opened `report.html?r=` in a new tab, creating the frozen report on first use.
- Production: 138 saved sessions, 69 with a report; 9 coaches' notes on 8 sessions.
- A report is a frozen file in the public `reports` bucket (~100 KB); History itself works offline.

## 3. Joel's answers (Nov 5)
- **A. A feed.** Every session's report shows in the list as you scroll, no tapping.
- **B.** Sessions with no report yet keep a **Create report** button that makes the report and its link as before.
  Everything going forward reads like a feed (built as: sessions started from Nov 5 get their report made automatically
  the first time they're on screen, same call and eligibility gate).
- **C. Agreed:** a report opened once is kept on the device (IndexedDB, not localStorage) and opens offline; one never
  opened there says it opens once online.
- **D. Recommendation:** no new notes anywhere; existing notes stay visible read-only (History and the report page);
  the database is untouched.
- **E. Phones only:** "Back to top" at the end of History and Trends.
- **F.** Not answered; the recommendation stands: the installed app keeps its Share button beside Copy Report URL.

## 4. As built (staging, v328)
- `bullpen-tracker.html` only (plus `sw.js` v328 and docs). No database, function or report change.
- The report is drawn inside a shadow root (its styles can't reach the app's) after the same inert pass as
  `report.html` (no script, no handlers, no javascript: links).
- 20 sessions at a time ("Show older sessions" adds 20), reports fetched ~900 px before they reach the screen.
- Device copies: `kb-reports`, at most 100, least recently opened dropped first, cleared at sign-out with History's.
- A row's "New" dot now clears when its card is on screen (there's no tap any more), except on the landing right after
  the viewer's own save (U10 (3)).
- F1-D's History back target (an opened session) is gone with the expansion.
