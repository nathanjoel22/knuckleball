# P1-10 acceptance evidence

Packet: `plans/p1-10-age-attestation-and-policies.md`. Shipped to production Oct 2 2026
(backup 2026-10-02-1044, frontend v140; current v143). Recorded Oct 3 2026 at Joel's
request. "Staging" = `wpsscxwawgiwmifpjpec`, "production" = `fkgccjhuimkkbupbanxp`.

| # | Check | Status |
|---|-------|--------|
| 1 | New adult pitcher, landing + join link, both sports | PASS. Baseball Oct 2; softball Oct 3 (below) |
| 2 | 13–17: gate refuses a hand-crafted report request | PASS. DB Oct 2; crafted HTTP request Oct 3 (below) |
| 3 | Guardian link approve / reuse / themed, both sports | PASS. Baseball Oct 2; softball Oct 3 (below) |
| 4 | Under 13 stopped, no auth user or profile (SQL) | PASS (below) |
| 5 | Coach adult-only; coach minor attestation refused | PASS (Oct 2: `coaches_must_be_adults`) |
| 6 | Joins refused with NULL attestation | PASS (Oct 2: both `attestation_required`) |
| 7 | Catch-up screen, recorded 'catchup' | PASS. Production rows show `adult / catchup` for coach logins. Offline "Connect to continue" superseded by Joel's decision: the box is never shown offline |
| 8 | Offline cold launch < 1 s for an attested account | PASS (Oct 3, Joel's phone: "basically immediate") |
| 9 | Roster "Guardian pending"; secrets not selectable | PASS (Oct 2) |
| 10 | Guardian send: 10-min limit, `<b>` escaped, stored recipient only | PASS. Limit + stored recipient: Oct 2 (DB). Real email Oct 3: name shown literally as `<b>Test</b>`, not bold (below) |
| 11 | Policy pages live, zero JS, linked everywhere | PASS (below) |
| 12 | Joel approved texts; (a)/(c)/(d) evidence shown | Approval: commit 951628c (and 577507e for Version 2026-10-03). Evidence: below. Wording corrections: see "Claims that need different wording" |
| 13 | No "cannot access", "one person", "tamper-proof"; says "small team" | PASS (grep, below) |
| 14 | Policy count before/after; P1-01 offline 1–3 both sports; CACHE_VERSION | PASS (35/35; Joel ran offline checks Oct 2 after v143; bumped) |

## Check 4 — under 13 (Oct 3, staging, headless Chrome on the local staging site)

Each form was filled with a fake `example.invalid` address, "Under 13" picked, terms ticked,
the disabled button force-enabled, and the form submitted. Every page showed "Players under
13 need a parent or guardian to create their profile..." and sent **no request** to Supabase
(no `auth/v1/signup`). Pages: `pitcher-signup.html?sport=softball`, `?sport=baseball`,
`join.html?t=<Staging Softball Team>`.

SQL on staging afterwards — every attempted address has 0 auth users and 0 profiles:
`u13-landing-softball@`, `u13-landing-baseball@`, `u13-join-softball@` (and the four check-1
addresses below). The database itself has no under-13 value:
`CHECK (age_attestation = ANY (ARRAY['adult','minor_13_17']))`, and
`record_attestation('under_13')` returns `invalid_status` (Oct 2).

## Check 1 — form blocking, softball (Oct 3, same method)

| Page | Missing | Message | Requests sent |
|---|---|---|---|
| pitcher-signup.html?sport=softball | age | "Tell us how old you are." | none |
| pitcher-signup.html?sport=softball | terms | "Agree to the Terms and Privacy Policy to continue." | none |
| join.html (softball team) | age | "Tell us how old you are." | none |
| join.html (softball team) | terms | "Agree to the Terms and Privacy Policy to continue." | none |

All pages rendered in the softball theme (`data-sport="softball"`).

**Softball accounts (Oct 3, Joel on the local staging site; verified by SQL on staging):**

| Account | Path | Profile | Team | Reports |
|---|---|---|---|---|
| `+p110sb3` | landing page (`pitcher-signup.html?sport=softball`) | softball pitcher, `adult`, `signup`, terms `2026-10-03b` | none ("not on a team yet") | not eligible — unverified and no team, the pre-P1-10 rule, as expected |
| `+p110sb1` | team invite link (Staging Softball Team) | softball pitcher, `adult`, `signup`, terms `2026-10-03b` | Staging Softball Team | email verified, 1 pen, 1 report generated; `is_pitcher_report_eligible` true |
| `+p110sb2` | (Joel unsure of path; joined the team) | softball pitcher, `adult`, `signup`, terms `2026-10-03b` | Staging Softball Team | email verified, 1 pen, 1 report generated; eligible |

## Check 11 — policy pages

`privacy.html`, `terms.html`: 0 `<script>` tags, 0 inline `on*=` handlers. Both links appear on
index, login, pitcher/parent/coach signup, join, join-coach, accept-invite, verify-email,
reset-password, guardian-consent, the tracker, report.html, and both report templates
(`template.ts`, `template_game.ts`).

## Check 12 — evidence for the Data-handling section

**(a) Team-scoped access is enforced in the database.** Production `pg_policies` (Oct 3), every
rule on the session tables:

| Table | Rule | Who |
|---|---|---|
| sessions | Pitchers manage own sessions | `is_my_profile(pitcher_id)` |
| sessions | Coaches manage / view sessions for their team | `is_team_coach(team_id)` |
| pitches | Pitchers manage pitches in own sessions | session's `is_my_profile(pitcher_id)` |
| pitches | Coaches manage / view pitches for their team's sessions | session's `is_team_coach(team_id)` |
| game_events | same two shapes as pitches | |
| session_notes | read: author, the pitcher, coaches of the session's team; add: coaches; delete: author | |

No rule grants any other user. Secret columns (invite tokens, verify and guardian tokens,
guardian email, email-change requests) have no client column grant (security fix + P1-10 +
Change Email migrations). Policy count 35.

**(c) No tracking, advertising, or analytics.** Grep of all 20 frontend files (html/js/css,
excluding vendored supabase-js): the only network host is the Supabase project
(`fkgccjhuimkkbupbanxp.supabase.co` in the committed config); `www.w3.org` appears only as the
SVG namespace. Tracker keywords (gtag, google-analytics, googletagmanager, plausible, mixpanel,
segment, hotjar, fbq, facebook.net, clarity, posthog, amplitude, sentry, datadog, fullstory,
doubleclick, adsbygoogle): no matches except two false positives ("pendin**gTag**").
`document.cookie`: never used. Live site (Oct 3): no external `<script src>` or
`<link href>` on index, tracker, report, privacy. The service worker only handles same-origin
requests (`sw.js:73`). Server side, the report function calls Resend (listed processor) and
imports code from esm.sh at deploy time; neither reaches a visitor's browser.

**(d) Encryption.** supabase.com/security (fetched Oct 3), verbatim: "All customer data is
encrypted at rest with AES-256 and in transit via TLS." The page does not limit it to a plan.
Region: both projects `us-east-1` (US East, N. Virginia) per `supabase projects list`.

### Claims that need different wording (found Oct 3)

These sentences describe what the app does; the database does not enforce them.

**Joel's decisions (Oct 3):** sentences 1–3 keep their wording and are made true in the
database by **H1** (Part 1 locks saved sessions; Part 3 makes `delete_session()` the only way
to delete — pitcher and head coach only — and limits report emails to the report contacts
the player saved in Profile). Sentence 4: wording changed to the accurate version below,
**approved by Joel, Version 2026-10-03b**.

1. **"Saved sessions are final: pitch data can't be edited after a session is saved."** The
   pitcher and the team's coaches hold edit rights on `pitches` rows and no trigger blocks
   edits after save. Accurate: "The app doesn't let anyone edit pitch data after a session is
   saved." (Or add a database guard — separate task.)
2. **Deletion** ("a head coach can delete their team's... a marker stays in history"). The app's
   path (`delete_session`) does exactly this, but the rules also let the pitcher or any coach
   of the team, assistants included, delete a session row directly, leaving no marker.
   Accurate: "In the app, a pitcher can delete their own sessions and a head coach can delete
   their team's..." (Or restrict direct deletes — separate task.)
3. **"Reports go only to the addresses on your account."** `send-session-report` accepts up to
   three addresses from the app and doesn't check them against the account. Accurate: "The app
   sends reports only to the addresses saved on the player's account." (Or check recipients
   server-side — separate task; this also stops a crafted request from mailing a report link
   to an arbitrary address.)
4. **(CHANGED, Version 2026-10-03b)** **Leaderboard "totals only... never individual pitches."** `get_team_leaderboard` also
   returns pitch counts and the id and time of each pitcher's fastest pitch. Accurate: "the
   team leaderboard, which shows rankings (peak velocity, accuracy, strike percentage) and pitch
   counts — never anyone's sessions, pitch charts, or notes."

## Check 13 — wording grep

`privacy.html`, `terms.html`: no "cannot access", "can't access", "one person", "tamper-proof";
"small team" present.

## Checks 2, 3, 10 — softball 13–17 account (Oct 3, staging)

Account `+p110minor`, full name `<b>Test</b>`, signed up via the Staging Softball Team invite
link: softball pitcher, `minor_13_17`, `signup`, terms `2026-10-03b`; `guardian_email` =
`+p110guardian` (the address typed); approval token set; guardian email sent 02:22 UTC.

- **Check 10:** the guardian email arrived only at the stored address `+p110guardian` and showed
  the name literally as `<b>Test</b>`, not bold (Joel). PASS.
- **Check 2 (first attempt):** crafted request from the console while unverified and unapproved →
  `403 {"error":"No report can be sent for this pitcher's sessions until their account email is
  verified and they're on a team."}`. Refused, but the account was ALSO unverified, so this does
  not isolate the guardian reason. Redo pending with `+p110minor2` (verify email first, then the
  crafted request, then approve). Note: the function's refusal text predates P1-10 and doesn't
  name the guardian reason — to be fixed in H1, which reworks that function.
- **Check 3 (softball):** a resend went out at 02:33:00 UTC and the guardian link was approved at
  02:33:18 → `guardian_consented_at` set, `consent_via = 'guardian_email'`, token cleared, email
  verified, `is_pitcher_report_eligible` true. A crafted request then got past the gate (`403
  "Session not found..."` — the session id was deliberately fake). The approval page was in the
  softball theme, and reopening the used link said it was already used (Joel). PASS.

**Check 2 (redo, isolated):** account `+p110minor2` (softball, `minor_13_17`, `signup`, terms
`2026-10-03b`, guardian `+p110guardian2`), via the Staging Softball Team invite link. Joel verified
the player's email and did NOT approve. Crafted request from the tracker's console (fake session
id, empty recipients) →
`403 {"error":"No report can be sent for this pitcher's sessions until their account email is verified and they're on a team."}`.
State at that moment (SQL): email verified = true, on Staging Softball Team, `guardian_consented_at`
NULL, approval token set, `is_pitcher_report_eligible` = false. Guardian approval was the only
missing condition, so the refusal is the guardian gate. PASS.

**Check 8:** Oct 3, Joel's phone, live site (https://knuckleballonline.com, v144), production
coach account that has attested: loaded once online, airplane mode on, app fully closed and
reopened → opened "basically immediate"; no age box. Timed by eye, not instrumented. PASS.

**All 14 acceptance checks: PASS (Oct 3 2026).** Check 7's offline "Connect to continue" was
replaced by Joel's decision (the box is never shown offline).
