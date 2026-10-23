# P2-06 — Getting started and help (Oct 23, 2026)

**Joel, Oct 23, 2026.** One page, `help.html`, that answers a new coach's, pitcher's or parent's first-day questions without emailing anyone, plus a support address that reaches a person. It is the support URL for the App Store and Google Play listings (W1) and the last Phase 2 item.

**Page content is below, ready to build.** Claude Code adjusts any step that doesn't match the app as it is on `main` today, and says what it changed. Joel approves the final copy before it goes live (it's public).

## Rules

- Plain words, short steps, the app's own button names in bold. No screenshots in v1 (they go stale with every ship); a later pass can add them.
- Three tracks on one page, picked at the top with a Segmented tray: **Coach · Pitcher · Parent**. Each section shows only its track's steps; the "Everyone" sections show for all.
- Sport-neutral wording ("a session," "the field") except where the sports differ; those lines are tagged *Baseball* / *Softball*.
- Themed by `tokens.css`, D2 look, 65-character measure, Big Shoulders section headings, anchor links so a support reply can link straight to a section (`help.html#reports`).
- Linked from: the landing page footer, the sign-in page, the app's account menu, and the privacy/terms footers. Precached by the service worker so it opens offline.
- **Support:** `support@knuckleballonline.com`, shown as selectable text with a Copy button (mailto links are unreliable in the installed app). Joel creates the alias in Cloudflare Email Routing forwarding to the inbox he reads; Jordan is added when he takes support (SC0/P1-11). A one-line promise: "We answer within two business days."

## The copy

### Getting started with Knuckleball

Knuckleball charts pitches. In a bullpen it records where you meant to throw and where it went. In a game it records where it went and what happened. Every saved session becomes a report you can open on any phone.

**Pick who you are:** [ Coach | Pitcher | Parent ]

---

#### Coach

**1. Make your team.** Sign in at knuckleballonline.com/signin.html, choose your sport, then **Coach sign up**. Name your team and set its **Level of play** (Little League, High school, College); the level decides when extra-inning rules apply.

**2. Invite your pitchers.** Open your profile (top right) and copy the **team invite link**. Send it any way you like: text, GroupMe, a QR code on the iPad. A pitcher who opens it signs up and lands on your roster. Coaches on your staff use the **coach invite link** the same way; assistants can chart and view, the head coach manages the team.

**3. Chart a bullpen.** Tap a pitcher on the roster, then **Bullpen**. Choose where you're standing (behind the catcher or behind the pitcher), the pitch type, and whether to turn on Relative Accuracy. For each pitch: tap the target, tap where it landed. Velocity sits under the chart if you use a radar gun.

**4. Chart a game.** Tap the pitcher, then **Live Game**. Tap where the pitch landed; the chart turns into the field. Tap what happened: ball, strike looking, swing, foul, or in play. For balls in play, tap where it landed and who's on base. Outs, counts and innings keep themselves. **Back** undoes the last tap; **More** holds the rare plays.

**5. Save and send.** **End session & save**. Then **View report** or **Send report**. Reports go only to the contacts the pitcher saved in his profile.

**6. Add a note.** Open any saved session and write a note; the pitcher sees it, and so does anyone with the report link.

---

#### Pitcher

**1. Join or go solo.** If your coach sent a link, open it and sign up; you'll be on the roster. No team? Sign up at knuckleballonline.com/signin.html with **Pitcher sign up** and start charting on your own. You can join a team later with a coach's link and keep everything.

**2. Set up your profile.** Your pitches (up to eight), your throwing hand, and the email addresses your reports should go to (up to three). If you want Relative Accuracy, mark up to four extra cells per pitch, per batter side.

**3. Chart a bullpen.** **Bullpen**, pick a pitch, tap the target, tap where it landed. If you're on more than one team, the app asks **Which team is this for?** first; **Independent** means nobody but you and your current coaches see it.

**4. Chart a game.** Same as a coach (step 4 above).

**5. Your reports.** After **End session & save**, **View report** opens it; **Send report** emails the link to your saved contacts. Reports are frozen when made; a report someone already has never changes.

**6. Who can see your charts.** You, always. Coaches of every team you're currently on can see your sessions; only the team a session was charted for can add notes or send its report. Leave a team and its coaches keep the sessions charted while you were there, nothing after.

---

#### Parent

**1. Make the account.** At knuckleballonline.com/signin.html choose **Parent or guardian? Set up a family account**. You sign up; your player doesn't need an email or a login.

**2. Add your player.** **Add a player** in the account menu. One account can hold a son in baseball and a daughter in softball.

**3. Join a team.** Open the coach's invite link and pick which player is joining.

**4. Chart and read.** Charting works the same as for a coach (above). Reports come to your email.

**5. If your player is 13 to 17 and signed up alone,** they'll have named you as guardian. You get an email with an approval link; until you approve, they can chart but can't receive reports.

---

#### Everyone

**Working with no signal.** The app keeps working in the bullpen with no signal. Sessions save on the phone and sync when you're back online; **Pending sync** on a session means it hasn't reached the server yet. Don't delete the app or clear its data while something is pending.

**Fixing a pitch.** During a session, tap a pitch in the list to change or remove it. Once a session is saved it can't be edited; you can delete it (the team sees a record that it was deleted) and chart again.

**Install it like an app.** iPhone and iPad: in Safari, tap **Share**, then **Add to Home Screen**. Android: tap **Install** when the banner appears, or use the browser menu.

**Password.** On the sign-in page tap **Forgot password?**; the reset email lands you on the reset form. To change your email or password later, open your profile.

**Your data.** Your profile has **Download my data** (everything, as a ZIP) and **Delete my account** (seven days to change your mind). What Knuckleball keeps and why is on the privacy page.

**Softball.** Same app, same steps. No Windup/Set; an illegal pitch is under **More**; seven innings.

**Still stuck?** Email **support@knuckleballonline.com** [Copy]. We answer within two business days. Say which sport, which screen, and what you expected to happen.

---

## Decisions made in drafting (Joel may override)

1. One page with a track picker rather than three pages; sections hide by track so a parent isn't reading coach steps.
2. No screenshots in v1.
3. `support@` as a Cloudflare routing alias, not a new mailbox. Two-business-day promise.
4. The page is precached so it opens offline (the "Working with no signal" section is the one people need when they have no signal).

---

## The packet (paste for Claude Code)

```
ID:              P2-06
Title:           Getting started + help page (help.html) and the support address
Spec:            plans/p2-06-help-page.md on GitHub (pull first; work only from
                 GitHub). Copy is in the spec; adjust only where the app differs
                 from the steps, and list every adjustment. Look per
                 docs/design/target/DESIGN.md; the track picker is a U13 tray.
Depends on:      P2-01/02 (solo), S4 (parents), P1-10 (guardians), A1 (data),
                 P2-05 (install), U14 (RA), R4 (visibility), L1 (landing/footer).
                 All shipped.
Staging only.    No database change. Only Joel ships to production.

PRECONDITIONS — REPORT before code:
  1. Walk every step in the copy against the app on main and list each
     mismatch (button names, order, what a screen is called) with the
     corrected wording.
  2. Where the footer/menu links live today (landing, sign-in, app account
     menu, privacy/terms) and the sw.js precache list.
  3. Whether a Copy button pattern already exists (A1 export page? invite
     link copy) to reuse.
  4. Cloudflare Email Routing: confirm the domain's routing is on and what
     Joel must click to add support@ → his inbox (Joel does it; you document
     the click path in SETUP.md).
  Build nothing until Joel has read the report and approved the copy.

BUILD:
  - help.html: tokens.css + components; track tray (Coach / Pitcher / Parent,
    remembered in localStorage, deep-linkable as #coach etc.); sections with
    ids (#start, #invite, #bullpen, #game, #reports, #notes, #offline, #fix,
    #install, #password, #data, #softball, #support); Copy button for the
    address; "Which sport?" theming follows data-sport if present, else
    baseball.
  - Links in the four places; precache; CACHE_VERSION.
  - SETUP.md: the support@ alias steps; OPERATIONS.md (P1-11, if present):
    "support inbox" line.
OUT OF SCOPE: screenshots; video; in-app tours; chat widgets; a ticketing tool.
ACCEPTANCE:
  1. Every step verified against the live app by a cold read-through by
     someone who isn't Joel (the next coach to onboard, or Jordan), both
     sports; corrections applied.
  2. Page reachable from all four link locations; opens offline on an
     installed phone.
  3. Track tray hides the other tracks; deep links land on the right section.
  4. Copy button works in Safari and in the installed app; the address is
     selectable text.
  5. Mail to support@knuckleballonline.com arrives in Joel's inbox (Joel
     sends one).
  6. Lighthouse accessibility pass on the page; screenshots at 390/iPad.
VERIFICATION: Joel reads it on his phone; one outside reader.
ROLLBACK: git revert; CACHE_VERSION.
SIZE: S.
ESCALATE IF: any step in the copy can't be made true without a product
  change (then list it, don't paper over it).
```

### Standing constraints (in force)

Public page: strict escaping, no third-party loads, themed by tokens. GitHub is the source of truth. **Only Joel ships to production.**
