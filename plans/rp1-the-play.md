# RP1 — "The Play": field locations by name in reports, Nov 25, 2026

**Joel, Nov 25.** In a game report's **What led to it** section, the table headed "By field box" lists rows as "Box 10", "Box 18". Replace the box numbers with plain names, and state each row as the play itself. His example: an out on a fly ball to box 10 reads **"Flyball out in the Right-field corner"**.

Report function only (`send-session-report`: `diamond.ts`, `compute_game.ts`, `from_rows.ts`, the templates, every SR1 reader version). No database change. The box numbers stay in the data and on the charting field; **reports already sent are frozen and keep their old wording.**

## 1. The heading and the rows

- "What led to it" stays.
- **"By field box" becomes "The Play".**
- Each row is one distinct play, written as **how it was hit + what it was + where**, e.g. "Flyball out in the Right-field corner". Rows with the same sentence are one row. The other three columns (Balls in play, Pitch types, Pitch locations) are unchanged. Most frequent first.
- **Names only. No box number anywhere in a report.**

Words:

| Stored | Written |
|---|---|
| ground / line / fly / pop / bunt | Groundball / Line drive / Flyball / Pop up / Bunt |
| out / error / fielder's choice | out / error / fielder's choice |
| hit | single / double / triple / home run from the hit type; "hit" if an old game has none |

## 2. Where — the names

The location phrase carries its own preposition, so the sentence reads naturally.

| Box | Phrase |
|---|---|
| 1 | in foul ground behind home, third-base side |
| 2 | in foul ground on the third-base side |
| 3 | down the Left-field line |
| 4 | in the Left-field corner |
| 5 | over the fence down the Left-field line |
| 6 | over the fence in Left field |
| 7 | over the fence in Center field |
| 8 | over the fence in Right field |
| 9 | over the fence down the Right-field line |
| 10 | in the Right-field corner |
| 11 | down the Right-field line |
| 12 | in foul ground on the first-base side |
| 13 | in foul ground behind home, first-base side |
| 14 | in foul ground right of home |
| 15 | at Home plate |
| 16 | in foul ground left of home |
| 19 / 20 / 21 | in Left field / in Center field / in Right field |
| 25 | up the middle |

**Boxes 17, 18, 22, 23 depend on whether the ball was fielded in the infield or the outfield** (the IF / OF answer stored with the play):

| Box | Infield | Outfield |
|---|---|---|
| 17 | at Third base (3B) | down the shallow Left-field line |
| 18 | at Shortstop (SS) | in shallow Left field |
| 22 | at Second base (2B) | in shallow Right field |
| 23 | at First base (1B) | down the shallow Right-field line |

**Box 24, the mound, depends on who fielded it:**

- Pitcher or catcher, or no fielder recorded → **at the Pitcher's mound**.
- 3B, SS, 2B or 1B → **shallow 3B / shallow SS / shallow 2B / shallow 1B**, written before the hit type as Joel gave it: "Shallow SS groundball out".

*Drafting decisions, restate each as a yes/no in your report:*

1. Box 25 fielded in the outfield reads "in shallow Center field"; in the infield, "up the middle".
2. When a play has no IF / OF answer stored: a groundball or bunt counts as infield, a flyball as outfield, a line drive or pop up as infield.
3. The same names replace the box number in the report's **at-bat log** ("1B · LD · box 22") and in the spray chart's caption. The app's charting field and History keep their numbers.
4. Games charted before the field chart, which are placed by the fielder who made the play, use the infield names.

## Report first, then build

Before code: where every box number is printed in any report version; how the IF / OF answer and the fielders are stored and how often each is empty on production (counts only); the full list of sentences the rules above produce for each hit type, so Joel can read them once; the four drafting decisions.

## Done when

1. "The Play" replaces "By field box"; no report shows a box number.
2. Joel's example renders exactly: "Flyball out in the Right-field corner".
3. Box 18 infield → "…at Shortstop (SS)"; box 18 outfield → "…in shallow Left field"; the same pairs for 17, 22, 23.
4. Box 24 fielded by the pitcher → "…at the Pitcher's mound"; fielded by the shortstop → "Shallow SS groundball out".
5. Baseball and softball, every reader version, print included.
6. A report sent before this change hashes the same as before.
7. Function deployed to staging only; tests pass; `STATUS.md` updated.

## Prompt for Claude Code

```
Save this packet verbatim as plans/rp1-the-play.md on the branch before anything else; if a copy already exists on main, use that one and tell me if the two differ.

Do the "Report first" section and wait for my answers. Then build it as one pull request, staging only. No migration. Do not push to main, do not merge, do not deploy the function to production. Finish with the numbered "Done when" list, each item marked pass or fail with evidence.
```
