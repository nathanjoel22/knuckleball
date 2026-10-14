# A1 preconditions report (Oct 14, 2026)

Spec: `plans/a1-account-deletion-export.md` (GitHub main `2e3b28e`). Every fact here was read from **production** (read-only queries) and the repo. **No code changed.** Branch `a1-account-deletion`.

## Joel's answers (Oct 14, 2026)

1. **Tombstones:** a tombstone is only a record that the session happened. The date, the pitch count and "Deleted account" stay in the recording team's history, and it **can never be opened again**.
   - Its pitches, events, notes and report file all go.
   - Because `sessions.pitcher_id` CASCADEs, the row survives only by re-pointing it to the nameless "former account" stub before the profile is deleted.
2. **A coach deletes their account:** the sessions they charted **stay with the pitcher who threw them**, on that pitcher's account. "Charted by" shows "Former coach" (via the stub).
3. **Notes the deleted person wrote:** deleted.
4. **Backups:** a **one-week retention**. Backup dumps older than 7 days are deleted for good. With the 7-day grace, a deleted account is gone from the app after 7 days and from backups within 14.

## Summary: what Joel was asked (four escalations, the spec's own triggers)

1. **Tombstones vs the pitcher's deletion contradict each other, and the database decides it today.**
   - The spec's two positions:
     - Rule 3: each of the pitcher's sessions leaves a tombstone ("deleted account") for the recording team.
     - Drafting decision 3: his sessions go "everywhere, tombstones included."
   - What the database does: `sessions.pitcher_id → profiles` is **ON DELETE CASCADE**. Deleting a pitcher's profile deletes every session row, tombstones too, unless something else holds the profile.
   - **Options:**
     - **(a)** Remove everything, tombstones included (decision 3; simplest; closest to Apple's "all data").
     - **(b)** Keep a nameless stub profile so tombstones survive for the recording team.
   - **Proposed: (a).** The data subject is gone, and a team keeps no row about him. That also means rule 3's "through `delete_session()`" applies only to the coach case below.
2. **A coach's charted sessions and notes need a stub to point at.**
   - `sessions.logged_by`, `session_notes.author_id`, `invites.invited_by` and `team_coaches.invited_by` all reference `profiles` with **NO ACTION**: the database refuses to delete a profile they point to.
   - To keep a coach's charted sessions ("Former coach"), those rows must point at something. **Proposed:** one shared, nameless **"former account"** profile, a system row with no login, no email and no name. Rows are re-pointed to it before the delete.
   - Display "Former coach" / "Former player" comes from the row's role.
3. **The coach's notes: keep (spec rule 4) or delete (Apple)?**
   - Apple's deletion page (below) says people expect all associated data deleted, "including user-generated content that's shared with others" (text posts).
   - **Proposed:** delete the notes the person wrote. The charted sessions stay, because they're the pitcher's data (D3), not the coach's content.
4. **The privacy page doesn't say what the spec assumes:**
   - **(i)** It has **no backup sentence at all.** The spec says it "already says so".
   - **(ii)** There is **no backup retention to quote.** BACKUPS.md backups are manual dumps on Joel's Mac, kept indefinitely, so a deleted account would live on in them with no limit.
   - **(iii)** Deletion is currently promised **by email** ("email nate@… We answer within 30 days"). A1 changes that.
   - **Proposed:**
     - A retention rule for the manual dumps (e.g. delete dumps older than 30 days; Joel's call, done by Joel).
     - New policy wording: in-app deletion, the 7-day grace, backups kept up to N days.
     - Version bump 2026-10-05 → the A1 date.
   - All wording needs Joel's approval in the commit.

**Also needed (not escalations):**
5. **`delete_session()` can't run from the scheduled delete.** It checks `auth.uid()` (the pitcher or the team head), and the scheduled run has no login. With decision 1(a) it isn't needed for the pitcher. For anything else, a **service-role-only** helper does the same tombstone write.
6. **Apple wants a confirmation when deletion completes**, not only when it's requested. So the scheduled run sends a second email ("Your account has been deleted"), and sends it **before** the login's address is erased.
7. **Two storage places the spec misses:**
   - `headshots/<profile_id>.jpg` (profile photos);
   - `reports-archive/2026-10-06/<token>.html` (the private U12 originals of the 23 Cairn reports): a deleted pitcher's archived copies would otherwise stay.
   - Both are removed by the scheduled run.
8. **ZIP without a new dependency.** **Proposed:** a ~60-line "stored" (uncompressed) ZIP writer in the function, rather than adding `fflate` / `jszip` (CLAUDE.md: no new dependencies without approval). The largest account is ~0.5 MB uncompressed (below), so compression isn't needed.
9. **Scheduling.** `pg_cron` 1.6.4 and `pg_net` 0.20.4 are **available but not installed** on production. **Proposed:** install both on staging in the A1 migration, with a daily job that calls `delete-account` in execute mode.
   - Production gets the same migration (it's a schema change, so after a fresh backup, Joel ships).
   - The call needs a secret header: a new function secret, set by Joel in the dashboard / CLI.
10. **"Signed out on a second device within a minute"** needs more than token revocation.
    - `auth.admin.signOut(jwt, 'global')` revokes every refresh token, but an access token stays valid until it expires (1 hour by default).
    - **Proposed:** the app checks `deletion_requested_at` on every online load and focus, and shows the interstitial.
    - Offline devices keep charting (CLAUDE.md's design principle). Their sessions sync if the account is restored, and are refused once it's hard-deleted. The outbox shows why.

## 1. Every row tied to a login or profile (production foreign keys)

| Table.column | → | ON DELETE | Null? | What A1 does |
|---|---|---|---|---|
| profiles.account_id | auth.users | CASCADE | NOT NULL | the login's profiles go with the auth user |
| profiles.managed_by | profiles | CASCADE | nullable | parent-created players go with the parent's profile |
| teams.coach_id (head) | profiles | CASCADE | NOT NULL | **blocked first** (rule 5: no head teams left; `sessions.team_id` is RESTRICT anyway) |
| teams.archived_by | profiles | SET NULL | nullable | fine |
| pitcher_teams.pitcher_id | profiles | CASCADE | NOT NULL | memberships go |
| team_coaches.coach_id | profiles | CASCADE | NOT NULL | staff rows go |
| team_coaches.invited_by | profiles | NO ACTION | nullable | re-point to the former-account stub (or NULL) |
| invites.invited_by | profiles | NO ACTION | NOT NULL | delete the person's sent invites |
| sessions.pitcher_id | profiles | **CASCADE** | NOT NULL | escalation 1 |
| sessions.logged_by | profiles | **NO ACTION** | NOT NULL | escalation 2 (stub) |
| sessions.deleted_by | profiles | NO ACTION | nullable | stub; `deleted_by_name` blanked |
| session_notes.author_id | profiles | **NO ACTION** | NOT NULL | escalation 3 |
| accuracy_zones.pitcher_id / .updated_by | profiles | CASCADE / SET NULL | | fine |
| leaderboard_exclusions.excluded_by | profiles | SET NULL | | fine |
| roster_seen.pitcher_id / .viewer_id | profiles | CASCADE | | fine (red-dot state) |
| session_opened.viewer_id | profiles | CASCADE | | fine (red-dot state) |
| pitcher_team_departures.pitcher_id | profiles | CASCADE | | fine |
| pitches / game_events / session_opened / session_notes .session_id | sessions | CASCADE | | follow their session |

**Tied without a foreign key** (the spec's escalate-if: none blocks the function; it handles each by name):
- `rate_limit_events.actor` (uuid) and `.recipient` (email): pruned after 7 days already. **Proposed:** delete the actor's rows at execute.
- `invites.email`: pending invites addressed to the login's email. Delete.
- `profiles.contact_emails` / `guardian_email` / `email_*` columns: go with the profile row.
- Storage: `reports` (`<token>.html`), `reports-archive/2026-10-06/<token>.html`, `headshots/<profile_id>.jpg`. All three are removed by the function with the admin client.

**Policies:** 34 public RLS policies on production today (the RLS matrix is run on staging before and after the migration).

## 2. `delete_session(p_session_id uuid)` (production)

- `SECURITY DEFINER`, `search_path ''`.
- Refuses when `auth.uid()` is null. Allowed: the session's pitcher (`is_my_profile`), or the team's head (`is_team_head`).
- **Writes the tombstone:**
  - `deleted_at`;
  - `deleted_by` (the actor's profile);
  - `deleted_by_role`;
  - `deleted_by_name`, **the actor's full name (PII)**;
  - `pitch_count`.
- **Removes:** the session's `game_events` and `pitches`.
- **Keeps:** the session row, its `session_notes`, `report_path`.
- **Returns** `report_path`. The report **file** is removed by `send-session-report` (index.ts:162, its delete mode, with the admin client).

## 3. Logins, profiles, players, guardians

- **S4 A:** a login (`auth.users`) owns profiles via `profiles.account_id`. The primary profile has `id = account_id`.
  - Production: 56 profiles, 3 of them not primary.
- **S4 B:** a parent-created player has `managed_by` = the parent's primary profile and `account_id` = the parent's login.
  - Production: 1. Deleting the parent's login removes the player, by both cascades.
  - **Rule 6's** "parent deletes a created player" is a profile-level delete: the player's sessions go by `sessions.pitcher_id` CASCADE, and the parent's login stays.
- **P1-10 guardian fields** live on the login's **primary** profile:
  - `age_attestation`, `attested_at`, `attested_via`, `terms_version`, `guardian_email`, `guardian_consent_token`, `guardian_consent_sent_at`, `guardian_consented_at`, `consent_via`;
  - production: 1 profile has a guardian email.
  - `guardian_email` and the token are never client-readable, so the function reads them with the admin client to send the minor's guardian email.

## 4. Team heads, handoff, archive

- **Head:** `teams.coach_id`; `is_team_head(team)`.
- **Handoff:** `hand_off_team_head(p_team_id, p_new_head_id)`.
- **Archive / restore:** `archive_team` / `restore_team`. **Delete:** `delete_team` (only with no sessions; P1-09).
- Assistants leave via `remove_coach(team, coach)`.
- **The block screen links to:** the team's settings (handoff to an assistant, or archive). Delete is shown only when the team has no sessions. **Proposed:** an **archived** team still blocks.
  - Its `coach_id` would CASCADE-delete the team, and `sessions.team_id` RESTRICT makes that fail. So a head of an archived team must hand it off too, or delete it when empty.

## 5. Email and limits

- One-off emails already go through Resend directly in each function: e.g. `send-removal-notice/index.ts:79` calls `takeRateLimit(user.id, 'removal_notice', [toEmail])`, and line 88 calls Resend.
- **Reusable as is:** add `'account_deletion'` (and `'account_export'`, for the export's 3/day) to `RateKind` in `_shared/rate_limit.ts`, plus two `rate_limit_config` rows.
- The per-recipient limit (20/day) and the 90% circuit breaker apply automatically.

## 6. The privacy page (Version 2026-10-05) and backups

Its exact sentences today:
- "To get a copy of your data, or to delete your account and its data, email nate@knuckleballonline.com from your account's email address. We answer within 30 days. A parent can ask the same for a player they added."
- Section "(f) Export and deletion" (header only), and in the intro: "to have it exported or deleted."
- **No sentence about backups.**
- **BACKUPS.md:** manual dumps in `~/knuckleball-backups/` on Joel's Mac, no retention stated, and no platform backups (free tier).

These need new wording and a version bump; see escalation 4.

## 7. Supabase Auth

- **The function can delete the login:** `admin.auth.admin.deleteUser(id)` from an Edge Function with the service role in env (the same pattern as `request-email-change`'s admin `generateLink`).
  - It CASCADEs `profiles` (escalations 1–2 decide what must be moved first).
- **Sign-out everywhere does not exist in the app today:** it calls `supabaseClient.auth.signOut()` (this device only).
  - `admin.auth.admin.signOut(<caller's JWT>, 'global')` revokes all refresh tokens at request time.
  - Existing access tokens live until expiry (default 3600 s), hence the in-app check (item 10).

## 8. Export size

- **The largest production account** (a head coach; the three logins sharing that team): 68 sessions, 1,546 pitches, 7 game events.
- At about 300 bytes per pitch row (≈35 columns), that's about 0.5 MB uncompressed, all files together.
- An Edge Function builds that in memory comfortably, so no streaming is needed.

## 9. Apple, guideline 5.1.1(v) and its deletion page

- **5.1.1(v):** "If your app supports account creation, you must also offer account deletion within the app."
- **From Apple's "Offering account deletion in your app"** (paraphrased):
  - Deletion must be **initiated in the app**, and must delete **the whole account record and associated personal data**. Deactivation alone isn't enough.
  - A **waiting period is fine**, as long as the person is told how long it takes **and gets a confirmation when deletion is complete.**
  - Confirmation steps are allowed. Making it "unnecessarily difficult" fails review, and non-regulated apps may not require emailing support.
  - People expect user-generated content shared with others to be deleted too.

**Against the spec:**
- In-app start with a typed DELETE: ✓.
- Seven days, stated, with a date: ✓.
- A completion email: **add** (item 6).
- Notes: **delete** (escalation 3).
- Today's privacy-page flow ("email nate@") is exactly what Apple says not to require, so A1 replaces it.
