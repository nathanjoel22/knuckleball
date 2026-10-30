# F1-G: guardian link and roles — preconditions (Oct 29 2026)

Source: `plans/f1-training-facilities.md` v2, "Guardian roles (Joel, Oct 29)", and decision B in
`plans/f1c1-preconditions.md` (the guardian link became its own stage).

## What the packet asks for

- **The link:** a guardian link in a parent's Profile.
- **The joiner's choice:** the joiner picks **Parent/guardian** or **Friend/extended family**, and attests 18+.
- **The two-guardian limit:** at most two parent/guardians per player. The creator (`profiles.managed_by`) is one.
  `player_guardians (player_id, profile_id, role 'guardian' | 'family')` holds the others, and a third `guardian`
  is refused.
- **What each role gets:** parent/guardians chat. `family` sees the player's sessions and reports, with no chat.
- **Removal:** only the creator removes a guardian or deletes the player.

## What exists today (checked Oct 29)

1. **A second adult can't see a player at all.** Every pitcher-side read rule uses `is_my_profile(pitcher_id)`, which
   means "the caller's login owns the profile". There are 5 such rules:
   - `sessions`, `pitches`, `game_events`, `session_stats` and `session_notes`;
   - `profiles` reads "own" as `account_id = auth.uid()`;
   - `pitcher_teams` and `teams` (through `is_team_member`) also read through ownership.

   `is_my_profile` also grants **writes** (charting through `sync_session`, deleting, report contacts, accuracy zones).
   So it must **not** be widened. The plan instead adds a separate read-only helper, `is_guardian_of(pitcher)`, beside
   it in those read rules.
2. **The app only knows the login's own profiles.** It finds them with `profiles where account_id = me` in 5 places. A
   guardian's player isn't theirs, so the switcher needs a read-only "guardian view" of a player: History, Trends and
   report links, with no charting, no Profile editing and no deleting.
3. **`managed_by` (11 functions, 2 pages)** stays "the creator". Nothing there changes (F1-A precondition 7).
4. **Chat** decides who counts as "family" with `chat_family_ok` / `chat_my_orgs` (`account_id = auth.uid()`). It
   would also accept `player_guardians.role = 'guardian'`.
5. **Production has 1 parent-created player (on 1 parent login) and 40 pitchers with their own login.**
6. **A 13–17 pitcher's guardian** today only approves by email (`guardian-consent.html`), with no account. The packet
   says approval "gives the parent a foothold", but it never says how a guardian joins a pitcher who has their own
   login.
7. **Policy text** has nothing on guardian roles. New wording is needed, and Joel approves it.

## Questions for Joel

See the session message (A–G). Answers are recorded below once given.

## Joel's answers (Oct 29)

- **A.** The facility link goes to a parent first, never to a child. The parent joins and creates the child's profile.
  The parent can then give a link to a child under 18 so the child joins under the parent's account, if they want.
- **B.** That one-time link can be sent or copied to the child.
- **C.** Joel asked who accepts what (clarified in the follow-up questions H–L).
- **D.** Joined friends and family see the charting history only: read only, no chat. Parent/guardians see everything
  for their child, whether the child is a profile only or has their own login, and they chat. At most two parent roles
  per child.
- **E.** At most 5 friends and family.
- **F.** Correct: only the creator removes people or deletes the player; a joiner can leave; deletion and export as
  proposed.
- **G.** Draft the policy wording on staging.

## Follow-up answers (Oct 29)

- **H.** Yes: a child's own sign-in is for 13–17 only. An under-13 stays a parent-run profile with no sign-in.
- **I.** Yes: the child charts, sees History, Trends and reports, and chats with their coach. The parent-only controls
  (delete the player, report contacts, invites, removals) stay with the creator. No guardian email is needed, and the
  child signs in through the Pitcher card.
- **J.** Yes: the creator picks the role when making the link. Each link is one-time and lasts 7 days.
- **K.** Keep the email approval for teens who signed up on their own. Facility links go to parents. A parent who
  already made the child's profile and opens a facility's join link joins that player to the facility (the existing
  "Join as:" picker).
- **L.** The second parent/guardian **can chart** for the child. Two adults can chart for a child: the creator and the
  second parent/guardian (plus the child's own sign-in).

## As built (staging, Oct 29)

- **Migration** `20261101000000_f1g_player_links`:
  - tables `player_links` and `player_link_invites` (no client grant, no policy);
  - profiles role `child`;
  - helpers `is_linked_to`, `can_chart_for`, `player_link_role`, `f1g_linked_team`;
  - functions `create_player_link`, `cancel_player_link`, `player_link_info`, `accept_player_link`,
    `my_linked_players`, `player_access`, `remove_player_link`, `leave_player`;
  - 10 read rules edited (policies stay 32);
  - `sync_session`, `get_team_leaderboard`, `pitcher_report_block`, the join functions and 5 chat functions updated.
- **Edge Functions:** `send-session-report` (a linked parent or the child may send) and `export-account`
  (`player_access.csv`).
- **App:** `player-link.html` (new). The tracker gets the switcher, a read-only Profile for linked players and the
  creator's "Who can see". Friends and family get no Charts, Chat, Leaderboard, Contacts or delete.

### Choices made while building (for Joel's review)

1. **Linked parents and the child chart AS the player** (`logged_by` = the player), the way the creating parent already
   does. History therefore never labels their pens "Logged by coach".
2. **Friends and family also read coach notes.** A report link shows them anyway, so hiding notes in the app would
   have been inconsistent.
3. **Adults join with a parent account.** A coach or pitcher login is refused and has to use a separate email.
4. **One unused link per role at a time.** Making a new link replaces the unused one, so the button hides while a link
   is pending.
5. **Only the creator manages the profile.** The second parent and the child can't edit name, pitch mix, throws,
   contacts or teams, and can't delete sessions. The creator does all of that.
6. **Joining a facility is unchanged (K).** The existing "Join as:" picker on a facility's team link joins a player
   the parent already made.
