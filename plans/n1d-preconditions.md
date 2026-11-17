Written against: `b35c789` (main; production v345, N1 Stages A-C live). Packet: `plans/n1-navigation-and-home.md`, Stage D.

# N1 Stage D · Getting-started card · preconditions (Nov 17, 2026)

**Joel, Nov 17 2026: "yes to all, build it"** -- Q1-Q5 as recommended, and the two example.com emails for testing.

**Front end only:** no migration, no RLS change, no new function. Hidden / seen state lives on the device (`kb:` keys),
as the packet says.

## 1. What Stage D changes

| What | Where now | Stage D |
|---|---|---|
| The card | none | At the top of Home (`d-getting-started.png`): "GET STARTED", "3 of 5 · Hide", a progress bar, the steps. Done steps get a green check; the first step not done is bold, with its hint and a ›. Never blocks anything. |
| The steps | none | **Data**: one list per role, each step `{ id, label, hint, go, done(ctx) }`. Adding a step is one entry. |
| Hidden | none | `kb:gs:<uid>:<profile>` = hidden. Hidden, the card stays reachable from More → Getting started, which today opens `help.html`. |
| More → Getting started | a link to `help.html` | Opens Home with the card shown (un-hides it) and shows "3 of 5" on the row, as drawn. "Help and support" keeps `help.html`. |
| The iPad / computer menu | "Help and getting started" → `help.html` | Unchanged (Help). The card is on Home, where the menu's Home goes. |

## 2. The steps, and how each one knows it's done

From the packet's table (coach, pitcher and parent steps follow `help.html`; the facility owner's are a starting
point). "Device" means a `kb:gs:<uid>:<profile>:<step>` mark set when the user does the thing on this device, used
only where the app can't tell from data it already has.

**Coach**
1. **Name your team and set level of play.** Done when the team has a level (`teams.level`). Goes to Account → Team
   settings.
2. **Share your join code or invite link.** Done when the roster has a pitcher, or on this device after Copy / Share /
   Show code. Goes to More → Join codes and invite links (facility: Show my join code).
3. **Chart a bullpen.** Done when the team has a bullpen: Home's 14-day read, any loaded History, or a device mark at
   save. Goes to Chart.
4. **Send a report.** Done after a successful Email report on this device, or when any loaded session has a report
   sent. Hint: "End a session, then Send report". Goes to History.
5. **Chart a live game.** As step 3, for a game.

**Pitcher**
1. **Join your coach or go solo.** Done when on a team, or after their first session (solo).
2. **Set your pitch mix and throwing hand.** Done when `pitch_types` and `throws` are set. Goes to Account.
3. **Chart a bullpen.** Done when History has a bullpen.
4. **Read your report.** Done when a report has been drawn on this device (History's feed shows them as it scrolls).
   Goes to History.
5. **See who can view your charts.** Done when tapped. Goes to `help.html#pitcher-visibility`.

**Parent**
1. **Add your player.** Done when the login has a player.
2. **Join the team with the coach's link.** Done when the active player is on a team.
3. **Approve the guardian email if your player is 13 to 17.** See Q3.
4. **Open the latest report.** As the pitcher's step 4.

**Facility owner**
1. **Add your coaches.** Done when a side has a coach besides the manager. Goes to Account → Team settings (staff,
   coach invite link).
2. **Share the join codes.** Done when any group has a pitcher, or after Show / Print on this device. Goes to Coaches
   and groups.
3. **Set up groups.** Done when there's at least one pitcher and nobody is under No coach yet. Goes to Roster.
4. **Look over the facility view.** Done after opening Coaches and groups or Roster on this device.
5. **Chart a first session.** Done when the facility has any session (Home's read).

View-only family: no card (nothing on the packet's lists is theirs to do).

## 3. Questions for Joel, each with a recommendation

**Q1. Step wording.** The picture's coach steps read a little differently from the packet table: "Share your join code
with pitchers", "Chart your first bullpen", "Send your first report".
*Recommend:* the picture's wording for the coach. The other roles use the same style: "Chart your first bullpen", "Read
your first report".

**Q2. When every step is done.**
*Recommend:* the card shows "All set" with a green bar on that visit. From the next visit it's gone from Home. More →
Getting started still shows it, as "5 of 5".

**Q3. The parent's "Approve the guardian email" step.**
- It only applies when a teen signed up on their own and named this parent.
- A parent's own players (added by the parent) never need it.
- The parent's login can't see that a teen named them until the email arrives.

*Recommend:* drop it from the parent's list. The parent card becomes 3 steps: Add your player, Join the team, Open the
latest report. The approval email itself explains what to do (it already does), and Help keeps its step 5.

**Q4. The existing first-run prompts that overlap the card.**

| Today | Overlaps | Recommend |
|---|---|---|
| Pitcher setup popup (first sign-in, until "Set this up later" or saved) | pitcher step 2 | **Keep.** It's the real form, once per account, and it never shows over a pen. |
| Coach Welcome popup (a new head coach with an empty roster) | coach step 2 | **Keep for normal teams; stop showing it on facility sides.** There it offers team invite links, while a facility joins by QR code (seen on staging Nov 17). The card's step points facility coaches to their join code. |
| "Finish setting up your profile" banner (every visit while uniform #, throws or pitch mix is missing; dismissable per page load) | pitcher step 2 | **Retire it.** The card shows the same thing as a step, without nagging on every visit. |

**Q5. Who sees the card.** Coaches, pitchers, teens, parents and facility owners; never view-only family. Assistant
coaches get the coach list, with step 1 done when the team has a level (an assistant can't set it).
*Recommend:* yes.

## 4. Not drawn

- "All set" (Q2): the same card with a full green bar and "You're all set", then gone.
- More → Getting started: the row with a pale "3 of 5" pill (drawn in `a-more-screen.png`).

## 5. How it will be checked

Every packet check (1-5, 24-25) on staging at 390, 820, 1180 and 1440, with each role's first screen.
- **24:** a new login of each role sees its list, and each step ticks when really done. The DS1 logins and Stage A's
  test logins mostly have steps done already, so I'd clear this device's `kb:gs` marks and use their real states.
  For "new login" I'd make one new coach on staging. That sends one verification email to an example.com address (Joel
  OK'd these before), and I'd do the coach steps for real. A new pitcher and parent are covered by the test logins'
  real states; I'll say in the evidence which steps were seen ticking live.
- **Coach step 4 for real** means Email report, which sends one report email to the pitcher's saved contacts. I'd do it
  on the new staging coach's own test pitcher, whose contacts are example.com addresses: one more email, nobody's real
  inbox.
- **25:** adding a sixth step to one role is a one-entry change. The diff is shown in the evidence, then reverted.
