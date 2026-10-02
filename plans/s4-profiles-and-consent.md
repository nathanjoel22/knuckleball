# S4 — One login, many profiles; parent-created players; consent and policies (Oct 2, 2026)

Saved from the packet Joel pasted on Oct 2, 2026 (the referenced `claude/s4-profiles-and-consent.md` did not exist in the repo). Decisions recorded at the bottom.

**What Joel asked for** (softball answers 5, 6, 9, 10, 43, 45): one email and password can run baseball and softball, and the two are never visible to each other. One login can hold several profiles, for example a parent with a son in baseball and a daughter in softball. A sport can be added from inside the account. Parental consent happens now, on the GameChanger model: in 9 cases out of 10 the parent signs up and then creates the child's profile. Keep it simple.

**What S4 replaces:** P1-10's deferred guardian design (D2) and the "slim P1-10". S4 ships the 18+ attestation, the privacy and terms pages and the Data-handling section, which C2 requires before programs #2–3. It also undoes S1's "refuse sign-in on the wrong sport or role", which can't survive one login owning two sports.

**Built and shipped in two stages, one packet.** Stage A is the profile model, the RLS rewrite, the profile switcher, "Add a sport" and the sign-in rework, with no child accounts and no consent. It's a refactor plus one feature, and it's verifiable on its own. Stage B adds parent-created players, attestation, guardian approval for teens who sign up themselves, the catch-up screen for existing accounts and the policy pages. Joel ships A to production and checks it on his own account before B is built.

## Three calls for Joel (packet written to these defaults)

1. **Teens who sign themselves up (13–17): keep a guardian-approval path.** Default yes. The teen names a parent's email, the parent taps Approve, and until then the teen can chart but gets no reports (P1-10's design). If no: cut B5 and B6.
2. **Under 13: allowed only as a parent-created profile.** Default yes. The account holder is always the adult; the child never has a login. (Counsel review of the youth setup is still owed before any youth marketing push.)
3. **Policy facts:** deletion and export requests answered within **30 days**; governing law **New Jersey**.

## The model

- **A login** is one auth user (email + password). It has exactly one **primary profile**, whose `id` is the auth user id. Account-level facts live on the primary profile only: `email_verified_at` (Amendment 9 unchanged), the age attestation and the terms version.
- **A profile** is one person in one sport in one role. `profiles.account_id` is the login that owns it. A login can own: its primary profile (pitcher, coach, or **parent** — new; a parent profile never charts and never joins a team); **a second-sport profile of its own** ("Add a sport": same person, same role, the other sport); **players it manages** ("Add a player": child profiles with no login, `managed_by` = the parent's primary profile).
- **One profile is active at a time** in the app; it decides the sport, theme, tabs and every query. Switching profiles re-themes the app.
- **What the database guarantees:** no row ever links across sports (S1's triggers, unchanged), and a login can read and write only the profiles it owns, plus what those profiles are entitled to through teams.
- **`is_my_profile(p uuid)`**: true when profile `p` has `account_id = auth.uid()`. SECURITY DEFINER, read-only, `search_path = ''`. Every policy and function that compares `auth.uid()` to a profile id switches to it. Team helpers change to "the caller owns a coach profile on this team". **No policy references `teams` and `pitcher_teams` directly (42P17).**

## Stage A — profiles, switcher, Add a sport, sign-in

- **A1. Schema.** `profiles.id` stops being tied to an auth user (FK moved to `account_id` only). New: `managed_by uuid NULL REFERENCES profiles`, `is_primary` (generated `id = account_id`). Role gains `'parent'`; `sport` may be NULL only for `'parent'` (CHECK); S1's sport triggers ignore parent profiles. Unique (account_id, sport, role) for non-managed profiles. At most 10 profiles per login (trigger). Existing rows unchanged.
- **A2. The RLS rewrite.** One migration swapping every `auth.uid()` profile comparison for `is_my_profile(...)` and updating the team helpers. Show the full SQL diff before applying. Policy count stays 35. On staging, before and after, run the same read/write matrix (pitcher, head coach, assistant, stranger, anon) against every table and prove identical results for existing single-profile accounts.
- **A3. Server functions that take "me".** Every RPC acting as the caller gains an explicit `p_profile uuid` (or reads it from the row) and checks `is_my_profile(p_profile)`. No silent fallback to `auth.uid()` as the profile id. `ensure_account_setup()` still creates the primary profile only.
- **A4. Email verification is per login.** `email_verified_at` on the primary profile; `is_pitcher_report_eligible(p)` and the caller check (Amendment 11) read verification through the profile's account. Recorded as an amendment.
- **A5. Active profile, offline.** `kb:activeProfile` + the login's profile list in the P1-13 boot snapshot; offline cold start opens the right profile in the right theme with no flash. The outbox carries `pitcher_id` per row, so a pen syncs to its profile regardless of which profile is active.
- **A6. Account menu (upper right).** Every profile the login owns (photo/initials, name, sport chip, role, "Player" badge on managed players); tap to switch; **Add a sport** (A) and **Add a player** (B); the login's email once at the top. Same placement on phone, iPad, laptop.
- **A7. Add a sport.** "Add softball"/"Add baseball" creates the other sport's profile under the same login (same name, role), then runs that sport's U9 setup page. No team created.
- **A8. Sign-in rework (replaces S1's refusals).** Any valid login signs in on any sport's page. Exactly one profile of the chosen sport → open it; several → "Who's charting?" picker; none → open the last active profile and offer "Add <sport>" in a banner, no error, no sign-out. No role refusal either. The landing page's "Which sport?" stays; sign-in links keep carrying their sport.
- **A9. Join links with more than one eligible profile.** "Join as:" with the login's matching profiles (+ **New player** in B). One eligible → no picker. None → S1's mismatch message plus "Add <sport>".
- **A10. Everything keyed to "me" follows the active profile.** History, Profile, leaderboard, dots (viewer = active profile), notes authorship, reports' default recipient (the login's email), the coach's team switcher (teams of the active coach profile only).

## Stage B — players, consent, attestation, policies

- **B1. Attestation on the login** (primary profile): `age_attestation` ('adult' | 'minor_13_17'), `attested_at`, `attested_via` ('signup' | 'catchup'), `terms_version`. No date of birth, ever. Every signup ends with "I am 18 or older and agree to the Terms and Privacy Policy" (both linked), except the teen path. `record_attestation(...)` SECURITY DEFINER on the caller's primary profile. Coaches and parents can only be 'adult'.
- **B2. Add a player (GameChanger path).** Account menu, and on signup as "I'm a parent setting this up for my child". First/last name, sport, throws, optional jersey number, required checkbox: "I am this player's parent or legal guardian, and I consent to Knuckleball storing their pitching data." Creates a managed pitcher profile (`account_id` = parent login, `managed_by` = parent's primary profile, `guardian_consented_at = now()`, `guardian_profile_id`, `consent_via = 'parent_created'`); no email, no login, no age. Runs U9 setup. Only an 'adult'-attested login can add players.
- **B3. Players on teams.** Parent opens the join link → "Join as: [Emma] / [New player]". Coaches see a `Parent account` badge (their team only).
- **B4. Reports for a managed player** go to the parent login's email by default (cap of 3 unchanged); verification is the parent login's.
- **B5. Teens who sign themselves up.** Pitcher signup asks 18 or older / 13–17 / Under 13. 13–17: parent/guardian email (not their own), records 'minor_13_17', fixed-template guardian email (R0 token + Resend; only the player's name interpolated, HTML-escaped; resend at most every 10 minutes; one guardian per login); guardian taps Approve on `guardian-consent.html` (sets `guardian_consented_at`, `consent_via = 'guardian_email'`, clears token). Teen can chart; reports gated "Guardian approval pending". Under 13 stops with: "Players under 13 need a parent or guardian to create their profile. Ask them to sign up and choose 'Add a player'." Nothing created. Coaches and parents see only the adult statement. P1-10 (c) text and relay-risk mitigations reused.
- **B6. The report gate.** `is_pitcher_report_eligible(p)` = login verified AND caller verified AND consent (managed player with consent, or login attested 'adult', or 'minor_13_17' with guardian consent). Only in that function and the Edge Function's caller check. View/Send grey out with the specific reason.
- **B7. Catch-up for existing logins.** First sign-in after B: unattested login gets a full-screen, non-closable screen (age question + terms; adult only for coaches); needs network ("Connect to continue" offline); never again; no delay to P1-13's offline paint for attested logins (decide from the cached snapshot). Joel walks it first on his production coach login.
- **B8. Policy pages.** `privacy.html`, `terms.html`: static, themed by `?sport=`, zero JS, linked from every signup form and footer (landing, tracker, join, verify, guardian consent, report shell). Drafted by Claude Code; ship only after Joel approves the text (approval recorded in the commit message). Content per P1-10 (g), updated: who can see what (login holder; coaches of a profile's team; teammates' leaderboard aggregates, baseball only; anyone with a report link, including coach notes on that page); children (parents create players; 13–17 with guardian approval; under 13 only through a parent); processors (Supabase, GitHub Pages, Cloudflare, Resend, nothing else; no tracking — verify by grep); deletion/export to nate@knuckleballonline.com within 30 days, and the tombstone; governing law New Jersey; effective date; `TERMS_VERSION`; Data-handling commitments (a)–(f) with P1-10's accuracy rules (never "cannot access", no unheld certifications, never "tamper-proof").
- **B9. Coach roster states.** `Guardian pending`, `Parent account` beside verification; one explicit-column query; no token or guardian email selectable by another user.

## Out of scope

Handing a managed player their own login; moving an existing teen login under a parent; self-service account deletion (record the request path only); re-prompting on a terms change; coach-attested ages; pricing; softball leaderboard (never).

## Acceptance — Stage A

1. RLS matrix identical before/after for pitcher, head coach, assistant, stranger, anon; policy count unchanged (35).
2. Add a sport: Joel's coach login adds a softball coach profile; switching re-themes; each profile sees only its own teams; the other sport's data never appears while one is active; the database refuses cross-sport team membership.
3. Sign-in: baseball login on the softball page → last profile + "Add softball" banner, no sign-out; two softball profiles → "Who's charting?"; wrong role page → right profile, no refusal.
4. Join link with two eligible profiles → "Join as:"; the chosen profile is on the roster (SQL).
5. Offline cold start opens the last active profile in its theme under one second; a pen charted offline for X syncs to X after switching to Y.
6. Report gate: a second-sport profile of a verified login can generate a report; an unverified login's profiles can't; Amendment 11 unchanged otherwise.
7. Crafted requests using another login's profile id (insert a pitch, join a team, write a note, delete a session) are each refused.
8. Existing single-profile screens pixel-identical except the account menu; P1-01 offline checks 1–3 pass; CACHE_VERSION bumped.

## Acceptance — Stage B

9. Parent signup + Add a player → managed profile with consent, no email; joins via "Join as:"; coach sees "Parent account"; reports to the parent's email.
10. Add a player refused for 'minor_13_17' or unattested logins.
11. Teen signup: guardian email required and not their own; charting works; reports greyed "Guardian approval pending" and a crafted request refused; approval → reports work; reused link → invalid_or_used_token; resend within 10 minutes refused; a name with `<b>` escaped in the email.
12. Under 13 self-signup stopped; no auth user, no profile (SQL).
13. Catch-up: unattested login sees it first; offline "Connect to continue"; once only; attested logins' offline paint unchanged (timing).
14. Roster shows Guardian pending / Parent account; guardian token and email not selectable by another user (failing select shown).
15. privacy.html and terms.html live, zero JS, linked from every signup form and footer; Joel's approval in the commit; each Data-handling claim evidenced; no "cannot access", certifications, or "tamper-proof".
16. P1-01 offline checks 1–3 pass in both sports; CACHE_VERSION bumped.

**Verification:** staging with Joel's coach login + Add softball; a parent with one baseball and one softball player; an adult pitcher; a 13–17 pitcher (guardian = a plus-addressed Gmail Joel controls); an assistant coach. Production: A after a fresh backup, Joel checks his account; B after a fresh backup, Joel walks the catch-up screen first.

**Rollback:** down migration per stage written before deploy; git revert; redeploy Edge Functions.

**Escalate if:** a policy can't be rewritten without teams + pitcher_teams directly; the RLS matrix differs for existing accounts; the outbox can't keep a pending pen tied to its profile across a switch; the catch-up check would delay P1-13's offline paint; the guardian email can't be sent with a fixed body to a stored recipient only; a data-handling claim can't be verified.

## Decisions recorded (Joel, Oct 2 after the precondition report)

1. `sessions.pitcher_id`, `sessions.logged_by`, `sessions.deleted_by`, `teams.coach_id`, `invites.invited_by` move from `auth.users` to `profiles(id)`.
2. The 4 headshot storage policies are rewritten to the ownership check (photos named by profile id).
3. Google Fonts and jsDelivr (supabase-js) get **self-hosted** so pages load nothing from third-party hosts (done in Stage B, before the privacy page lists processors).
4. This spec saved at `plans/s4-profiles-and-consent.md`.
5. The `invites` table's three policies are rewritten like the rest.
