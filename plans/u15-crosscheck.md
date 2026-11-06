# U15 — cross-check and acceptance (staging, Nov 6 2026, v337)

Local staging site (`localhost:8000`, staging database) in Chrome, driven over the DevTools protocol.
Widths: 390 (phone, touch), 768 (iPad portrait, touch), 1180 (iPad landscape, touch), 1440 (laptop, mouse).
Logins:
- an assistant coach on Staging Knights (baseball, two pitchers);
- test logins made for U15 (`u15-*@example.com`): a softball head coach with one pitcher, that pitcher, and a parent
  with a player added in the app.

## Per screen

| Width | Sport | Kind | "+" | Clock | Perspective control (default) | Name tap (coach) | Hold chips | Sideways scroll |
|---|---|---|---|---|---|---|---|---|
| 390 | baseball | pen | right of Windup | none | button on the count line (Pitcher) | switch sheet | yes | 0 |
| 390 | baseball | game | start of the pitch row (Windup is in the scoreboard) | none | button under the scoreboard (Catcher) | switch sheet | yes | 0 |
| 768 | baseball | pen / game | beside the delivery control | none | chips (Pitcher / Catcher) | name in the header | yes | 0 |
| 1180 | baseball | pen / game | beside the delivery control | none | chips (Pitcher / Catcher) | name in the header | yes | 0 |
| 1440 | baseball | pen / game | beside the delivery control | none | chips (Pitcher / Catcher) | name in the header | yes | none |
| 390 | softball | pen / game | first in the pitch row (the delivery slot) | none | button (Pitcher / Catcher) | n/a, one pitcher | yes | 0 |
| 768 | softball | pen / game | beside "Pitch type" | none | chips (Pitcher / Catcher) | n/a | yes | 0 |
| 1180 / 1440 | softball | pen / game | beside "Pitch type" | none | chips (Pitcher / Catcher) | n/a | yes | 0 / none |

At 768, with a coach's roster list open, the page under it is blank (v336, as designed). The checks were made with it
rolled up.

**Other screens:**
- Profile → Pitch mix shows chips and Edit pitches, which opens the bubble.
- The coach's Player Profile (assistant) shows Pitch mix with Edit pitches and Relative accuracy. Name, throws and
  uniform stay text, with "Only the head coach can change the name, throws and uniform number."
- On a parent's player profile, Pitch mix and Relative accuracy sit directly under the photo.
- The new-player "Welcome" box shows Pitch mix with Add pitches, and the bubble opens over it.

## Acceptance

1. **Phone bullpen:** the "+" sits right of the Windup / Set button, the clock's old slot and size (44 px). The app shows
   no ⏱. A pre-U15 session's History shows "Time to home (2) 1.25" (`41dfb237…`, Sept 30). Today's pen shows none. Every
   report reader already skips missing times (preconditions A4), and no report was regenerated.
2. **"+" opens the bubble on Add:**
   - an assistant coach added Slider to a rostered pitcher (`set_pitch_arsenal`); the chip appeared in the strip;
   - a softball coach's change showed on the pitcher's own login, in the strip;
   - crafted calls were refused, in the app (parent → another pitcher: `not allowed`) and in `u15_pitch_arsenal.sql`
     (other team's head, other group's coach, archived team).
3. **Hold and remove:**
   - holding Curveball (touch, 750 ms) opened the bubble on Curveball and selected nothing; a short tap on Changeup
     selected it and opened nothing;
   - Remove asks "Remove Curveball from the pitches? Pitches already charted keep it.";
   - after removing the thrown Curveball, the two charted pitches kept their type and colour (`rgb(34,181,115)` before
     and after), the strip dropped CB, and the selection cleared;
   - the report list for that session is the arsenal plus Curveball.
   - **Two-pitch proof** (RA on, staging session `a3cda8bf…`):

     | Pitch | Curveball's marked cell at the time | Landed | Stored hit kind |
     |---|---|---|---|
     | 1 | 0-0 | 0-0 | `ra` |
     | 2 | 4-4 (edited mid-session) | 0-0 | `miss` |

     Pitch 1 still reads `ra` in the database after the save.
4. **Perspective:**
   - a bullpen opened behind the pitcher and a Live Game behind the catcher, with no question;
   - the button flipped Pitcher → Catcher → Pitcher before the first pitch;
   - after pitch 1 it reads "Pitcher · locked" and a tap shows "Perspective is set for this session." (the perspective
     didn't change); on iPad / laptop the chips were disabled after the first pitch;
   - discard gives a fresh session, unlocked;
   - storage is unchanged: the U5 capture code wasn't touched (`perspectiveCol` at the tap).
5. **Switch pitcher:**
   - mid-pen with a pitch, Discard and switch was two-step; it landed on the other pitcher's bullpen start, and the old
     draft is gone;
   - with no pitches it switched at once;
   - mid-Live-Game, after a walk put a runner on 1B: Save and switch → "Continue from where <the starter> left off?" (set
     to Yes) → Start. The reliever's game began in inning 1, 0 outs, 0-0, runner on 1B (inherited, owner = the starter's
     game);
   - saved on staging: the reliever's `relieved_session_id` = the starter's game, `inherited_runners` 1, `runners_left` 1;
     the starter's line is still open (his runner is still on base, as R3 intends);
   - R3 Stage B's database test was re-run with every check as recorded. Its fixture's second pitcher had left Staging
     Knights, so the run used the team's current second pitcher (a scratch copy; the repo file is unchanged).
6. **Parent:** Pitch mix and Relative accuracy sit right under Upload photo. Through the bubble the parent added Four
   Seam Fastball and Slider and marked Slider's cell 1-1. The database shows `Four Seam Fastball/Slider`, and the
   player's charting strip shows 4SFB, SL.
7. **Softball:** the "+" is in the delivery slot on phones and beside "Pitch type" elsewhere. No clock. Everything else
   is the same as baseball (table above).
8. **Database and release:**
   - RLS matrix before / after on staging identical; 32 policies (`plans/u15-rls-matrix.md`);
   - the new function's refusals proven;
   - CACHE_VERSION v337;
   - STATUS.md entry written;
   - pre-push checks run before the push.

## Also checked
- **Offline:** "+" → add says "Needs a connection. Changes to pitches save online." and nothing changes. Charting a
  pitch offline still works.
- **Pitcher logins:** the name is not a button.

## Not run
- **On a real iPhone / iPad.** Long-press feel, the iOS callout and the switch sheet need Joel's device check.
- **Linked guardian / teen logins.** They're read-only by code (`canEditArsenal` returns false for any linked
  sign-in); no linked test login exists on staging.
- **A facility coach in the app.** Covered by the database test only; staging has no facility right now.
