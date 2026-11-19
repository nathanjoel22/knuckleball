# R7 — One login; account type chosen at sign-up; more roles by link, Nov 19, 2026

**Joel, Nov 19:** "I want to change it so that it is all the same login spot but that based upon what you chose when you signed up for an account, it sorts you into that sort of account… when you sign up for an account, it will ask you to choose the type of account: pitcher, coach or facility. let's also add a fourth option which is parent. Parent will then get prompted to create a profile for their pitcher. when they login, it will then follow the same path as a pitcher account."

And on holding more than one role: "you should be able to be different roles after the initial signup. for example, I may start a facility but then be given a link by another coach to join as an assistant on another team. so, based on the link type I click after my initial signup, that email could hold different roles. but the initial signup dictates my primary role initially."

## What changes, in one paragraph

Today the front door asks Baseball or Softball, then Pitcher / Coach / Training facility, and each card has its own sign-in that refuses the "wrong" kind of account. After R7 there is **one sign-in** (email and password, nothing else) and **one New Account form: name, email, password, then sport, then role — Pitcher, Parent, Coach or Facility — then Create account**. The choice made at sign-up is the account's **primary role**; signing in opens that role's home. Later, a join link can add another role to the same email, and the person switches between their roles inside the app.

## Decisions this packet is built on

| # | Decision | Source |
|---|---|---|
| 1 | **Facility is open self-serve sign-up.** Anyone who picks Facility creates one on the spot, with no link from Knuckleball. This reverses F1-A decisions A and E (Oct 29: invite-only, contact address shown as text). | Joel answered "2" to the facility question, read as the second choice offered. **If he meant something else, Stage B changes and nothing else does.** |
| 2 | **Sport is asked at sign-up, never at sign-in, and never on a join link** ("there is no need to ask the sport or role because it is assumed in the link"). The account knows its sport; the app opens in that sport's colours. | Joel, Nov 19 follow-up. |
| 3 | **A parent lands on their pitcher's own screens** — what the pitcher would see. With more than one child, a short "Which pitcher?" chooser comes first. | Assumed, from "it will then follow the same path as a pitcher account." |
| 4 | **"Parent" is the parent account the app already has** (`parent-signup.html`, `add_player`, S4 consent, F1-G linked sign-ins), now on the menu as an equal fourth choice. No new kind of account. | Assumed. |
| 5 | **One email can hold several roles.** The first is chosen at sign-up and is the primary. Others are added only by accepting a link of that type. | Joel, in his own words above. |
| 6 | **With more than one role, the person picks their primary in account settings.** Sign-in opens the primary first; they can switch to their other roles once inside. | Joel, Nov 19 follow-up. |
| 7 | **One sign-up form, reusing today's buttons at a smaller size.** New Account → name, email, new password → sport (Baseball / Softball) → role (Pitcher / Parent / Coach / Facility) → Create account. | Joel, Nov 19 follow-up. |

## The front door

**Sign in (`login.html`).** Email, password, Forgot password, "Create an account". No sport screen, no role cards, no role in the address. After sign-in the server says what this login is and the app opens the primary role's home:

| Primary role | Opens |
|---|---|
| Pitcher | the pitcher's own screens (as today from the Pitcher card) |
| Parent | their pitcher's screens; chooser first if more than one; "Add your player" if none yet (as today) |
| Coach | the coach's team (as today from the Coach card) |
| Facility | the facility manager's roster (as today from the Training facility card) |

The four "this is a coach account, use the Coach card" refusals in `login.html` go away. What anyone can read is still decided by the server, exactly as now.

**New Account.** Reached from "New Account" on the sign-in page, as today. **One form on one screen**, in this order:

1. Full name, email, new password.
2. **Sport** — Baseball / Softball. Use the two sport cards from today's `signin.html` (same artwork, same wording, same selected state), **at a smaller size**, side by side.
3. **Role** — **Pitcher · Parent · Coach · Facility**, in that order. Use today's role cards (the Pitcher, Coach and Training facility cards, plus a Parent card drawn to match), **at a smaller size**, in one row on wide screens and a 2×2 block on a phone.
4. **Create account.** Disabled until name, email, password, sport and role are all set.

Rules that ride on the form and do not change: the age question (P1-10) and the terms box stay on this screen — put them between the role and the button, shown for the role chosen; a pitcher under 13 is sent to the Parent path with what they typed carried over; 13–17 goes to guardian approval; a coach, parent or facility manager under 18 is refused; `record_attestation` and `ensure_account_setup` are called exactly as now. If any field a role's form collects today is missing from this list (a team name for a coach, a level for a pitcher), ask for it **after** Create account, inside the app, not on this form — list them in the report.

After Create account:

- Pitcher, Coach → their home, as today.
- Parent → straight into **"Create your pitcher's profile"** (today's `add_player` step), then into that pitcher's screens.
- Facility → Stage B below. A facility is both sports; the sport chosen here only sets which sport it opens in.

The four separate sign-up pages stop being places people are sent; whether they are kept as redirects or removed is your call in the report.

**Join links never ask sport or role.** A team link, a coaching-staff link, a coach's QR code, a player link and a facility coach link already carry both. A new person arriving by link sees name, email, password, the age question and terms, and nothing else; that link's role is their primary. A signed-in person arriving by link just confirms.

**Old addresses keep working.** `signin.html`, `signin.html?choose=1`, `signin.html#signup`, `login.html?role=…&sport=…` and the four sign-up pages are in emails already sent, printed QR sheets, the landing page's Join buttons, the Help page, the Android shell and the iOS shell's start address. Each must land somewhere sensible (sign-in, or Create account with the type preselected) for good — list every one in the report.

## Stage A — one door, no database change

Everything above except Facility self-serve and extra roles. Until Stage B ships, choosing the Facility card on the form shows today's wording (set up by Knuckleball, the contact address) and keeps Create account disabled. The login's kind is read from what already exists: `profiles` rows for the login, `is_facility_login()`. The sport/role hints the app keeps on the device (`kb:sport`, `kb:signinSport`, `kb:signinRole`) are set from the account after sign-in instead of from the card that was tapped; the offline cold launch (P1-13) must open the same role with no network. Copy changes ride along: Help page, landing page, the coach onboarding sheet and QR print pages, anywhere that says "tap the Pitcher card".

## Stage B — Facility self-serve (migration)

- Picking Facility collects what `facility-signup.html` collects today (manager name, facility name, email, password, the 18+ attestation and terms) and creates the facility in one go. The result is identical to one made from an operator link: one organization, both sports' facility teams, `manager_login` set.
- `create_facility` needs a token today. Propose the smallest safe change in the report — a second function for self-serve, or the page issuing itself a single-use invite server-side — and say why. **No policy is widened.** Policy count before and after.
- Limits, so the open door is not a mess: one facility per login; the creator's email must be verified by the app's own mechanism (`profiles.email_verified_at`) before the facility can add coaches or pitchers — never `auth.users.email_confirmed_at`; Confirm email stays OFF; a per-address and per-device rate limit on creation.
- The operator page stays: it lists every facility with how it was created (operator link or self-serve) and when, and operator links keep working for facilities Joel sets up by hand. Joel gets one plain email per self-serve facility (Resend, to the operator address only).
- **Flag for Joel in the report, not for you to decide:** what a self-serve facility gets before it pays (pricing model), and the wording on the landing page and in the policy pages that says facilities are set up by Knuckleball.

## Stage C — more than one role on one email (migration)

**The rule.** A login has a **primary role** (set at sign-up, or by the first link for someone who arrived by link) and may gain others. A role is added **only** by the server function that accepts a link of that type — never by a value the page sends:

| Link accepted | Role gained |
|---|---|
| Coaching-staff link (`join_team_as_coach`) | Coach (assistant on that team) |
| Team join link / coach's QR code, joining as the pitcher (`join_team_via_invite`, `join_group_via_token`) | Pitcher |
| The same links, joining as a parent with a player | Parent |
| Player link, guardian or family (`accept_player_link`) | Parent of that player |
| Facility's coach link | Coach in that facility |
| Create account → Facility while signed in | Facility manager |

Joel's example is the acceptance case: a facility manager clicks another coach's staff link and becomes an assistant on that team, same email, same password.

**Today's blockers.** Several functions refuse a login whose primary profile is the "wrong" kind (`not_a_coach_login`, `not_coach`, `not_a_parent_login`, the non-child check in `accept_player_link`), and the sign-in page refuses mixed logins. List every such refusal and say, for each, whether it is a rule we keep or a wall this stage removes.

**Rules that do not bend.**

- A **child's linked sign-in** (role `child`) never gains any other role, and nobody who has attested under 18 gains Coach, Parent or Facility. Coaches stay 18+.
- Holding two roles **never merges what they can see.** Each role reads exactly what it would read alone (R4, the facility narrowing from F1-A, `coach_sees_pitcher`). A coach on Team A who is a pitcher on Team B sees Team A's roster as a coach and only himself as a pitcher. Prove it in the RLS matrix.
- Players a coach added with no email of their own (`managed_by`) are **not** roles of the coach.
- Saved sessions stay immutable; report access still needs the pitcher verified and the caller verified.

**In the app.**

- Sign-in opens the primary role. A **role switcher** in the menu lists the login's other roles by plain name ("Coach — Cairn Baseball", "Parent — Eli"), and remembers the last one used on that device for the next cold start, including offline.
- **Account settings shows "Your roles"** whenever the login has more than one, with the primary marked and a control to make a different one primary (decision 6). With one role the section is not shown. The choice is stored on the account, so it applies on every device.
- Account deletion and export (A1) cover every role on the login in one go; say what happens to a facility whose manager deletes their login (today's `handoff_facility` path).

**Storage.** Report the smallest shape that holds "primary role" and "roles gained, by which link, when" — today the primary is the profile whose id equals the login's id, and facility is a property of `organizations`. Prefer reusing those over a new table.

## Still in force

Service-role key only in Edge Function env vars. No Admin API. Every schema or RLS change by migration, staging first, fresh backup before production, rollback written before deploy. `auth.users.email_confirmed_at` is never read; Confirm email stays OFF. Explicit column lists on `profiles`. **Only Joel ships to production**; no push to main, no merges, and merges go through the GitHub page after checks. No email address or password in a commit — the facility contact address already in `login.html` is the one existing exception; add no others.

## Store submissions

The iOS review notes and screenshots (`knuckleball-app/store/`) and the Play listing describe signing in by tapping a card, and the reviewer demo account's steps name the Coach card. **Do not ship R7 to production while a build is in review.** Either ship Stage A before the screenshots are taken and rewrite the review notes to match, or hold it until after approval. Say in the report which the dates allow; Joel decides.

## Report first, then build

Pull `origin/main`; read `CLAUDE.md`, `STATUS.md`, `plans/r0-join-link-onboarding.md`, `plans/r6-coaching-staffs.md`, `plans/s4-profiles-and-consent.md`, `plans/p1-10-age-attestation-and-policies.md`, `plans/f1-training-facilities.md` with `plans/f1a-preconditions.md` and `plans/f1g-preconditions.md`, and `signin.html`, `login.html`, the four sign-up pages, `join.html`, `join-coach.html`, `player-link.html`, `accept-invite.html`. Report, with file and line numbers, before any code or SQL:

1. Every way a person reaches sign-in or sign-up today (pages, query strings, hashes, emails, QR sheets, both app shells) and where each will land after R7.
2. How the app decides a login's role today, on the server and on the device, and what the offline cold launch reads.
3. Every mixed login that already exists on staging and on production (counts only): logins with profiles of more than one role, facility managers with a pitcher or parent profile, coaches with `managed_by` players. Where does each land under Stage A?
4. Every server refusal based on the login's kind (function, line, error code) and your keep / remove call for Stage C.
5. Stage B: the smallest change to facility creation, the limits, and the policy count.
6. Stage C: the storage shape, the switcher's place in the menu on phone and iPad, and the RLS proof plan.
7. What in the store materials, Help page, landing page, policy pages and printed sheets names the old cards.
8. Anything in Joel's five decisions that the existing age, consent or facility rules make impossible as written, with the closest alternative.

Then build **A, B, C as three pull requests in that order**, each on staging, each stopping for Joel's check.

## Done when

Stage A
1. One sign-in page; a pitcher, a parent, a coach and a facility manager each sign in there with no role in the address and land on the right home.
2. New Account is one form: name, email, password, the two sport cards and the four role cards (Pitcher · Parent · Coach · Facility) at the smaller size, then Create account, which stays disabled until all five are set. Screenshots at 390 px and 1280 px beside today's cards show the same artwork. Every age and consent rule behaves exactly as before (under-13 pitcher → Parent path; 13–17 → guardian approval; coach under 18 refused).
3. A new parent is taken straight to "Create your pitcher's profile" and then into that pitcher's screens; with two players, the chooser appears at sign-in.
4. Every old address in report item 1 lands where the report said.
5. No "use the other card" message can be reached. A wrong password still says only that.
6. Offline: after one sign-in, a cold start with no network opens the same role.
7. Every join link still works for a new person and for a signed-in one, on phone and iPad, and none of them shows a sport or role question.

Stage B
8. A new person picks Facility and has a working facility, identical in the database to an operator-made one; a second attempt on the same login is refused; an unverified manager cannot add people; Joel receives one email; the operator page lists it as self-serve.
9. Policy count unchanged; operator links still work.

Stage C
10. Joel's case: a facility manager accepts a coaching-staff link and is an assistant on that team; sign-in opens the facility; the switcher opens the team.
11. A coach accepts a team link as a pitcher; a pitcher (adult) accepts a staff link; a coach accepts a player link as guardian — each gains the role and loses nothing.
12. A child sign-in and an under-18 pitcher are refused every adult role, with a plain message.
13. The RLS matrix shows each role on a two-role login reading exactly what a single-role login would.
14. Changing the primary in Profile changes where the next sign-in opens, on a second device too.
15. Delete account removes every role; export contains every role's data.
16. Full test suite passes; shell version bumped; `STATUS.md` updated per stage; store review notes rewritten if Stage A ships before submission.

## Prompt for Claude Code

```
Save this packet verbatim as plans/r7-one-login.md on the branch before anything else; if a copy already exists on main, use that one and tell me if the two differ.

Do the "Report first" section and wait for my answers. Do not write feature code or SQL before I reply.

After I reply: build Stage A, Stage B and Stage C as three separate pull requests, in that order, staging only, stopping after each for my check. Migrations go to staging after a dry run, with the rollback written first. Do not push to main, do not merge, do not deploy to production, and do not ship anything to production while an App Store or Play build is in review. Finish each pull request with the numbered "Done when" items for that stage, each marked pass or fail with evidence.
```
