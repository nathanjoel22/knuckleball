# H1 acceptance evidence

Packet: `plans/h1-hardening.md` (with the Oct 3 Part 3 amendment and Joel's Oct 3 decisions:
atomic `sync_session` with a seal, a 14-day grace path for old app versions, assistants can't
delete, reports only to saved contacts). Applied to **staging** Oct 4 2026 (Joel OK): migrations
`20261003000000_h1_saved_lock.sql`, `20261003010000_h1_rate_limits.sql`; functions
send-session-report, send-verification-email, send-removal-notice, send-guardian-consent,
request-email-change; staging secrets `RESEND_DAILY_QUOTA=100`, `ALERT_EMAIL`; app v145.
Database scripts: `supabase/tests/h1_part1_acceptance.sql`, `supabase/tests/h1_part2_acceptance.sql`
(run live on staging Oct 4, rolled back). Production: pending Joel's ship.

| # | Check | Result |
|---|-------|--------|
| 1 | Direct UPDATE/DELETE on a saved session's pitch and event refused; in-session edit and Undo still work | PASS. Pitcher: 0 rows each (no update/delete rule); the lock also refuses the table owner (`session_saved_locked`). Adding to a sealed session: `session_sealed_locked`. Edit + Undo while charting: Joel, Oct 5 (baseball pen, 13 pitches, sealed) |
| 2 | delete_session removes pitches and events, leaves the tombstone | PASS. 130-pitch game deleted by its pitcher: tombstone `pitcher`, pitch_count 130, 0 pitches and 0 events left; head-coach delete likewise |
| 3 | Saved session can't be un-saved; pitcher/kind/sport/team/start can't change; report_path and tombstone still write | PASS. Each change refused; fake tombstone and unseal refused for API callers; report_path write 1 row; delete_session writes the tombstone |
| 4 | Offline save → lands; replay → 0 new rows; offline checks both sports | PASS on staging: softball (`+p110sb1`, Oct 4) and baseball (`stagingsmoke`, Oct 5) pens saved via v145 → sealed, all pitches. Retry → `already_saved`, 0 rows; the app clears the item and tells the user (harness). Joel's phone check: at the production ship |
| 5 | Report emails: 41st/hour refused, resets; 21st to one address/day refused; generate-only doesn't count | PASS (scripted). Messages: "You've sent a lot of reports in the last hour. Try again in 60 minutes." / "One of these addresses has received a lot of Knuckleball email today..." |
| 6 | Verification and guardian limits | PASS (scripted): 6th verification/hour, 11th to one address/day, 4th guardian/day refused; Change Email 6th/day refused |
| 7 | Circuit breaker: refusal + exactly one alert | PASS. Scripted (cap 3: #4 refused with alert, #5 refused without). Live Oct 5: quota set to 1 on staging, Joel's coach tapped Send report twice → the limit message both times, exactly one alert email to joelhauserman@gmail.com, 1 `breaker_alert` row, 0 report emails got through. Quota restored to 100 |
| 8 | A normal day never hits a limit | PASS (scripted): 16 report emails to 47 addresses + 15 report views → 0 refusals |
| 9 | rate_limit_* tables refused to clients | PASS: select/insert/config/RPC refused for authenticated and anon |
| 10 | Policies and triggers before/after; schema.sql; CLAUDE.md; CACHE_VERSION | 35 → 35 during grace (→ 29 when the grace path closes); triggers `sessions_h1_lock`, `pitches_h1_lock`, `game_events_h1_lock`; CLAUDE.md updated; v145. schema.sql: at the production ship |
| 12 | Direct DELETE refused for pitcher, head coach, assistant; delete_session: pitcher and head coach yes, assistant no | PASS: 0 rows ×3; assistant `not entitled to delete this session` |
| 13 | Crafted report to a non-saved address refused (pitcher and coach), nothing sent; saved contacts work; coach can't edit contacts | PASS. Live Oct 5: pitcher `+p110sb1` and coach `+malachistaging` (for `stagingsmoke`) → `400 recipient_not_saved`, no send recorded. Normal Send report from the coach → one email to both saved contacts (send log shows both; Gmail shows one copy because both are the same inbox). Coach editing a pitcher's contacts: 0 rows; Contacts panel hidden for coaches |
| 14 | Privacy sentences now enforced | PASS, with the grace-period nuance below |

**Joel's added acceptance (Oct 3):**
- *An unsaved session is visible nowhere:* no path can create one (direct insert refused by
  `ended_at is not null`; `sync_session` returns `not_saved`). Production has 0. Staging has 2
  old test rows (Sept 23, Sept 26) that no device holds — to be shown to Joel before the grace
  path closes.
- *A 130-pitch game with events syncs in one call:* `{"ok":true,"status":"saved","pitches":130,"events":10}`;
  the exact payload the real app code builds stored with 0 field mismatches.
- *A retry returns "already saved" with zero new rows:* yes, even with an extra pitch added.
- *A v144 client's queued pen still syncs during the grace period:* yes — scripted (a half-done
  sync then its retry lands all pitches), and live on staging Oct 4 from the v144 app: `+p110sb2`
  (softball) and two `stagingsmoke` pens (baseball), 10 pitches each, saved and unsealed as
  designed.
- *How today's outbox handles a refused insert:* it keeps the item with its reason and retries
  on the next sync; it never discards. v145 keeps that for every refusal except `already_saved`,
  which clears the item and tells the user.
- **Absorbs SC2** (insert-only sync).

## Check 14 — the privacy page against the database (staging, Oct 5)

1. **"Saved sessions are final: pitch data can't be edited after a session is saved."** Enforced:
   `pitches_h1_lock` / `game_events_h1_lock` refuse any change to a saved session's pitches and
   events for every caller, and `sessions_h1_lock` refuses changes to the session itself.
   **Nuance during the grace period:** a saved session written by an old app (v144 or earlier)
   stays unsealed until the grace path closes, so new pitches could still be *added* to it by a
   crafted request (existing ones can't change). Sessions saved by v145 are sealed at once. When
   the follow-up migration seals every remaining session and drops the grace rules, the sentence
   is fully true. Staging has 48 such unsealed sessions (recent ones; older ones were sealed by
   the migration).
2. **Deletion** ("a pitcher can delete their own sessions, and a head coach can delete their
   team's... a marker stays in history"). Enforced: 0 client DELETE (or FOR ALL) rules on
   sessions, pitches or game_events; deleting is only `delete_session()` (pitcher or head coach;
   assistants refused), which always writes the tombstone.
3. **"Reports go only to the addresses on your account."** Enforced: `send-session-report`
   refuses any recipient that isn't one of the player's saved report contacts (400, nothing sent),
   for pitchers and coaches alike.

## Preconditions 6–7 — Supabase Auth email (Joel, from the dashboards, Oct 5)

| | Staging | Production |
|---|---|---|
| Auth emails per hour | 2 (Supabase's fixed limit for its built-in sender) | 50 |
| SMTP | built-in (`noreply@mail.app.supabase.io`) | custom: `smtp.resend.com`, sender `nate@knuckleballonline.com` |

Only two kinds of email still go through Supabase Auth: password resets and coach invites of
brand-new pitchers (`invite-pitcher`). Recommendation: keep production at 50/hour (a full roster
invite plus resets fits). Staging's 2/hour is fine for testing but can't exercise bulk invites
(landmine 6).

Because production's Auth SMTP is Resend, invites and resets use the same 100/day free quota but
are not counted by H1's circuit breaker (it sees only Knuckleball's own functions). Today's daily
email volume is far below 100 (most reports are opened by link, which uses no email). Options if a
roster-invite day ever coincides with heavy report sending: set production `RESEND_DAILY_QUOTA`
to 70 (breaker at 63, ~30 left for invites/resets), or move to a paid Resend plan and raise the
quota to match. The other Auth rate-limit rows (sign-ups/sign-ins, token refresh, verifications)
were not reported; nothing in H1 depends on them.

## Still open

- Production: fresh backup; apply both migrations; deploy the five functions; set
  `RESEND_DAILY_QUOTA` and `ALERT_EMAIL`; push v145 to main; regenerate schema.sql; Joel's phone
  offline pen + P1-01 offline checks 1–3 in both sports.
- The grace-closing migration: ≥ 14 days after the production deploy, once production shows a
  week with no old-path writes; show Joel unsealed/unsaved leftovers first.
