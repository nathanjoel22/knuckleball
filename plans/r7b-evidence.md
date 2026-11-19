# R7 Stage B · facility self-serve · evidence (Nov 19, 2026)

**Where it was tested:**
- Branch `r7b-facility-self-serve`, cache `kb-shell-v359`.
- Migration `20261121000000_r7b_facility_self_serve` on **staging** (`wpsscxwawgiwmifpjpec`), recorded in staging's
  migration history.
- `facility-notify` and `facility-invites` deployed to staging.
- The local staging site, in headless Chrome.

**Pictures (`plans/r7b-evidence/`):**
- `facility-signup-phone.png`, at 390, left to right: the form with Facility chosen; Home and Roster for the
  unverified manager; the join page someone sees trying to join an unverified facility.
- `facility-form-1280.png`: the form's Facility part at 1280.
- `operator-facilities-1280.png`: operator.html's new Facilities list, drawn from staging's real rows.

## A database slip, found and checked (no harm done)

The first dry runs and ten facility tests went to **production**, not staging. I used `supabase db query --linked`
without `--project-ref`, and DEPLOY.md keeps the CLI linked to production.

- **Why nothing changed:** every one of those runs was a transaction that was rolled back or ended in a raised error,
  so nothing was committed.
- **Checked on production afterwards (read-only):**
  - no new column, function, trigger or limit row;
  - `create_facility` and `rate_limit_take` match their original checksums;
  - 0 test logins;
  - newest login and profile from Nov 13;
  - newest deletion Oct 22;
  - 32 policies.
- **What ran on staging:** everything after that, with `--project-ref wpsscxwawgiwmifpjpec` written out. The rule is
  saved so this doesn't recur.

## Done when (Stage B)

8. **A facility signs itself up: PASS.**
   - **The form (390):** the user picks Facility and enters the facility's name. Create account stays disabled until
     the name is there (test: disabled `true` → `false`). Then the 18+ box.
   - **Creating it:** the facility is made in one go and the app opens on its softball side (the sport picked), as
     its manager (`isFacilityManager` true).
   - **Identical to an operator-made one:** in `supabase/tests/r7b_facility_self.sql`, a self-serve facility and an
     operator-link one have the same shape:
     - 1 organization;
     - both sides with `kind = facility`, a head and both invite tokens;
     - 2 head rows;
     - baseball and softball coach profiles;
     - 2 coach groups;
     - the same primary profile.

     The only differences are `created_via` (`self_serve` / `operator_link`) and the levels (the teams' default
     against the link's choice). In the browser, the staging row has 2 sides and 2 coach profiles, `created_via
     self_serve`, the 18+ answer recorded, and the manager unverified.
   - **A second attempt on the same login** is refused with `already_manager`. Also refused:
     - `adult_required`: a login with no 18+ answer;
     - `name_invalid`: a one-letter name;
     - `daily_cap`: when the day's cap is reached.
   - **An unverified manager can't add people:**

     | Attempt (manager unverified) | Result |
     |---|---|
     | A coach using the staff link | refused, `facility_unverified` |
     | A pitcher using a join code | refused, `facility_unverified` |
     | A direct roster insert (a Create Child's Profile player) | refused, `facility_unverified` |
     | The same coach join after verifying | joins |
     | An operator-made facility with an unverified manager | not gated |
   - **In the app, while unverified:**
     - Home and Roster carry "Verify your email to invite coaches and pitchers" with Resend.
     - Account's Join codes and Invite links sections show that note in place of the codes and links.
     - After verifying, the banner goes and the codes and links show.
   - **On the join page:** a parent joining by code sees "Not open yet: … its manager still has to verify their
     email".
   - **Joel's email:** one email to the operator address. `organizations.notified_at` is set, there is 1
     `facility_notify` limit event, and nothing is left pending on the device. The facility made from an operator
     link sent none.
   - **operator.html:** a login that isn't the operator's is refused ("This page is for the Knuckleball operator
     only.").
     - The Facilities list is drawn with staging's three facilities: "Self-serve · R7B Self Serve Lab · … · email not
       verified yet", and two "Operator link" ones.
     - The page couldn't be signed in as the operator (Joel's login). The list's server action is deployed but has not
       been run under the operator login: **please open operator.html on staging once to confirm it.**
9. **Policies unchanged; operator links still work: PASS.**
   - **Policies:** 32 public and 12 storage, before and after, on staging.
   - **An operator link, end to end:** a `facility_invites` row (as operator.html makes it), then
     `facility-signup.html?t=` in the browser. The facility exists, marked `operator_link`, with the link's levels
     (high_school / high_school_up). The link is marked used; it isn't gated; no email is sent.
   - **Every facility test** gives the same result with and without the migration, and passes on staging after it:
     `f1a_acceptance`, `f1a_rls_matrix`, `f1b`, `f1g`, `f1c1_chat`, `n1b`, `n1e`, `n1g`, `n1g2`, `u15_pitch_arsenal`.
     `s4b_acceptance` and `p1_10_acceptance` were run too.
   - **The rollback, run for real on staging:** both functions are back to their original checksums, and the new
     columns, functions, triggers and limit rows are gone. Then the migration was re-applied.

## What changed

- **Database** (`supabase/migrations/20261121000000_r7b_facility_self_serve.sql`):
  - `organizations.created_via` and `notified_at`.
  - `f1_make_facility`: `create_facility`'s body, moved, so both ways in share it. `create_facility` is unchanged in
    what it does and refuses.
  - `create_facility_self(name)`.
  - The verify-gate trigger on `pitcher_teams` and `team_coaches`.
  - `my_facility_needs_verify()`.
  - Two `rate_limit_config` rows, and the `facility_notify` kind in `rate_limit_take`.
- **Edge Functions:**
  - new `facility-notify`;
  - `facility-invites` gains `facilities`;
  - `_shared/rate_limit.ts` gains the kind.
- **Pages:**
  - `login.html`: the Facility form path, with a retry that finishes a facility whose account was made.
  - `bullpen-tracker.html`: the verify check, banner and notes, and the email retry.
  - `join.html` and `join-coach.html`: "Not open yet".
  - `operator.html`: Facilities.
  - `index.html`: "Running a facility? Create a facility account" (and the hidden Facility tier's button).
- `CLAUDE.md`: F1-A's signup is no longer invite-only; Stage B is described; `facility-notify` is added to the list of
  functions.

## Deviations and notes

- **Levels aren't asked:** a self-serve facility's levels are the teams' default (baseball College, softball High
  School & up), as a new coach's team gets. The manager changes them in Account. `facility-signup.html` never asked
  them either; the operator did.
- **The verify gate sits on joining,** not on handing out codes and links. The server refuses the join itself, and the
  app hides the codes and links and says why. That covers every way in with one trigger, without rewriting five
  functions.
- **The daily cap counts every self-serve facility in the last 24 hours** (20, tunable). Per address = one facility per
  login. There is no per-device limit (report item 5, Joel's yes).
- **Pricing:** a self-serve facility gets everything, as an operator-made one does (Joel, "right now everything").
- **Staging test data** (all `@example.com`): "R7B Self Serve Lab" (its manager left unverified) and "R7B Operator
  Lab".
- **Production:** the migration, both functions, and the secrets they already use (`OPERATOR_EMAILS`, `RESEND_API_KEY`,
  `VERIFY_FROM_EMAIL`, all set on production). It's Joel's to ship, after a backup:
  1. `supabase db push --project-ref fkgccjhuimkkbupbanxp`;
  2. `supabase functions deploy facility-notify --project-ref fkgccjhuimkkbupbanxp`;
  3. `supabase functions deploy facility-invites --project-ref fkgccjhuimkkbupbanxp`;
  4. then merge.

  **The site must not go live before the database:** the form would call a function production doesn't have yet.
