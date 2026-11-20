# SR1 Stage G · Print · preconditions (Nov 19, 2026)

Read at `543f974` (main: SR1 A–F on production, v366). **Branch:** `sr1g-print`, from `origin/main`.

**Pictures:** none (the packet: "the preconditions report sketches the printed pages"; section 3).

**No migration and no app change.** Stage G is the stored report's own CSS plus a small amount of print-only markup,
in `send-session-report` (`sr1.ts`, `template.ts`, `template_game.ts`). `report.html` doesn't change, so no cache bump.

## 1. What changes, where it is now

| Where | Now | Stage G |
|---|---|---|
| `sr1.ts` `SR1_CSS` (L385) | no print rules. Panels show by `:checked`, so a print gives only the open tab | `@media print`: every panel of the version on screen shows, each from a new page (panel 1, Summary, first); the tab row (`.kr-tabs`) and the window switch (`.kr-ws`) hide |
| `sr1.ts` `panel(i, html)` (L310) | `<div class="kr-panel kr-p<i>">` for every version alike | + the versions that use it (`kr-pv-coach` / `-player` / `-parent`, read from the same labels as `tabBarVersions`), so print shows only this version's pages, plus a **print-only page title** (section 3) |
| `template.ts` L212 `@media print` | white page, header colours kept, `.section` unbroken, dark dot outlines | unchanged, plus: no card, tile row, strip, trend row, rest card or 7-day card split across a page |
| `report.html` `<style media="print">` (L68) | 12 mm margins, the bar hidden, tables unclipped, no break inside svg / tr / tiles | **unchanged.** It's what makes iPhone Safari paginate (U10). |

**Where the packet doesn't match the repo:**

1. **A panel isn't tied to a version in the file today.** Each version picks its panels through its tab labels, and some
   panels are shared under different names:
   - pen panel 3 is "Velocity & workload" (coach) and "Velocity" (high school player);
   - pen panel 4 is "Trends" (coach) and "Progress" (high school player, little league parent);
   - game panel 5 is the same Trends / Progress case.

   "Every tab's panel shows" therefore needs the panel to carry its versions, and its print title the right name per
   version. Both are new markup in new reports only, built from the labels `tabBarVersions` already uses.
2. **Printing happens on report.html.** History draws the report inside the app, so printing History prints the app
   page, not the report. A coach prints from the report link (Copy Report URL, or the email's button), where report.html
   has its Print button and iPhone's Share → Print. See question 1.
3. **"The header repeats on page 1 only":** the header is in the flow, so it prints once, at the top of page 1. Each
   later page gets one title line instead (section 3), so a loose page still says whose report it is.
4. **"The selected window is the one printed":** this works as is. `:checked` holds in print, so the window chosen on
   screen (3 months unless changed) is the one in the tiles, captions and the Command table. Each page title names it.

## 2. CLAUDE.md decisions this stage touches

| Recorded now (quoted) | New rule beside it |
|---|---|
| "Reports are HTML pages … content frozen at save time" | Unchanged. Print rules ship inside new reports. Reports already sent print as they do today (one tab). |
| SR1 C: "Every section the old reports had is kept inside a tab" | Unchanged. Print shows every tab of the version on screen, one tab per page. |
| SR1 E: "`kr-as-player` / `kr-as-parent` on an ancestor; none = coach" | Print follows the same class: a `&v=player` link prints the player's pages. |

## 3. The printed pages (sketch)

Each page after the first starts with one title line (shown only in print):

```
COMMAND · Sam Test · Bullpen · Nov 18, 2026 · compared with 3 months
```

That's the tab's name for this version, the pitcher, the kind, the date and the window shown. Little league parents
have no window switch, but their numbers are still read against 3 months, so their pages name it too.

**Bullpen, coach (and college player, in "you"):**

```
┌──────────────────────────┐ ┌──────────────────────────┐ ┌──────────────────────────┐ ┌──────────────────────────┐
│ ▓ KNUCKLEBALL  SOFTBALL ▓│ │ COMMAND · name · date ·  │ │ VELOCITY & WORKLOAD · …  │ │ TRENDS · …               │
│ ▓ Sam Test · Command pen▓│ │   3 months               │ │ velocity by type         │ │ trend lines              │
│ (no tab row)             │ │ grids per type and side  │ │ 7-day card               │ │ pen history table        │
│ headline                 │ │ type table (vs avg)      │ │                          │ │                          │
│ Compared with … 3 months │ │ where it missed          │ │                          │ │ footer                   │
│ 4 tiles                  │ │                          │ │                          │ │ (coaches' notes, if any, │
│ What stood out           │ │                          │ │                          │ │  from report.html)       │
│ pitcher's-view caption   │ │                          │ │                          │ │                          │
└──────────────────────────┘ └──────────────────────────┘ └──────────────────────────┘ └──────────────────────────┘
        page 1                       page 2                      page 3                      page 4
```

- **Game, coach:** Summary · Location · Batters · Pitch types · Trends · Every pitch: six pages. The Every pitch log
  can run to two or more pages. Rows never split, and the browser repeats the table's header row.
- **High school player:** pen Summary · Command · Velocity · Progress; game Summary · Location · Batters · Progress.
- **Little league player:** Summary · Where it went · Progress (no velocity anywhere, as on screen).
- **Little league parent:** Summary · Progress.
- **A page taller than the paper** (a long Command or Every pitch) continues on the next sheet. The break never falls
  inside a card, a tile row, a chart, a table row or an at-bat line.

## 4. Questions for you

1. **Where printing happens:** report.html only, through its Print button, Share → Print, or Chrome's Print / Save as
   PDF. History stays a screen view. **Recommendation:** yes. Printing the app's History page isn't a report print, and
   History can't add a print layout without app changes the packet doesn't ask for.
2. **The page title line** (section 3) on pages 2 onward. **Recommendation:** yes, with the window on every page (the
   packet: "named on each page"), including pages the window doesn't change.
3. **Which version prints:** the one on screen (coach by default, `&v=` from an email link). **Recommendation:** yes,
   with no "print every version" option.
4. **Checks:**
   - Chrome: I make PDFs of a bullpen and a game (coach, high school player, little league player and parent) from
     staging and attach them.
   - **iPhone Safari (Share → Print → save as PDF):** yours. I can't reach your phone. Two reports: I'll send you the
     staging links.

## 5. Checks after your yes (packet 22, plus every-stage 1–4)

- **PDFs:** a bullpen and a game report from Chrome (Save as PDF), each version. One page per tab, the title line on
  pages 2 onward, no tab row or window switch, nothing split inside a card. From Safari on iPhone: yours.
- **On screen, unchanged:** the same report at 390 before and after looks identical (screenshots compared). Print-only
  markup is hidden on screen.
- **History:** the shadow-root view is unchanged.
- **Old reports:** a report sent before the stage hashes the same and still prints the old way.
- **The rest:** sizes (a few hundred bytes); pre-push checks; no cache bump (no `.html` changed); STATUS, CLAUDE.md.

## 6. Production (Joel's, after the PR)

1. `supabase functions deploy send-session-report --project-ref fkgccjhuimkkbupbanxp` (no migration).
2. Merge (no cache bump).
