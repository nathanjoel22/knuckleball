# U13 evidence (Oct 9–10, 2026), branch `u13-segmented-buttons`, v200

Spec: `plans/u13-segmented-buttons.md` plus the Oct 10 update `plans/u13-segmented-buttons-2.md` (adds the draggable bottom menu tray; no drag on any other tray).

Built to `plans/u13-segmented-buttons.md` with Joel's Oct 9 answers to `plans/u13-preconditions.md`:
- **A:** trays on iPad/laptop, single buttons on phones.
- **B:** pitch colors generated from the palette.
- **C:** the field-box position stays.
- **D:** the landing cards stay.
- **E:** each sport's dark ink for the underline.
- **F:** `--red-bg` for danger.
- **G:** one shared `buttons.css`.

**What changed**
- New `buttons.css`: tokens and the role classes (tray/segment, primary, secondary, tertiary, icon, danger, disabled, pressed, focus-visible, on-dark, reduced motion, a 44px hit-area helper). It's linked from the app and from the sign-in/sign-up, guardian, landing and report pages, and precached by `sw.js`.
- `bullpen-tracker.html`:
  - `segTray()` builds every pick-one group; `placeTrayIndicators()` slides the selection after each render; one keydown listener moves the choice with the arrow keys.
  - Pitch colors are generated at sport load as `.ptc-N` classes from `SPORTS[sport].palette`.
  - Every button now carries a role class. The old look rules are removed, and layout rules stay.
- Small pages: the 8 identical copies of `.btn-primary` and the guardian, landing and report button rules are removed.
- `report.html`: only its `<style>` and two button classes changed. **The CSP hash is unchanged and still matches the inline script** (recomputed).

**Decisions made while building (for Joel)**
- **Type size:** 16px on standalone buttons and 14px in trays, matching the app's 8-size scale set the same day. The spec rows say 15.
- **Next pitch:** both versions (`#C9A227` and the theme gold) now use the theme's primary color, per the spec's primary row.
- **Narrow side columns:** on iPad/laptop the perspective tray stacks its two long choices.
- **Soft fills on the sidebar:** the sidebar is the same pale green as the soft button fill, so buttons there sit on white.
- **Not at 44px wide (Escalate-if: can't fit 44pt in the current space):**
  - the phone pitch-strip ‹ › (20 px wide, 44 tall);
  - the phone bullpen velocity ‹ › (22 px wide, 62 tall);
  - the in-chart velocity ‹ › on the field (22 px wide).

  At 44 px wide, the phone bullpen row would show about 2 pitch types instead of 3½.

**Acceptance**
1. **Screenshots:** 17 app states × baseball and softball × 390, 375 and 1180 px (102 per side), before and after, plus the sign-in pages, landing, guardian and report toolbar. Automated check on all 102 after-screens: **no clipped text, no text spilling out of a button, no sideways page scroll.**
2. **44 px:** every target is ≥ 44 × 44, counting each button's own box plus its hit area, except the three narrow arrows above. Fixed from the audit:
   - `btn` (35 → 44);
   - page tabs (37 → 44);
   - account (38 → 44);
   - Sign out (35 → 44);
   - Roster bar (40 → 44);
   - Windup and ⏱ in the Live Game status bar (34 → 44 hit area; the visible pill stays 34 in the 44 bar);
   - Delete this session (15 → 44);
   - roster ✕ (19 → 44);
   - recent-pitch ✕ and leaderboard values (hit area).
3. **Same behavior:**
   - All 102 screens: **identical `onclick` handlers, same calls, same counts**, before vs after.
   - The same bullpen (4 pitches) and Live Game tap script run on old and new code gives **identical stored pitches, events and session state** (IDs and timestamps set aside).
4. **Trays (Chrome):**
   - One selected at a time; `aria-pressed` on each segment; `role="group"` with a label.
   - ArrowRight/Left move the choice, wrap around, and keep focus across the re-render.
   - The indicator slides in 0.15 s, and in 0 s with `--force-prefers-reduced-motion`.
5. **Pitch strip:** a scrollable tray. The selected segment is underlined in its type color (`--seg-accent` ← `.ptc-N`), and unselected segments show a type-color dot. ‹ › and scrolling use the same code. Chip width is unchanged (`var(--chip)`), so the same number show.
6. **Set/Windup, ⏱, batter pill:** the same handlers and states (Set looks selected; ⏱ disabled on Windup; the pill cycles as before).
7. **Softball:** 51 softball screens scanned. **No baseball ink, gold, soft green or old gold** in any button's computed colors. Tokens resolve to navy `#234B6E` / pink `#E27BA2` / navy accent.
8. **Reports:** the toolbar uses the new classes; CSP unchanged (hash recomputed and equal); no script edited; frozen reports contain no buttons.
9. **Offline:** `buttons.css` is in `PRECACHE_URLS`; `CACHE_VERSION` is v196. P1-01 checks 1–3 are Joel's device checks.
10. **Count:** 185 button elements (pick-one groups now come from one builder).
    - Roles used: `btn`, `btn-primary`, `btn-secondary`, `btn-tertiary`, `btn-icon`, `btn-danger`, `seg` (in `.tray`).
    - Size variants: `btn-sm`, `btn-block`.
    - **Inline `style=""` on buttons: 1** (the `g5-cell` position, decision C).
    - **Danger buttons: 20, all `btn-danger`, zero inline red.**
    - The other classes on buttons are layout hooks. Those that still set a look are the charting targets (field boxes, bases, batter), the coach dock (the nav role's sliding pill), the narrow arrows above, and three text-color details.

**Oct 10 update (spec -2): the bottom menu tray** (v200)
- The coach dock is the one draggable tray: `role="tablist"`, a translucent glass segment (`rgba(255,255,255,.85)`, 12 px blur, the accent underline), a 300 ms spring (`cubic-bezier(.34,1.56,.64,1)`), pointer events with pointer capture, `touch-action:none` on the dock only.
- Tested in Chrome with simulated touch pointers:
  - **Quick tap:** switched once, never lifted, sprang.
  - **Hold:** not lifted at 80 ms, lifted at 200 ms (`scale(1.06)`, deeper shadow).
  - **Drag:** followed the finger continuously (232 → 7 px), previewing Roster > Charts > Home; the page didn't switch during the drag, then switched once on release.
  - **Keys:** ArrowRight moved focus and segment, Enter selected; selected tab `aria-selected="true"`.
  - **Reduced motion:** no lift, no spring.
- A quick sideways slide (before 150 ms) also picks the segment up. The spec doesn't cover this case; it keeps the Oct 8 swipe working.
- **Removed:** the Oct 9 slide-to-pick on every other tray (v197), per the spec's "no other tray is draggable". Ordinary trays are tap-only again, with the 150 ms slide.
- Also on this branch: the G5 chart flip is 325 ms (Joel, Oct 10; it was 650).
- Still needed: acceptance 4b, a video on a real iPhone (Joel).
