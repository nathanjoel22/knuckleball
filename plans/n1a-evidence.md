# N1 Stage A · evidence (Nov 16, 2026)

Branch `n1a-names-phone-menu`, cache `kb-shell-v343`. Run on staging (local server with the staging config), in headless
Chrome with device emulation (touch, safe-area insets, display-mode). Screenshots are in `plans/n1a-evidence/`; any
that showed a real email address were left out.

**Logins used:**
- DS1 demo (staging): the facility manager, pitching coach 1, and pitcher 10 (Andre Boateng).
- Staging test logins:
  - `feed-coach-1793899731@example.com`: an assistant on the normal team "Staging Knights";
  - `u15-parent-03123297@example.com`: a parent;
  - `u15-sbcoach-03123297@example.com`: a softball coach with a pitcher.
- Those three were given a throwaway password on staging only. It's listed in STATUS for removal.

## Every-stage checks

**1. Roles and sizes.** Each first screen's bar, read from the page:

| Role | Size | Bar | Chat icon |
|---|---|---|---|
| Facility manager | 440 phone | Home · Chart · History · Roster · More | yes |
| Pitching coach (facility) | 440 | Home · Chart · History · Roster · More | yes |
| Pitcher (facility) | 440 | Home · Chart · History · More | yes |
| Parent (no facility) | 440 | Home · Chart · History · More | no |
| Assistant, normal team | 440 | Home · Chart · History · Roster · More | no |
| Facility manager | 820 iPad | Home · Chart · History · Roster · More | yes (once `chat_summary` loads, as before) |
| Facility manager | 1180 iPad | Home · Chart · History · Roster · More | yes |
| Facility manager | 1440 laptop | no bar; tabs HOME · CHART · SESSIONS · TRENDS · PITCHER SETTINGS | yes |

Softball: `u15-sbcoach` and the manager's softball side. The bar, chooser, More and Sign out sheet all use the softball
tokens (`e-390-*-softball.png`), with no baseball color left.

**View-only family: not run.** Staging has no family login left; the F1-G ones were removed on Nov 1. Making one means a
new parent login and a player link, which sends a verification email. The code path: `dockKeys()` returns home,
history, more for `viewOnlyLinked()`, and More draws no Team rows for that role (`canAddPlayer()` false for a linked
login). Joel to check on a real family link, or I make a staging one if he OKs one test email.

**2. Offline.**
1. One online load, then the service worker took over (`kb-shell-v343` the only cache).
2. Network set to offline in DevTools, then a reload.
3. Result: signed in, `navigator.onLine` false, the bar drew, and More drew (10 rows). The Sign out sheet drew, and the
   Chart chooser drew (2 cards). The Chat icon still showed (`kb:chatOn`).
4. The chooser's "Last session" card is absent offline for a pitcher the coach only auto-selected. That's correct: by
   design, History is kept offline only for pitchers the coach has opened (SC1-B). It shows for opened pitchers.

**3. Charting.** As the manager, for Andre Boateng (staging):
- Chart → Bullpen → No / No → Start bullpen.
- While charting, the page reported `onChartingScreen()` true, no bar, no Chat icon, no More and no sheet.
- 3 pitches, then End session & save.
- Back on History with the bar showing, outbox 0. The session is on staging, sealed, with 3 pitches (query below).
- A second pen, charted offline, was saved to the outbox and synced after signing back in (check 10).

```
started_at 2026-11-17 03:13:39 · sealed true · 3 pitches
started_at 2026-11-17 03:15:59 · sealed true · 3 pitches
```

**4. Side by side with the pictures** (390px, `plans/n1a-evidence/`):

| Picture | Built | Differences, and why |
|---|---|---|
| `a-phone-bar.png` | `e-390-chart-baseball.png` | The pitcher chip isn't there: it's Stage B (packet text). Today's banner, team line and roster bar still sit above the page; they go in Stage B. The question reads "What will we be charting today?", the app's existing words, not the picture's "What are we…". The bar's highlight is today's sliding pill. Same order, same dark cards, display type for BULLPEN / LIVE GAME, small-caps labels, Last session card. |
| `a-more-screen.png` | `e-390-more-baseball.png` | Account rows: one row per profile and "+ Add softball", not "Sport: Baseball · Switch" (Joel, Q3). The login's email sits under the account row (the old menu showed it). "Getting started" has no "3 of 5" until Stage D. Same groups, order, heading type and Sign out card in red. |
| `a-sign-out-sheet.png` | `e-390-signout-baseball.png` | Matches: display title, the name in bold, Stay signed in (light), Sign out (filled red). The unsynced line appears with an outbox item (check 10). |

**5.** `CACHE_VERSION` is `kb-shell-v343`. STATUS.md and CLAUDE.md are updated in this PR. The pre-push checks ran
before the push (output in the PR).

## Stage A checks

**6.**
- Every role's bar matches the packet's table (check 1).
- Every bar tap lands at scroll 0 (`scrollY` 0 after More, History, Chart).
- History stays lit on Sessions and Trends: `view history → lit History`, `view trends → lit History`.
- The tray reads "History: Sessions · Trends".

**7.** Grep of the tracker and help.html for Charts / Charting / New Session / Analysis / Player Profile in on-screen
text. What's left:
- code comments;
- "Charting perspective" on the charting screen (out of scope; preconditions item 1);
- "Charting works offline as always" (Chat's offline line);
- "Charting works the same as for a coach" (a sentence in Help, not a place name).

**8.** Every item of the old account menu is on More:
- the email (under the account row);
- switching profile (one row per profile, ✓ on the active one);
- Account ("<name> · <role>" row);
- + Add a sport;
- + Add a player;
- the menu's message line (`acctMsg`);
- Help & getting started (Getting started, Help and support).

Rows checked per role:

| Role | More rows |
|---|---|
| Manager | account, Baseball ✓, Softball, Add a player, Join codes and invite links, Team settings, Getting started, Help and support, Privacy · Terms, Sign out |
| Pitcher | account, + Add softball, Add a player, Getting started, Help and support, Privacy · Terms, Sign out |
| Parent | account, Add a player, Help rows, Sign out |
| Assistant (normal team) | account, + Add softball, Add a player, Team settings, Help rows, Sign out |

- "Join codes and invite links" opens Account at the join codes / invite links; "Team settings" opens it at the team name.
- The invite row shows only where there's something there: a facility side's coaches, or a team's head. Found and fixed
  during the run: it first showed for an assistant, who has no links.
- Computers keep the dropdown (Joel, B later), checked at 1440.

**9.** The Chat icon shows, with the badge when there's a count, for the manager and a facility pitcher. It's absent for
the normal-team assistant and the parent. With `window.Capacitor.isNativePlatform()` stubbed true, the same results (bar
and icon unchanged in the "app").

**10.** Sign out:
- The sheet says "You're signed in as Jordan Thayer." Stay signed in closes it: still signed in, still on More.
- With one pen in the outbox (charted offline), the sheet said: "You're signed in as Jordan Thayer. 1 session saved on
  this phone hasn't synced yet. It stays here and syncs when you sign back in."
- Signed out (offline), went online, signed back in: outbox 0, and the session is on staging, sealed, 3 pitches.

**11.** `help.html` in a plain browser tab (1440, `display-mode: browser`): "‹ Back to Knuckleball" shows (44px high). It
returns to `bullpen-tracker.html`, still signed in. The store apps no longer send Help to the Safari sheet (all 17 pages'
handlers). On a real iPhone this is checked after merge.

**12.** Every view scrolled to the end at 440px (pitcher: home, chart, history, trends, more, account; manager: the same
plus pitcher settings) and at iPad 820. On the phone the last control (the footer's Privacy link) ends at 820px and
the bar starts at 850; on the iPad they end by 1058px and the bar starts at 1088. Nothing is under the bar.

## Found and fixed while checking

- The Sign out sheet first sat mid-screen: `.modal-overlay` comes later in the stylesheet and overrode the sheet
  alignment. It now has its own two-class rule.
- The More invite row showed for an assistant with nothing to show (see check 8).

## Staging test data left

- Two 3-pitch bullpens for Andre Boateng (DS1 demo, Nov 17 03:13 and 03:15 UTC), charted by the manager.
- The throwaway staging password on `feed-coach-1793899731`, `u15-parent-03123297` and `u15-sbcoach-03123297`
  `@example.com`.
