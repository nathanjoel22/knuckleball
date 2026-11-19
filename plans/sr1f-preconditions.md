# SR1 Stage F · Email and the parent contact · preconditions (Nov 19, 2026)

Read at `07629d5` (main: SR1 A–E on production, v363). **Branch:** `sr1f-email-parent`, from `origin/main`.

**Pictures:** `e01` (coach email, game), `e02` (little league player email, bullpen).

**No migration.** `profiles.contact_emails` is jsonb, and nothing in the database checks its keys.

## 1. What changes, where it is now

| Where | Now | Stage F |
|---|---|---|
| `send-session-report/index.ts` L476–507 | one Resend message `to: emails` (all of them), subject "Bullpen Session Report — <name> — <date>", a plain "Your report is ready" email (`brandedEmail`) | **one message per recipient**, each with its slot's version (section 3) |
| `index.ts` L55 `MAX_RECIPIENTS = 3` | coach, additional contact, the pitcher's own | **4** (+ parent or guardian) |
| `index.ts` L298 recipient check | every address must be one of `Object.values(contact_emails)` | unchanged, and the slot is found the same way (the key holding that address) |
| `_shared/email.ts` `brandedEmail` | title, paragraphs, button | + a report summary block (headline, a row of 3–4 numbers, 1–2 bullets, rest, the 7-day line, the "compared with" line), tables and inline styles only |
| the report file (template.ts / template_game.ts) | the HTML | + one HTML comment at its end with each version's email summary as JSON (`<!--kr-email {...}-->`), written at save like the rest, so the email always says what the frozen report says |
| tracker contacts panel (L16995–17015), `saveContactEmails` (L5827) | Coach email · Additional contact · Your email (read-only) | + **Parent or guardian** (little league and high school players; section 4) |
| tracker sends (L13374, L13505, L16559) | `[coach, pitchingCoach, pitcher]` | `+ parent` |
| `sw.js` | `v363` | `v364` |

**Where the packet doesn't match the repo:**

1. **A parent-created player's "your email" slot is the parent's address.** The panel calls it "Parent email (reports
   go here)", and it's the parent's login. The packet maps the pitcher slot → player version, which would send the
   kid's "you" email to the parent. See question 1.
2. **The app sends to every saved contact on each send**; there's no picking. With a parent slot that's up to 4,
   over today's cap of 3, so the cap goes to 4.
3. **A resend reuses the frozen report, but the email was always written fresh.** The email's numbers have to match
   the frozen report, so the report carries its own email summary (the comment above). Reports made before Stage F
   have none and keep today's plain email. Nothing is re-rendered.
4. **The sending limits:** H1's limits count the sender's requests (still 1 per send) and recipients (already one per
   address, against each address and the daily cap), so they behave exactly as today. **Resend** may now count 3–4
   messages where it counted 1 (free plan: 100/day). At today's volume that's well inside, and the 90% breaker still
   guards it.

## 2. CLAUDE.md decisions this stage touches

| Recorded now (quoted) | New rule beside it |
|---|---|
| H1 3b: "emails only addresses saved in the player's report contacts (`profiles.contact_emails`, edited only by the owning login …)" | Unchanged. A fourth key, `parent`, is one more saved contact, edited by the same people. |
| "Report links open frozen HTML pages" | Unchanged. Each email's button opens the same file with its slot's `&v=`. |

## 3. Each recipient's email (slot → version, as the packet; question 1 for the parent-created case)

| Slot | Version | Subject | Body |
|---|---|---|---|
| Coach email (`coach`), Additional contact (`pitchingCoach`) | coach | "Game report: Sam Test · 5.0 IP, 5 K · Nov 15" / "Bullpen report: Sam Test · 18 of 42 on the spot · Nov 18" | headline · 4 numbers (game: Strike · 1st pitch · K / BB · Pitches; pen: On the spot · Strike · FB avg · Pitches) · top 2 stood-out items · rest (baseball games) · the 7-day line when over · "Compared with Sam's 3-month average (5 games)." · **Open the full report** (`&v=coach`) |
| the pitcher's own (`pitcher`) | player | "Your game report: …" / "Your bullpen report: 18 of 42 on the spot · Nov 18" | the player version's headline and numbers in "you". Little league: two numbers plus the best pitch ("14/25 fastballs on spot"), no velocity, and the button "See where every pitch went". High school: 4 numbers and 2 items. College: as coach, in "you". |
| Parent or guardian (`parent`) | parent (little league), else coach | as coach | little league: workload and rest first, then How it went, the numbers, and the button to `&v=parent`. High school: the coach email. |

- **Not in the email:** tabs and window switches.
- **The coach's focus line** in `e02` belongs to the coach-note packet.
- **Softball:** no rest or 7-day lines (Stage D).

## 4. Questions for you

1. **A parent-created player** (an under-13, or any player a parent made): the "your email" slot is the parent's own
   address.
   - **Recommendation:** that slot gets the **parent version** (a player with no login of their own can't read a
     "you" email). The new Parent or guardian field is then for a second parent, also the parent version.
   - **A teen's own login** keeps the player version.
2. **Who sees the Parent or guardian field:** **Recommendation:** every player who isn't college. That means a player
   whose own level, or any of whose teams' level, is little league, high school or high school & up, or who has no
   level at all. A player whose level and every team are college doesn't see it (the packet: "not offered to a
   college player").
3. **The test sends** (packet 20–21 need real inboxes; Resend refuses @example.com, and these are real emails).
   - **Recommendation:** one staging test player's contacts set to your Gmail with plus-addresses (e.g.
     `you+coach@…`, `you+kid@…`, `you+parent@…`), then **one send = three emails** to you.
   - I'd screenshot Gmail on the web. You'd open the same three in Gmail on your iPhone and in Apple Mail, and
     screenshot them for the evidence (I can't reach your phone).
   - **Your yes and the address are needed before I send anything.**
4. **Subjects** (packet): "Game report: <name> · 5.0 IP, 5 K · Nov 15" / "Bullpen report: <name> · 18 of 42 on the
   spot · Nov 18". The player's start with "Your". **Yes?**

## 5. Checks after your yes (packet 20–21, plus every-stage 1–4)

- **Messages:** one send to three slots → three Resend messages, each with its slot's version and `&v=` (the Resend
  log and the inboxes).
- **The parent field:** it saves for a little league player and isn't offered to a college player.
- **Rendering:** Gmail web (me), and Gmail iPhone plus Apple Mail (you).
- **Old reports:** a report made before Stage F still sends today's plain email.
- **The rest:** sending limits as before; `kb-shell-v364`; STATUS, CLAUDE.md.
