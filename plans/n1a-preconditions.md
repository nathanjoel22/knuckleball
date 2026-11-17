Written against: `f9cce4c` (main after PR #86, production v342). Packet: `plans/n1-navigation-and-home.md`, Stage A.

# N1 Stage A · Names and the phone menu · preconditions (Nov 16, 2026)

**Joel, Nov 16 2026: "go with recommendations and then build"** -- Q1 to Q8 as recommended below.

## 1. What Stage A changes, where it is now

All in `bullpen-tracker.html` unless named. Line numbers are as of `f9cce4c`.

| What | Where now | Stage A |
|---|---|---|
| Phone bar keys | `dockKeys()` 4134 | Coach: home, chart, history, roster, more. Pitcher / parent / teen: home, chart, history, more. View-only family: home, history, more. No chat key. |
| Bar labels | `DOCK_LABELS` 4139 (`Charts`, `Analysis`) | Replaced by one `PLACE_LABELS` object (Home, Chart, History, Sessions, Trends, Roster, More, Pitcher settings, Account). The bar, tabs, headings, aria-labels and titles read it. |
| Bar icons | `DOCK_ICONS` 4114 | `more` added (three lines, as drawn). History's icon becomes the bar chart in the pictures (today a clock turning back). Inline SVG, as now. |
| Which button is lit | `dockActiveIndex()` 4140 | Adds `more` (lit on More, Account and Pitcher settings), `home`. |
| Bar taps | `dockGo()` ~4186 | `home` → `goHome()`; `more` → `setView('more')`; `chat` branch removed (Chat is the icon). Still lands at scroll 0. |
| Chat "coming soon" page | `renderChatView` 13263 | Removed. With no facility there is no way to reach Chat at all (W1 made that true in the store apps on Nov 13; now on the web too). |
| Account menu | `renderAccountButton()` 3695, `toggleAcctMenu` 3682 | On phones and iPads the avatar opens More. On computers the dropdown stays until Stage B. |
| Chat icon | new, beside the avatar in `.acct-row` / `.acct-side` | Only when `chatEnabled()`; the badge = unread + reports (today's dock count, `renderCoachDock` 4148); taps `openChat()`. Offline it still draws from `kb:chatOn:<uid>`. |
| More | new view `state.view = 'more'` | See the picture `a-more-screen.png` and section 3, Q3. A section's first screen: no ‹ Back (`headerBackTarget` 7259). |
| Sign out | `window.signOut` 3855; phone footer 14804 / 14806; sidebar 14825 | New `askSignOut()` opens the sheet (`a-sign-out-sheet.png`); its Sign out calls today's `signOut()`. The phone footer goes. The first-run screens keep their direct Sign out (2503, 3767, 12276, 14733). |
| Tabs (computers) | `renderTabs()` 13329 (`New Session` / `New`, `Player Profile` / `Player`, `Profile`) | Home · Chart · History · Trends · Chat · Pitcher settings (coach) / Account (pitcher). |
| History / Trends tray | `analysisTray()` 12287 (aria label "Analysis") | Tray reads Sessions · Trends; its label is History. |
| Home tiles | `renderHomeTiles()` 13110 (`Charting`, `Profile`) | Labels only: Chart, Account. Stage C replaces the tiles. |
| Coach taps the pitcher's name | `title="Player Profile"` 14908 | "Pitcher settings". |
| Profile page headings | `renderProfileView()` 13768 | Two headed groups, see Q5. No section is rebuilt. |
| Help's way back | `help.html` 76; `css/standalone.css` 34-37 (hidden unless installed) | Shown always; see Q4 for the store apps. |
| Help's names | `help.html` 94, 95, 104, 115 ("Charting"); step 6 "Add a note" | New names; step 6 per Q6. |
| CLAUDE.md | lines 210-212 (Coach dock, Trends, Navigation Nov 5) | The Navigation paragraph rewritten as built; the two above marked history. |

Nothing here touches charting, saving, syncing, reports, the palettes or the database.

**Things in the packet that don't match the repo:**

1. **"Charting" can't all go.** Check 7 says no "Charting" text remains in the UI. Three uses are the charting screen's "Charting perspective" label (5422, 7189, 7196) and one is Chat's offline line, "Charting works offline as always" (13264). Neither is the name of a place, and the charting screen is out of scope. Proposed: check 7 covers place names only, and these four stay.
2. **The store apps open Help in a Safari sheet.** Every page's native link handler (line 29 of the tracker and 16 other pages: 17 in all) sends `help.html` to `Browser.open`. A "‹ Back to Knuckleball" link inside that sheet would load the tracker inside the sheet, where the user isn't signed in. See Q4.
3. **The `a-phone-bar.png` picture shows more than the bar.** It also draws the pitcher chip (Stage B's text), the Chat icon, and a new **Chart chooser**: two dark cards, "BULLPEN · Practice session, pitch by pitch" and "LIVE GAME · Batters, counts and results", under "CHART · WHAT ARE WE CHARTING TODAY?", plus a "Last session" card. Today's chooser (`renderSessionKindChooser` 7235) is a centered title over a two-button tray. The packet's text doesn't mention the chooser. See Q2.
4. **The More picture differs from the packet's sketch.** It shows "Sport: Baseball · Switch" where the packet lists one row per other profile plus "+ Add baseball / softball", and "Getting started · 3 of 5" (Stage D's count). See Q3.

## 2. Recorded decisions this stage changes (Joel approved all of them on Nov 16; quoted here for the record)

| CLAUDE.md now | From Stage A |
|---|---|
| "Bar: coaches Charts · Analysis · Chat (in a facility) · Roster; players, parents and teens Charts · Analysis · Chat ("Soon" outside a facility: a coming-soon page); view-only friends and family Analysis · Profile (`dockKeys()`)." | Coaches Home · Chart · History · Roster · More; players, parents, teens Home · Chart · History · More; view-only family Home · History · More. Chat is an icon at the top right, only in a facility. No coming-soon page. |
| "The KNUCKLEBALL wordmark goes Home (`goHome`); Profile is in the account menu (`acctGoProfile`) and a Home tile; a coach taps the pitcher's name or photo for Player Profile." | The wordmark still goes Home, and Home is also on the bar. Account is on More (and the avatar opens More on phones and iPads). The coach's tap on the name opens **Pitcher settings**. |
| History and Trends share "one button, **Analysis**". | The button is **History**; inside it, **Sessions** and **Trends**. |
| Sign out at the very bottom of every phone page (Nov 5, the `phone-footer`). | A Sign out row on More that asks first. |

The iPad bar keeps today's layout with these keys until Stage B. Computers keep the tab row, renamed, until Stage B.

## 3. Questions for Joel, each with a recommendation

**Q1. Chat on computers before Stage B.** The packet puts Chat in a top-right icon. Computers still have the tab row until Stage B, which has a Chat tab today.
*Recommend:* the icon on every size, and drop the Chat tab, so Chat is in one place everywhere.

**Q2. The Chart chooser in the picture.** Build the new chooser (dark Bullpen / Live Game cards and a "Last session" card) in Stage A, or keep today's?
*Recommend:* build it in Stage A. It's what the approved picture shows, and it changes no logic: the same two choices, Resume as today, and the Last session card from History's data on the device, so it works offline. The pitcher chip stays in Stage B, as the packet says.

**Q3. More's account rows.** The picture shows "Sport: Baseball · Switch". The packet lists every other profile as its own row plus "+ Add a sport". A parent with two players, or a coach with a softball side, has several profiles.
*Recommend:* the packet's version. One row per profile with its sport chip (tap to switch), then "+ Add baseball / softball" when allowed, then "Add a player" when allowed. "Getting started" shows no "3 of 5" until Stage D.

**Q4. Help's way back in the store apps.** In the store apps Help opens in a Safari sheet whose **Done** already goes back, and a Back link there would open the app inside the sheet, signed out.
*Recommend:* open Help inside the app itself (take `help` out of the Safari-sheet list in the 17 pages' link handler), so "‹ Back to Knuckleball" works everywhere: browser tab, home-screen install and store apps. Privacy, Terms, reports and delete-account keep the sheet (device check 15). Help is our own page with no outside links that need the sheet.

**Q5. Profile's two headed groups.** Today the page interleaves the player's settings with the login's (headshot, pitch mix, uniform, level, throws, radar, name, who can see, email, password, your data).
*Recommend:*
- **Pitcher settings:** photo, name, pitch mix, relative accuracy, uniform number, level, throws, radar gun, who can see (for a parent's player).
- **Account:** email, password, your data, and the coach's team admin.

The player's name sits under Pitcher settings because for a parent's player it's the player's name, not the login's. Order inside each group as today. Only headings and order change.

**Q6. Help's coach step 6, "Add a note".** It describes the note box removed on Nov 5. Stage E brings notes back on the recap.
*Recommend:* Stage A removes step 6, and Stage E adds a step in your words. Proposed text for Stage E: "6. Leave a note. When you end a session, write a line under 'Note to the pitcher'. It shows at the top of their report and on their Home." It needs your OK, because help.html is your text.

**Q7. ‹ Back on Account.** On phones, Account and Pitcher settings are opened from More.
*Recommend:* "‹ Back" on Account goes to More, the section's first screen, under the F1-D rule. A coach's Pitcher settings keep today's Back to the roster.

**Q8. The sidebar's Sign out (iPads and computers) before Stage B.** The packet keeps it until Stage B.
*Recommend:* it opens the same sheet. That's one Sign out behavior everywhere, and nobody signs out with sessions unsynced without being told.

## 4. Not drawn

Everything in Stage A is drawn: the bar, More and the Sign out sheet. Two changes have no picture:
- the computers' tab row, which only takes the new names;
- the Account / Pitcher settings headings, which follow `.profile-section h3`.

## 5. How it will be checked

Every check in the packet (1-5 and 6-12), on staging at 390, 820, 1180 and 1440px, baseball and softball, with evidence in `plans/n1a-evidence.md`. Roles:
- the demo facility's manager, a pitching coach and a pitcher (DS1);
- staging `…@example.com` test logins for a parent, view-only family and a normal-team head coach.

The store-app behavior (Chat icon with `isNativeApp()` true, Help in-app per Q4) is checked on Joel's iPhone after merge, as device-check item 18 already expects.
