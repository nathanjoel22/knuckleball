# R7 Stage A · one sign-in, one New account form · evidence (Nov 19, 2026)

**Where it was tested:**
- Branch `r7-one-login`, cache `kb-shell-v358`, no database change.
- The local staging site (staging database), in headless Chrome with device emulation.
- "Before" is today's main (v357), served from a separate copy.

**Pictures (`plans/r7a-evidence/`):**
- `signin-before-after-390.png`: today's "Which sport?" and role cards, the new sign-in, and the top of New account.
- `cards-before-after-1280.png`: today's two screens beside the whole New account form at 1280.
- `new-account-390-1280.png`: the whole form at 390 (a softball pitcher, 13-17, so the guardian email shows) and at
  1280 (Facility chosen: the contact line, with Create account disabled).
- `which-pitcher-390.png`: a parent with two players signing in.

The pictures show only the form's placeholder (`you@example.com`) and the existing facility contact address, the one
exception the packet allows. The test accounts made here are `@example.com` addresses, which Resend refuses, so no real
email was sent.

## Done when (Stage A)

1. **One sign-in page: PASS.** Each of these signed in on plain `login.html` (no role or sport in the address) and
   landed on the right home:
   - a coach: Staging Knights, coach Home;
   - a pitcher: their own screens, in softball;
   - a parent with one player: that player's screens;
   - the DS1 facility manager: Thayer Pitching Lab, with `isFacilityManager` true.
2. **New account is one form: PASS.**
   - The fields: name, email, password, then the two sport cards and the four account types (Pitcher · Parent ·
     Coach · Facility) at the smaller size, with today's artwork and wording (a new Parent card drawn to match), then
     Create account.
   - Create account is disabled before the sport, before the type, and after both until name, email and password are
     filled (test: `true / true / false`). For Facility it stays disabled.
   - **The age rules, unchanged:**
     - A pitcher adult saves `age_attestation = adult`.
     - 13-17 needs a guardian's email; it saved `minor_13_17` and the app shows "Waiting for a parent or guardian to
       approve".
     - **Under 13** turns the form into a Parent account, with the note, and the typed name is set aside. The parent's
       account then opens on "Create your pitcher's profile" with that name ("Little Leaguer") and the sport filled in.
     - Coach and parent only ever make the adult statement (the 18+ box), as before; there is no way to answer under
       18 for them.
3. **A new parent: PASS.**
   - Create account opens straight on **Create Child's Profile**, and adding the player opens that player.
   - With two players (Little Leaguer, baseball; Second Kid, softball), a fresh sign-in shows **"Which pitcher?"**.
   - The player's one-time setup popup waits until one is chosen.
4. **Old addresses: PASS.** Every row of report item 1, opened on a signed-out device:
   - `signin.html` and `?choose=1` → Sign in.
   - `#signup` → New account. `?sport=softball#signup` → New account with Softball preselected.
   - `login.html?role=coach&sport=softball` and `?role=facility…` → Sign in.
   - `pitcher-signup.html?sport=softball` → New account with Softball and Pitcher preselected. `coach-signup.html` →
     Coach preselected.
   - `parent-signup.html?sport=softball&next=join.html?t=…` → New account with Softball and Parent, `next` kept.
   - `facility-signup.html?t=` → still its own page.
   - The landing page: "Sign in" → `login.html`, "Join" and "Start charting free" → `login.html#new`. The iPhone
     app's opening film now ends on `login.html`.
5. **No "use the other card" message: PASS.**
   - A search of every page and Edge Function finds none. The two "Pitcher card" hits in the app are the N1 trading
     card. The operator page's "on the Training facility card" was removed too.
   - A wrong password says only "Invalid login credentials".
6. **Offline: PASS.** After one sign-in, with the network cut and the page reloaded, each reopened the same role from
   the device: the pitcher, the coach, and the parent's chosen player (Second Kid, not asked again).
7. **Join links: PASS.**
   - **Signed out, on a phone (390) and an iPad (820):** the team link shows name, email, password, the age question
     and terms; the staff link shows name, email, password and terms. No sport or role question on either.
   - **A new person** signing up through the team link lands in the app already on "U15 Softball Test".
   - **Signed in as a parent:** the team link asks only "Who's joining this team?" (their players or a new one), as
     before.
   - **New:** "Already have an account? Log in" on a join page now comes back to the join link after signing in
     (`login.html?…&next=join.html?t=…`). Before, the link was lost.

## What changed

- **`login.html`:**
  - Sign in: email and password; no card checks, and no hints written from a card.
  - New account (`#new`): the one form. What each type creates is exactly what its old sign-up page created
    (`signUp` metadata, `ensure_account_setup`, `record_attestation`, the verification email for pitchers and parents).
  - `?role=` / `&sport=` preselect New account. `?next=` (allow-listed) returns to a join, staff or player link.
  - A pending operator-link facility (`kb:facilityToken`) finishes on any sign-in.
- **`signin.html`, `pitcher-signup.html`, `coach-signup.html`, `parent-signup.html`:** forwards only.
  `facility-signup.html` stays (operator links), with its card wording removed.
- **`bullpen-tracker.html`:**
  - `pickActiveProfile`: a parent with two or more players gets "Which pitcher?" on a fresh sign-in (`kb:freshSignin`).
  - The setup popup asks the pitcher's **Level** (it left the form).
  - The add-player screen takes a carried-over name (`kb:playerNamePending`).
- **Other pages and docs:**
  - `css/components.css`: the smaller cards (`.pick-card`).
  - `index.html`: links and the splash target.
  - `help.html`: the steps, with no cards and no "choose your sport and role".
  - `join.html` and `join-coach.html`: "Log in" returns to the link.
  - `operator.html`: wording.
  - CLAUDE.md: the pages and the retired cards.
- **Store:**
  - `knuckleball-app` PR #12: the review notes say there is one sign-in, from the next submission on.
  - `store/android/phone-5-sign-in.png` (Play) shows the old sign-in and needs retaking before the Play listing goes out.

## Deviations and notes

- **Fields asked in the app after Create account** (report item 8.5):
  - a coach's team name: the existing "Create your team" screen;
  - a pitcher's level: now in the one-time setup popup (and Pitcher settings, as before);
  - a parent's player: Create Child's Profile.
- **The sport chosen at sign-up** sets the device's theme and the account's first profile. A parent's own profile has no
  sport, so the choice goes to the first player.
- **Staging data from these checks** (all `@example.com`, test only): adult pitcher, 13-17 pitcher, coach (no team yet),
  two parents (one with two players) and one team-link joiner on U15 Softball Test.
