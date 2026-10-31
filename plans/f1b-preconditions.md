# F1-B: QR join codes — preconditions (Oct 29 2026)

Source: `plans/f1-training-facilities.md` v2, "QR join (F1-B)".

## What the packet asks for

- **One code per coach,** valid until regenerated. It encodes `join.html?c=<coach_groups.join_token>`, so a scan lands
  the pitcher in that coach's group.
- **The `join.html?c=` page:** shows the facility and the coach, asks "Which sport?", then runs the parent flow (the
  parent makes a login and adds the child). Joining makes the facility membership plus the coach-group row, flagged
  New.
- **A second path,** "I'm the player (13 or older)": 18+ uses the normal pitcher join, and 13–17 the P1-10 guardian
  approval.
- **`qr-print.html?c=`:** a letter-size sheet with the facility, side, coach, the code, the address in text and "Scan to
  join…". The manager's roster gets "Print all codes". (Ask the facility: color or black and white.)
- **The encoder:** a small MIT-licensed QR encoder kept under `vendor/`, working offline.
- **Regenerate** stops the old code (acceptance: the old address no longer works).

## What exists today (checked Oct 29)

1. **`coach_groups.join_token`** exists from F1-A, one per coach per side, and is never readable by the app. Nothing
   reads it yet, and there's no way to regenerate it.
2. **`join.html?t=`** is the team invite page. It already has the parent path: "Signing up your child? Create a parent
   account" goes to `parent-signup.html?next=join.html?t=…`. On return it shows the **"Join as:"** picker (existing
   players plus "New player"), and the join is `join_team_via_invite`. `parent-signup.html` accepts only a
   `join.html?t=` next address today.
3. **Sport:** a coach group belongs to one side, so its sport is already known. "Which sport?" has nothing to ask.
4. **F1-G, Joel's answer A:** "the initial link should never be given to a child". That conflicts with the packet's
   "I'm the player (13 or older)" path for 13–17.
5. **`vendor/`** holds only supabase-js and fonts; no QR encoder yet. Proper encoders are bigger than the packet's
   "~5 KB": Nayuki's "QR Code generator" (MIT, the widely used reference) is about 12 KB minified.

## Questions for Joel

See the session message (A–E). Answers are recorded below once given.

## Joel's answers (Oct 31)

- **A. Agreed.** The code opens the parent flow only: the parent signs in or makes an account, then picks an existing
  player or adds one. Below it there's one small link for adult pitchers, "I'm 18 or older and pitch for myself". No
  13–17 self-join from a code; teens get their own sign-in from the parent (F1-G).
- **B. Black and white, no color.** Each page has the QR code, Knuckleball branding and the coach's name. Otherwise as
  proposed: one letter-size page per coach, facility, side, the address in text, and "Print all codes" for the
  manager.
- **C. Exactly.** Each coach sees, prints and regenerates their own code; the manager sees, prints and regenerates all
  of them, with a confirmation, and the old code stops at once. Also: **a coach must be able to show their code on the
  phone easily, so a parent can scan it right there before a lesson.**
- **D. OK:** Nayuki's QR Code generator (MIT), vendored.
- **E. OK:** a second coach's code adds the pitcher to that group too (New), keeping the first.

## As built (staging, Oct 31)

- **Migration** `20261102000000_f1b_qr_join`: four functions, plus the column-grant fix on the two group tables. The
  fix was found by this stage's test: coaches could read every join code directly.
- **Pages:**
  - `join.html?c=` (code mode);
  - tracker join-code screens;
  - `qr-print.html`;
  - `vendor/qrcodegen.js` (Nayuki v1.5.0, MIT).
- **No coach photo on the join page.** Headshots are private to coaches.
