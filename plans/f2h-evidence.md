# F2 Stage H · Housekeeping · evidence (Nov 20, 2026)

Branch `f2-report` (also carries the packet and `plans/f2-preconditions.md`), cache `kb-shell-v367`. No database.
Tested on the local staging site in headless Chrome, each check in a fresh signed-out browser context at 390.

## Done when

1. **The film: PASS in Chrome with a stand-in iOS bridge; the iPhone and iPad builds are Joel's.**
   - Signed out, online: the film plays from 0 to **4.97 s**, then black (5.05 s), the logo (5.5 s), and `login.html`
     (about 7.7 s). The page leaves no `kb:introSeen`.
   - No signal (`navigator.onLine` false): no video element is made, and it goes straight to black, the logo, then
     `login.html` (about 2.7 s).
   - Signed in: unchanged (`index.html:18` goes to the app before the film).
   - The cause of "no film" (Nov 18's mid-film parts waiting for metadata that iOS never loads before `play()`) is in
     `plans/f2-preconditions.md` §1. The new film starts at 0 and plays at once.
   - **Open (Joel):** an iPhone and an iPad store build, signed out: about 5 s of film, then the logo and sign-in, on
     every launch. No new store build is needed, because the app loads the site.
2. **"Create Your Child's Profile" in all five places: PASS.**
   - `grep -rn "Create Child" *.html` finds 0.
   - The new wording is in: More, Account, the account button, the box heading, the tracker's under-13 stop, the Get
     started label and hint, the join pages' under-13 messages, and Help.
3. **Pitcher Name then Parent Name: PASS.**
   - **`login.html#new`:**

     ```
     pitcher:  "Pitcher Name" | parent box shown
     parent:   "Your name (the parent or guardian)" | parent box hidden
     coach:    "Full name" | parent box hidden
     facility: "Full name" | parent box hidden
     ```

   - **Required for 13–17:** with no Parent Name, Create account says "Enter the Parent Name." and nothing is created.
     It's optional at 18 or older (the check applies only to `minor_13_17`).
   - **Under 13:** the form becomes a Parent account, and the Parent Name typed fills the parent's name box (role
     parent, under-13 note shown).
   - **Pitcher join links:** `join.html` shows "Pitcher Name | Parent Name" (then the parent's "Player's name" for Join
     as, unchanged); `accept-invite.html` shows "Pitcher Name | Parent Name". Both require it for 13–17.
   - **Stored:** in the sign-up's auth metadata as `parent_name`. accept-invite uses `updateUser({ password, data })`,
     never the email.

The full test suite: the pre-push checks pass. There are no SQL tests in this stage.
