# P2-06 preconditions report (Oct 23, 2026)

Packet: `plans/p2-06-help-page.md` (GitHub, `eacbcad`; that upload added only this file). Branch `p2-06-help` from `main`
(`a00386a`, v302). Nothing built. `BT` = `bullpen-tracker.html`.

## 1. The copy against the app (every step walked on `main`)

**Escalations (the packet: "any step in the copy can't be made true without a product change -- list it"):**
- **A pitcher can't leave a team.** There is no leave button; only the head coach removes a pitcher (roster ✕, BT:13022).
  The copy's "Leave a team and its coaches keep..." describes a flow that doesn't exist (CLAUDE.md's roster model says
  "player leaves or coach removes" -- the player half was never built). Corrected copy says "If a coach removes you".
- **Reports don't go only to saved contacts.** Recipients are the profile's Coach email and Additional contact **plus
  the pitcher's own account email, always** (read-only; a parent-run player: "Parent email (reports go here)").
- **No level at coach sign-up.** coach-signup.html asks name, email, password and **Team / program name**; the head
  coach sets **Level of play** later in Profile. (Corrected in the copy -- not a product gap.)

**Mismatches corrected in the copy below:**

| # | Copy said | The app | Fix |
|---|---|---|---|
| C1 | Sign in at signin.html, choose sport, **Coach sign up** | Sport -> **Coach** -> "New coach? **Create an account**" (login.html:162); fields include **Team / program name** | reworded; level moved to Profile |
| C2 | Profile (top right) -> **team invite link** | Profile -> **Invite links** -> **Pitcher invite link** / **Coach invite link**, **Copy** -- head coach only. Top right is the account menu | reworded |
| C3 | tap a pitcher, then **Bullpen**; choose where you're standing first | pitcher -> **Charting** -> "What will we be charting today?" -> **Bullpen**; start questions (radar gun, Relative Accuracy); **Start bullpen**. Where you stand = **Charting perspective** on the charting screen (phones: the session menu), locked after the first pitch | reworded |
| C4 | tap what happened: ball, strike looking, swing, foul, in play | the row under the chart: **K** (swinging), **backwards K** (looking), **B**, **F**, **IP**; only IP turns the chart into the field (FC / E / H / O, contact, location, who fielded it, runners) | reworded |
| C5 | Reports go only to the contacts the pitcher saved | + his own account email, always; the report waits while a pitcher's line is open | reworded |
| C6 | open any saved session and write a note; the pitcher sees it | coaches of the team it was charted for (**Save note**), online, after it syncs; pitchers don't write notes | reworded |
| P2 | pitches up to eight; contacts up to three | no pitch limit (**Pitch mix** -> Add); **Contacts**: Coach email + Additional contact + your own email; RA: Profile -> **Relative accuracy** -> **Mark cells**, up to 4 per pitch per batter side | reworded |
| P3 | asked if on more than one team | asked if on **one or more** teams | reworded |
| P6 | leave a team | no leave button (see escalation) | "If a coach removes you..." |
| R1 | signin.html: "Parent or guardian? Set up a family account" | no parent link on signin.html; it's on login.html ("Parent or guardian? **Set up your player**"), pitcher signup ("**Create a parent account**") and the join page | reworded |
| E2 | tap a pitch in the list to change or remove it | Bullpen rows: **edit** (type, mph) and **✕** (remove; to move a location, remove and re-chart). Live Game rows: **edit** (incl. **Move location**), no remove -- **Back** undoes. Delete a saved session: **Delete this session**, type DELETE | reworded |
| E4 | **Forgot password?** on the sign-in page | on login.html (after choosing sport and role), not the sport picker; Profile has **Email** (Change email) and **Password** sections | reworded |
| E6 | softball: seven innings | the app doesn't end games at an inning; extra innings start in the 8th (softball) | reworded |

True as written: P1 (with labels), P5, R2, R3, R4, R5, E1, E3, E5.

## 2. Link locations and precache

- Landing footer `index.html:601` (Privacy · Terms · Delete account · Sign in) -> add **Help**.
- Sign-in page `signin.html:190` footer (Privacy · Terms) -> add **Help**.
- App account menu `renderAccountButton()` BT:3450 (profiles, + Add sport, + Add a player; no Profile / help item) -> add **Help** at the bottom.
- `privacy.html:194` and `terms.html:133` footers -> add **Help** (link only; no policy wording changes).
- `sw.js` precache: add `/help.html`; bump `CACHE_VERSION`.

## 3. Copy button

Exists: the invite links (BT:4028-4050) -- `navigator.clipboard.writeText` with a `document.execCommand('copy')` fallback
(installed app / non-HTTPS). help.html gets the same small pattern inline (no shared JS dir).

## 4. Cloudflare Email Routing

On: knuckleballonline.com's MX records are `route1/2/3.mx.cloudflare.net`, SPF `include:_spf.mx.cloudflare.net`
(that's how nate@ works). Joel's click path goes in SETUP.md: Cloudflare dashboard -> knuckleballonline.com -> **Email**
-> **Email Routing** -> **Routing rules** -> **Create address** -> Custom address `support` -> Action **Send to an
email** -> Destination (his inbox, already verified for nate@) -> **Save**. `OPERATIONS.md` doesn't exist (P1-11 not
built); the support line goes in SETUP.md only.

## 5. The corrected copy (for Joel's approval -- public text)

See `plans/p2-06-copy.md`.

## Decisions for Joel

1. Approve the corrected copy (or edit it).
2. The pitcher "leave a team" gap: leave the copy saying a coach removes you (no product change), or a later packet
   adds a **Leave team** button.
3. Everything else as the packet drafted (one page with a track tray; no screenshots; support@ as a routing alias;
   precached).
