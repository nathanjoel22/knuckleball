Written against: STATUS 2026-11-13 (W1 App Store: no placeholders in the app; privacy host line), production v342

# N1 · Navigation, Home and the enhancements (Nov 16, 2026)

**From Jordan + Claude, after the Nov 15 review with Joel.** Joel asked for everything in the two proposals to be
built. The agreed design, with a drawing of every screen, is the page **Knuckleball App Navigation**
(https://claude.ai/artifact/9c6e7A3Kj2SYACz3KpzHqx; Jordan shares it with Joel). This packet is that page as build
instructions.

**The look is in the repo:** `docs/n1/` holds a picture of every drawn screen, and
`plans/n1-design-reference.md` gives the values behind them (color roles as app tokens, type, the styling of the
line score, recap and pitcher card, the recap's motion). Open the pictures for a stage before building it. The
text layouts in section 3 show structure only; the pictures are the approved look.

Seven stages, A to G. **Each stage is its own branch, its own preconditions report, its own PR and its own cache
bump, and reaches staging before Joel ships it. A stage starts only after the one before it is on production.**
Stages A to F are front end only, except one database function changed in Stage B (J3). Stage G is the only one
with new tables or columns.

Code facts below were read at `6d6c959` (v342). Line numbers are for finding the place, not a promise; each
preconditions report confirms them.

## 1. Goal

Make the app easy to get around and worth opening:

- one menu with one name per place, on phones (bottom bar + More) and on iPads and computers (a sidebar);
- a Home that shows information per role in place of four launcher tiles;
- risky buttons moved away from everyday ones;
- a getting-started card on first login;
- seven enhancements that put baseball on the screen: zone pictures on sessions, a weekly line score, a pitcher
  card, a recap when a session ends, milestones, the coach's note on Home, a facility's own name and colors.

## 2. Decisions already made (don't re-open; flag if the repo contradicts one)

**Joel, Nov 15 (with Jordan):**

1. Build all six navigation recommendations and all seven enhancements.
2. The facility leaderboard is planned but **not** in N1. `hasLeaderboard` stays `false`; `renderLeaderboardView`
   stays untouched.
3. The open questions on the design page are built at their **starting points** and reviewed by Joel and Jordan
   once the features are in the app. Each must be one constant or one list, so a later change is small:

   | Question | Built as | Where it lives |
   |---|---|---|
   | Days without throwing before a pitcher is flagged | 5 | one constant, `IDLE_FLAG_DAYS` |
   | The number that leads a pitcher's Home | 7-day pitch count, as the week's line score | Stage C |
   | Names of the main places | Home, Chart, History (Sessions and Trends inside), Roster, More | one labels object |
   | Where Chat lives on a phone | an icon at the top right with the unread count | Stage A |
   | Facility owner's getting-started steps | the five in Stage D | the steps list |
   | What makes a week count toward a run | at least one charted session that week | one constant |
   | Which milestones are celebrated | the list in Stage F | the milestones list |

**These recorded decisions in CLAUDE.md change. Joel agreed to the design on Nov 15; each stage's preconditions
report restates the ones it touches so he confirms them in writing before code:**

4. "Navigation (Joel, Nov 5 2026, v331)":
   - Home returns to the phone bar (the wordmark keeps going Home);
   - iPads lose the bottom bar and computers lose the tab row, both for a sidebar;
   - "Analysis" becomes **History**, "Charts" becomes **Chart**;
   - Chat leaves the bar for a top-right icon. The web's "Chat is coming soon" page for players outside a
     facility goes away with it, so the bar is the same on the website and in the store apps.
5. "A coach's open roster list stands alone" (v336) and the Roster toggle bar: retired in Stage B, when the roster
   becomes a page.
6. Sign out "at the very bottom of the page" on phones (Nov 5): replaced in Stage A by a Sign out row on More that
   asks first.

**Kept, unchanged:**

7. One "‹ Back", never browser history, never on the charting screen, never on a section's first screen.
8. No bar and no sidebar on the charting screen; the bar hides while a typing field has focus; every bar tap lands
   at the very top of the page.
9. Charting never needs the network. Home, the menus, the recap, milestones and the line score must draw with no
   signal from what the device already holds.
10. No build step, no new dependency, nothing loaded from another host, icons as inline SVG.
11. Frozen reports, the pitch palettes (three places) and `ZONE_NAMES` are untouched.
12. Colors only through `css/tokens.css` variables, so both sports keep working. 44px minimum tap targets.
    Animations respect `prefers-reduced-motion`.
13. Every plot stays in the pitcher's view (Amendment 16).

**Joel's answers (Nov 16, 2026):**

- **J1, the coach's note: Jordan's proposal.** One optional line, "Note to the pitcher", on the Stage E recap,
  saved to `session_notes`. On a normal team the insert rule on `session_notes` already allows it. On a facility team
  it needs a server change (`is_coach_of_session` refuses facility teams): still Joel's call, asked in Stage E's
  preconditions; until he says yes, the line isn't drawn for facility sessions. Home's note card (Stage C) shows the
  newest note. This reverses "No new coaches' notes" (History is a feed, Nov 5); Stage E updates CLAUDE.md.
- **J2, who may share a pitcher card: option A.** An adult pitcher shares their own card. For a player under 18, only
  the parent or guardian on the account: the parent login the player sits on, or a linked `guardian` (F1-G). A teen
  who signed up with their own login has no parent login in the app, so no one gets Share for them. A coach never
  does. Anyone can still take a screenshot; this is only about the Share button.
- **J3, removing a pitcher from a facility coach: they stay on the facility.** A player can exist without a coach.
  Removing a pitcher from their only coach group leaves them on the facility under the roster's existing **"No coach
  yet"**, for the manager to give a new coach or remove from the facility on purpose. No email for that (they are
  still on the facility). **Removing from the facility sends the removal email**, as it does today. This changes
  `remove_from_group` (Stage B).

## 3. The work

Sizes seen in the drawings: phone 390px, iPad upright 820px, iPad wide 1180px, laptop 1440px.

Each stage names its pictures in `docs/n1/`. Read the matching section of `plans/n1-design-reference.md` with them.

### Stage A · Names and the phone menu (size M, front end only)

Pictures: `a-phone-bar.png`, `a-more-screen.png`, `a-sign-out-sheet.png`.

**Names.** One labels object feeds the bar, the sidebar (Stage B), page headings and `help.html`:

| Place | Today | From now on |
|---|---|---|
| Landing screen after login | reached by the wordmark only | **Home** |
| Starting a bullpen or a game | Charts, Charting, New Session, New | **Chart** ("Resume" stays as a note on it when a draft exists) |
| Past sessions and reports | Analysis, History | **History** (its first view is **Sessions**) |
| Progress over time | Analysis, Trends | **Trends**, inside History |
| The list of pitchers | Roster | **Roster** |
| The selected pitcher's setup | Profile, Player Profile, the gear, tapping the name | **Pitcher settings** |
| Your own login, team and data | Profile | **Account** |

A pitcher's own page holds both kinds of thing today. Keep it one page with two headed groups, "Pitcher settings"
(pitch mix, throws, level, radar, relative accuracy, contacts) and "Account" (name, email, password, your data).
No section is rebuilt; this is headings, labels, aria-labels and titles.

**Phone bar** (`dockKeys()`, `DOCK_LABELS`, `DOCK_ICONS`, `dockGo`, `dockActiveIndex`), at ≤500px:

```
 coach, facility owner      Home · Chart · History · Roster · More
 pitcher, parent, teen      Home · Chart · History · More
 view-only family           Home · History · More
```

- Home → `goHome()`. History stays lit on Sessions and Trends. Roster behaves as today until Stage B.
- iPads keep today's bar until Stage B, with the new keys and labels.
- On computers, the tab row keeps working until Stage B with the new names.

**More** is a new view (`state.view = 'more'`), a section's first screen (no Back):

```
 MORE
 ┌ YOUR ACCOUNT ─────────────────────────────┐
 │ <name> · <role>                         › │  → Account
 │ one row per other profile (sport chip)  › │  → switchProfile(id)
 │ + Add baseball / + Add softball           │  as sportsToAdd() allows
 ├ TEAM ─────────────────────────────────────┤
 │ Add a player                            › │  canAddPlayer() only
 │ Join codes and invite links             › │  coaches: that part of Account
 │ Team settings                           › │  coaches: team admin in Account
 ├ HELP ─────────────────────────────────────┤
 │ Getting started                         › │  help.html until Stage D
 │ Help and support                        › │  help.html
 │ Privacy · Terms                         › │
 └───────────────────────────────────────────┘
 ┌ Sign out                                › ┐
 └───────────────────────────────────────────┘
```

- Every item in today's account menu (`renderAccountButton`) appears on More. The avatar button stays at the top
  right and opens More on phones.
- Rows a role can't use are not drawn.

**Chat.** An icon at the top right, left of the avatar, only when `chatEnabled()`. It carries the badge the bar
shows today (unread + reports) and calls `openChat()`. `kb:chatOn:<uid>` keeps it right offline.

**Sign out asks first.** Sign out on More opens a sheet:

```
 Sign out?
 You're signed in as <name>.
 [only if the outbox holds sessions]  N session(s) saved on this phone haven't synced yet.
                                      They stay here and sync when you sign back in.
 [ Stay signed in ]   [ Sign out ]
```

- That sentence matches the code: `signOut` does not clear `outbox:<uid>` or drafts, and only the same login
  drains them.
- The phone footer's Sign out goes away (decision 6). The sidebar's Sign out stays until Stage B.
- The first-run screens keep their own Sign out buttons (terms notice, Add your player, account setup, No player
  here, No team yet).

**Help has a way back.** `help.html` shows "‹ Back to Knuckleball" always, not only when installed
(`css/standalone.css` hides it otherwise). Its text takes the new names. Its Coach step 6, "Add a note", describes
a box that was removed on Nov 5: report it to Joel with J1; don't rewrite it without his wording.

**The bar never covers content.** Check every view at 390px, scrolled to the end, with the bar on. Fix any view
whose last control sits under it (Home's lower tiles do today, until scrolled).

**CLAUDE.md.** In the same PR, replace the "Navigation (Joel, Nov 5 2026 ...)" paragraph with the rules as built,
and mark the two paragraphs above it (Coach dock, Trends) as history. Stage B does the same for what it changes.

### Stage B · Sidebar and roster (size L, front end + one database function, J3)

Pictures: `b-sidebar-ipad.png`, `b-remove-sheet.png`. Not drawn: the icon rail, the roster page, the pitcher's
page and Manage; sketch them in preconditions in the same style.

**Sidebar.** At ≥501px the left column becomes the menu. It replaces the bottom bar on iPads and the tab row on
computers, so `dockDevice()` narrows to phone width and `renderTabs` retires.

```
 ┌──────────────────────┐
 │ KNUCKLEBALL          │  wordmark → Home
 │ ┌ <team / facility> ▾│  team switcher (onTeamChange) and the sport
 │ └ <sport>            │
 │ ▣ Home               │
 │ ▣ Chart              │
 │ ▣ History          ▾ │  opens to show:
 │     Sessions         │
 │     Trends           │
 │ ▣ Roster     [3 new] │  coaches only; the count is facilityNewCount()
 │ FACILITY             │  section only when chatEnabled() / a facility
 │ ▣ Chat           [2] │
 │ ▣ Coaches and groups │  manager only
 │ ──────────────────── │
 │ ▣ Help and getting started
 │ (JT) <name>        ▸ │  opens Account; Sign out lives inside, with the Stage A sheet
 └──────────────────────┘
```

- **501 to 860px (iPad upright):** the sidebar is an icon rail that opens to full width on tap. This width was not
  drawn; the preconditions report shows a sketch of the rail for Joel before code.
- **Above 860px:** the full sidebar, 280px as today.
- The offline pill and the outbox badge keep a place in the sidebar.
- Not drawn on the charting screen (as today's `phoneSessionMode` and `onChartingScreen` rules).

**Roster is a page** (`state.view = 'roster'`):

- Above 860px: the list on the left, the selected pitcher's page on the right. Narrower: the list fills the
  screen and a pitcher opens as their own page, with "‹ Back" to the list.
- A row shows what it shows today (number, name, LHP/RHP, pitch chips, the new-session dot, the "New" tag, the
  workload line from `pitcher_workload`). Tapping a row opens the pitcher's page. **No Remove, Clear or "⋯" on
  rows.**
- Facility managers keep the per-coach sections and "No coach yet".
- The pitcher's page: header (Stage F turns it into the card), recent sessions, **Pitcher settings**, then
  **Manage** at the bottom.
- `rosterOnly`, the Roster toggle bar and `rosterCollapsed` retire (decision 5).

**Pitcher chip.** On Chart and History for a coach, a chip with the selected pitcher's photo or initials and name.
Tapping it opens the switch sheet (the `renderSwitchSheet` pattern) to pick another pitcher without leaving the
view. A parent with several players gets the same chip, listing their players (`switchProfile`).

**Where you land.** Picking a pitcher on Roster opens the pitcher's page. Switching with the chip keeps the
current view. Switching team keeps the current view. Report in preconditions where today's rules differ
(`selectPitcher` lands on Home or History; team switch lands on History).

**Manage** (inside the pitcher's page, under its own heading):

| Action | Who | Today | N1 |
|---|---|---|---|
| Clear "New" | manager, own coach | button under the row | on the page; no question needed |
| Move to coach / Add to coach | manager | a select that fires on change | pick the coach, then **Confirm** |
| Remove from this coach / my group | manager, own coach | **no question, no email** | a sheet, see below; the pitcher stays on the facility (J3) |
| Remove from facility / from this team | manager / head coach | inline confirm | the same words, in a sheet |

- "Remove from this coach" is the real gap today: `remove_from_group` also deletes the `pitcher_teams` row when
  that was the pitcher's last group, so one tap takes a pitcher off the facility. **J3 fixes it:** a migration
  changes `remove_from_group` so it only removes the group row; a pitcher with no group stays on the facility and is
  listed under "No coach yet". It still returns `left_side` (now always false) so cached apps don't break. Write the
  down script in `supabase/rollback/` and update `supabase/tests/f1a_acceptance.sql` (it may assert the old
  behavior). The preconditions report carries the migration, rollback and test for Joel's yes; backup before
  production, as for any schema change.
- The sheet says: "Removes <name> from <coach>'s group." and, when it is the only group, "<name> stays at the
  facility under No coach yet." No email.
- Team and facility removal keep today's sentence: "Removes <name> from this team's roster and emails them to let
  them know. Their sessions and stats aren't deleted -- only this team's view of them."

**Account.** "Delete my account" moves out of the row it shares with "Download my data", into its own "Danger"
group at the bottom of Account. The typed DELETE, the 7-day wait and every word of the delete flow stay as they
are. The path printed in `delete-account.html`, `help.html#data` and the terms notice ("Profile → Your data →
Delete my account") must still be true or be updated; those pages are Joel's text, so show him the new path
sentence in preconditions.

### Stage C · Home dashboards (size L, front end only unless preconditions say otherwise)

Pictures: `c-home-pitcher.png`, `c-home-parent.png`, `c-home-coach.png`, `c-line-score.png`, and the owner's Home
in `b-sidebar-ipad.png`.

`renderHomeTiles` gives way to a Home per role. Each card leads somewhere.

**The line score** (one component, used for one pitcher and for a roster):

```
 THIS WEEK · PITCHES                 NOV 8 TO 14
  S    M    T    W    T    F    S       P    S
 [37] [31] [ 0] [ 0] [ 0] [ 0] [ –]   [68] [ 2]     P pitches · S sessions

 PITCHER      S   M   T   W   T   F   S     P
 Lindqvist   37  31   0   0   0   0   –    68       one row per pitcher (coach, owner)
 Boateng     28   0   0   0   0   0   –    28
```

- Sunday to Saturday in the device's time. Today's box is outlined and shows "–" until a session is charted.
  Days with pitches are in the accent color. Dark scoreboard surface from the brand tokens.
- Sessions waiting in the outbox count.

**Pitcher, teen:** line score → "Chart today" → coach's note (when one exists) → last session (zone picture,
date, pitches, accuracy, pitch chips, "Open report") → Trends link.

**Parent:** the player chip → one sentence ("<Name> threw 68 pitches in 2 sessions this week.") with the line
score → coach's note → latest report → earlier sessions. View-only family: the same without Chart.

**Coach:** three numbers (active pitchers "2 of 5", sessions, pitches this week) → "Start a session" → the line
score with one row per pitcher → "Needs your attention" → recent sessions.

**Facility owner:** the coach's Home across every coach, plus "By coach" (active of total per coach). A pitching
coach sees their own group only; the server already decides that (`coach_sees_pitcher`).

**Needs your attention** rows, each opening the thing it names:

- new pitchers to welcome (`flagged_new`, facility);
- pitchers with no session in `IDLE_FLAG_DAYS` (5) or more, longest first, from `pitcher_workload.last_at`;
- unread chat messages.

**Data.** `pitcher_workload` gives last session and 7-day sums but not a count per day. The preconditions report
proposes how the roster line score gets its per-day counts and Joel picks:

- (a) a direct read of `session_stats` (pitcher_id, started_at, pitch_count) for the roster for the week, under
  the existing read rule, no migration; or
- (b) a new function, which is a migration.

Prefer (a). Whatever is read is kept with `lastKnownContext` so Home draws offline, with the time it was read.
A pitcher's own Home needs nothing new: History's data is already on the device.

**Coach's note (J1).** The newest note on the pitcher's sessions (`session_notes`, already loaded with History), as a
card: "Coach <name> · <date>", the text, "Open the session". Nothing is drawn when there is none or on a facility
team. Confirm in preconditions that a parent's login can read the note; if the rule doesn't allow it, stop and
report (no RLS change without Joel). Writing is the Stage E recap line (J1).

**Zone picture on the last session** uses `renderHistoryPlot` (small), not a new drawing.

### Stage D · Getting-started card (size M, front end only)

Picture: `d-getting-started.png`.

A card at the top of Home: title, "3 of 5", a progress bar, the steps, "Hide". Hidden, it stays reachable from
More → "Getting started". It never blocks anything.

- The steps are **data**: one list per role, each step `{ id, label, hint, go, done(state) }`. Adding a step or a
  feature highlight later is one entry. `done` is worked out from what the app already knows, not stored, where
  that is possible.
- Hidden / seen state is per login on the device (`kb:` key), no database change.

| Role | Steps |
|---|---|
| Coach | Name your team and set level of play · Share your join code or invite link · Chart a bullpen · Send a report · Chart a live game |
| Pitcher | Join your coach or go solo · Set your pitch mix and throwing hand · Chart a bullpen · Read your report · See who can view your charts |
| Parent | Add your player · Join the team with the coach's link · Approve the guardian email if your player is 13 to 17 · Open the latest report |
| Facility owner | Add your coaches · Share the join codes · Set up groups · Look over the facility view · Chart a first session |

The coach, pitcher and parent steps follow `help.html`. The facility owner's are a starting point (decision 3);
`help.html` has no owner section and N1 doesn't add one.

The app already has a coach Welcome modal, a pitcher setup modal and a setup reminder banner. The preconditions
report lists where they repeat a step on the card and proposes what to keep; Joel decides. Don't remove them
unasked.

### Stage E · Zone pictures in History and the recap (size M, front end only)

Pictures: `e-history-zones.png`, `e-zone-large.png`, `e-recap.png`.

**History.** Each session's bar gets a small zone picture at its left: a 5×5 heat map from `session_stats.cells`
(darker = more pitches), pitcher's view, the 3×3 zone outlined. It needs no pitch rows, so it draws for every
session in the list and offline. Whether bars then start closed is Joel's question in preconditions; the default
stays open as today (Nov 5).

**Recap.** After "End session & save", one screen before History:

```
 [FINAL · BULLPEN]                    Nov 10 · 4:42 PM
 NOAH LINDQVIST
 ┌ 31 ────┐ ┌ 58% ────┐ ┌ 79 ─────┐
 │ PITCHES│ │ ACCURACY│ │ TOP VELO│      top velo only when the session used a radar gun
 └────────┘ └─────────┘ └─────────┘      games: the game line (IP, K, BB, H) in place of accuracy
 [zone plot, dots by type]   4SFB 18 · 67%
                             CH    8 · 50%
                             CB    5 · 40%
                             Best fastball accuracy in 5 sessions     ← only when true
 [ Send report ]
 [ View report ]
   Done
```

- Drawn from the session just saved, on the device, with no network. `endSession` still never waits on anything.
- Dark broadcast surface; the label slides in and the three numbers count up over about half a second; still
  under reduced motion.
- **Done** goes to History, as today. **View report** goes to that session in History. **Send report** follows
  today's rules exactly: a session that hasn't synced has no report yet ("Available once this session has
  synced."), so the button says so and takes the user to the session in History. No new send path.
- The callout line has two rules in v1, both computed from sessions on the device: best accuracy for a pitch type
  in the last 5 sessions, and a new top velocity. Otherwise the line is absent.
- Switching pitcher mid-game with "save" (`doSwitchPitcher`) skips the recap.
- **Note to the pitcher (J1):** an optional one-line box above Send report, for a coach charting a pitcher on a
  normal team (facility teams only if Joel says yes in Stage E's preconditions). It is saved to `session_notes` once
  the session has synced (kept on the device until then; the preconditions say how), so the recap never waits on
  the network.

### Stage F · Pitcher card and milestones (size M, front end only)

Pictures: `f-pitcher-card.png`, `f-milestones.png`.

**Card.** The header of the pitcher's page (Stage B), and of a pitcher's own Account:

```
 ┌─────────────────────────────┐
 │  21 (large, faint)    [RHP] │  photo when there is one, else initials
 │  TAYLOR PITCHING LAB · 2026 │  the team or facility name
 │ ANDRE BOATENG               │
 │ [4SFB] [CU] [SL] [CH]       │  the pitcher's own colors (colorForType)
 │  14       412     81    56% │
 │ SESSIONS PITCHES TOP VELO ACCURACY
 │ KNUCKLEBALL   knuckleballonline.com
 └─────────────────────────────┘
```

- Totals come from the sessions the viewer can already read (History's data); say "since <first date>" when that
  is not a calendar year. Top velo only when there are readings.
- **Share (J2, option A):** draws the card to a canvas by hand (no library) and hands a PNG to the share sheet: the
  Capacitor Share plugin in the store apps, `navigator.share` with a file where the browser supports it, otherwise
  a download. The button is drawn only for the people J2 allows: an adult pitcher on their own card, and for a
  player under 18 the parent login the player sits on or a linked guardian.

**Milestones.** One list, each `{ id, label, test(sessions) }`, worked out on the device from History's data:

- pitches charted: 100, 500, 1,000, then every 1,000;
- sessions: 10th, 25th, 50th;
- a new top velocity (radar sessions only);
- the weekly run: consecutive Sunday-to-Saturday weeks with at least one session. Rest days are shown in green
  and never break a run; only a whole week with no session does.

A banner on Home for 7 days after one is earned (dismissable, remembered per device), and a "Recent" list on the
pitcher's page. Nothing is stored on the server. Wording never tells a pitcher to throw more.

### Stage G · Facility name and colors (size L, database + front end)

Pictures: `g-sidebar-standard.png`, `g-sidebar-facility.png`. Not drawn: the logo and color picker.

This is T1 ("team branding: moved to later", STATUS) for facilities. **It changes the database, so the
preconditions report carries the full migration, the rollback and the RLS for Joel to approve before anything
runs** (CLAUDE.md: no RLS change, no schema deploy without asking).

- The manager uploads a logo and picks two colors (brand and accent) in Account. Proposed storage: columns on
  `organizations` and a small image bucket with manager-only writes, readable by the facility's members.
- Members see: the logo and facility name in the sidebar and the phone's top bar with "Powered by Knuckleball"
  under it; the two colors on the brand, dock and accent tokens; the same on pitcher cards.
- Colors are applied by setting the token variables the softball theme already overrides (`--brand-bg`,
  `--brand-bg-deep`, `--brand-bg-2`, `--accent` and the ones derived from them, `--dock-bg`). Text colors on top
  are picked for contrast (`readableTextOn`); a pair that can't reach 4.5:1 for text is refused with a plain
  message at the picker.
- **A facility may not change:** the pitch palettes, frozen reports, the Live Game field, emails, the Knuckleball
  wordmark and "Powered by".
- The theme is kept on the device with the last known context so it paints offline and before load, like
  `kb:sport`.
- An archived facility's branding isn't applied (`plans/p1-09`).

## 4. Out of scope

- The leaderboard, in any form.
- Home-screen widgets and notifications (they live in the `knuckleball-app` shell).
- A practice bullpen with sample data.
- Any change to the charting screen, the session sheet, Live Game, voice, or how sessions save and sync.
- Any change to reports, the report page, emails or the three palettes.
- Team (non-facility) branding.
- `privacy.html` and `terms.html` wording. `help.html` beyond names, the Back link and what a stage names.
- Automated click-through tests (Jordan is researching tools separately). Checks here are click paths.
- New notes on facility teams, unless Joel says so in J1.
- Rebuilding Profile's sections; N1 moves and renames, it doesn't redesign them.

## 5. Escalate if

- A stage can't keep a "Kept" decision (7 to 13) as written.
- Home, More, the recap or the line score would need the network to draw.
- A view can't be reached, or reached back from, without the browser's Back.
- Any stage before G turns out to need a migration, an RLS change or a new function, beyond Stage B's
  `remove_from_group` change (J3) and, if Joel says yes in Stage E, facility notes (J1).
- A parent's login can't read the coach's note under today's rules.
- Moving "Delete my account" would make any sentence in `delete-account.html`, `help.html` or the terms notice
  untrue.
- The iPad rail (501 to 860px) can't hold the menu without covering content.
- A facility color pair breaks the softball theme or any text's contrast.
- Anything here contradicts the repo as it is when the stage starts. Stop and report; don't improvise.

## 6. Acceptance checks — all must pass, each with evidence (command output, query result or click path)

**Every stage:**

1. Staging, local server, at 390, 820, 1180 and 1440px, baseball and softball. Roles: the demo facility's
   manager, a pitching coach and a pitcher (`tools/seed-demo`); the demo has no parent, view-only family or
   normal-team head coach, so use staging test logins for those (`…@example.com`, as earlier packets did, listed
   in STATUS for later removal). Screenshot of each role's first screen.
2. Airplane mode after one online load: every screen the stage adds still draws.
3. Start a bullpen and a Live Game: no bar, no sidebar, no new element on the charting screen; a session saves and
   syncs as before.
4. **Side by side with the picture.** For each picture the stage names, a staging screenshot of the built screen
   at 390px (iPad pictures at 1180px) beside the picture from `docs/n1/`, both in the evidence file, with a list of
   every visible difference and why it is there. Same order, same dark and light surfaces, same type roles, same
   color roles. A softball screenshot of the same screen shows the softball tokens, with no baseball color left.
5. `CACHE_VERSION` bumped; pre-push checks pass; STATUS.md entry in the same PR; CLAUDE.md updated where the stage
   changed a rule.

**Stage A:**

6. Each role's bar matches the table. Every bar tap lands at scroll 0. History is lit on Sessions and Trends.
7. No "Charts", "Charting", "New Session", "Analysis" or "Player Profile" text remains in the tracker's UI or
   `help.html` (grep output), apart from code identifiers.
8. Every item of the old account menu is reachable from More, per role (click path for each).
9. Chat icon: shown with the right count for the manager and a facility pitcher; absent for a normal-team coach
   and for a pitcher outside a facility, on the web and with `isNativeApp()` true.
10. Sign out: the sheet names the login; with one unsynced session in the outbox it shows the unsynced line;
   "Stay signed in" does nothing; after signing out and back in, that session syncs.
11. `help.html` opened from More shows "‹ Back to Knuckleball" in a plain browser tab and returns to the app.
12. At 390px no view's last control is under the bar (screenshot of each view scrolled to the end).

**Stage B:**

13. At 820, 1180 and 1440px there is a sidebar and no bottom bar or tab row; at 390px the Stage A bar is unchanged.
14. Every sidebar item opens its place for each role; History opens Sessions and Trends; the manager sees
    Facility items, a normal coach doesn't.
15. Roster: no Remove, Clear or "⋯" on any row. A row opens the pitcher's page; Back returns to the list.
16. The chip switches pitcher on Chart and on History without leaving the view.
17. Manage, on staging with demo pitchers: Clear "New"; Move with Confirm; Remove from a coach when the pitcher
    has two groups (stays in the other); Remove from a coach when it is the only group (the sheet says they stay;
    afterwards `pitcher_teams` still has the row, they show under "No coach yet", no email sent; query shown);
    Remove from facility (email function called once). The updated `f1a_acceptance.sql` passes on staging.
18. "Delete my account" is in its own group, not beside "Download my data"; the delete flow's two screens are
    word for word as before; the path sentence in the three pages is true.

**Stage C:**

19. Each role's Home matches section 3. Line score totals equal History's counts for the same week (numbers
    shown side by side).
20. A pitcher with no session for 5 days is listed under "Needs your attention"; one at 4 days is not.
21. A pitching coach's Home shows only their group; the manager's shows all (compare with the roster).
22. A session saved offline appears in the line score before it syncs.
23. The coach's note shows on a normal team where a note exists, for the pitcher and (if the rule allows) the
    parent; nothing on a facility team.

**Stage D:**

24. A new login of each role sees its list; each step ticks when done by really doing it; "Hide" hides it; More →
    Getting started brings it back.
25. Adding a sixth step to one role is a one-entry change (the diff shown).

**Stage E:**

26. Every History bar has a picture; a session's picture matches its report's first plot (same cells, pitcher's
    view), for a RHP and a LHP.
27. Ending a bullpen and a game shows the recap offline; its numbers equal the History card's; Done, View report
    and Send report go where section 3 says, synced and unsynced.
28. With reduced motion on, nothing moves.

**Stage F:**

29. The card's totals equal Trends' totals for the same pitcher. No "Top velo" for a pitcher with no readings.
30. Each milestone fires once on the session that earns it, using a seeded pitcher; a week with no session ends
    a run, rest days inside a week don't.
31. The Share PNG matches the card. Share shows for an adult pitcher's own card and for a parent's or linked
    guardian's player under 18; it is absent for coaches, view-only family and a teen's own login.

**Stage G:**

32. Migration and rollback run on staging; the RLS test shows a pitching coach and a pitcher can read and cannot
    write the facility's branding, and another facility's manager can do neither.
33. With a logo and two colors set: sidebar, phone top bar and card show them for every member role; a normal
    team and the other sport's side are unchanged; pitch chips, reports and the Live Game field are unchanged.
34. A low-contrast pair is refused. The theme paints on an offline reload.

## 7. Ship (staging first; production only by Joel)

- One branch per stage from `main`: `n1a-names-phone-menu`, `n1b-sidebar-roster`, `n1c-home`, `n1d-getting-started`,
  `n1e-zone-recap`, `n1f-card-milestones`, `n1g-facility-colors`.
- Each stage: preconditions report (`plans/n1<x>-preconditions.md`) and stop for Joel → build → acceptance with
  evidence (`plans/n1<x>-evidence.md`) on staging → `CACHE_VERSION` bump → STATUS.md and CLAUDE.md in the same PR
  → push → PR → stop. Joel checks on his own iPhone and iPad, then merges.
- Stage B (`remove_from_group`) and Stage G: backup first, migration on staging, tests, then production by Joel.
- Rollback for A to F: `git revert` and a cache bump. Stage G: the rollback migration, written before the forward
  one runs.

---

## Paste into Claude Code (one stage at a time; replace <X> and <stage name>)

> Pull `origin/main` and work only from what GitHub has. Read `CLAUDE.md`, the top of `STATUS.md`,
> `plans/n1-navigation-and-home.md` and `plans/n1-design-reference.md`, and open this stage's pictures in `docs/n1/`. This is **N1 Stage <X>: <stage name>**. Stages before <X> must already be on
> production; if STATUS says otherwise, stop and tell me. Branch `n1<x>-…` from `main` as named in section 7.
> Standing rules apply: staging only, only Joel ships to production, no new dependency, nothing from another
> host, charting never needs the network, frozen reports and the palettes untouched, pre-push checks finish
> before any push.
>
> **Before writing code, write `plans/n1<x>-preconditions.md` and stop for me.** It must have: (1) every function
> and CSS rule Stage <X> will change, with file and line as they are now, and anything in the packet that no
> longer matches the repo; (2) each recorded CLAUDE.md decision this stage changes, quoted, with the new rule
> beside it, for my yes; (3) the questions the packet leaves to me for this stage, each with your recommendation;
> (4) for anything the packet says was not drawn, a text sketch; (5) for Stage C, where the per-day counts come
> from; for Stage G, the full migration, rollback and RLS.
>
> **Then, on my approval, build Stage <X> exactly as section 3 says**, run every "Every stage" check and every
> Stage <X> check in section 6 on staging, write the evidence to `plans/n1<x>-evidence.md`, bump `CACHE_VERSION`,
> add the STATUS.md entry and the CLAUDE.md changes in the same PR, push, open the PR, and stop before production.

### Standing constraints (in force)

No build step. No fonts, scripts or images from other hosts. Legal and policy text only with Joel's approval.
GitHub is the source of truth; pre-push checks finish before any push. **Only Joel ships to production.**
