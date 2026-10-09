# U13 — Every button in the segmented style (Oct 9, 2026)

**Joel, Oct 9, 2026.** Every button in the app is redesigned to **direction #5, "Segmented"**, from the Knuckleball Button Directions page. Grouped choices sit in one soft tray, and the selected choice rises as a white segment with an accent underline. Standalone buttons are softly rounded rectangles. It should feel quiet until tapped, like the iPhone's own controls. Reference: `docs/button-directions-reference.html` (the Button Directions page; style 5 is the one being built).

## What Claude Code found (Oct 9 audit)

Claude Code counted **208 buttons using 46 different styles** in the charting app, plus **31 buttons with inline styles**. The core follows the usual pattern — `btn-primary` (filled, 41 buttons) and `btn-ghost` (outlined, 73) cover more than half — and the other ~43 styles grew one screen at a time: charting targets (zone cells, `g5-cell` field boxes, bases, scorebook), pick-one chips (`type-chip`, `pstrip-chip`, Set/Windup, `pb-pill`, throws, team and account chips), action rows (`g5-act`, `ph-act`, Next pitch, Undo, velocity arrows, ⏱), navigation (page tabs, coach dock, ‹ back, Roster bar, account), small utilities (close, copy invite link) and one-offs (Sign out, Bullpen / Live Game, invite buttons). Danger (red) is not a style; it is written inline on each destructive button. Measured at iPhone width, everything used while charting is 44–72px tall, but the standard `btn` (35), page tabs (37), the account button (38), Sign out (35), the Roster bar (40) and the Live Game's Windup and ⏱ (34) are under Apple's 44pt.

Claude Code proposed: fold the 46 styles into about 8, add a real danger style, raise the small buttons to 44px. **U13 is that cleanup, done in the segmented style.** The eight roles below are the fold targets; Claude Code's inventory (precondition 1) maps every one of the 46 styles and 31 inline cases onto them.

## Colors do not change

**Joel, Oct 9: the color schemes currently in place stay where they are.** Baseball keeps its green and gold; softball keeps its navy/pink/blue theme. The navy/Carolina palette on the Button Directions page and the green/copper front-page mock are explorations, not decisions. U13 defines **button color tokens** mapped to each sport's current theme colors, so a palette change later is a token swap, not another button pass.

## The style (exact values)

| Element | Spec |
|---|---|
| **Tray** (2–5 mutually exclusive choices shown together) | background `--btn-soft`, radius 12px, padding 3px, no gap; total height 44px |
| **Segment** (a choice inside a tray) | radius 9px, height 38px, weight 600, transparent background, `--btn-ink` text |
| **Selected segment** | white background, shadow `0 1px 3px rgba(0,0,0,.18)`, inset underline `0 -3px 0 var(--btn-accent)`; slides to the new choice in 150ms (instant with reduced motion) |
| **Primary button** (one per screen region: Next pitch, Save, Create team, Send report) | `--btn-primary` fill, `--btn-on-primary` text, radius 12px, min height 44px, weight 600 |
| **Secondary** (Back, Cancel, New batter, Undo) | `--btn-soft` fill, `--btn-ink` text, radius 12px |
| **Tertiary** (+ Add out, text-like actions) | transparent, `--btn-ink` text, radius 12px; same 44px hit area |
| **Icon button** (‹ › steppers, strip arrows, menu) | 44×44, radius 12px, `--btn-soft` fill |
| **Danger** (Discard, Delete session, Remove pitcher, Sign out of all devices) | one shared class, never inline: `--btn-soft` fill, red text `--btn-danger` (the red already used inline today, unified); confirm dialogs unchanged. Replaces every inline red. *(The reference shows no danger button; this is the drafting decision.)* |
| **Disabled** | `#F1F3F6` fill, `#ADB4C0` text, no shadow, not tappable |
| **Pressed** | 4% darker fill (transform `scale(.98)` unless reduced motion) |
| **Focus** | 3px `--btn-accent` outline, 2px offset, keyboard only (`:focus-visible`) |
| **On dark surfaces** (status bar, dark panels, report headers) | tray `rgba(255,255,255,.10)`; segment text 80% white; selected segment stays white with `--btn-ink` text |

Type: the app's existing self-hosted body font, 15px on standalone buttons, 13–14px in segments. No new font.

**The eight roles:** tray/segment (pick-one), primary, secondary, tertiary, icon, danger, nav (tabs, dock, Roster bar — a tray on a dark or light surface), charting target (grid cells, field boxes, bases, scorebook — **not restyled**, see §4). Every one of the 46 styles must land in one of these or be escalated.

**Minimum height 44px everywhere**, including the standard `btn`, page tabs, the account button, Sign out, the Roster bar, and Windup and ⏱ in the Live Game status bar. Where a bar can't grow (the phone status bar), the control gets a 44px hit area with padding/`::before` while its visible box stays.

## What becomes what

1. **Trays:** every place 2–5 mutually exclusive options are shown side by side: mode choosers, view toggles, History and report filters, Profile and roster tabs, charting perspective (on iPad/laptop where it shows as buttons), sport choice where it is buttons, and any Yes/No pair (the G3 extra-inning prompt).
2. **The pitch-type strip** becomes a scrollable tray, with the ‹ › icon buttons outside it. **The selected chip keeps its pitch-type color as the underline** instead of the accent, so a charter can still find pitches by color. Unselected chips show a small dot in their type color.
3. **These stay single buttons by Joel's earlier decisions** and are restyled as secondary buttons, not turned into trays:
   - **Set/Windup** is one button that flips on tap. Set looks selected (white, with the underline); Windup looks secondary.
   - **⏱** is an icon button, disabled on Windup.
   - **The batter pill** keeps its states: Live Game flips vs RHB ⇄ vs LHB; the bullpen cycles No batter → vs RHB → vs LHB. No batter is secondary; a set side looks selected.
4. **Not buttons, so not restyled:** the 5×5 location grid cells, the G5 diamond boxes (and their white flashing choice boxes), the velocity number itself, scorebook cells, chart marks, and links inside running text. The corner buttons on the grid and diamond (Back, Next, + Add out) **are** restyled.
5. **Report pages:** buttons on `report.html` and the game report get the same style **through the external stylesheet only**. If an inline script or style must change, recompute the CSP hash.

---

## The packet (paste for Claude Code)

```
ID:              U13
Title:           Redesign every button to the segmented style (direction #5);
                 shape and behavior via button tokens, current colors kept
Spec:            plans/u13-segmented-buttons.md on GitHub (pull first; work only
                 from GitHub). Reference: docs/button-directions-reference.html,
                 style 5. Build to the spec; where the reference differs, the
                 spec wins. Your Oct 9 button audit (208 buttons, 46 styles, 31
                 inline) is the starting inventory.
Depends on:      G1b-r5/r6 layouts, S1/S2 theming, U10/U11, G3. All shipped. If G5
                 is in progress, build U13's button classes so G5 uses them.
Staging only.    No database change. Only Joel ships to production.

PRECONDITIONS — REPORT, with file and line numbers, before any code:
  1. The Oct 9 audit extended to every page (app shell, bullpen, Live Game,
     History, Roster, Profile, team/coach pages, join/signup/sign-in, landing,
     privacy/terms, both report pages, guardian approval): each of the 46
     styles and 31 inline cases, its current classes, which of the eight roles
     it folds into (tray/segment, primary, secondary, tertiary, icon, danger,
     nav, charting target) and anything that doesn't fit. A table, grouped by
     page, with measured heights.
  2. Where button styles live today (shared CSS vs per-page vs inline styles),
     and how the baseball and softball themes set colors (custom properties?).
  3. Every place a choice group is currently built from separate buttons with
     JS toggling a class, and whether a shared helper exists.
  4. Report pages: whether any button style is inline (CSP hash impact).
  5. Every control under 44px today (the audit's list plus any others) and
     how each reaches 44px: taller box, or a padded hit area where the bar
     can't grow.
  Build nothing until Joel has read the report.

BUILD:
  - One shared stylesheet section: button tokens (--btn-ink, --btn-soft,
    --btn-primary, --btn-on-primary, --btn-accent) defined per sport from the
    CURRENT theme colors; classes for tray, segment (+ selected), primary,
    secondary, tertiary, icon, destructive, disabled; pressed, focus-visible,
    dark-surface variants; reduced-motion handling. Exact values in the spec.
  - One small shared helper for trays: selection, aria-pressed (or radiogroup
    semantics), arrow-key movement, sliding indicator. Existing handlers keep
    their behavior; only markup/classes change.
  - One danger class replacing every inline red; 44px minimum on every
     control (spec); remove the 31 inline button styles.
  - Apply to every control in the inventory. Pitch strip: scrollable tray,
    selected underline in the pitch type's color, type dot on unselected.
    Set/Windup, ⏱ and the batter pill stay single buttons (spec §3).
  - Grid cells, diamond boxes, scorebook cells: untouched.
  - Remove per-page button styles the shared classes replace (report what was
    removed).
  - CACHE_VERSION bumped.

OUT OF SCOPE: any color change — baseball stays green/gold, softball keeps
  its current theme (Joel, Oct 9); layout changes
  beyond what a control's new shape needs; behavior changes of any control;
  grid/diamond/scorebook visuals; new fonts.

ACCEPTANCE (both sports):
  1. Screenshots of every page at 390, 375 and iPad landscape, before and after,
     side by side; every control matches its spec row; nothing clipped; no
     horizontal scroll introduced.
  2. Every interactive target ≥ 44pt (measured, listed), including the ones
     the audit found short: btn, page tabs, account, Sign out, Roster bar,
     Windup and ⏱ in the Live Game status bar.
  3. A bullpen and a Live Game half-inning charted on staging behave exactly as
     before: same taps, same stored rows (compare one session's pitches table
     before/after on the same tap script).
  4. Trays: one selected at a time, keyboard arrows move it, screen reader
     announces the selected option; reduced motion = no slide.
  5. Pitch strip: selected chip's underline is its type color; scrolling and
     ‹ › arrows still work; five/four chips visible as r5 specifies.
  6. Set/Windup, ⏱ and the batter pill keep their exact states and auto-set
     rules.
  7. Softball theme applies its own tokens everywhere; no baseball color leaks.
  8. Report pages render with the new buttons; CSP unchanged or hash recomputed
     and stated; strict escaping untouched.
  9. Offline: app shell loads offline with the new styles (P1-01 checks 1–3).
 10. Style count after: the 46 button styles are down to the eight roles (plus
     size variants); zero inline button styles; every danger button uses the
     danger class. Counted the same way as the Oct 9 audit.
VERIFICATION: Joel taps through bullpen, Live Game, History and Profile on his
  phone and iPad, both sports, on staging.
ROLLBACK: git revert; bump CACHE_VERSION.
SIZE: M–L (wide but shallow).
ESCALATE IF: a control can't fit 44pt in its current space in the new shape; a
  choice group's handler can't move to the shared helper without changing
  behavior; a report page needs a CSP change beyond a recomputed hash; any
  control doesn't fit a spec row.
```

### Standing constraints (in force)

No behavior changes, only presentation. Strict escaping; report.html CSP hash recomputed if its inline script changes. GitHub is the source of truth. Pre-push checks finish before push. **Only Joel ships to production.**
