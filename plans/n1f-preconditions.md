Written against: `143a868` (main; production v347, N1 Stages A-E live). Packet: `plans/n1-navigation-and-home.md`, Stage F, with
Joel's J2 (Nov 16: option A).

# N1 Stage F · Pitcher card and milestones · preconditions (Nov 17, 2026)

**Joel, Nov 17 2026: "I agree with all"** (Q1-Q6 as recommended), **and he replaced the milestone list** (below,
"Joel's milestones"), which wins over the packet's list in section 1.

## Joel's milestones (Nov 17 2026)

No pitch-count milestones ("100, 500, 1000, 2000 pitch milestones incentivize a pitcher to throw more pitches").
- **Sessions:** 1st session charted; 1st, 3rd and 5th bullpen charted; 1st, 3rd and 5th live game charted; then total
  sessions at 10, 20, 50, 75, 100 and every 50 after that.
- **Strikeouts in live games:** the 1st, 5th, 10th, then every 10 up to 100, every 100 up to 1,000, then every 1,000.
- **Top velocity:** every time a new top velocity is recorded, the first radar reading included.
- **The weekly run:** a banner at 4, 8, 12, 26 and 52 weeks running.

**Front end only:** no migration, no RLS change, nothing stored on the server. The store-app share needs a decision
(Q1), because one way of doing it means a new app build.

## 1. What Stage F changes

| What | Where now | Stage F |
|---|---|---|
| The pitcher card | the pitcher's page header is `renderPlayerIdent` (photo, name, chips) | The card (`f-pitcher-card.png`) heads the pitcher's page (coaches, Stage B) and a pitcher's own Account: a large faint uniform number; RHP / LHP; photo or initials; the team or facility name and the year (or "since <month year>"); the name; the pitch chips in the pitcher's colors; Sessions, Pitches, Top velo (only with readings), Accuracy; the KNUCKLEBALL wordmark and the site address. |
| Card totals | none | From the sessions the viewer can already read (History's data on the device): sessions, pitches (`pitch_count`, the number Home uses), top velo (`velo_max`), accuracy (the one U14 number, bullpens only). So a coach's card counts that team's view, and the pitcher's own card counts everything. |
| Share (J2, option A) | none | Drawn to a canvas by hand (no library) as a PNG. Offered only to an adult pitcher on their own card, and to the parent login a player sits on or a linked guardian for a player under 18. Never to coaches, view-only family or a teen's own sign-in. |
| Milestones | none | One list, each `{ id, label, test(sessions) }`, worked out on the device: pitches 100, 500, 1,000 then every 1,000; the 10th, 25th and 50th session; a new top velo (radar sessions only); the weekly run. Nothing on the server. |
| Milestone banner | none | On Home for 7 days after one is earned, one at a time, dismissable (remembered on the device) (`f-milestones.png`, top). |
| Weekly run and Recent | none | The run card ("4 weeks running", this week's days) and the "Recent" list (`f-milestones.png`). |

**Wording:** nothing ever tells a pitcher to throw more. A day with no session is "Rest", in green, and never breaks the
run; only a whole week with no session does.

## 2. What the pictures show that the packet doesn't

- **"ON PLAN"** beside "4 weeks running": there's no plan in the app to be on.
- **The run card** in the picture sits between the banner and Recent; the packet only places the banner (Home) and
  Recent (the pitcher's page).

Both are covered in Q4 and Q5.

## 3. Questions for Joel, each with a recommendation

**Q1. Share inside the iPhone and Android apps.**
- The app shell has the Share plugin, which shares text and links, but not the file plugin needed to hand it a picture.
- In a browser and the home-screen app, Share works with the picture where the phone supports it, and otherwise
  downloads it.

Options for the store apps:
- (a) Add the file plugin to the shell. That needs a new iOS / Android build, TestFlight and the device check again
  before submitting.
- (b) Show the finished picture full screen with "Press and hold the picture to save or share it". That's the phone's
  own menu, with no new build.

*Recommend (b) now*, and (a) folded into the next shell build if one is needed for other reasons. N1 needs no new build
so far.

**Q2. The player's photo on a shared picture.** Profile says "Only your coaches can see your photo".
*Recommend:* the shared picture uses the photo. Only the adult pitcher themself, or the parent / guardian of a minor,
can press Share, so it's their own choice about their own (or their child's) picture. On screen the card shows the photo
to whoever can already see it.

The alternative is initials only on the shared picture.

**Q3. The year on the card.**
*Recommend:* the year when every session is in one calendar year ("Thayer Pitching Lab · 2026"); otherwise "since
<month year>" of the first session. The name is the coach's current team; for a pitcher's own card, their current team,
or "Independent" when they have none.

**Q4. "ON PLAN".** *Recommend:* leave it out. There's no plan to be on, and "on plan" could read as a target to throw to.

**Q5. Where the run card and Recent go.**
*Recommend:*
- the banner on the pitcher's, teen's and parent's Home (7 days, one at a time);
- the run card and Recent under the card, on the pitcher's page (coaches) and the pitcher's own Account (Stage A's
  Pitcher settings group);
- not on Home, which already shows the week in the line score. Two week strips on one screen would repeat each other.

**Q6. When a milestone counts.**
*Recommend:* the date of the session that crossed it:
- pitches: the cumulative `pitch_count`, in date order;
- sessions: the nth saved session;
- top velo: the newest session whose `velo_max` beat every earlier reading (the first radar session only sets the
  mark);
- the run: weeks back from this one (or last week, when this week has nothing yet).

A coach sees milestones from the sessions their team can read, so their count can be lower than the pitcher's own. The
card and Recent say what they count from ("from this team's sessions" for a coach).

## 4. Not drawn

- **The Share preview sheet:** the PNG, then Share (or Save / Download) and Close. In the store apps it's the full-screen
  picture with the press-and-hold line (Q1).
- **No milestones yet:** no banner, and Recent says "Milestones show up here: the 100th pitch, the 10th session and
  more." (No "throw more" wording.)

## 5. How it will be checked

Every packet check (1-5, 29-31) on staging at 390, 820, 1180 and 1440.
- **29:** the card's totals against Trends' totals for the same pitcher; no Top velo for a pitcher with no readings.
- **30:** each milestone fires once, on the session that earns it, using a seeded pitcher. On staging I'd use DS1
  pitchers (Noah Lindqvist has the longest history) and check the dates against their sessions. A week with no session
  ends a run; rest days inside a week don't.
- **31:** the Share PNG matches the card. Share shows for an adult pitcher's own card and for a parent's / linked
  guardian's player under 18, and is absent for coaches, view-only family and a teen's own login.
