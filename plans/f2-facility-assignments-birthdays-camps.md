# F2 — Facility session assignments, reassigning pitchers, birthdays, camp rosters, and three small fixes, Nov 20, 2026

Five requests from Joel on Nov 20, built as five stages, each its own pull request. Stages 1–4 are for training facilities; stage 3 (birthdays) touches every pitcher. Joel's own words are quoted where the wording matters.

| Stage | What | Database |
|---|---|---|
| **H** | Housekeeping: opening film, "Create Your Child's Profile", Pitcher Name / Parent Name | none |
| **2** | Roster top row: Search facility, Join Codes, Assign Pitchers (manager moves a pitcher to another coach) | none expected |
| **1** | Any facility coach can find any facility pitcher by name and assign them to a coach **for one session** | migration |
| **4** | Create Temporary Team/Camp Roster | migration |
| **3** | Birthdays, and the silent move to the next playing level | migration + policy wording |

Build order is H, 2, 1, 4, 3. Stage 3 is last because it cannot go to production until Joel has approved new privacy-policy wording.

---

## Stage H — housekeeping

**a) The opening film.** Joel: "The video is no longer showing at the beginning of the app loading." First find out why and say so in the report (the Nov 18 change made it the whole film the first time, then one of three parts at random; something since has stopped it). Then the new rule, which **replaces** the Nov 18 rule:

- **Signed out:** the first **5 seconds** of the film, then the Knuckleball sign-in screen. Every time, not only the first.
- **Signed in:** no film. Straight into the app.
- No signal: skip the film, as today. The `kb:introSeen` memory and the three random parts are removed.
- This is the store apps' opening (iPhone, iPad, Android), as today. The website's landing page keeps its own hero film. Say in the report if the cause or the fix lives in `knuckleball-app` rather than the site.

**b) One label.** "Create Child's Profile" becomes **"Create Your Child's Profile"** everywhere it appears: the More row (Joel named Team → Create Child's Profile), the Account page button, the heading of the box it opens, the under-13 stop message, and the Get started card's hint. One wording, one capitalisation.

**c) Pitcher sign-up.** Joel: "when signing up for a Pitcher account on baseball or softball, the first question should say Pitcher Name and the second box to fill in should say Parent Name." On the New Account form, when the role chosen is **Pitcher**, the name box is labelled **Pitcher Name** and a second box labelled **Parent Name** follows it. The same two labels on any join link where a new pitcher signs up. Other roles keep "Full name" and get no second box.

- *Drafting decision:* Parent Name is **required when the pitcher is under 18, optional at 18 or over** (a college pitcher has no parent signing up). Until stage 3 ships, "under 18" comes from the age answer already on the form.
- Store it where SR1 Stage F's parent contact already lives if that fits; say where in the report. No new column unless there is no home for it.

---

## Stage 2 — the roster's top row, and Assign Pitchers

On a facility's Roster, where **Show my join code** and **All join codes** sit today:

- **Left: a search box**, placeholder **"Search facility"** (stage 1 gives it its results; in stage 2 it filters the roster the person can already see).
- **Right: one button, "Join Codes".** Tapping it opens a box in the style of the join-code box with **Show my join code** and **All join codes** (the second for managers only, as today). Tapping either continues exactly as it does now.
- **Facility manager only, under Join Codes on a phone: "Assign Pitchers".** Tapping it puts the roster into assign mode: every pitcher on the roster can be tapped, and a tap opens a box naming the pitcher and listing the facility's pitching coaches (the current one marked). Pick a coach, confirm, and the pitcher moves. "That change is permanent until reassigned." A pitcher with no coach yet is assigned the same way. Done leaves assign mode.

This is the move the manager can already make from Manage (`facAct('move' / 'add')`); **use the same server path**, do not write a second one. Say in the report whether the old inline "Choose a coach…" control stays or is replaced, and what happens today to the private chat thread between a pitcher and the coach he is moved away from — nothing about that changes here.

On iPad and laptop the same three controls appear; propose their place in the report.

---

## Stage 1 — assign a pitcher to a coach for one session

Joel: "they should be allowed to assign a pitcher, within the facility, that they cannot see otherwise to themselves or to another coach, for charting for a session. Once they finalize the session the player gets released from their roster and they can no longer view them."

**Who.** Any coach in the facility — head or assistant — and the facility manager.

**Search.** The "Search facility" box searches **every pitcher on the facility's roster** by name, whoever their coach is. A pitcher not in the facility never appears. A result shows the name only (and, when two pitchers share a name, each one's coach, to tell them apart). Nothing is listed until at least two letters are typed; at most 20 results. A coach's own pitchers appear in the results too and open as they always do.

**Tap a name → a box** (join-code style): the pitcher's name and **"Assign for a session"**, then **choose the coach** — yourself or any other coach in the facility.

- Assigned to yourself: straight to the charting start screen for that pitcher. "From there the coach chooses how they will chart and then they chart."
- Assigned to another coach: the pitcher appears at the top of that coach's roster under **"Assigned for a session"**, and the person who assigned gets a one-line confirmation.

**What the assignment allows, and only this.** The assigned coach can chart **one session** for that pitcher, bullpen or game, with what charting needs: the name, the pitch types, the Relative Accuracy cells, the usual velocity centre. They **cannot** see the pitcher's History, Trends, reports, notes, card, parent contact or birthday, and they **cannot message** the pitcher or the parents ("that pitcher does not 'belong' to them"). A session assignment must not count as group membership anywhere chat or visibility is decided.

**Release.** The moment the session is saved and final, the assignment ends: the pitcher leaves that coach's roster and the coach can no longer open the pitcher or the session just charted. Also ends if the coach discards the session, if whoever assigned (or the manager) cancels it, or — *drafting decision* — **24 hours** after it was made if no session was started. A session started inside the window and saved later from the offline queue is still accepted.

**The session.** It belongs to the pitcher like any other. In the pitcher's History it reads **"Charted by a coach"** — no name. "No need to identify that it was a different coach." Everyone who normally sees that pitcher's sessions (the pitcher, parents, his own coach, the manager) sees it; the coach who charted it does not, once it is saved.

**Shape (propose your own in the report if better).** A `session_assignments` row (facility, pitcher, coach, assigned by, made at, expires at, session, released at); one function that searches (caller must be a coach or manager **of that facility**; returns id and name only); one that assigns; release inside the save transaction. The read the assigned coach gets comes from narrow `SECURITY DEFINER` functions that return exactly the charting fields — **no existing policy is widened**, and `coach_sees_pitcher` stays false for an assigned coach. Policy count before and after. Saved sessions stay immutable.

**Questions for the report.** Who is offered "View / Send report" after an assigned session is saved — the default is nobody on the charting device; the report is there for the pitcher's own coach and family as usual. And how "charted by" is shown in History today, so the new wording matches.

---

## Stage 4 — Create Temporary Team/Camp Roster

**Where.** Facility manager only, under **More →**: a row named exactly **"Create Temporary Team/Camp Roster"**. It opens a box in the join-code style asking:

1. **Team/Camp Name** — "this is what will get displayed."
2. **Assign a coach** — one coach in the facility.
3. **Assign pitchers** — any pitchers in the facility, as many as needed, with the same name search.
4. **Set date** — one date, or a series **From** and **To**.

**For the coach.** The camp appears **under that coach's Roster**, titled with its name, listing its pitchers. "Once the final date passes, it should disappear from their roster." Dates are the facility's local days (Eastern, as reports now are, unless the facility says otherwise — report what is stored).

- *Drafting decision:* the camp is listed on the coach's roster from the day it is created, marked with its dates, and can be **charted from on its dates only**.
- *Drafting decision:* what a camp coach can do with a camp pitcher is **the same narrow grant as stage 1** — chart, nothing else: no History, no reports, no messages — for as many sessions as the camp's dates allow. If Joel wants camp coaches to see the sessions charted in that camp while it runs, that is one more narrow read, not roster membership.

**For the pitcher.** "All data is saved in the history of the individual pitchers." Camp sessions are ordinary sessions in the pitcher's History, labelled with the camp's name. SR1 Stage A's session tags may already be the right place for that label; say so in the report.

**For the manager.** In Roster, **at the bottom of the pitching-coach list**, every temporary team/camp the manager has created. Tapping one expands it to show its pitchers "in the same way that pitchers currently assigned to a pitching coach appear", with its coach and dates. The manager can change the name, coach, pitchers and dates, or end it early. Removing a camp never removes a session.

- *Drafting decision:* after the final date a camp leaves the coach's roster **and** the manager's list; its record stays in the database and its name stays on the sessions.

**Shape.** `camp_rosters` (facility, sport, name, coach, first day, last day, created by) and `camp_roster_pitchers`; a nullable camp reference on the session, written at save. No existing policy widened. A pitcher's permanent coach does not change.

---

## Stage 3 — birthdays, and the silent move to the next level

Joel: "Add a birthday question when creating a player profile or signing up a new player. Knuckleball needs to keep track of birthdays. Once kids age up to the next playing levels: high school, college, etc… Knuckleball needs to know that and switch the player over accordingly. This should be a silent switch that happens in the background… For players currently with profiles, they should be asked this question the next time they login."

**Where it is asked.**

- **New Account, role Pitcher:** a Birthday question (month, day, year). It **replaces the three-way age answer** for pitchers: the server works out adult / 13–17 / under 13 from the date and the existing rules run exactly as now (under 13 → the parent path; 13–17 → guardian approval). Coach, Parent and Facility sign-ups are not asked a birthday; their 18-or-older box stays.
- **Create Your Child's Profile:** required.
- **A coach adding a player who has no email of their own:** asked, with "I don't know" allowed; without it that player's level stays hand-set.
- **Join links** where a new pitcher signs up: asked, same as New Account.

**Players who already have a profile.** At their next sign-in, one question before anything else: a pitcher answers for himself; a parent answers for each child. Coach-added players with no login get a quiet prompt on the coach's roster instead, never a blocking screen.

**The hard case — stop and ask, do not decide.** A birthday can contradict what an account said at sign-up (someone who ticked 13–17 enters a date that makes them 11; someone who ticked 18+ is 16). Report how many such accounts could exist and what the S4 / P1-10 rules would require for each case. The default this packet assumes: the account is treated exactly as a new sign-up of that age would be (a parent must set it up, or a guardian must approve), nothing is deleted, and saved sessions are untouched. **Joel approves the handling before this ships.**

**Who can see a birthday.** The pitcher's own login and his parents' logins. **Not** coaches, **not** facility managers, not other pitchers: they see the playing level, as today. The date is never in a report, an email, a chat, a log line or an export other than the person's own A1 data export. A1 deletion removes it. Explicit column lists on `profiles`; the new column is in none of the lists a coach reads.

**The level switch.** Levels today: baseball Little League · High school · College; softball Little League · High school & up. Proposed rule, **for Joel to confirm or change in the report reply**:

| Age on September 1 | Baseball | Softball |
|---|---|---|
| 13 or under | Little League | Little League |
| 14 to 18 | High school | High school & up |
| 19 or over | College | High school & up |

- Everyone in a school year moves together on **September 1**, not on each birthday.
- A scheduled job in the database makes the change (the way the chat-clear job runs), so it happens whether or not anyone signs in. No notice, no email, no banner. Each change is written to a small log (who, from, to, when) that only the operator can read.
- A level never moves **down** by this rule.
- *Drafting decision:* a level set by hand (a 17-year-old already in college) is kept; the rule only ever moves that player **up** from it.
- The switch changes the player's level going forward only. **No saved session, frozen report, `session_stats` row or baseline is recomputed.** List in the report everything a player's level drives (workload and rest from SR1 Stage D, report wording, season boundaries, anything else) and what each does on the day of a switch.

**Before production — Joel's, not yours.** The privacy policy, the terms and the parent-consent wording must say a birthday is collected and why, and carry a new version; the App Store privacy label and the Play Data safety form must list it. Draft the sentences in the pull request, marked DRAFT, as F1-C2's was. **Stage 3 does not go to production until Joel has approved that wording.**

---

## Policy wording for stages 1 and 4

The policy pages describe who at a facility can see a pitcher. After stage 1, any coach in the facility can find a pitcher by name and chart a session when assigned; after stage 4, a camp coach can chart camp pitchers on the camp's dates. Draft the one or two sentences that make the pages true, marked DRAFT, in the stage 1 pull request.

## Still in force

Service-role key only in Edge Function env vars. No Admin API. Every schema or RLS change by migration, staging first, fresh backup before production, rollback written before deploy. Saved sessions immutable. `auth.users.email_confirmed_at` never read; Confirm email stays OFF. Report access needs the pitcher verified and the caller verified. A child's sign-in and anyone under 18 never gain an adult role (R7). Holding two roles never merges what each can see. **Only Joel ships to production**; no push to main, no merges; merges through the GitHub page after checks. No email address, password or real birthday in a commit or a test fixture. Nothing ships to production while a store build is in review if it changes what a reviewer does.

## Report first, then build

Pull `origin/main`; read `CLAUDE.md`, `STATUS.md`, `plans/f1-training-facilities.md` with `plans/f1a-preconditions.md` and `plans/f1a-rls-matrix.md`, `plans/r7-one-login.md`, `plans/s4-profiles-and-consent.md`, `plans/p1-10-age-attestation-and-policies.md`, the N1 Stage B roster work and the SR1 Stage A, D and F entries in STATUS. Report, with file and line numbers, before any code or SQL:

1. **H:** why the opening film stopped showing, and in which repo the fix lives. Where Parent Name is stored.
2. **2:** the roster's top row today on phone, iPad and laptop; the existing manager move path and what it does to chat threads; where the three controls go on wide screens.
3. **1:** your table and functions; exactly which fields the assigned coach's device receives; how the release happens inside the save, including a save from the offline queue; every place chat or visibility is decided from group membership, and proof an assignment is not counted there; policy count.
4. **4:** your tables; how the camp shows on the coach's roster and the manager's list; how the dates are evaluated and in what time zone; whether session tags carry the camp name.
5. **3:** where the birthday is stored and every read path that must not return it; the contradiction cases with counts on staging and production; the job; everything a level drives; the DRAFT policy sentences.
6. Every drafting decision above, restated as a yes/no for Joel.
7. Anything here that the existing age, consent or facility rules make impossible as written, with the closest alternative.

Then build **H, 2, 1, 4, 3** as five pull requests in that order, each on staging, each stopping for Joel's check.

## Done when

Stage H
1. Signed out, the app plays the first 5 seconds of the film and then shows sign-in, on every launch; signed in, no film; no signal, no film. Checked on an iPhone and an iPad build.
2. "Create Your Child's Profile" in all five places; the old wording appears nowhere.
3. New Account with Pitcher chosen shows Pitcher Name then Parent Name; other roles do not; Parent Name is required under 18 only; the same on a pitcher join link.

Stage 2
4. Roster shows Search facility on the left and Join Codes on the right; Join Codes opens the two choices and each continues as before.
5. A manager taps Assign Pitchers, taps a pitcher, picks a coach, confirms: the pitcher is under the new coach on both devices, and stays there after sign-out and sign-in. A coach does not see Assign Pitchers.

Stage 1
6. A coach types two letters of a pitcher in another coach's group: the pitcher appears by name; a pitcher outside the facility never does; a coach from another facility gets nothing.
7. Assign to self → charting start screen; chart and save a bullpen; the pitcher is gone from the coach's roster and every direct read of that pitcher or that session by the coach is refused (shown with SQL as that coach).
8. Assign to another coach → it appears under "Assigned for a session" for that coach only.
9. During the assignment the coach's device holds only the charting fields; History, Trends, reports, notes, parent contact and chat for that pitcher are all refused.
10. The session is in the pitcher's History as "Charted by a coach", visible to the pitcher, parent, own coach and manager.
11. Unused assignment gone after 24 hours; a session started in the window and saved offline later is accepted and then released.
12. Policy count unchanged; RLS matrix updated.

Stage 4
13. A manager creates a camp with a name, a coach, four pitchers from three different coaches, and a three-day range. It shows under that coach's roster and at the bottom of the manager's coach list, expandable.
14. On a camp date the coach charts a camp pitcher; the session is in that pitcher's History with the camp's name; the coach can read nothing else about him.
15. The day after the last date the camp is gone from the coach's roster and the manager's list; the sessions and their label remain. Each pitcher's permanent coach never changed.
16. Editing the camp (name, coach, pitchers, dates) and ending it early both work; neither touches a saved session.

Stage 3
17. A new pitcher is asked a birthday; the under-13 and 13–17 paths behave exactly as before, driven by the date.
18. Create Your Child's Profile requires a birthday; a coach adding a no-email player may answer "I don't know".
19. An existing pitcher and an existing parent with two children are each asked once at next sign-in, and never again.
20. As a coach and as a facility manager, every read that could return the birthday is shown returning nothing.
21. With the clock set to September 1, the job moves a 14-year-old Little League pitcher to High school and a 19-year-old to College, writes the log rows, sends nothing, and changes no saved session, report or stats row. A hand-set College level on a 17-year-old is kept.
22. The contradiction cases behave as Joel approved.
23. Export includes the birthday; delete removes it.
24. DRAFT policy sentences in the pull request; not on production until approved.

Every stage: full test suite passes; shell version bumped where a page changed; `STATUS.md` updated.

## Prompt for Claude Code

```
Save this packet verbatim as plans/f2-facility-assignments-birthdays-camps.md on the branch before anything else; if a copy already exists on main, use that one and tell me if the two differ.

Do the "Report first" section and wait for my answers. Do not write feature code or SQL before I reply.

After I reply: build Stage H, Stage 2, Stage 1, Stage 4 and Stage 3 as five separate pull requests, in that order, staging only, stopping after each for my check. Migrations go to staging after a dry run, with the rollback written first. Do not push to main, do not merge, do not deploy to production. Stage 3 does not go to production until I have approved the policy wording. Finish each pull request with that stage's numbered "Done when" items, each marked pass or fail with evidence.
```
