# N1 Stage F · evidence (Nov 17, 2026)

Branch `n1f-card-milestones`, cache `kb-shell-v348`. Staging app (local server, staging config); no database change.
Headless Chrome with device emulation. Pictures are in `plans/n1f-evidence/`; I scanned them for email addresses and
found none.

**The milestone list is Joel's (Nov 17), not the packet's.** There are no pitch-count milestones:
- 1st session; 1st, 3rd and 5th bullpen; 1st, 3rd and 5th live game;
- total sessions at 10, 20, 50, 75, 100, then every 50;
- strikeouts at 1, 5, 10, then every 10 to 100, every 100 to 1,000, then every 1,000;
- every new top velocity, the first reading included;
- run banners at 4, 8, 12, 26 and 52 weeks.

## Every-stage checks

1. **Roles and sizes:**
   - The card on the coach's pitcher page at 390 and 1180 (`f6-coach-page-1180.png`).
   - The card on a pitcher's own Account at 390 (`f4`), with the run card and Recent (`f5`).
   - The parent's player view and the view-only family's.
   - The Home banner at 390 (`f3`).
2. **Offline:** everything here comes from History's data on the device, and the Share picture is drawn on the device.
   Nothing reads the network.
3. **Charting:** unchanged by this stage.
4. **Side by side:**

   | Picture | Built | Differences, and why |
   |---|---|---|
   | `f-pitcher-card.png` | `f4-account-card-390.png`, `f-card-share.png` (the Share PNG) | Same parts and order: stripes, faint number (Andre has no uniform number, so there's none), RHP, initials, team · year, name, chips, four stats, wordmark and address. |
   | `f-milestones.png` | `f3-banner-home-390.png`, `f5-run-recent-390.png` | No "ON PLAN" (Q4). The run card and Recent sit under the card, not on Home (Q5). Banner, coins, Rest days and Recent are as drawn. |

5. `CACHE_VERSION` is `kb-shell-v348`. STATUS.md and CLAUDE.md are in this PR, plus `supabase/schema/schema.sql`
   regenerated after Stage E's production migration. The pre-push checks run at push.

**Bar:** Account and Home end above the bar at 390 (708 vs 738).

## Stage F checks

**29.** The card's totals against Trends', for Noah Lindqvist (coach view):
- **card:** sessions 16, pitches 541, top velo 81, accuracy 33%;
- **Trends:** "16 sessions · Jul 16, 2026 – Nov 17, 2026 · 541 pitches", top velo 81 mph (4SFB);
- **History:** 16 sessions, 541 by `pitch_count`.

Top velo shows only with readings (`t.top != null`). Andre's own card shows 23 / 590 / 83 / 47%, the same on screen and
in the PNG.

**30.** On staging data (Andre Boateng, his own view):
- Every milestone has a unique id and fires once, dated by its session:
  - 1st session and 1st bullpen Jul 3;
  - top velocity 81 Jul 3, 82 Aug 20, 83 Nov 8 (the first reading counts, then each new best);
  - 1st, 5th, 10th and 20th strikeouts;
  - 3rd and 5th bullpen;
  - 1st, 3rd and 5th live game;
  - 10th session Sep 27, 20th session Nov 17.
- **The run:**
  - The weeks with sessions were Jun 28, Jul 12, Aug 2, Aug 16, Aug 30, Sep 13, Sep 27, Oct 11 (every other week, so
    no run), then Oct 25, Nov 1, Nov 8, Nov 15.
  - That gives "4 weeks running" on Nov 16, the first session of the 4th week in a row.
  - A week with no session ends a run. Days without one inside a week show as "Rest" and don't.
- The Home banner showed the newest ("20th session · Nov 17"). Dismissing it showed the next ("4 weeks running"), which
  stayed after a reload; the dismissal is remembered on the device.

**31.** Share:
- **Who sees it:**
  - adult pitcher (Andre, own card): yes;
  - parent (U15 Kid): yes;
  - view-only family: no;
  - coach (manager, Noah's page): no, with "From this team's sessions." under Recent;
  - adult U15 pitcher: yes.
- **Not run:**
  - a teen's own sign-in (none on staging): the rule needs the login's `age_attestation` to be 'adult';
  - a linked guardian (none on staging): the rule allows `activeLinked() === 'guardian'`.
- **The PNG:** 1080 × 1350, drawn by hand on a canvas (`f-card-share.png`), matching the card. On the web the sheet
  offers Share (or Download). With `isNativeApp()` true it shows "Press and hold the picture to save or share it."
  (Q1).

## Found and fixed while checking

- **The PNG's pitch chips had no labels.** The app's text-color helper returns `var(--ink)`, which a canvas can't read,
  so the label was drawn in the chip's own color. Colors are now resolved before drawing.
- The run card's green "Rest" uses `color-mix`, so I added a plain fallback for older iPhones.
- During testing the browser tab froze once while signing in after a reload. Every Stage F function, run one by one
  under a time limit, returned in under 10 ms, and the freeze didn't come back on a fresh tab. It's noted here in case it
  shows up on a device.
