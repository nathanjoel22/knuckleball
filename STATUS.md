# STATUS — what shipped, where, and what's open

The log. CLAUDE.md holds the rules; this file records each release. **A new entry goes on top every time a packet (or a request Joel ships without one) reaches staging or production**, with:
- date;
- packet ID;
- where it went;
- branch;
- commit;
- cache version;
- what was built;
- what deviated from the packet;
- open items.

Newest first. Entries before Oct 10, 2026 were written afterwards from git history.

---

## 2026-10-10 · U13 (+ spec update `-2`) · **staging**
- **Branch / commit / cache:** `u13-segmented-buttons` · `61102f9` · `kb-shell-v202`. The live site is still v195.
- **Spec:** `plans/u13-segmented-buttons.md` + `plans/u13-segmented-buttons-2.md`; report `plans/u13-preconditions.md` (Joel's answers A–G); evidence `plans/u13-evidence.md`.
- **Built:**
  - Every button in the segmented style, with one shared `buttons.css` on every page (precached). Its tokens come from each sport's current colors, so no color changed.
  - `segTray()` trays for every pick-one group: a 150 ms sliding white segment, arrow keys, `aria-pressed`.
  - The pitch-type strip and pitch types as trays (type-color dot, selected underline in the type's color, colors generated from the palette).
  - One `btn-danger` class (20 buttons, zero inline red) and 44 px targets.
  - The bottom menu (coach dock) as the one draggable tray: spring, hold 150 ms to lift, drag follows the finger, release switches once.
  - A locked tray reads as locked.
  - Also on this branch, by Joel's requests: the G5 chart flip at 325 ms (was 650), and the leaderboard hidden for baseball too (`hasLeaderboard: false`, nothing deleted).
- **Deviations from the packet:**
  - Type is 16 px on buttons and 14 px in trays (the spec says 15), to keep the Oct 9 eight-size scale.
  - Three arrows stay narrower than 44 px (phone pitch-strip ‹ ›, phone bullpen velocity ‹ ›, in-chart velocity ‹ ›). At 44 px wide the phone pen would show about 2 pitch types instead of 3½; escalated.
  - Next pitch's two golds are unified to the theme primary.
  - On iPad/laptop, Windup|Set and None|RHB|LHB are trays (decision A); phones keep the single buttons.
  - A quick sideways slide on the bottom menu picks the segment up without the hold (the spec doesn't cover this case).
  - The v197 slide-on-every-tray was removed per spec `-2`.
- **Open items:**
  - Joel's device checks (bullpen, Live Game, History, Profile; phone + iPad; both sports).
  - Acceptance 4b: an iPhone video of the bottom menu.
  - P1-01 offline checks 1–3.
  - Joel's call on the narrow arrows and 15 vs 16 px.
  - When shipping: merge `main` (it has the spec `-2` upload) and run the pre-push checks.
  - If the leaderboard stays off, the privacy and guardian pages' leaderboard sentence needs Joel's approved rewording.

## 2026-10-09 · no packet (type scale) · **production**
- **Branch / commit / cache:** `type-scale-8` · `016d72d` · `kb-shell-v195`.
- **Built:** the tracker's 30 font sizes folded into 8 (10/12/14/16/20/24/32/44).
- **Deviations:** the phone status bar and ADV caption use 16 (not 20) so the status bar stays on one line.
- **Open:** the other pages (landing, sign-in, join) still use their own 9–12 sizes each.

## 2026-10-09 · no packet (coach dock, phone roster) · **production**
- **Branch / commit / cache:** `coach-mobile-dock` · `d9e81fd` · `kb-shell-v193`; then `roster-full-list` · `b939869` · `kb-shell-v194`.
- **Built:**
  - Coach phone dock: Home / Charts / Roster / Profile, translucent, hides scrolling down, glide pill.
  - The phone roster stays rolled up until Roster is tapped, and then opens the whole list.
- **Deviations:** none. **Open:** none.

## 2026-10-08 · no packet (wordmark) · **production**
- **Commit / cache:** `42c85f4` · `kb-shell-v189`; the Noto files were removed in `f73aad8`.
- **Built:** KNUCKLEBALL in self-hosted Black Ops One on every page, no diamond or period.
- **Open:** `privacy.html` / `terms.html` still show the old wordmark (a change there needs Joel's approval).

## 2026-10-08 · no packet (History cards) · **production**
- **Commit / cache:** `925d497` · `kb-shell-v188` (v185–v188).
- **Built:** History cards show the report's first chart (pitcher's view, dots by type, grey ring, cream zone) over a drawn home plate; games get a per-type table.

## 2026-10-08 · G5 Live Game on the field · **production**
- **Commit / cache:** `25290c2` · `kb-shell-v184`, after backup 2026-10-08-1527.
- **Migrations:** `20261007000000_g5_spray_box`, `20261008000000_g5_spray_field`; report functions deployed; schema dump `e714125`.
- **Built:** see CLAUDE.md "Live Game on the field" and `plans/g5-evidence.md`.
- **Deviations:** many, by Joel's later decisions, all recorded in CLAUDE.md. Where they differ from `plans/g5-live-game-diamond.md`, CLAUDE.md wins.
- **Open:** Joel's production phone check; P1-01 offline checks 1–3 on the G5 build.

## 2026-10-06 · U12 pitcher's-view reports · **production**
- **Commit / cache:** `9834627` (U12 complete) · `kb-shell-v153`.
- **Built:** pitcher's-view report and History grids; `from_rows.ts`; the operator-only `rerender-reports`; the Cairn re-render 23 of 23 (originals in `reports-archive/2026-10-06/`).
- **Open:** none (the phone and offline checks passed Oct 6).

## Standing open items (not tied to one release)
- **H1 grace path:** close no earlier than **Oct 19, 2026**. Drop the 6 grace policies, seal the remaining sessions, and show Joel any leftovers first.
