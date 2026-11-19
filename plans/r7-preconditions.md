Written against: `974bef4` (main; production v357). Packet: `plans/r7-one-login.md` (saved verbatim, no copy on main).

# R7 · One login · preconditions report (Nov 19, 2026)

Nothing is built. Line numbers:
- `S` = `supabase/schema/schema.sql`;
- `BT` = `bullpen-tracker.html`;
- other pages by name.

**Missing inputs.** `plans/r0-join-link-onboarding.md` and `plans/r6-coaching-staffs.md` are not on GitHub, and never
were (`git log --all` finds neither). This report uses CLAUDE.md's R6 / S4 / F1 sections and the code in their place.

## 1. Every way in today, and where it lands after R7

The new front door: **`login.html`** is the one sign-in page (email, password, Forgot password, Create an account).
**Create account** is one form on the same page (`login.html#new`, preselectable with `?role=` / `&sport=`).

| Way in today | Where it comes from | After R7 |
|---|---|---|
| `/` (landing) "Sign in" | index.html:443, :452, :688 | `login.html` |
| `/` "Join", "Start charting free", "Choose Plus / Team" | index.html:444, :475, :621, :630, :638 → `signin.html#signup` | Create account |
| `/` head forward: auth links, `?sport/role/choose`, a signed-in device | index.html:11-19 → `signin.html…` | unchanged target (`signin.html` forwards on, below) |
| iOS app: start.html → `/` → splash → `signin.html` | knuckleball-app www/start.html; index.html:406 | splash goes to `login.html` (one-line change) |
| Android app: root config `/` (stale synced copy opens the tracker) | capacitor.config.json; android assets copy | `/` → `login.html`; tracker → `login.html` when signed out |
| PWA `start_url` `/bullpen-tracker.html` | manifest.webmanifest | signed out → `login.html` |
| `signin.html` (bare, `?choose=1`, `?sport=X`) | landing, login "← Back" (login.html:162), old bookmarks, emails | **kept as a forward**: → `login.html` (a `?sport=` is remembered as the form's preselected sport) |
| `signin.html#signup` | landing Join buttons | → Create account |
| `signin.html#…type=recovery` | password-reset email | unchanged: → reset-password.html (signin.html:83) |
| `login.html?role=coach\|pitcher\|facility&sport=X` | signin.html cards, help, old links | `login.html`; `role` / `sport` only preselect Create account if it's opened; sign-in ignores them |
| `login.html?sport=X` | tracker `loginUrl()` (BT:3859), report email footer (send-session-report/template.ts:34, :335; template_game.ts:548), reset-password.html:83/94/123/262, accept-invite.html:325, the sign-up pages | `login.html` (sport ignored at sign-in) |
| `login.html` bare | delete-account email (delete-account/index.ts:132), delete-account.html:75 | unchanged |
| `pitcher-signup.html?sport=X` | login.html:164-168, help | **kept as a forward** → Create account, Pitcher + sport preselected |
| `coach-signup.html?sport=X` | login.html, help | → Create account, Coach + sport |
| `parent-signup.html?sport=X[&next=join.html?t=…\|c=…]` | login.html, join.html:443 (with `next`), :93/:127/:170/:178, accept-invite.html:336, pitcher-signup.html:69/:101 | → Create account, Parent + sport, **`next` carried**: after "Create your pitcher's profile" it goes to that join link, as today |
| `facility-signup.html?t=<token>` | operator links (facility-invites/index.ts:30, operator.html mailto) | **unchanged page** (operator links keep working); its links to `login.html?role=facility` become `login.html` |
| `join.html?t=` / `?c=` | invite links (BT:4765, :5013), QR sheets (qr-print.html:68) | unchanged; its "Log in" links drop `?sport`, and **"Already have an account? Log in" now returns to the join link** (today it loses the token: join.html:176, no `next` on login.html) |
| `join-coach.html?t=` | staff links (BT:4768) | unchanged; links to signin/login (:80, :141, :142) → `login.html?next=…` |
| `player-link.html?t=` | BT:15621 | unchanged (its own sign-in / sign-up inline) |
| `accept-invite.html` | `invite-pitcher` email (INVITE_REDIRECT_URL; no page calls it today) | unchanged; "Go to login" → `login.html` |
| Supabase Auth emails (confirm, invite, recovery) | supabase/templates/*, `{{ .ConfirmationURL }}` | unchanged (Site URL settings untouched) |
| verify-email, guardian-consent, email-change links | send-verification-email, send-guardian-consent, request-email-change | unchanged (they open their own pages or the tracker) |
| Tracker sign-out / revoked session | BT:3184, :3277, :3281, :3332, :4305, :3860 | `login.html` (no `?sport`) |

**The four sign-up pages:** keep them as small forwards (no form) rather than deleting them. They are in emails already
sent, Help, bookmarks and the join pages' parent links. `facility-signup.html` stays a real page for operator links.

**New: `login.html?next=`.** A same-site, allow-listed return address (`join.html?…`, `join-coach.html?…`,
`player-link.html?…`), so a person who has to sign in from a join link comes back to it. Today join.html loses the token.

## 2. How a login's kind is decided today

**Server.**
- The "kind" is the **primary profile's role**, the profile whose id = the login id (`profiles.is_primary`, generated,
  S:5037). Role is coach / pitcher / parent / child (S:5060); parent and child have no sport (S:5061).
- Facility is separate: `organizations.manager_login` (S:4801), checked by `is_facility_login()` (S:2582).
- `intended_role` lives only in the auth user's metadata. It's set by each sign-up page and read by:
  - `handle_new_user` (S:2420), which makes a coach's profile;
  - `ensure_account_setup` (S:1562-1651; it acts only when no primary exists, and never adds a role);
  - `p1_10_login_is_coach` (S:3163-3169).

**Device.**
- `login.html` writes `kb:sport`, `kb:signinSport` and `kb:signinRole` from the card that was tapped (login.html:120,
  :264-273).
- `pickActiveProfile` (BT:3924-3943) reads them (then deletes them), plus `kb:activeProfile:<uid>`.
- It skips account-only profiles (parent / child, BT:2616), so a parent opens a player.
- A sign-in sport matching several of the login's profiles shows "Who's charting?" (BT:3938, 4240-4250).
- `isCoach()` = the active profile is a coach (BT:2607): that decides teams, Home and the menu.
- A parent with no player gets "Create Child's Profile" as the first screen (BT:16530).
- A facility manager is an ordinary coach login whose teams are `kind = 'facility'` (`isFacilityManager`, BT:2634).

**Offline cold launch (P1-13).**
- The pre-paint script reads the session plus `lastKnownContext:<uid>` (`.profile.sport`; BT:85-101).
- `init()` restores `lastKnownContext:<uid>`, the last active profile with its teams and roster (BT:3192, :3142-3161).
- `kb:activeProfile` is not read offline.
- So **offline already opens the role that was last open on the device**, with no network. R7 keeps that: the
  primary decides the first online sign-in, and the last-used role is what a cold start reopens (the packet's switcher
  rule).

## 3. Mixed logins that exist today (counts, read-only, Nov 19)

| | Staging | Production |
|---|---|---|
| Logins with own profiles | 50 | 79 |
| **Logins with own profiles of more than one role** | **0** | **0** |
| Facility managers | 1 | 4 |
| Facility managers with a pitcher or parent profile | 0 | 0 |
| Facility managers who also coach a normal team | 0 | 0 |
| Coach logins with no-email players (`managed_by`) | 1 | 1 |
| Parent logins with players | 2 | 5 |
| Pitcher logins with players | 0 | 0 |
| Logins with linked players (F1-G) | 1 (parent) | 0 |
| Coach logins also assistant on a team | 4 | 9 |

**Under Stage A:**
- **Every login keeps exactly what it opens today.** None holds two roles.
- **The coach with no-email players** opens their coach profile (the primary is the coach). The players stay rows in
  the switcher, as now.
- **Parents** open their player, with a chooser when they have more than one (decision 3).
- **Assistants** are coaches, and nothing changes for them.

Nothing needs moving.

## 4. Every server refusal based on the login's kind

| Function | Where | Code | Condition | Stage C |
|---|---|---|---|---|
| `accept_player_link` (guardian / family) | S:247 | `not_a_parent_login` | primary role ≠ parent | **remove** (any adult login may be a guardian / family; adds the Parent role) |
| `accept_player_link` | S:248 | `adult_required` | primary not attested adult | **keep** |
| `accept_player_link` (child) | S:234-236 | `login_in_use` | login has any non-child profile or any link | **keep** (a child sign-in is its own login, never another role) |
| `create_facility` | S:1375-1377 | `login_in_use` | any profile on a team (staff or pitcher) | **remove** (a coach or pitcher can also start a facility) |
| `create_facility` | S:1386 | `not_a_coach_login` | primary role ≠ coach | **remove** (the facility adds coach profiles if missing) |
| `create_facility` | S:1371 | `already_manager` | login already runs a facility | **keep** (one facility per login) |
| `facility_email_status` | S:1787 | `in_use`, `not_coach` | mirrors the two above, for operator links | **remove both** (matching the change) |
| `join_team_via_invite` | S:2947 | `coach_cannot_join` | chosen profile is coach / parent / child | **change**: a coach or parent login joining as themselves gets their own pitcher profile made for the team's sport (adds the Pitcher role) |
| `join_group_via_token` | S:2828 | `coach_cannot_join` | same | **change**, the same way |
| `join_group_via_token` | S:2830 | `adult_required` | a pitcher's own login under 18 | **keep** |
| `join_team_as_coach` | S:2886 | `pitcher_cannot_join` | chosen profile is pitcher / child | **change**: an adult pitcher (or parent) login gets a coach profile made for the team's sport (adds Coach). A child: **keep** refusing |
| `join_team_as_coach` | S:3155 | `coaches_must_be_adults` | primary not adult | **keep** |
| `create_team` | S:1459 | `only_coaches_create_teams` | profile isn't a coach | **keep** (creating a team is a coach's action; a pitcher gains Coach only by a staff link) |
| `add_sport_profile` | S:366 | `no_profile_to_copy` | primary not coach / pitcher | **keep** (adds a sport, not a role) |
| `add_player` | S:332 | `adult_required` | primary not adult | **keep** (age, not kind) |
| `record_attestation` | S:3550 | `coaches_must_be_adults` | a minor answer on any coach / parent login | **keep** |
| `handoff_facility` | S:2462 | `already_manager` | new manager already runs one | **keep** |
| `my_single_profile` | S:3123 | (→ `profile_required`) | more than one profile on the login | **keep**, but every Stage C join passes the profile it makes, so nobody hits it |

**Client walls:**
- `login.html`'s four card refusals (:251-254): **removed in Stage A**.
- `join.html`'s silent redirect on `coach_cannot_join` (:428): replaced in C.
- `join-coach.html`'s "You're signed in as a pitcher" card (:93, :328): the child case only, in C.
- `player-link.html`'s `not_a_parent_login` message (:158): C.
- `facility-signup.html`'s `login_in_use` / `not_a_coach_login` messages (:137-140): B or C.

**Already true today (good news for Joel's own example):** `join_team_as_coach` has **no** facility refusal. A facility
manager's login already has a coach profile in each sport, so a staff link adds that profile to the other team's staff
as assistant. That works on the server now. What stops it is the app: the sign-in cards, and the team switcher not
expecting a facility head on a normal team.

## 5. Stage B: facility self-serve

**The change: a second function, `create_facility_self(facility_name, baseball_level, softball_level)`**, rather than
the page issuing itself a token.
- A token exists to say "Joel allowed this email". Self-serve has no such permission to carry, so faking one adds a
  table row, a service-role write and an Edge Function for nothing.
- The new function reuses the same insert code: refactor `create_facility`'s body into one internal
  `f1_make_facility(login, name, levels, via)`, called by both. That keeps the result identical by construction (one
  organization, both facility teams, both coach profiles, head rows, groups by trigger, `manager_login`).
- `organizations` gains `created_via text` ('operator_link' / 'self_serve').
- **No policy is added or widened**, and the counts stay **32 public / 12 storage** (both projects today).

**Limits:**
- **One facility per login:** `already_manager`, as now.
- **Verified before adding people.** A new check, `facility_manager_verified()`, refuses the manager's
  people-adding actions until the primary profile's `email_verified_at` is set: join codes, staff / coach invite
  links, and `add_to_group` for a new pitcher. Unverified, those screens show "Verify your email to invite coaches and
  pitchers" with the existing resend button.
  - Self-serve sign-up sends the verification email, which `coach-signup` and `facility-signup` don't today.
  - `email_confirmed_at` is never read, and Confirm email stays off.
  - Operator-made facilities: the link already proved the address, so their manager is marked verified when the link
    is used.
- **Rate limits:**
  - A new `facility_create` kind in `rate_limit_take` (rate_limit_config): per login, plus a daily cap on self-serve
    facilities (suggest 20 a day, tunable without a deploy).
  - Per address: one facility per login, and a login is one address.
  - **Per device:** the app has no device identity. Supabase Auth's own per-IP sign-up limit (30 per 5 minutes) is the
    only network-level limit. Adding Turnstile (CAPTCHA) was the recorded next step if sign-ups are abused (CLAUDE.md).
    I'd rely on the daily cap plus Joel's email for now, and say so; a per-device token in browser storage is easily
    cleared, so it would only look like a limit.
- **Joel's email:** one plain email per self-serve facility to the operator address, from a new `facility-notify`
  Edge Function. It's sent server-side after creation, rate-limited, Resend.
- **operator.html:** gains a "Facilities" list from a new operator-only action on `facility-invites` (every
  organization: name, created via, when, manager's name). The links list is unchanged.

**Flags for Joel (not decided here):**
- **What a self-serve facility gets before it pays.** There is no billing.
- **Wording:**
  - login.html:170 "Facility accounts are set up by Knuckleball. Contact us…";
  - index.html:649 "Running a facility? Email …";
  - index.html:646 (hidden tier "Talk to us");
  - facility-signup.html's "Contact … for a new one".
  - privacy.html and terms.html say nothing about who sets facilities up, so the policy text needs no change for this
    point.

## 6. Stage C: storage, the switcher, the RLS proof

**Storage (no new table):**
- **Roles are profiles.** Pitcher, coach and parent profiles already hang off the login (`account_id`). The unique
  index (account_id, sport, role) already allows a coach and a pitcher in the same sport (S:5727).
  - Parent: a parent profile with no sport, or a `player_links` guardian / family row (which already records the role
    and `created_at`).
  - Facility: `organizations.manager_login`.
- **"Roles gained, by which link, when":** `profiles` gains `created_via text` ('signup' / 'team_link' / 'qr_code' /
  'staff_link' / 'facility' / 'add_sport' / 'player_created' …). `created_at` already exists. Old rows stay null
  ("signup").
- **The primary:** the profile whose id = the login can't be changed (`is_primary` is generated, and the age, terms and
  verification columns live on it). So the primary profile gains **`opens_profile uuid`**: which of the login's
  profiles sign-in opens.
  - Null = the primary itself.
  - Written only by a new `set_opening_role(profile)` that checks the profile belongs to the login.
  - Readable by the login, through the explicit column grant.

**The switcher (`renderRoleSwitch`):**
- It lists the login's roles by plain name: "Coach — Cairn Baseball", "Pitcher — Thunder 14U", "Parent — Eli",
  "Facility — Thayer Pitching Lab".
- **Phones:** in More → "Your account", right under the name row, above the sport switch (BT:13894).
- **iPad / laptop:** in the side menu's `nav-team` block, under the team selector (BT:13939). The same list goes in
  Account's Profiles group (BT:14144).
- Switching is `switchProfile` (it works offline for a profile already opened on the device).
- A cold start reopens the last role used on the device (`lastKnownContext`, as now).
- **Account → "Your roles"** (only with two or more) marks the opening role, and "Open this first" sets
  `opens_profile`, so the choice follows the account to every device.

**The RLS proof.** `supabase/tests/r7_roles_matrix.sql` (rolled back):
1. Make single-role logins (coach A, pitcher B, parent P, facility manager F), and two-role logins built by the new
   link functions (coach A + pitcher on B, F + assistant on X, coach + guardian of P's player).
2. For every table with a read rule (sessions, pitches, game_events, session_stats, pitcher_teams, profiles columns,
   session_notes, chat via its functions) and for `coach_sees_pitcher`, `is_current_coach_of_pitcher`, the roster
   functions and `pitcher_workload`: assert the two-role login reads **exactly the union** of what each single-role
   login reads, row for row. Nothing more.
3. Plus F1-A's narrowing (a group coach still sees only their group) and R4 (since-joined).
4. Policy count stays 32.

## 7. What names the old cards

- **help.html**:
  - :93 (Coach: "…choose your sport, tap **Coach**, then **New coach? Create an account**");
  - :103 (Pitcher);
  - :113 (Parent: "tap **Pitcher**, then **Parent or guardian? Set up your player**");
  - :126 ("after choosing your sport and role").
  - No facility section.
- **login.html**: the four refusals (:251-254), the tags (:179-182) and the facility contact line (:170).
- **signin.html**: "Which sport?" and "Who are you?", and the three cards (:148-198).
- **facility-signup.html**: "sign in on the Training facility card" (:112, :131, :196).
- **index.html**: "Pick your sport when you join." (:664), which stays true (sport is asked at sign-up).
- **Store:**
  - `knuckleball-app/store/android/phone-5-sign-in.png` (Play screenshot of the old sign-in with its role links).
  - `review-notes.md` names no card, but its reviewer (a coach) and the pitcher demo account would each be refused on
    the other card today. R7 removes that trap.
  - `SUBMIT.md`:55 ("splash, then sign-in") stays true.
- **Not affected:** privacy.html, terms.html, qr-print.html, emails and templates name no card.

## 8. What the existing rules make impossible as written, and the closest alternative

1. **"Each role reads exactly what it would read alone" can't hold in the database.** The database checks the login,
   not the role on screen, so a two-role login can read the union of its roles' rows.
   - What can hold: (a) the union, never more than each role allows on its own, proven by item 6's matrix; and (b) the
     app shows each role only its own screens.
   - Example: a coach who is also a pitcher on Team B can, through the API, read their own Team B sessions while in
     the coach role. They could read those anyway.
   - Recommend accepting this framing.
2. **The primary can't move between profiles** (item 6). The alternative is `opens_profile`: the same effect for
   sign-in, while age, terms and verification stay on the login's own profile.
3. **Parent and sport.**
   - A parent profile has no sport (S:5061). The sport chosen at sign-up becomes the first player's sport on "Create
     your pitcher's profile" (preselected; changeable there, as now).
   - A parent's later players can be either sport.
4. **Under 13 on the one form.** P1-10 has no self-serve under-13 path. A pitcher answering "under 13" is sent to the
   Parent path with what they typed carried over, and the form switches to Parent with a note. **The adult re-enters
   the email and password as their own**: the account becomes the parent's.
5. **Fields today's forms collect that the one form doesn't**, asked inside the app straight after Create account:
   - Coach: **team name** (coach-signup.html; `ensure_account_setup` makes the team). Today's in-app "Create your team"
     screen already asks for it (BT, the setup screen seen on Nov 18).
   - Pitcher: **level** (`intended_level`, P2) → asked on a one-time screen. Throws stays in Pitcher settings.
   - Parent: **the player** (name, sport, throws, consent) = "Create your pitcher's profile" (today's add-player screen).
   - Facility: **facility name** (and the two levels operators set today). It's a Facility-only field on the form, so
     the facility exists on Create account (Stage B).
   - 13–17 pitcher: **the guardian's email** (P1-10). It stays on the form, shown only for that answer, because the
     approval email goes out at sign-up.
6. **Facility before Stage B:** the Facility card shows today's contact wording, and Create account stays disabled (as
   the packet says).
7. **A facility manager deleting their account** is refused (`still_head`, S:3702-3735) until they hand both sides
   over. But `handoff_facility` has no button in the app, and the Account "Hand off head coach" isn't facility-aware
   (BT:15431-15444). Handing one side off that way leaves `manager_login` on the old login.
   - Also, `organizations.manager_login` has no ON DELETE, so a purge whose facility teams were deleted would fail at
     `deleteUser` (delete-account/index.ts:220).
   - Recommend: Stage C keeps the refusal and adds a facility hand-off in Account, or a separate small fix. **Joel's
     call.**

## Store submissions

- iOS build 34101 was submitted to App Review on Nov 17 (manual release). The store apps load the live site, so
  **anything shipped to production changes the app under review**.
- **Recommend:** build A, B and C on staging now, and ship none to production until Apple's decision. Then:
  - if approved: release the app, ship Stage A, rewrite `store/review-notes.md` (one sign-in; the demo accounts sign
    in on the same page), and replace the Play screenshot `phone-5-sign-in.png` before the Play listing goes out;
  - if rejected: fold Stage A into the resubmission, with the notes and screenshots redone.
- Play: internal testing only, no review in progress.
- **Joel decides.** I don't know whether Apple has answered yet.

## Questions for Joel, each with a recommendation

1. **App Review status:** has Apple answered on build 34101? *Recommend:* hold every R7 production ship until it has.
2. **Decision 1:** confirm "2" meant open, self-serve facility sign-up. *Recommend:* as written.
3. **Self-serve facility before paying:** what it gets, and the landing page's "Email us" line. *Recommend:* full
   features (as operator-made ones) until pricing exists; replace "Running a facility? Email …" with "Running a
   facility? Create a facility account".
4. **The four sign-up pages:** keep them as forwards to Create account (type and sport preselected). *Recommend:* yes.
5. **Device limit:** the daily cap and your email instead of a per-device limit. *Recommend:* yes; Turnstile only if
   abused.
6. **"Never merges":** accept "the union, never more" (item 8.1). *Recommend:* yes.
7. **Choosing the opening role:** `opens_profile` instead of moving the primary (item 8.2). *Recommend:* yes.
8. **Facility manager leaving:** keep `still_head` and add a facility hand-off button in Stage C? *Recommend:* yes, in
   Stage C.
