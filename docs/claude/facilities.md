# Training facilities (F1) — Knuckleball

Moved word for word from CLAUDE.md on 2026-11-05 (card 015). CLAUDE.md's rules apply here too; read it first.

## Training facilities, chat, QR join codes and linked sign-ins (F1; from Schema and RLS)

**Training facilities (F1-A, Joel, Oct 29 2026; `plans/f1-training-facilities.md` v2, decisions in
`plans/f1a-preconditions.md`; staging, v321).** A third login area beside Pitcher and Coach.
- **Model:** an `organizations` row (`manager_login`) owns two teams, `teams.kind = 'facility'`, one per sport, ALWAYS
  both (decision B). The **Facility Manager is plain head of both** (`teams.coach_id`; two coach profiles on one login),
  so every head rule works unchanged. "Facility login" = a login that owns an organization (`is_facility_login()`); its
  profiles are ordinary `coach` profiles.
- **Signup:** Joel makes the link on **`operator.html`** (Oct 31 2026: the `facility-invites` Edge Function, OPERATOR_EMAILS
  only, writes the `facility_invites` row with the service role after `facility_email_status` checks the email can work;
  it lists open / used / expired links and cancels unused ones; it never sends email -- the page opens a ready message in
  Joel's own mail app). `facility-signup.html?t=<token>` makes the
  login, then `create_facility(token)` makes everything, once (wrong email / used / expired refused; same login again
  returns the same org). No self-serve signup and no inquiry form: the facility card shows
  nate@knuckleballonline.com as text (decision E).
- **Cards (decision A):** `login.html?role=facility` signs in only facility logins; the Pitcher and Coach cards refuse
  them. Browser-side only (sign straight out, plain message); the server's read rules still decide all access.
  **Since Nov 5 (Joel, v327):** the Pitcher card is for pitchers, parents (with their players) and teens' own sign-ins,
  and refuses any login with a coach profile; a player a coach added with no email of their own sits on the coach's
  login and opens from the Coach card. The Coach card refuses a login with no coach profile, so a player with their own
  email (their own login, even one a coach invited) signs in only on the Pitcher card. A login with no profile yet goes
  by its signup `intended_role`, or is let through.
- **Groups:** `coach_groups` (one per coach per facility team, made by trigger when a coach joins; `join_token` is
  F1-B's QR, never granted) and `coach_group_members` (`flagged_new`). Actions only through `add_to_group`,
  `remove_from_group` (the last group on a side takes the pitcher off it, departure logged), `move_between_groups`
  (manager only) and `clear_new_flag`; a coach acts on their own group only.
- **Narrowed R4 inside a facility (decision D):** `coach_sees_pitcher(team, pitcher)` replaced `is_team_coach(team)`
  wherever a pitcher is involved (the sessions / pitches / game_events / session_stats / pitcher_teams / profiles read
  rules, the report-link write, `is_current_coach_of_pitcher`, `is_coach_of_pitcher`, `is_coach_of_session_team`,
  `sync_session`'s charting check, the roster functions). It equals `is_team_coach` on `kind = 'team'` (proven by
  `supabase/tests/f1a_rls_matrix.sql`: every login, every table, before = after). On a facility team a pitching coach
  sees, charts and reports only their group's pitchers; the manager sees all. Coaches of the pitcher's other teams
  still read lesson pens (R4 stands).
- **No notes and no leaderboard on facility teams** (`is_coach_of_session` refuses; `get_team_leaderboard` raises
  `facility_team`; the tracker hides both). `handoff_facility(new_manager)` = the R6 handoff on both sides at once
  (the new manager must already coach both; decision C).
- Rollback `supabase/rollback/20261030000000_f1a_facilities_down.sql` (refuses while facility sessions exist); tests
  `supabase/tests/f1a_acceptance.sql`, `f1a_rls_matrix.sql`; load test `plans/f1a-load-test.md`.

**Chat (F1-C1, Joel, Oct 29 2026; `plans/f1c1-preconditions.md`; staging, v322).** Only inside a training facility.
- **Threads:** `facility` (one per organization; only the manager posts; every coach, pitcher and parent there reads)
  and `private` (one open per pitcher per coach group: the group's coach and the family post; the side's manager reads).
  "Family" = the login the pitcher's profile sits on: the pitcher themself, or the parent who created the player
  (`chat_family_ok`; a 13-17 login needs the guardian's approval first), and since F1-G a linked second parent or the
  player's own sign-in (`chat_is_family`); never friends and family.
- **Access is computed, not stored:** `chat_access(thread)` from today's groups, so moving a pitcher
  (`move_between_groups`) takes the open thread to the new coach, who reads its history; leaving a group closes it
  (family keeps read-only). The four chat tables have no client grant and no policy (policies stay 32); the app uses
  only the `chat_*` functions.
- **Rules:** 2,000 characters, text only; YouTube links open in the browser (`chatBodyHtml`, escaped first). Author
  deletes their own message (text kept for the manager); pins up to 5 (the thread's coach, or the manager on the
  facility thread); Report reaches the manager (Resolved clears it); a coach's "Close this chat" = read-only, the
  manager reads it for 90 days, then pg_cron `f1c1-chat-clear` deletes it (`chat_clear_archived`).
- **Account deletion:** `a1_purge_profile` blanks their messages to "Deleted account" and closes private threads
  about them; Download my data has `chat_messages.csv`.
- **App:** a Chat tab after Trends and a Chat button after Analysis on the phone bar, only when `chat_summary()` says
  the login has a facility (cached per login, `kb:chatOn:<uid>`); the count = unread (a manager: the facility thread
  and their own trainees) + open reports. Polling, not real time (decision F): 30 s for the count, 5 s in an open
  thread. Online only; never on or over the charting screen.
- **Policy text:** the facility and chat additions on `privacy.html` / `terms.html` (Version 2026-10-29) were approved
  by Joel on Oct 29 as a quiet update: `TERMS_VERSION` stays 2026-10-17, so no login is shown the "I agree" box.
- Rollback `supabase/rollback/20261031000000_f1c1_chat_down.sql`; test `supabase/tests/f1c1_chat_acceptance.sql`.

**QR join codes (F1-B, Joel, Oct 31 2026; `plans/f1b-preconditions.md`; staging, v325).** One code per coach per facility
side (`coach_groups.join_token`) opens `join.html?c=<token>`: **parents first** (make a parent account or sign in on
the page, then the "Join as:" picker: pick or add the player); one small link, "I'm 18 or older and pitch for myself",
for adult pitchers (no 13-17 self-join from a code: `join_group_via_token` refuses a pitcher's own login under 18 with
`adult_required`). A join adds the facility membership and the coach-group row flagged New; a pitcher already there
joins the second coach's group too. A coach shows ("Show my join code": full screen, black on white, drawn on the device
by `vendor/qrcodegen.js`, Nayuki MIT v1.5.0, from codes cached per login, so it works offline), shares, prints
(`qr-print.html`: one black-and-white letter page per coach with the wordmark; the manager's "Print all codes") and
regenerates (`rotate_group_code`; the old code stops at once, joined pitchers stay) their own code; the manager every
code on their sides (`my_group_codes`). The migration also restored F1-A's intended column-only grants on
`coach_groups` / `coach_group_members` (Supabase's default table-wide SELECT had let a side's coaches read every join
code). Rollback `supabase/rollback/20261102000000_f1b_qr_join_down.sql`; test `supabase/tests/f1b_acceptance.sql`.

**Linked sign-ins for a parent's player (F1-G, Joel, Oct 29 2026; `plans/f1g-preconditions.md`; staging, v323).**
- **Who links:** only the parent who created a player (`profiles.managed_by`; the player sits on that parent's login)
  makes one-time links (7 days, one unused link per role), removes people and deletes the player. Roles
  (`player_links`, no client grant): `guardian` (one: two parents in all), `child` (one: the player's own sign-in,
  **13-17 only**, a brand-new login whose primary profile has role `child`, no sport, approved by the link,
  `consent_via = 'parent_link'`) and `family` (up to 5). The joiner opens `player-link.html?t=`: the child makes a new
  sign-in; adults sign in to, or make, a parent account (coach and pitcher logins are refused). Anyone linked can leave
  (`leave_player`). Under-13s never get a sign-in. Teens who signed up themselves keep the P1-10 email approval.
- **What each gets:** `guardian` and `child` chart for the player (`sync_session` takes `can_chart_for`; they chart
  AS the player, `logged_by` = the player, like the creator), read everything, send reports to the saved contacts (their
  own email verified) and chat (`chat_is_family`). `family` reads the charting history only (sessions, pitches, events,
  stats, notes, report links): no charting, chat, contacts or leaderboard. Nobody linked edits the profile, joins teams
  or deletes sessions.
- **Checks, not ownership:** `is_my_profile` is NOT widened (it grants writes). Read rules add `is_linked_to(pitcher)`
  (any role) or `can_chart_for(pitcher)` (owner, guardian, child) beside it; the policy count stays 32. The app adds
  `my_linked_players()` to the switcher (`fetchMyProfiles`, rows carry `linked_role`); `activeLinked()` /
  `viewOnlyLinked()` hide what the server refuses; the creator's Profile has "Who can see <player>"
  (`player_access`, `create_player_link`, `cancel_player_link`, `remove_player_link`).
- **Deletion and export:** links go with the player, the linked login or a removal; a purged child sign-in's chat
  messages blank like anyone's. Download my data has `player_access.csv`.
- **Policy text:** the linked sign-ins additions on `privacy.html` / `terms.html` (Version 2026-10-29) were approved by
  Joel on Oct 29 as a quiet update (`TERMS_VERSION` stays 2026-10-17, no "I agree" box).
- Rollback `supabase/rollback/20261101000000_f1g_player_links_down.sql` (refuses while links or child sign-ins exist);
  test `supabase/tests/f1g_acceptance.sql`.
