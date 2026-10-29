# F1-C1 — Chat, preconditions report (no code yet)

Oct 29, 2026. Packet: `plans/f1-training-facilities.md` v2, "Chat (F1-C1 and F1-C2)". F1-A is on production (v321).

**Order:** Joel chose Chat next, ahead of the packet's F1-D (bar and Back) and F1-B (QR codes).

## What C1 is (from the packet)

**Threads:**
- `facility`: one per facility. Only the manager posts.
- `private`: one per pitcher per coach. The coach, the pitcher (if they have a login) and up to two parent-guardians post.

**Writing:**
- **Compose button:**
  - manager: *Everyone at the facility*;
  - coach: one pitcher's family;
  - pitcher or parent: *My coach*.
- **Messages:** text up to 2,000 characters. YouTube links are tappable and open in the phone's browser; nothing is
  embedded.
- **Pins:** a coach or the manager can pin up to 5 per thread.
- **Report:** flags a message to the manager, who gets a dot.

**Deleting and keeping:**
- A deleted message shows "This message was deleted". The text is kept for the manager and for us.
- A coach "deleting" a thread archives it: the manager can still read it for 90 days, then a daily job clears it.
- Departed families keep read-only access until the thread clears.
- An account deletion removes the person from every thread, and their messages read "Deleted account".

**Guardian roles:** Parent/guardian or Friend/extended family. At most two parent/guardians per player; only they chat.

**Reading and notifications:**
- The manager reads every thread.
- Coaches of other teams get nothing.
- Unread dots only: no email, no push (push is C2b), no "Seen by".

**Policy text:** chat, the manager's read access, the 90-day retention, the guardian roles and lesson visibility. This
means a version bump, which Joel approves.

**Left for C2:** the coach's *All my pitchers* thread, Reply privately, and the manager's filter.

## What exists today (checked Oct 29)

1. **There is no guardian link.** Nothing in the app lets a second adult join a player today:
   - A parent-created player belongs to the creating parent's login (`managed_by`).
   - A 13–17 pitcher's guardian only approves by email (P1-10). There's no account and no app access.

   So the packet's "the guardian link in a parent's Profile" is **new**. It's a second adult getting into another
   login's player: a join link, a new `player_guardians` table, and **new read access to that player's sessions,
   pitches, events, stats and reports for a login that doesn't own them**. That means changes to the read rules on
   five tables and to the report function. It is the biggest single piece of C1, and it isn't chat.
2. **Who would be in chat today, per pitcher:**
   - production has 40 pitchers with their own login and 1 parent-created player (1 parent login);
   - staging has the 100 LoadTest players under 12 parents.

   For a parent-created player, the family member is the creating parent. For a pitcher with a login, it's the pitcher
   themself.
3. **Where Chat would sit:**
   - The phone bar is Home · Charts · Analysis · Roster · Profile for coaches, and Home · Charts · Analysis · Profile
     for pitchers.
   - The top tabs are Home · New · History · Trends · Player.
   - The packet's place for Chat is F1-D's bar, which isn't built.
4. **Live updates:** the bundled supabase-js has the real-time client, so no outside load is needed. Polling is simpler
   to run.
5. **Daily jobs:** pg_cron already runs `a1-account-deletion` and `r3-final-lock`. A third, the 90-day chat clear,
   fits the same pattern.
6. **Account deletion and export (A1):**
   - `a1_purge_profile` deletes a person's notes today, and would need to handle chat (the H1-style single exception).
   - `export-account` (the ZIP) has no chat today.
7. **Policy pages:** both are Version 2026-10-17 and approved by Joel. Any text change needs his re-approval.

## Decisions needed

**A. Where Chat lives until F1-D.** Proposal:
- add **Chat** to the top tabs, after Trends;
- add Chat to the phone bar, only for someone who has a thread (facility managers, facility coaches, and pitchers or
  parents on a facility);
- an unread count on both;
- a facility coach's bar becomes 6 buttons (Home · Charts · Analysis · Chat · Roster · Profile); a pitcher's becomes 5.

Everyone else sees no change.

**B. The guardian link: in C1, or a stage of its own?**
- (a) **In C1, as the packet says.** C1 becomes chat + a guardian link + new session read access for guardians. Bigger,
  with more read-rule changes.
- (b) **C1 without it (recommended).** Chat works for the people who exist today: the pitcher if they have a login, and
  the parent who created a player. Guardian roles and the link become their own small stage (call it F1-G), with their
  own read-rule matrix, before or after C2.

**C. 13–17 pitchers with their own login.** Today their parents have no account. Under (b), their private thread is the
coach and the pitcher, and opens only after the guardian has approved (P1-10, as the packet says). Their parents join
once F1-G exists. OK?

**D. Account deletion and "Download my data."**
- Proposal: the purge removes the person from every thread, and their messages read "Deleted account" until the
  thread's own clear. (The packet keeps the text for the manager. I'd blank it on a purge, since the person asked for
  their data to go.)
- The data ZIP gets the messages the person wrote.
- This touches A1's purge and the `export-account` function.

**E. Policy text.** I draft the privacy and terms additions, put them on staging, and you approve the exact words
before production (version 2026-10-30 or the ship date). OK?

**F. Refresh.** Proposal: dots refresh when the app comes to the front and every 30 seconds while it's open; an open
thread checks every 5 seconds. No real-time connection in v1. Chat needs a connection; offline it says so, and
charting is untouched. OK?

## Joel's answers (Oct 29, 2026)

A yes (Chat tab + bar button, only with a thread) · **B (b)**: no guardian link in C1 (its own stage, F1-G) · C yes ·
D yes (purge blanks their messages to "Deleted account"; the ZIP gets their messages) · E yes (draft policy text on
staging, Joel approves the words before production) · F yes (polling: 30 s dots, 5 s in an open thread).

## As built (staging, Oct 29 2026)

See STATUS.md (F1-C1 entry). Test: `supabase/tests/f1c1_chat_acceptance.sql`.
