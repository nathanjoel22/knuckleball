# N1 Stage C · evidence (Nov 17, 2026)

Branch `n1c-home`, cache `kb-shell-v345`. Staging app (local server, staging config); no database change. Headless
Chrome with device emulation at 390, 820, 1180 and 1440. Pictures are in `plans/n1c-evidence/`; I scanned them for email
addresses and found none.

Today on the test machine was Monday, Nov 16 (local), so the week is Nov 15 to 21 and Monday is outlined.

## Every-stage checks

**1. Roles:**

| Role | Home (from the page) |
|---|---|
| DS1 pitcher (Andre Boateng), 390 | Line score S 0 · M **9** (outlined) · later days empty · P 9 · S 3; Chart today; Last session "Bullpen · Nov 16 · 3 pitches · 67% accuracy" with chips and Open report ›; Trends › (`c1-pitcher-390.png`) |
| U15 softball pitcher, 390 | The coach's note "U15 SOFTBALL COACH · NOV 16 / “N1 Stage C test note…”", the line score M 3, in softball colors (`c2-pitcher-note-390.png`) |
| Parent (U15 Kid), 390 | The player chip (no ▾, one player); "U15 threw 0 pitches in 0 sessions this week."; Chart today |
| View-only family, 390 | The same, without Chart |
| Manager, 390 / 1180 / 1440 | "This week · Thayer Pitching Lab · Nov 15 to 21"; Active 1 of 10, Sessions 3, Pitches 9; Start a session; line score "Boateng 0 9 · 9" and "+ 9 with no pitches this week ›"; Needs your attention (3 new pitchers; 9 haven't thrown in 5+ days, longest Mason Reilly, 23 days); By coach (Danny Ortiz 1 of 5 active, Jordan Thayer 0 of 0, Marcus Bell 0 of 5); Recent sessions (`c3`, `c5`, `c8`) |
| Pitching coach (DS1 coach 1), 390 | Active 0 of 5; their group's 5 only; Needs your attention: 5 idle + 5 unread messages (`c4-pcoach-390.png`) |
| Normal-team assistant, 390 | the coach Home without By coach |

**2. Offline:**
1. One online load at 1180, then a reload with the network off (the service worker served it).
2. Home drew fully from the saved copy: Active 1 of 10, Sessions 4, Pitches 12, the line score, and Needs your
   attention.
3. It said "As of Nov 16, 11:29 PM" (`c7-offline-home-1180.png`).

**3. Charting:** two bullpens were saved through the app this stage, one by the U15 coach and one by the manager while
offline (check 22). Both synced, and neither showed a bar or menu while charting.

**4. Side by side:**

| Picture | Built | Differences, and why |
|---|---|---|
| `c-home-pitcher.png` | `c1-pitcher-390.png` | Same order and surfaces. The plot is History's own (with its home plate under it) rather than the drawing's bare zone, as the packet says (`renderHistoryPlot`). Days after today are empty outlined cells (Q3). The "Finish setting up your profile" banner above is the existing setup reminder; Stage D decides what to keep. |
| `c-home-parent.png` | parent at 390 | Same order. No note or report yet for U15 Kid (no team, no sessions), so those cards don't draw. |
| `c-home-coach.png` | `c3-manager-390.png` | Same order (numbers, Start a session, line score, Needs your attention). The manager's first tile is light, as the design reference says for owners. A normal coach's is dark. |
| `c-line-score.png` | inside `c1` / `c5` | The same cells, colors and today outline. On the pitcher's Home the label is "This week · pitches"; on the coach's, one row per pitcher with last names. |
| `b-sidebar-ipad.png` (owner Home) | `c5-manager-1180.png` | Needs your attention beside the line score, as drawn. The title is "This week" with the facility's own name (Q8). By coach and Recent sessions sit under them. |

**5.** `CACHE_VERSION` is `kb-shell-v345`. STATUS.md and CLAUDE.md are in this PR, and the pre-push checks run at push.

**Bar:** at 390 no Home's last control is under the bar, for the manager, the pitcher, the parent or the assistant
(footer 708 / 498 vs bar top 738).

## Stage C checks

**19.** Line-score totals equal History's for the same week. Andre Boateng: 9 pitches in 3 sessions on the line score
and 3 × 3 in History (later 12 in 4, after check 22's pen).

**20.**
- Real data: Noah Lindqvist at 6 days is listed (part of "9 haven't thrown"), and Andre Boateng at 0 days is not.
- No staging pitcher sat at exactly 4 or 5 days, so the cutoff was checked on the device: 4 days false, 4 days 23 hours
  false, 5 days true, 6 days true (`IDLE_FLAG_DAYS = 5`).

**21.** The pitching coach's Home covers their group's 5 pitchers (Active 0 of 5). The manager's covers all 10, and By
coach shows the same group sizes as the roster (Danny Ortiz 5, Marcus Bell 5).

**22.** As the manager, offline:
- A 3-pitch pen for Andre Boateng was saved to the outbox (1 item).
- Home showed Sessions 4, Pitches 12, "Boateng 0 12 · 12", and the newest recent session "… · waiting to sync"
  (`c6-offline-pending.png`).
- Back online, it synced (outbox 0), and the totals stayed 4 / 12 with nothing counted twice.

**23.** As the U15 team's head coach (staging):
- I saved a 3-pitch pen for "U15 Softball Pitcher".
- I added one note through the existing insert rule (`session_notes`, the coach's own profile; no email).
- Signed in as that pitcher, Home showed the note card (`c2-pitcher-note-390.png`). Facility pitchers show no note card,
  since facility teams have none until Stage E.

**The parent, not run end to end:** U15 Kid has no team, so no coach can leave them a note. The note read rule allows
the parent (`is_my_profile(pitcher)`) and linked logins (`is_linked_to(pitcher)`), and the parent's Home uses the same
`renderNoteCard` with "For <name> · from …".

## Found and fixed while checking

On phones the manager's line score was drawn below Needs your attention. The Home now uses grid areas: phones get line
score, attention, by coach, recent; above 860px attention sits beside the line score, as drawn.

## Staging test data from this stage

- A 3-pitch pen for "U15 Softball Pitcher" (U15 coach), with one test note on it.
- A 3-pitch pen for Andre Boateng (manager, charted offline).
- `u15-sbpitch-03123297@example.com` has the throwaway password.
