# SR1 Stage F · Email and the parent contact · evidence (Nov 19, 2026)

**Where it was tested:**
- Branch `sr1f-email-parent`, cache `kb-shell-v364`.
- `send-session-report` deployed to **staging** only. No migration.
- The local staging site in headless Chrome.

Decisions: `plans/sr1f-preconditions.md`.
- Joel: yes to all.
- Test inboxes (Joel): `nate+chaoscoach@`, `nate+chaosparent@` and `nate+chaospitcher@knuckleballonline.com`.

**Pictures (`plans/sr1f-evidence/`):**
- `e01.jpg`: the approved coach game email beside one built from a demo game (high school, ages 15–16, over the
  7-day line), rendered in Chrome exactly as the function builds it.
- `e02.jpg`: the approved little league player email beside the player email of the test send.
- `three.jpg`: the test send's three emails (coach · player · parent), as built.
- The demo names are swapped as in Stages C–E, and OCR finds no real name.

## Acceptance checks (packet section 6)

1. **Staging: PASS.** The U15 softball pitcher's own login, at 820, made one real send.
2. **Side by side with the pictures: PASS, with these differences:**
   - The email header is today's branded lockup (KNUCKLEBALL with "The spot" image), not a drawn sport tag. Email
     apps can't load the report's fonts, so the existing header stays.
   - The rest line reads "back Sat, Nov 7" (as the report), not "Can pitch again".
   - The coach's-focus line in `e02` is the coach-note packet.
3. **Reports sent before the stage are unchanged: PASS.** Nothing re-renders. A report made before Stage F has no
   email summary, so it still sends today's plain email: `8bb84022` and `b560c741` read "no email summary → the
   plain email", while the new `25629f55` has summaries.
4. **Checks, cache, STATUS, CLAUDE.md: PASS.** Pre-push checks, `kb-shell-v364`, STATUS, CLAUDE.md.
20. **One send to three slots produces three messages, each with its slot's version and link; the parent slot saves
    for a little league player and isn't offered to a college player: PASS.**
    - **Setup:** the U15 pitcher's level was set to Little League, so all three versions exist.
      - On the charting screen at 820, the contacts panel showed **"Parent or guardian (optional)"**. Coach and parent
        were saved through that form: `{"coach": "nate+chaoscoach@…", "pitchingCoach": "", "parent": "nate+chaosparent@…"}`.
      - The pitcher's own slot always holds the login's address, here an @example.com one that Resend refuses. For
        this test only it was set to `nate+chaospitcher@…` directly.
    - **The send:** an Independent command pen of 12 pitches, then the app's **Send report**: "Report sent to 3
      recipient(s)." One Resend call per address; all three succeeded.
    - **What the stored report gives each slot** (`25629f55…`, `data-kr-versions="coach player parent"`):

      ```
      coach  | Bullpen report: U15 Softball Pitcher · 6 of 12 on the spot · Nov 19 | 50% on the spot and 83% strikes over 12 pitches. | button "Open the full report" (no v)
      player | Your bullpen report: 6 of 12 on the spot · Nov 19 | 6 of your 12 pitches hit your spot. | 83% Strikes · 50% On your spot · 6/12 FB on spot | "See where every pitch went" (&v=player)
      parent | Bullpen report: U15 Softball Pitcher · 6 of 12 on the spot · Nov 19 | 6 of 12 pitches hit the spot. | 83% Strikes · 50% On the spot · 12 Pitches | "Open the full report" (&v=parent)
      ```

    - **Not offered to a college player:** a demo pitcher on a college team with no level of their own →
      `collegeOnlyPlayer()` true, so no field. The U15 pitcher (high school & up) is offered it.
    - **Sending limits:** unchanged. One request per send, and each address counted against itself and the daily cap,
      as before.
21. **The email in Gmail (web and iPhone) and Apple Mail: Joel's.** The three emails went to Joel's addresses at the
    send above, with the three subjects in the table.
    - Built with tables and inline styles only (the shared `brandedEmail`, plus an optional summary block).
    - **Open:** Joel screenshots them in Gmail on the web and the iPhone and in Apple Mail, for this file. I can't
      reach those apps.

## Found, not changed (for Joel)

- **A player can't reach their report contacts on a phone.** The contacts panel lives only in the old pitcher
  header, and since N1 Stage B (v344) that header shows only on the charting screen at iPad / computer width. On a
  phone no screen shows "Contacts", which is why the test used 820. This predates SR1.
- **Suggested fix (a separate, small change):** a "Report contacts" section in Pitcher settings, the same form.

## Staging test data

- The U15 pitcher was put back afterwards: level unset, contacts as before (coach, its own address), no test
  addresses (0 profiles hold "chaos").
- It keeps the one test pen and its report.

## Production (Joel's)

1. `supabase functions deploy send-session-report --project-ref fkgccjhuimkkbupbanxp` (no migration).
2. Merge (`kb-shell-v364`).

**The function first:** the app then sends a parent contact, which needs the new cap of 4.
