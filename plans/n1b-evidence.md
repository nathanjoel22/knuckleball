# N1 Stage B · evidence (Nov 17, 2026)

Branch `n1b-sidebar-roster`, cache `kb-shell-v344`. Staging: the migration was applied with `supabase db push`, and the app
was served locally with the staging config. Headless Chrome with device emulation at 390 (phone), 820 (iPad upright),
1180 (iPad sideways) and 1440 (laptop: no touch, browser display mode). Pictures are in `plans/n1b-evidence/`; I scanned
them for email addresses and found none.

Logins:
- the DS1 demo manager, a pitching coach and pitcher 10;
- the staging test logins from Stage A: the parent, the view-only family login, and the normal-team assistant;
- for check 17, `feed-pitcher-1793899731@example.com`, given the same throwaway staging password (Q8).

## The migration (J3)

```
supabase db push --project-ref wpsscxwawgiwmifpjpec --dry-run   -> Would push 20261117000000_n1b_remove_from_group.sql
supabase db push --project-ref wpsscxwawgiwmifpjpec             -> Applying migration 20261117000000_n1b_remove_from_group.sql
```

**F1-C2's parked migration.** Staging holds `20261104000000_f1c2_roster_threads`, from the parked F1-C2 branch, not on
main. Its file was put in place only for the push, so the CLI saw it as already applied, then removed. It is not
committed.

**Before:** staging's function body matched F1-A's exactly (md5 `8bc56e17…` both), so the rollback script restores
the same text.

**After:**
- `prosecdef` true;
- EXECUTE for `authenticated`, `postgres` and `service_role` only (no anon / public);
- the body no longer mentions `pitcher_teams`;
- 32 policies.

**Tests on staging (each rolls back):**
- `n1b_remove_from_group.sql`:
  `(5) CB removes from A:not_allowed | (1) CA removes P1 last group:ok left_side false on side 1 departures 0 | (2) old coach A sees P1 rows 0, manager sees 1 | (3) CB removes P2 (2 groups):ok groups left 1, on side 1 | (4) manager removes P1 from facility: rows 1, departure logged 1 | (6) policies 32 | fails 0`
- `f1a_acceptance.sql`: `CA remove own last group:ok left side false (P03 on side 1, departure logged 0) … policies 32 | hard fails 0`.
  The expected values changed with J3; the test now says so.
- `f1c1_chat_acceptance.sql`: `MIN removed: thread read, lists it true … policies 32 | hard fails 0`. The private
  thread still closes for the coach, and the family keeps reading.

## Every-stage checks

**1. Sizes and roles:**

| Size | What showed |
|---|---|
| 390 | The plain header (wordmark; Chat and avatar on the right), the Stage A bar, no menu, no old sidebar. |
| 820 | A 72px rail with icons only, every target 44px or more; ☰ opens the 280px menu over the page with a dimmed backdrop, and a tap outside closes it. The page keeps its place (main starts at 72px). |
| 1180 / 1440 | The 280px menu, no bar, no tab row. |

At 390:

| Role | Bar | Pitcher chip on Sessions |
|---|---|---|
| Pitcher (DS1) | Home · Chart · History · More | none (only one pitcher) |
| Parent (one player) | Home · Chart · History · More | none (one player) |
| View-only family | Home · History · More | none |
| Normal-team assistant | Home · Chart · History · Roster · More | yes |
| Manager | Home · Chart · History · Roster · More | yes |

Softball: the theme carries over (the menu uses the sport's `--brand-bg` and `--accent` tokens). Not re-shot this
stage; Stage A's softball shots cover the bar and sheets.

**2. Offline.**
1. One online load at 1180 (the service worker took over; `kb-shell-v344` was the only cache).
2. Network offline in DevTools, then a reload.
3. Result: signed in, `onLine` false. The menu drew on Home, the roster page drew (list and the pitcher's page, with
   Manage), and Coaches and groups drew (4 rows).

**3. Charting.**
- At 820 (Caleb Okafor) and 1440 (Andre Boateng): Chart → Bullpen → No / No → Start.
- `onChartingScreen()` true, with no menu, no bar and no `has-nav` (`b11-charting-820.png`, `b12-charting-1440.png`). The
  grid was 320px at 820 (as before) and 560px, its cap, at 1440.
- At 1440: 3 pitches, then End session & save. Back on History with the menu, outbox 0, newest session 3 pitches.
- The 820 pen was discarded.

**4. Side by side:**

| Picture | Built | Differences, and why |
|---|---|---|
| `b-sidebar-ipad.png` | `b1-manager-1180-home.png` | Same order, sections and dark surface; Home lit in the accent; the Roster "3 new" badge; Facility · Chat · Coaches and groups; Help; the name row at the bottom. The KNUCKLEBALL wordmark keeps The spot mark beside it (the app's sidebar always has). The team box shows "Team" above the name (today's selector) with the sport under it. The page beside it is today's Home: Stage C builds the dashboard drawn there. |
| `b-remove-sheet.png` | `b4-remove-facility-sheet.png` | Same layout and buttons (Keep on roster, Remove from facility in red). The words use they / them, as the app always has, where the picture says him / his (preconditions mismatch 2). |

**5.**
- `CACHE_VERSION` is `kb-shell-v344`.
- STATUS.md, CLAUDE.md and the policy sentences are in this PR.
- The pre-push checks run at push.

## Stage B checks

**13.** At 820, 1180 and 1440: the menu, with no bottom bar and no tab row (`tabs: 0`, `dock: false`). At 390 the Stage A
bar is unchanged.

**14.**
- Manager's menu: Home, Chart, History, Sessions, Trends, Roster 3 new, Chat, Coaches and groups, Help and getting
  started, the name row.
- Normal-team assistant: no Facility section.
- Each item opens its view: `navGo` home / charts / history / trends / roster / chat / coaches / account all checked.
- Sessions and Trends sit under History, and History stays lit on both.

**15.**
- The roster page has 10 rows and no Remove, Clear or "⋯" (`actionBtns: 0`).
- At 1180 the pitcher's page shows beside the list (`b2-roster-1180.png`).
- At 390 and 820, a row opens the pitcher's page, and ‹ Back returns to the list (`view: roster`).

**16.** The pitcher chip on Chart (`b6-chart-chip-390.png`), and the switch sheet with 10 pitchers (`b7-pick-sheet.png`):
- On Sessions, picking Jalen Whitfield stayed on History.
- On Chart, picking Noah Lindqvist stayed on the chooser, with his last session (Bullpen · Nov 10 · 31 pitches).

**17.** Manage, as the manager at 390, on `Feed Test Pitcher`. They joined the demo facility by the manager's join code
(`join_group_via_token` ok, no email).
1. **Clear "New"** (no question): the row went away.
2. **Move to coach:** Confirm stays disabled until a coach is picked. Marcus Bell → Confirm: now in Marcus Bell's group.
3. **Remove from Marcus Bell's group** (their only group): the sheet said "Removes Feed Test Pitcher from Marcus Bell's
   group. Feed stays at the facility under No coach yet." (`b3-remove-group-sheet.png`). Then:
   - staging: `on_side 1, groups 0, departures 0`;
   - the roster's NO COACH YET section listed them (`b5-no-coach-yet.png`);
   - Manage then offered "Add to coach".
4. **Add to coach** (Jordan Thayer) → Confirm: one group.
5. **Remove from my group** again: they went back to No coach yet.
6. **Remove from facility:** the sheet (`b4-remove-facility-sheet.png`), then confirm. The app returned to the roster,
   and they're off it. Staging: `on_side 0, departures 1`. `rate_limit_events`: one `removal_notice`, and its
   recipient row is the example.com address. That's the one email (Q8); nothing went to a DS1 address. **Correction (Nov 17, Stage D):** Resend refuses example.com recipients (422), so this
   email was attempted and counted but never delivered; the removal itself went ahead, as designed.
- A normal team's head (`u15-sbcoach`, head of "U15 Softball Test") sees only "Remove from this team". Its sheet: "Removes
  U15 from this team's roster and emails them to let them know. Their sessions and stats aren't deleted, only this
  team's view of them." I tapped Keep on roster, so nothing was removed.
- The assistant (`feed-coach`) sees no Manage (the server refuses them anyway).

**18.**
- Account: "Your data" holds Download my data only. A separate **Danger** group at the bottom holds Delete my account
  (`b8-account-danger-390.png`).
- No diff hunk touches `renderA1Delete` (the delete flow's screens), so they are word for word as before.
- The path sentences are updated in the PR, with Joel's approval (preconditions section 6).
- On iPads and computers, Account also shows the profile switcher, Add a player and Sign out, since there's no More
  there (`extras: Baseball ✓, Softball, Add a player, Sign out`).

**Also checked:**
- Switching team keeps the view (History stayed History).
- The 820 rail's "3 new" shows as "3".
- The view-only family's More / Account behave as in Stage A.

## Found and fixed while checking

- The menu's wordmark took the accent color from an old `.brand span` rule; it is now white, as drawn.
- The rail's "3 new" badge covered the Roster icon; the rail now shows the count only.

## Staging test data from this stage

- One 3-pitch bullpen for Andre Boateng (manager, 1440).
- `feed-pitcher-1793899731@example.com`: the throwaway password; joined and then removed from the demo facility (a
  departure row).
