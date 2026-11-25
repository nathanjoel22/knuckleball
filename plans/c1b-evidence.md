# C1 Stage B — evidence (Nov 25, 2026; staging)

Branch `c1-stage-b`, cache `kb-shell-v375`. Staging database: migrations `20261130000000_c1b_live_sessions` and
`20261130000001_c1b_piece_columns` (dry run, then push; the parked F1-C2 file copied in and removed). No function
changes. Devices: three headless Chrome tabs on three addresses of the local staging site, so each has its own sign-in:
- **A:** the staging demo coach;
- **B:** the demo pitcher's own login;
- **X:** a second demo coach who doesn't coach that pitcher (facility groups).

The tabs are told they're in front: a background tab correctly pauses polling.

## Done when

9. **The marks, joining, and who sees nothing: PASS** (bullpen and game).
   - **A starts with Outcome only** (Outcome & Response in a game) and gets a live session.
   - **What B sees:** the Home notice "Live bullpen in progress for … · Intent is open · Chart Now ›"; the red LIVE mark on
     Chart; the card "In Progress — Chart Now". The parts question offers Intent (on) and Outcome "· on another device"
     (disabled). B joins Intent from pitch 1.
   - **X:** an empty summary, no notice, no mark.
   - **A third person once both parts are held:** offered nothing (SQL: the assistant H2 got `taken`, and their list is
     empty).
   - **A second start** for the same pitcher and kind is refused with `live_exists`.
   - **The database matrix** (`supabase/tests/c1b_live_sessions.sql`), who sees the mark:
     - **Sees it:** the team's assistant and the pitcher.
     - **Sees nothing:** the head holding Outcome (the starter), another team's head (an R4 reader), an unrelated
       parent, view-only family and a stranger. The stranger's join is refused and its poll gets `not_holding`.
10. **Twenty pitches in step: PASS.**
    - Before any call, A's tap says "Waiting for the call" and records nothing.
    - **Bullpen:** for each of 20 pitches B picked a type (cycling through three), tapped, and confirmed. A's pitch type
      matched the caller's 20 of 20, and A's caption read "Select Pitch Outcome · CH called 8". Both pieces numbered all
      20.
    - **Game:** 4 pitches, 4 of 4.
    - A's batter side followed B's (B chose RHB; A showed R).
11. **No pitch and Chart without it: PASS** (bullpen and game).
    - B confirms a call; A has it. B taps **No pitch**: B's call comes off, and A goes back to waiting.
    - After 4 s A is offered **Chart without it**. A's next pitch is saved with no call, as a new number on the server
      (`skipped_intent` true).
12. **Back locks: PASS.** B's Back works until A records the pitch, then `c1CanBack()` is false. Database: Back after the
    outcome is `locked`; Back before it is `ok`; Back after a later call is `locked`.
13. **Airplane mode for six pitches: PASS.**
    - A went offline (network and `navigator.onLine`) while B called 6 pitches online. A charted each about 2 s after
      its call, then one extra tap with no call.
    - Back online: 7 of 8 numbered (1 online before, 6 offline matched); the extra tap is unmatched, so empty for that
      part. Queue empty.
    - Saved pieces on staging: the Outcome piece `live_seq` [1..7, null]; the Intent piece [1..7]. Both have
      `live_session_id`, with `live_part` outcome / intent. Both left the live session.
    - Database: offline calls kept 1 / dropped 1; offline outcomes kept 1 / dropped 1.
14. **A one-session-assignment coach joins and still can't read history: PASS (database).** The assigned coach sees the
    mark and joins; their read of the pitcher's sessions returns 0; a direct read of the live tables is refused. No
    grants on the live tables; policies 44 → 44 (public 32, storage 12).

## Also
- **Pitching change:** a new live session started with `p_after` points the old one's `successor_id` at it (database
  check). The caller's "Keep calling for <name>?" prompt wasn't run end to end. The only devices that could chart both
  pitchers are demo logins with real people's names.
- **Re-run on staging:** `c1a_charting_parts` (fails=0) and `h1_grace_closed`.
- **Two bugs found and fixed during testing:**
  - polling stopped when the app re-read its session from storage in the background;
  - a tap before any call asked for a pitch type instead of saying "Waiting for the call".
- **Staging clean-up:** test live sessions were closed afterwards. The demo pitcher's History has the test pieces.

## Notes for Joel
- **How fast it feels:** the waiting device sees a call about 1–1.5 s after Confirm Pitch. A call that's taken back or
  "No pitch" shows within about 3 s.
- **Until Stage C,** each piece shows in History as its own Intent-only / Outcome-only session.
