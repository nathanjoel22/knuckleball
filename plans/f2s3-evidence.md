# F2 Stage 3 · Birthdays and the September 1 level move · evidence (Nov 20, 2026)

**STAGING ONLY. Not for production until Joel approves the policy wording below, and the contradiction handling (22).**

- **Branch:** `f2-stage3` (on Stage 4), cache `kb-shell-v371`.
- **Migration:** `20261128000000_f2s3_birthdays` on staging. A dry run showed only that file; the rollback was written
  first.
- **Function:** `export-account` deployed to staging.
- **Test:** `supabase/tests/f2s3_birthdays.sql` (rolled back): **fails=0**. Its fixtures use dates relative to today;
  none is a real person's.

## A change from the report's default (for Joel)

**A birthday that contradicts the sign-up's age answer is not saved:**
- the cases are a login that said 18+ whose date says under 18, and one that said 13–17 whose date says under 13;
- `set_birthday` answers `contradiction`, and the case goes on an operator-only list (`birthday_contradictions`: the
  two brackets, no date);
- the person sees "That date doesn't match the age given when this account was made. Contact
  nate@knuckleballonline.com" and can choose Not now; they're asked again at the next sign-in.

This changes no report, role or session until Joel decides how each case is handled. The report's default (treat it
as a new sign-up of that age) would change report access and adult roles on its own. Up to 2 such logins on production
(13–17 attested) could hit the first case; the adult case depends on dates not yet given.

## Done when

17. **A new pitcher gives a birthday; under 13 and 13–17 behave as before, driven by the date: PASS.**
    - `login.html#new`, Pitcher: the age bracket question is now **Birthday** (Month 12, Day, Year 101 options). The old
      radios are hidden and set from the date.
      - 25 years: `adult`, no guardian box.
      - 15: `minor_13_17`, guardian email box shown.
      - 11: it becomes a Parent account (the under-13 note, the parent's name carried over). The birthday is carried
        to Create Your Child's Profile.
    - The same Birthday is on `join.html` (new account) and `accept-invite.html`.
    - **A real staging sign-up** (adult, Parent Name given): after the app loaded, `my_birthdays` shows answered (year
      2001), nothing is left pending, no question appears, and `parent_name` is in the sign-up metadata.
    - SQL: said 18+ with a date of 16 gives `contradiction`; with 18, saved. A future date gives `date_invalid`. Said
      13–17 with a date of 11 gives `contradiction`; with 14, saved. The operator list holds 2 (`adult->minor_13_17`,
      `minor_13_17->under_13`).
18. **Create Your Child's Profile requires a birthday; a coach adding a no-email player may answer "I don't know":
    PASS.**
    - The form reads Player's name, **Birthday**, Sport, Throws.
    - A coach without an answer: "Enter the player's birthday, or tick I don't know." With I don't know ticked, the
      player is created and the answer recorded (`access: write`, date never shown to the coach).
    - A parent has no I don't know box; the server refuses one too (`date_required`).
19. **An existing pitcher and an existing parent with two children are each asked once at next sign-in, never again:
    PASS.**
    - The U15 softball pitcher (attested adult): "Your birthday" before anything else, answered, then gone. After
      signing in again it wasn't asked.
    - A test parent with two players: "<first name>'s birthday" twice, then the normal "Which pitcher?". After signing
      in again, only "Which pitcher?".
    - **A coach-added player (no login):** no blocking screen. The Roster shows "Add a birthday for <player> so their
      level of play moves up on its own." with Add / Not now; "I don't know" clears it.
20. **A coach and a facility manager can read no birthday: PASS.**
    - Their own client reading `profile_birthdays`: denied.
    - `my_birthdays()` returns 0 dates for them.
    - `set_birthday` on a rostered pitcher: `not_allowed`.
    - `profiles` has 0 birth columns, so no roster, report, email or chat read can carry it.
    - A linked guardian reads their player's date. The three tables have 0 client grants.
21. **September 1: PASS.**
    - `f2_level_switch('<this year>-09-01')` moved 4:
      - a 14-year-old Little League pitcher to High school;
      - an 18-year-old Little League pitcher to High school;
      - a 19-year-old to College;
      - a 12-year-old with no level to Little League.
    - A 9-year-old set to College by hand **kept College** (only up). A second run moves 0.
    - Log rows are written. Sessions are byte-identical before and after (nothing recomputed). No email or notice.
    - The job is `53 9 1 9 * select public.f2_level_switch()` (Sept 1, 09:53 UTC).
22. **The contradiction cases: DECIDED (Joel, Nov 20: only under 18 matters).** Kept as built: not saved, operator list,
    contact us, for an under-18 date only; an 18+ date is always saved. Was: Joel approves or
    changes this before production.
23. **Export includes the birthday; delete removes it: PASS.**
    - The new pitcher's **Download my data** ZIP has `birthdays.csv` (`profile_id,birth_date,unknown,set_at`, the
      year-2001 row).
    - A coach-added player's birthday is left out of the coach's export.
    - SQL: deleting the profile leaves 0 birthday rows (on delete cascade, as A1's purge does).
24. **Policy sentences: APPROVED by Joel (Nov 20 2026)** and on the pages (privacy, terms, guardian-consent; Version
    2026-11-20). `TERMS_VERSION` 2026-11-20 on every page that records it. Staging: a 2026-10-17 login saw the birthday
    notice (no licensing paragraph), I agree recorded 2026-11-20 on the server, then the birthday question opened; an
    older login's notice also carries the licensing paragraph.
25. **Level table (Joel, Nov 20 2026):** 12 or under LL, 13–17 HS, 18+ on Sept 1 College (softball LL, then HS & up).
    `f2s3_birthdays.sql` re-run on staging after the change: fails=0, the table's edges 12/13/17/18 as listed.

## Policy wording: APPROVED by Joel, Nov 20 2026 (on the pages; the guardian email's wording was left as it is)

- **Privacy, replacing "We never ask for or store a date of birth"** (`privacy.html:81`): "Birthday: a pitcher's date of
  birth, entered by the pitcher or by the parent who set the player up. We use it only to apply our age rules (who needs
  a parent or guardian's approval) and to move a player to the next level of play on September 1 each year."
- **Privacy, who sees it:** "Only the player and their parents or guardians on Knuckleball see a birthday. Coaches,
  facility managers, teammates and anyone with a report link see the level of play, never the date. It never appears in
  reports, emails or chat. It is included in your own data download and is deleted with the account."
- **Privacy, line 82** ("We store no email address, login, or age for a player added this way"): "We store no email
  address or login for a player added this way; we store their birthday as above."
- **Terms, line 85:** "...accurate information, including your birthday or your player's."
- **Guardian consent page, line 57 ("What's stored"):** "...and their birthday, which only they and their parents or
  guardians can see."
- **The guardian approval email** (`send-guardian-consent`): "Because their birthday shows they're 13 to 17..."
- **`TERMS_VERSION`:** a material change. Proposed bump, so every login sees "I agree" once. Joel decides.
- **App Store privacy label and Play Data safety:** add "Date of birth", linked to the user, used for app functionality.
  Joel's.

## Staging test data
- Two new test logins (`f2s3-new*@example.com`).
- Birthdays on the U15 softball pitcher and a test parent's two players.
- Two coach-added test players on the U15 coach's login ("F2 Coach Kid", "F2 Coach Kid Two").
