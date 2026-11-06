# U15 preconditions report (Nov 6, 2026)

Written against: STATUS 2026-11-05 "Nothing under a coach's open roster", production v336. Branch `u15-charting-batch`
from `origin/main` (84ae0d2). The packet had no copy on main; it's saved verbatim as `plans/u15-charting-phone-batch.md`.
Line numbers are `bullpen-tracker.html` unless a file is named.

**Status: waiting on Joel.** Section B lists where the code differs from the packet. Section C lists the decisions
needed before building.

## A. Answers to the ten questions

1. **The arsenal is `profiles.pitch_types`** (`text[]`, no table and no catalog check; `coach_set_pitch_types` caps it at 20).
   - **Read by:**
     - `mapProfile` (2240), `pitchTypesFor` (2273);
     - the chip strip and trays (`pitchTypeTray` 2063, game 11152/11197, pen 11609/11664);
     - the colour, by position in the list (`colorForType` 2276, `typeColorClass` 2058);
     - Profile's Pitch mix (13152);
     - the RA painter's list (12608);
     - the read-only profile text (13639, 13689), the roster line (14499) and the header chips (14582);
     - the edit-row type picker (11527);
     - the report payload (13933, 14071);
     - `from_rows.ts:129/154`, and the report templates (`allTypes`, `template.ts:81`, `template_game.ts:90`);
     - the offline snapshot (`saveLastKnownContext` 3783, pre-warm 3575).
   - **Written by:** `savePitchMix` (4891):
     - a coach goes through `coach_set_pitch_types` (head of the pitcher only, `r6_coaching_staffs.sql:593`);
     - everyone else updates `profiles` directly (column grant `u7_profile_lockdown...sql:41`, rule "Users update own
       profile" = `account_id = auth.uid()`, which already covers a parent's own player).
   - Saving is online only today ("Could not save. Check your connection").
   - Removing a pitch leaves its `accuracy_zones` rows in place.
2. **RA cells are in `accuracy_zones`** (`pitcher_id, pitch_type, batter_side R/L, cells text[]`, at most 4 since U14; key on
   all three).
   - The app writes them directly (`saveZonePaint` 12547 upsert, `clearZonePaint` 12562 delete). The rule allows
     `can_chart_for(pitcher) or is_coach_of_pitcher(pitcher)`, so assistants are already allowed by the database; the app
     hides the painter from them.
   - **Scoring reads the live cells on every tap** (`scoreU14` 3875; pen tap 5645; game `gameHitScore` 3882). There is no
     snapshot taken at session start. The cells used are copied onto the pitch, and the hit kind is stored on the pitch.
   - **Confirmed: an edit mid-session changes only later pitches.** One exception: editing a logged pitch's type in the
     in-session editor rescores that pitch against the live cells (5723).
3. **There is no perspective question at the start (see B1).**
   - Perspective is `activeSession.chartingPerspective` (`behind_catcher` / `behind_pitcher`).
   - **Bullpen:** starts from this device's last choice (`lastChartingPerspective`, `freshActiveSession` 5120).
   - **Live Game:** forced to behind the catcher (7122).
   - **The lock:** `selectPerspective` (5241) refuses once `pitches.length > 0`; `renderPerspectiveToggle` (6963) shows it.
   - **Phones:** a roll-up drop-down (`persp-rollup`) plus full chips in the ⋯ sheet.
   - **Phone bullpen's count line** already shows a plain label `ph-persp` "Catcher / Pitcher · locked" (11574-11578).
   - **Live Game phones** have no such line.
4. **The ⏱ clock is in bullpens only, in two places, and is baseball only.**
   - **Where it shows:**
     - phone: `renderPhoneDeliveryRow` → `renderTimeToPlateBtn(true)` (11445);
     - iPad / laptop: `renderDeliveryToggle` (8883, skipped for games since Oct 14).
   - **How it works:** state `state.ttp`, `tapTimeToPlate` 5298, `takeTimeToPlate` 5324 (the pen tap at 5674). Games already
     write null.
   - **Every reader already handles null:**
     - tracker load (6407);
     - History's average (`avgTimeToPlateMeta` / `sessionTtp`, '' when none);
     - `finalize_session_stats` (`count` / `coalesce`);
     - `from_rows.ts:45`;
     - `helpers.ts:74 timesToHomeLine` ('' when none);
     - `template_game.ts:523`;
     - export (`toCsv` writes '').
   - Trends and `compute_game_summary` don't read it. **No Edge Function change is needed.**
5. **There is no "change pitcher" button. The R3 hand-off happens at save.**
   - `endSession` (5754) calls `saveGameHandoff` (7144). It writes localStorage `kb:gameHandoff`, which lasts 5 minutes and
     applies only to the same team and sport and a different pitcher. It holds: inning, outs, balls, strikes, runners, opponent,
     runner owners `meta`, phantom outs, `sessionId`, owner names.
   - The next game start shows **"Continue from where X left off?"** (7423, `q.carry`). On Yes, `startSessionNow`
     (7252-7271) copies the state and calls `gameStartInherited` (7323), which sets `runnerMeta`, `relievedSessionId`,
     `inheritedRunners` and `carriedCount`.
   - "Starting mid-game?" / "Who was pitching?" (7335 / 7387) is the manual path to the same thing.
6. **Roster and saving:**
   - **Choosing a pitcher:** a coach does it in the roster (`selectPitcher` 4240, from 14496). It leaves an open session as
     that pitcher's draft (drafts are per pitcher and team), and going back offers "Resume session / Discard".
   - **Saving:** `endSession` returns nothing. It refuses with no pitches, queues the session, writes the hand-off, makes a
     fresh session and goes to History.
   - **Discarding:** `armDiscardSession` → `discardActiveSession` (11283-11284) is a two-step inline confirm.
   - **The header** (`renderSessionHeader` 11255) has the name as a plain span. Only "‹ team" and ⋯ are buttons.
7. **The parent's player profile is `renderProfileView`** (13507-13530), the same page as a pitcher's own.
   - Order: photo buttons (`renderHeadshotControls` 13516) → uniform numbers → level → **Throws → Pitch mix → Relative
     accuracy (all editable today)** → radar gun → name → "Who can see …" → email / password / data.
   - Writes go to the player's row (correct).
   - Linked guardians and children see `renderLinkedProfileView` (read-only; F1-G: "Nobody linked edits the profile").
8. **The coach checks:**
   - `coach_sees_pitcher(p_team uuid, p_pitcher uuid)` (`f1a_facilities.sql:103`).
   - Any-team forms: `is_coach_of_pitcher(p)` (f1a:352; no archived check) and
     `is_current_coach_of_pitcher(p, at)` (f1a:397; skips archived teams).
   - `set_pitch_arsenal` can reuse it, with `p_types text[]` to match the column (not `jsonb`):
     ```
     is_my_profile(p) or exists(pitcher_teams pt where pt.pitcher_id = p
       and coach_sees_pitcher(pt.team_id, p) and not is_team_archived(pt.team_id))
     ```
   - No policy change, so the count stays 32.
9. **Policies: staging 32, production 32** (queried Nov 6).
10. **Softball** (`hasDelivery: false`):
    - phone bullpen: the delivery row holds only the pitch strip;
    - phone Live Game: the status bar ends at the runner diamond, with the strip below;
    - wide: no delivery toggle.
    - (`hasTimeToPlate` in `SPORTS` is never read.)

## B. Where the packet differs from the code

1. **E1 / Decision 1:** the U5 start question doesn't exist (it became a toggle on the charting screen).
   - E1 therefore means: the bullpen default changes from "this device's last choice" to always behind the pitcher; the
     Live Game default (behind the catcher) is already right.
   - The `lastChartingPerspective` setting stops being used.
2. **P1 "between Windup and Set":** on phones Windup / Set is one flip button. The "+" goes where the ⏱ is now: right of that
   button, before the pitch chips, the same size.
3. **P1 "the U3 list of 12":** baseball has 13 pitches, softball 8.
4. **P2 on Live Game phones:** there's no count line with the perspective on it; it's only in the ⋯ sheet. I'd add the same
   Catcher / Pitcher button to the Live Game status bar if it fits at 390px, and otherwise leave it in the sheet. The phone
   bullpen's roll-up drop-down goes, since the button replaces it.
5. **P4 "score":** the app keeps no team score (runs are each pitcher's own), so there's none to carry. Everything else in
   the hand-off is carried already.
6. **P4 continuation:** the existing "Continue from where X left off?" is exactly this question, already wired to R3 (5-minute
   window). The name-tap reuses it rather than adding a second one.
7. **"Changes queue like other profile edits":** no profile edit queues today. All of them are online only.
8. **"The client never writes profiles pitch columns directly":** installed apps on v336 and earlier still write directly
   (pitchers) and call `coach_set_pitch_types` (head coaches) until they update.
9. **Colours follow list position.** A removed pitch's dots fall back to the first pitch's colour, and every later pitch's
   colour shifts by one. Today that only happens in Profile; mid-session it would recolour the pitches already on the
   grid.

## C. Decisions needed before building

1. **Offline arsenal edits for the pitcher** (B7).
   - Recommended: online only for everyone (as today), with a plain "Needs a connection" message.
   - The alternative is a new small profile-edit queue (new code on the save path's neighbour; more to test).
2. **The direct write** (B8). Recommended:
   - the new app uses `set_pitch_arsenal` for every edit;
   - the column grant and `coach_set_pitch_types` stay until the old cached apps have updated;
   - a follow-up migration removes them (after Phase 5, say).
3. **Colours during a session** (B9). Recommended: the session keeps the colour order it started with (a copy of the list
   on the session), so removing or adding a pitch mid-session never recolours what's already charted. Profile and later
   sessions use the new list.
4. **Who else edits.** Recommended:
   - every coach who can see the pitcher edits the **arsenal and RA cells** (packet decision 3); assistants get the bubble;
   - name, throws, uniform and radar gun stay head-only (R6);
   - linked guardians and children stay read-only (F1-G); only the creating parent edits.
5. **After the name-tap save, where it lands.** Recommended: the new pitcher's start questions (team filing, RA, Intent),
   already answered with that pitcher's defaults and, in a game, "Continue …?" set to Yes. That's one "Start" tap, because
   the RA default and filing are per pitcher.
   - The alternative is to start charting at once with those defaults.
6. **Name-tap with pitches: is a third choice kept?** Today switching keeps the session as a draft.
   - Recommended: offer **Save**, **Discard** and **Keep charting** (cancel), with no "leave as draft". The "‹ team" button
     still leaves a draft as today.
7. **Hold on phones:**
   - a hold is 500ms and cancels if the finger moves (so swiping the chips still scrolls);
   - the iOS callout and text selection are off on chips;
   - on a computer, the same hold with the mouse;
   - for the keyboard, the "+" bubble lists every pitch with Edit accuracy / Remove anyway.

Apply order once built: backup → migration `2026110x000000_u15_pitch_arsenal` (staging first) → site. **No Edge
Function deploy** (no function reads anything that changes).
