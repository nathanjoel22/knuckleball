# H1 — Hardening: saved sessions locked in the database (P1-16) + rate limits (P1-06) (Oct 3, 2026)

**Why now.** P1-10 is done, so of the Phase 1 work that must finish before programs #2–3 (C2), what remains is P1-16, P1-06, P1-09, P1-07 and P1-11. Of those, P1-16 and P1-06 are both about closing doors before more people walk through them. Oct 2's three security fixes showed that gaps of this kind are real here. The site now also has several public forms that send email (pitcher signup, parent signup, guardian approval, Change Email), which is exactly what gets abused once a site is visible.

**Part 1 — P1-16.** Amendment 2 says saved sessions are final, but today that's a UI convention. Any pitcher can still change a saved pitch through the API (re-confirmed by P1-15 on Sept 25). After H1, the database refuses it. Only then can the honest claim become "saved sessions can't be changed", although the standing rule still forbids "tamper-proof", since the operator can always change data.

**Part 2 — P1-06.** Every function that sends email, or writes a report file, has per-user limits, a per-recipient limit and a daily circuit breaker that protects the Resend quota and the domain's reputation. Supabase's own Auth limits are checked and set deliberately.

## Decisions made in drafting (Joel may override)

1. **The lock is a trigger plus the policies, not just policies.** A BEFORE UPDATE trigger on `pitches` and `game_events` refuses any change once the parent session is saved, whoever the caller is. DELETE is refused by policy for normal callers, and P1-15's `delete_session()` (SECURITY DEFINER) keeps working. The session row itself can't be un-saved, and its identity columns (pitcher, kind, sport, team, start time) can't change after save. Columns written after save by design (report path and timestamp, the tombstone fields) stay writable.
2. **The offline queue becomes insert-only for pitches and events.** If the P1-01 outbox upserts (`ON CONFLICT DO UPDATE`), a retry of an already-synced pitch after the session is saved would hit the lock and get stuck, which is the "stuck sync" failure class. It switches to insert-and-ignore-duplicates. In-session corrections (P1-05 as shipped) keep their UPDATE path while the session is unsaved. This is the insert-only half of SC2, done now because the lock requires it.
3. **Limits (starting values, all in one config table so they can be tuned without a deploy):**

| What | Per user | Other |
|---|---|---|
| Report **emails sent** | 40 / hour, 150 / day | each recipient address ≤ 20 Knuckleball emails / day |
| Report **files generated** (no email) | 60 / hour | — |
| Verification emails | 5 / hour | recipient ≤ 10 / day |
| Guardian approval emails | existing 10-minute resend rule; 3 / day | one guardian address per account (P1-10) |
| **All Knuckleball email, everyone** | — | daily circuit breaker at 90% of the Resend plan's daily quota (env var); above it, sends refuse with a clear message and Joel gets one alert email |

A coach sending reports to 15 pitchers after a pen day uses about 15 sends; 40 an hour never touches normal use. Over a limit, the function returns 429 with a human-readable message that the UI shows as-is ("You've sent a lot of reports in the last hour. Try again at 4:15 PM.").

4. **Not rate-limited, on purpose:** the anon lookups (`get_report_notes`, the invite resolvers, `record_guardian_consent`). They all take 64-hex or similarly long tokens, so guessing is infeasible; per-IP limiting in Postgres isn't worth the complexity. Recorded as a known decision.
5. **Supabase Auth's own limits** (signups, password-reset and email-change emails, token refreshes) are read from both dashboards, reported, and set deliberately **in the dashboard by Joel**, never with `supabase config push`. A CAPTCHA on signup (Cloudflare Turnstile is supported by Supabase) is the next step if signups are ever abused. It's out of scope now and recorded.

---

## The packet (paste for Claude Code)

```
ID:              H1
Title:           Hardening — lock saved sessions in the database (P1-16) and
                 rate-limit every email/report function (P1-06)
Goal:            Part 1: once a session is saved, no caller can update its pitches
                 or game events, un-save it, or change who/what it belongs to; the
                 offline queue is insert-only so retries can never collide with the
                 lock. Part 2: every function that sends email or writes a report
                 file enforces per-user, per-recipient and global daily limits from
                 one config table, returning a clear 429; Supabase Auth limits are
                 reported and set deliberately.
Spec:            claude/h1-hardening.md (save in the repo as plans/h1-hardening.md).
Depends on:      P1-01, P1-05 (in-session corrections), P1-15 (delete_session), P1-10
                 (guardian email), S3, G3, S4. All shipped.
Staging only.    Only Joel ships to production. Migrations staging first; fresh
                 production backup first. Show policy and trigger SQL before
                 applying.

PRECONDITIONS — REPORT, with file and line numbers, before any SQL or code:
  1. How a session is marked saved (column and value) and every column written
     on a session AFTER it is saved (report_path, report_generated_at, tombstone
     fields, anything else) — these must stay writable.
  2. Every UPDATE and DELETE path on pitches and game_events: client (P1-05
     in-session edit/remove, Undo), the outbox, RPCs, triggers, delete_session.
  3. The P1-01 outbox: insert, upsert or both, per table; what it does on a
     conflict; whether a pitch can still be queued after its session is saved
     (offline save, then reconnect).
  4. The current pitches / game_events / sessions policies (FOR ALL or per
     command) and the policy count (expect 35 on production).
  5. Every function that sends email or writes a report file: names, callers,
     what they send, to whom; the Resend plan's daily and monthly quota.
  6. Supabase Auth rate-limit settings on staging and production (read from the
     dashboard, change nothing): emails per hour, signups, token refresh, OTP.
  7. Whether staging Auth uses custom SMTP (Joel saw a Change Email message from
     noreply@mail.app.supabase.io on staging) — report only.
  Build nothing until Joel has read the report.

PART 1 — P1-16 (migration h1_saved_lock)
  - BEFORE UPDATE trigger on pitches and on game_events: if the parent session
    is saved, RAISE 'session_saved_locked'. Applies to every caller.
  - pitches / game_events: split any FOR ALL policy into per-command policies;
    UPDATE and DELETE allowed only while the parent session is unsaved (DELETE
    of a saved session's rows happens only inside delete_session(), which must
    keep working — prove it).
  - BEFORE UPDATE trigger on sessions: a saved session cannot become unsaved;
    pitcher, kind, sport, team and start time cannot change after save; the
    post-save columns from precondition 1 stay writable.
  - Outbox: pitches and game_events become insert-and-ignore-duplicates (no
    ON CONFLICT DO UPDATE). In-session edits keep their explicit UPDATE while
    the session is unsaved. A queued insert for an already-saved session still
    lands if the row doesn't exist yet (offline save, then reconnect).
  - Policy count before/after reported; no policy references teams and
    pitcher_teams directly (42P17).

PART 2 — P1-06 (migration h1_rate_limits)
  - rate_limit_config (one row per limit: key, window, max) and
    rate_limit_events (who, what, recipient, at) — neither readable or
    writable by clients; only the server functions touch them through a
    SECURITY DEFINER check-and-record function with search_path ''.
  - Limits per the spec's table: report emails 40/hour and 150/day per user;
    each recipient ≤ 20 Knuckleball emails/day; report generation 60/hour per
    user; verification emails 5/hour per user and ≤ 10/day per recipient;
    guardian emails 3/day per account on top of the 10-minute rule; a global
    daily circuit breaker at 90% of the Resend daily quota (env var), which
    also sends Joel one alert email per day when tripped.
  - Over a limit: HTTP 429 with a human-readable message including when to try
    again; the UI shows it as-is. Generating without emailing never counts
    against email limits. Old rate_limit_events rows pruned after 7 days.
  - Report Supabase Auth's limits (precondition 6) with a recommendation;
    Joel sets them in the dashboard. Never `supabase config push`.

OUT OF SCOPE: CAPTCHA (recorded as next step); per-IP limits; limiting the anon
  token lookups (recorded decision); SC1/SC2 beyond the outbox change; the
  Change Email single-email fix (separate, pending its report).

ACCEPTANCE
  1. On staging, as the owning pitcher, a direct PostgREST UPDATE and DELETE on
     a saved session's pitch and game event are refused (show the errors); the
     same on an unsaved session succeed; in-session edit and Undo still work.
  2. delete_session() on a saved session still removes its pitches and events
     and leaves the tombstone (P1-15 acceptance rerun).
  3. A saved session can't be un-saved and its pitcher/kind/sport/team/start
     time can't change (show each refusal); report_path and the tombstone
     fields still write.
  4. Offline: chart a pen, save it offline, reconnect → every pitch lands, no
     errors, nothing stuck. Replay the outbox a second time → 0 new rows, no
     errors (insert-only proven). P1-01 offline checks 1–3 pass in both sports.
  5. Report emails: the 41st in an hour returns 429 with the message; resets
     after the window; the 21st email to one recipient in a day is refused;
     generating without emailing doesn't count. Scripted on staging.
  6. Verification and guardian limits hit and reset as specified.
  7. Circuit breaker: set the env var low on staging, trip it, see the refusal
     message and exactly one alert email to Joel.
  8. A normal day — a coach charting 15 pens and sending all 15 reports, plus
     a live game report — never hits a limit.
  9. rate_limit_* tables: a direct select/insert as any client is refused.
  10. Policy count and trigger list before/after; schema.sql regenerated;
      CLAUDE.md updated (the lock, insert-only outbox, limits); CACHE_VERSION
      bumped.
VERIFICATION: Staging scripts for 1–9; Joel charts one pen offline on his phone,
  saves, reconnects and confirms it lands. Production after a fresh backup.
ROLLBACK: Down migrations written before deploy (drop the triggers, restore the
  previous policies verbatim from schema.sql, drop the rate-limit tables);
  git revert; redeploy the Edge Functions.
SIZE: M–L.
ESCALATE IF: the outbox can't become insert-only without risking a stuck
  queue; delete_session can't coexist with the DELETE policy; any post-save
  column write is blocked by the session trigger and can't be carved out
  cleanly; a limit would block the normal-day scenario in acceptance 8.
```

## Amendment, Oct 3, 2026 — Part 3: make the privacy page true

P1-10's evidence check found four privacy-page sentences that the app honors but the database doesn't enforce. Part 1 already fixes the first (saved sessions final). H1 now also fixes two more, so the published text becomes true rather than being softened. The fourth (leaderboard wording) is a text fix in P1-10's pages, approved by Joel separately.

**3a. Deletion only through the tombstone.** Today the pitcher or any coach of the team, assistants included, can delete a session row directly through the API, leaving no tombstone. After H1: no client DELETE policy on `sessions` at all. Deleting goes only through P1-15's `delete_session()`, which writes the tombstone. Who may call it: the pitcher (own sessions) and the team's **head coach**. Assistants can't delete (R6: assistants don't administer). **Joel, Oct 3: confirmed — assistants can't delete.**

**3b. Reports are emailed only to known addresses.** Today `send-session-report` accepts up to 3 addresses from the browser without checking them, so a signed-in user could have the server email a report link to anyone. **Joel, Oct 3: a report can be emailed to anyone the player has saved in their profile's report contacts, and to no one else.** The player (or the parent, for a parent-created player) adds, edits and removes those contacts in Profile; coaches send to the player's saved contacts and can't type in other addresses. Any other address is refused with a clear message. Generating and viewing without emailing are unchanged. H1 Part 2's per-recipient daily limit applies to every saved contact.

Add to the paste block, after PART 2:

```
PART 3 — make the privacy page true (amendment Oct 3)
  3a. sessions: drop every client DELETE policy; deletion only via
      delete_session() (SECURITY DEFINER, writes the tombstone). Callable by the
      pitcher for own sessions and the team's head coach; assistants refused.
  3b. send-session-report: every recipient must be one of the pitcher's saved
      report contacts (edited only by the pitcher, or the parent for a
      parent-created player, in Profile). Anything else → 400 with a clear
      message; nothing sent. Coaches send to those contacts and can't enter
      others. Generate-only and View unchanged. Report (precondition) where
      the contacts live today and who can edit them.
  Acceptance (add):
  12. A direct DELETE on a session as the pitcher, a head coach and an
      assistant is refused (show each); delete_session() works for the pitcher
      and head coach and is refused for an assistant; the tombstone is written.
  13. A crafted report request naming an address that isn't a saved contact is
      refused and no email is sent (as pitcher and as coach); saved contacts
      still work; a coach can't edit a pitcher's contacts (UI and direct call).
  14. Re-read the privacy page's "saved sessions are final", deletion and
      "reports go only to…" sentences against the database and confirm each is
      now enforced (closes P1-10 check 12's findings 1–3).
```

### Standing constraints (in force)

Service-role key never outside Edge Function env vars. Every schema/RLS change via migration, staging first, fresh backup before production; show policy SQL first. No policy references `teams` and `pitcher_teams` directly (42P17). Saved sessions immutable — now enforced; still never describe data as "tamper-proof". Confirm email stays OFF; never `supabase config push` for Auth. P1-01 offline behavior must not regress. **Only Joel ships to production.**
