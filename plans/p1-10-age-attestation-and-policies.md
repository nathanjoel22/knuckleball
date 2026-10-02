# P1-10 — Age attestation, guardian approval for 13–17s, privacy policy and terms (refreshed Oct 2, 2026)

**Joel, Oct 2, 2026: P1-10 ships before S4.** This version replaces the Sept 25 refresh, which was written before softball, coach notes, G3 and Jordan's access existed. It builds the age question, guardian approval for 13–17 players who sign themselves up, a one-time catch-up for existing accounts, and the privacy and terms pages with the Data-handling section. C2 requires all of that before programs #2–3. S4 then adds parent-created players (including under-13s) on top of it and reuses everything here.

**D2 interim, confirmed by doing P1-10 now: option (a)-lite.** A 13–17 player names a parent or guardian email at signup. The guardian gets a link and taps Approve. Until then the account behaves like an unverified one: the player can chart, but gets no reports. Under 13 is refused in P1-10 (S4 opens the parent-created path for them). This reuses R0's token + Edge Function + Resend machinery. It is **not** a substitute for counsel review before any youth-focused launch; it's the honest interim, so that nobody charts with nothing on file. (This is not legal advice.)

## What changed since Sept 25 (built into the packet below)

1. **Two sports.** Every signup path carries a sport (S1): the landing page's sport → Pitcher/Coach pages (`?sport=`), `join.html` pitcher and coach links (themed from the team), direct coach signup and the new-coach welcome page. The age question and the terms checkbox appear on **every** path in **both** themes; the policy pages are themed by `?sport=`.
2. **Coach notes are public on report pages (S3, option A).** Anyone holding a report link sees the session's current notes. The privacy policy must say so.
3. **Departed pitchers (G3).** Coaches keep reading sessions charted while the pitcher was on their team; they don't see later ones. The policy states it.
4. **Two people have infrastructure access.** Jordan Thayer (operations) is a Supabase Administrator. The operator-access commitment must say "Knuckleball's small team", not "one person".
5. **The operator is Knuckleball LLC** (as the footers already say). Governing law **New Jersey**. Deletion and export requests answered within **30 days**.
6. **Supabase plan.** Production is on the Free plan today, and SC0 may move it to Pro. Quote the encryption and region statements for **the plan in use at ship time**; if SC0 lands first, quote Pro's.
7. **Forward-compatible with S4.** The attestation and guardian columns go on the account's own profile (the one whose id is the auth user). S4 treats that profile as the login's primary profile, so nothing moves later.
8. **Under-13 message** points to S4: "Knuckleball isn't available for players under 13 yet. Parent accounts are coming soon."
9. **Policy count is 35** on production today (S3). P1-10 adds none unless a precondition finds one is needed; report before/after.

## Decisions made in drafting (Joel may override)

1. **Three answers, not a checkbox.** "18 or older" / "13–17" / "Under 13". Under 13 stops with a plain message. A single "I am 18+" checkbox would have every 16-year-old lying to get in, which is worse than not asking.
2. **No date of birth stored.** Only the bracket (`adult` / `minor_13_17`) and when it was attested.
3. **Coaches must be adults.** Both coach signup paths (direct, and R6's coach invite link) offer only the adult statement.
4. **Guardian approval gates reports, not charting.** Same shape as email verification. The report invariant becomes: pitcher verified **and** caller verified **and** (adult or guardian-approved).
5. **Existing accounts attest once, at next login, online.** A full-screen screen (not the closable U9 modal). It needs the network; offline it says "Connect to continue". Nobody is backfilled: an attestation nobody made is worthless.
6. **The server refuses team joins without an attestation**, so a crafted client can't skip it. Session inserts are **not** gated server-side; that would put a policy between the P1-01 outbox and the database for no legal gain.
7. **Terms carry a version.** `TERMS_VERSION` is a constant; the profile stores which version was accepted. Re-prompting on a version change is out of scope.
8. **Policy text is drafted by Claude Code and ships only after Joel approves it**, recorded in the commit message.
9. **The guardian email goes to an address the user typed, so it's a relay risk** (P0-01's lesson). Mandatory: one guardian address per account, fixed message body with the pitcher's name HTML-escaped, resend at most once per 10 minutes, and the address only ever receives the consent template.

---

## The packet (paste for Claude Code)

```
ID:              P1-10
Title:           Age attestation, guardian approval for 13–17s, privacy and terms
                 pages (both sports)
Goal:            Every account records an age attestation (adult / 13–17) and the
                 terms version accepted — at signup for new accounts, once at next
                 login for existing ones. Under-13s are refused. A 13–17 player
                 names a parent or guardian, who approves by emailed link; until
                 then the player can chart but reports are gated. Coaches attest
                 as adults. privacy.html and terms.html exist, themed by sport,
                 linked from every signup form and footer, and Joel has approved
                 their text.
Spec:            claude/p1-10-age-attestation-and-policies.md (save in the repo as
                 plans/p1-10-age-attestation-and-policies.md). Build to it.
Depends on:      R0 (token + send-verification-email pattern; join.html), U9, R6,
                 U4b (is_pitcher_report_eligible), S1 (sport on every signup path),
                 S3 (notes on report pages), G3. All shipped.
Staging only.    Only Joel ships to production. Migration + Edge Function change:
                 staging first; fresh production backup first. Touches account
                 creation — show the SQL before applying.

PRECONDITIONS — REPORT, with file and line numbers, before writing code:
  1. Every account-creation path, both sports: landing → Pitcher/Coach signup
     (?sport=), join.html pitcher branch, join.html coach-link branch (R6),
     direct coach signup, the new-coach welcome page; where each calls
     ensure_account_setup(); which fields each form collects today.
  2. The U9 setup modal and the app boot (P1-13 paint-first): where a blocking
     screen can sit without delaying offline paint for accounts that have
     already attested; what the cached boot snapshot holds.
  3. is_pitcher_report_eligible and the Edge Function caller check (Amendment
     11) — the exact predicates, so the guardian clause is added in both
     places and nowhere else.
  4. The R0 machinery: generate_email_verify_token(), send-verification-email,
     verify_email(), verify-email.html. List what the guardian flow can share
     (CSPRNG helper, Resend call, page template) vs must duplicate.
  5. Every column the roster query selects (explicit list — must stay
     explicit and must NOT gain the guardian token or guardian email).
  6. Every external host loaded anywhere in the frontend and report pages:
     grep <script src, <link href, fetch(, import( — and list what IS loaded
     (Supabase client, Google Fonts if any, get_report_notes, etc.).
  7. Supabase's current published statements on encryption in transit and at
     rest for the plan production is on at ship time, and the project region.
     Quote, don't paraphrase.
  8. Every footer and every page a person can land on (landing, signup pages,
     tracker, join, verify-email, report.html shell and both report types),
     so the policy links appear everywhere.
  9. Whether the profiles id = auth user id for every existing account (S4
     will rely on the attestation living on that profile).
  10. Row counts: accounts by role and sport; policy count (35 expected).
  Build nothing until Joel has read the report.

Files touched:   NEW migration; bullpen-tracker.html (catch-up screen, banner
                 state, footer links, roster "Guardian pending" state); join.html
                 and every signup page (age question, guardian email field, terms
                 checkbox); the landing page footer; NEW privacy.html; NEW
                 terms.html; NEW guardian-consent.html; send-verification-email
                 (guardian template + rate limit) or a sibling function;
                 send-session-report (eligibility clause; footer links in both
                 report types); report.html only if its footer needs the links
                 (recompute its CSP hash if its inline script changes); sw.js
                 (CACHE_VERSION); CLAUDE.md (the new report invariant).

Approach:

  (a) MIGRATION. profiles gains:
        age_attestation          text CHECK IN ('adult','minor_13_17'), nullable
        attested_at              timestamptz
        attested_via             text CHECK IN ('signup','catchup')
        terms_version            text
        guardian_email           text
        guardian_consent_token   text   -- CSPRNG, >= 32 hex, never selectable
        guardian_consent_sent_at timestamptz
        guardian_consented_at    timestamptz
        consent_via              text CHECK IN ('guardian_email','parent_created')
                                        -- 'parent_created' reserved for S4
      All nullable; existing rows untouched. No date-of-birth column, ever.
      Down migration written before deploy.

  (b) RECORDING — one RPC, record_attestation(p_status, p_terms_version,
      p_guardian_email default null). SECURITY DEFINER, search_path '',
      scoped to auth.uid()'s own profile, authenticated only:
        - 'adult' → sets age_attestation, attested_at = now(), attested_via,
          terms_version; clears guardian_* if any.
        - 'minor_13_17' → requires a syntactically valid p_guardian_email that
          is NOT the account's own email; sets the bracket and guardian_email,
          generates guardian_consent_token, leaves guardian_consented_at NULL.
        - Coach accounts (any team_coaches row, or a coach signup in progress)
          may only record 'adult'. Refuse otherwise with a clear message.
        - Idempotent for the same status; changing guardian_email re-issues the
          token and clears approval.
      join_team (R0) and join_team_as_coach (R6) REFUSE when the caller's
      age_attestation is NULL: "Please finish setting up your account first."

  (c) GUARDIAN APPROVAL — copies R0's verification flow:
        - Send: the Edge Function, caller's own JWT, NO service-role for reads,
          reads guardian_email + token for auth.uid() only, sends a fixed
          template via Resend from nate@knuckleballonline.com to
          GUARDIAN_REDIRECT_URL?t=<token>. The pitcher's display name is the
          only interpolated value and is HTML-escaped. Refuse if
          guardian_consent_sent_at is within the last 10 minutes.
        - guardian-consent.html: themed by the player's sport; shows what the
          guardian is approving (Knuckleball LLC, the player's first name, a
          one-paragraph summary including that coaches on the player's team
          see the data and that report links — with coach notes — can be
          viewed by anyone who has the link; links to both policies) and an
          Approve button → anon-callable record_guardian_consent(p_token):
          stamps guardian_consented_at, consent_via = 'guardian_email', clears
          the token in one statement; returns {ok:false,
          error:'invalid_or_used_token'} rather than a raw error.
        - Banner for a 13–17 player without approval, beside the verify banner:
          "Waiting for a parent or guardian to approve your account", with
          Resend and Change guardian email.

  (d) THE GATE. is_pitcher_report_eligible gains: AND (age_attestation =
      'adult' OR guardian_consented_at IS NOT NULL). The Edge Function's
      server-side check gains the same clause (precondition 3 says where).
      View Report / Send Report grey out with "Guardian approval pending".
      The coach roster shows the state next to verification: Unverified /
      Guardian pending — one explicit-column query, no token, no guardian
      email.

  (e) SIGNUP FORMS, both sports (precondition 1):
        - Pitcher (landing signup and join link): "How old are you?" → 18 or
          older / 13–17 / Under 13. 13–17 reveals "Parent or guardian email".
          Under 13 stops: "Knuckleball isn't available for players under 13
          yet. Parent accounts are coming soon." Submit also requires "I agree
          to the Terms and Privacy Policy" with both linked (to the page's
          sport). The attestation is recorded immediately after
          ensure_account_setup(), before join_team — which refuses without it.
        - Coach (direct signup and the R6 coach link): "I am 18 or older and I
          agree to the Terms and Privacy Policy." Required.
      Nothing is created if the form is incomplete; no silent defaults.

  (f) CATCH-UP FOR EXISTING ACCOUNTS. On app boot, after auth resolves, a
      profile with age_attestation IS NULL gets a full-screen screen BEFORE
      the U9 modal or the app, in its sport's theme: same questions as (e),
      plus the terms agreement. Not closable. Needs the network; offline it
      shows "Connect to continue" and nothing else. Once recorded it never
      shows again. Must not delay P1-13's offline paint for accounts that
      have already attested — decide from precondition 2 whether the check
      reads the cached snapshot. Coaches see only the adult statement; a
      coach who can't attest as an adult can't proceed.

  (g) POLICY PAGES. privacy.html and terms.html: static, zero JS, themed by
      ?sport= (green or blue/pink; the CSS can switch on the query without
      JS, or ship two themed copies — say which), linked from every signup
      form and every footer in precondition 8, including both report types.
      DRAFTS FOR JOEL — text does not ship until he approves it, recorded in
      the commit message. Operator: Knuckleball LLC. Contact:
      nate@knuckleballonline.com.

      privacy.html covers, plainly:
        - What is collected: name, email, jersey number, throwing hand, sport,
          pitch types, pitch-by-pitch charting data (location, velocity,
          result, delivery, time to plate), game data (counts, outs, runners,
          plays), session dates, who charted, coach notes; for 13–17 players,
          a parent or guardian email.
        - Who can see it: the player; the coaches (head and assistant) of any
          team the player is on — and, after the player leaves a team, that
          team's coaches keep the sessions charted while the player was on it,
          but not later ones; teammates, through the baseball team
          leaderboard (aggregates only: peak velocity, accuracy, strike %;
          softball has no leaderboard); anyone a report link is sent to.
          Report links are long random URLs viewable by anyone who has the
          link, and the report page shows that session's current coach notes.
        - Where it lives: Supabase (precondition 7's region and encryption
          statements, quoted); the site on GitHub Pages; DNS and mail routing
          via Cloudflare; email via Resend. No other processors.
        - No third-party tracking, advertising, or analytics (precondition 6 —
          say exactly what IS loaded).
        - Age: 13+; 13–17 with a parent or guardian's emailed approval; under
          13 not permitted yet. What happens if we learn otherwise.
        - Deletion and export: on request to nate@knuckleballonline.com,
          answered within 30 days. Session deletion leaves a tombstone (date,
          pitch count, who) — say so.
        - Contact, effective date, version.
        - The "Data handling commitments" section, for coaches — (a)–(f) below,
          under the accuracy rules below.

      terms.html covers: who may use it (adults, or 13–17 with guardian
      approval); the account holder is responsible for their credentials; the
      player owns their pitching data (D3) and coaches see it through team
      membership; coaches are responsible for what they write in notes, which
      are visible on report pages; acceptable use (no scraping, no sharing
      another player's data outside the team, no abuse of email features);
      saved sessions are final and deletion leaves a tombstone; provided as-is
      with no warranty and may change; accounts may be suspended for misuse;
      governing law New Jersey; how changes are announced; effective date and
      TERMS_VERSION.

      DATA HANDLING COMMITMENTS:
        (a) Team-scoped isolation is enforced at the DATABASE level by
            row-level security, not just application code — tie the claim to
            named policies.
        (b) Knuckleball does not sell, share, license, or disclose team or
            player data to third parties — not scouts, not other programs, not
            brokers. A binding commitment, not a current practice.
        (c) No third-party tracking, advertising, or analytics SDKs. Verified
            in code (precondition 6).
        (d) Encrypted in transit and at rest on Supabase infrastructure — quote
            what the plan actually guarantees (precondition 7).
        (e) Operator access, honestly: Knuckleball is run by a small team who,
            as infrastructure operators, can technically access stored data —
            as with any hosted service. Committed: access only for support,
            debugging, or safety; never for sharing or competitive purposes.
        (f) Export and deletion on request, answered within 30 days.
      ACCURACY RULES: never write that the operator "cannot" access data or
      that access is "technically impossible" — false while the service-role
      key and dashboard exist. No claims of end-to-end encryption,
      zero-knowledge, SOC 2, GDPR, FERPA, or COPPA compliance, or any
      certification not actually held. Every sentence must survive a
      compliance officer asking how it is enforced. Never write
      "tamper-proof".

  (h) OFFLINE. Nothing here touches the charting path or the P1-01 outbox. The
      catch-up screen is the only new network dependency and it is one-time.

Out of scope:    Parent-created players and under-13 accounts (S4); re-prompting
                 on a terms change; self-service account deletion (record the
                 request path only); cookie banners (nothing to consent to — say
                 so); program-mediated consent (D2 option b); coach attestation of
                 a player's age; S1's per-sport sign-in refusals (S4 changes
                 them).

Acceptance (run in BOTH sports where a form or page is involved):
  1. New pitcher, adult (landing signup and join link): the form blocks without
     the age answer and the terms agreement; the profile shows 'adult',
     attested_at, 'signup', terms_version. Reports work as before.
  2. New pitcher, 13–17: guardian email required (own email rejected); profile
     shows 'minor_13_17', guardian_email, token set, approval NULL; banner
     shows; View/Send Report greyed with the guardian reason; a hand-crafted
     report request is refused server-side — show the refusal.
  3. Guardian link: approves → guardian_consented_at set, consent_via
     'guardian_email', token cleared, banner gone, reports available (with
     both verification conditions still required). Reusing the link returns
     invalid_or_used_token, not an error page. The page is themed to the
     player's sport.
  4. Under 13: stopped with the message; no auth user and no profile created —
     prove with SQL.
  5. Coach direct signup and coach-link signup: adult statement required;
     record_attestation('minor_13_17') from a coach account is refused — show
     it.
  6. join_team and join_team_as_coach with NULL attestation are refused
     server-side — show both with crafted calls.
  7. Existing pitcher account (attestation NULL) logs in → sees the catch-up
     screen before anything else, in its sport's theme; offline it says
     "Connect to continue"; online, answers, never sees it again; profile
     shows 'catchup'.
  8. Existing account that has attested: offline cold launch still paints
     under one second (P1-13) — show the timing.
  9. Coach roster shows "Guardian pending" for an unapproved minor; the roster
     query's column list is unchanged except for the non-secret state columns;
     the guardian token and email are not selectable by another user — show
     the failing select.
  10. Guardian send: a second send within 10 minutes is refused; the pitcher
      name in the email is escaped (test with a name containing <b>); the
      recipient is only ever the stored guardian_email.
  11. privacy.html and terms.html live, themed by sport, zero JS, linked from
      every signup form and every footer in precondition 8, including both
      report types (new reports only; sent reports stay frozen).
  12. Joel has approved both texts; the approval is in the commit message. The
      Data-handling section covers (a)–(f); each factual claim has its
      evidence shown to Joel (named policies for (a), the grep for (c), the
      quoted Supabase text for (d)).
  13. No sentence anywhere claims the operator cannot access data; the text
      says "small team", not "one person"; "tamper-proof" appears nowhere.
  14. Policy count before/after reported; P1-01 offline checks 1–3 pass in both
      sports; CACHE_VERSION bumped.

Verification:    Staging with five accounts: adult baseball pitcher, adult
                 softball pitcher, 13–17 pitcher (guardian = a plus-addressed
                 Gmail Joel controls), head coach, assistant via coach link. SQL
                 after each step. Production after a fresh backup; then Joel
                 walks the catch-up screen on his own coach account first —
                 before Cairn's pitchers hit it.
Rollback:        Down migration (drop the nine columns, restore
                 is_pitcher_report_eligible, remove the join refusals) written
                 before deploy; git revert; redeploy the Edge Functions. Policy
                 pages can simply be unlinked.
Size:            M–L (the guardian flow is the L; the pages are writing).
Escalate if:     the catch-up screen can't be placed without delaying P1-13's
                 offline paint for already-attested accounts; the guardian email
                 can't be sent with a fixed body to the stored recipient only (if
                 either is impossible, stop — that is P0-01's relay again); any
                 data-handling claim can't be verified in code or a provider's
                 published terms — report it rather than softening the wording.
```

## What this changes elsewhere

- **D2:** interim decided (option (a)-lite); counsel review still owed before a youth launch.
- **Report gate invariant:** pitcher verified AND caller verified AND (adult OR guardian-approved). Update CLAUDE.md on ship; S4 adds the parent-created case.
- **S4 shrinks.** Stage B no longer builds attestation, the teen path, the catch-up screen or the policy pages; it adds parent-created players (`consent_via = 'parent_created'`), opens under-13 through parents, extends the gate for managed players, updates the policy pages for parent accounts (Joel re-approves the changed text), and adds the "Parent account" roster badge.
- **Sales:** the Data-handling section is the document to hand a coach before the first conversation with program #2.
