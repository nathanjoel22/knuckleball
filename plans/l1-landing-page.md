# L1 — Landing page at knuckleballonline.com (Oct 21, 2026)

**Jordan + Claude, Oct 21, 2026; Joel's copy comments applied Oct 20.** knuckleballonline.com stops opening on "Which sport?" and opens on a landing page instead: the hero film, then how it works, the real charts, coaches, players & parents, pricing, FAQ. The picker doesn't go away. It moves, unchanged, to `start.html`, where Sign in and Join take you. Anyone already signed in still goes straight to the tracker, and every link that exists today keeps working.

- **Reference mockup:** `docs/design/landing/l1-mockup.html` (serve the repo root and open it; "Show review notes" explains each section). Viewing copy: https://claude.ai/artifact/DBDfsda9GSpdJhuvuc2rfb
- **Media:** the hero film and the landing images arrive in a separate PR from Jordan (**L1-media**), under `media/`. Stage B needs it.
- This packet will be amended when Joel adds or changes sections. Amendments go at the bottom, dated.

## What ships

1. **Root routing (the risky part).** `index.html` becomes the landing page. Before anything paints, a small router decides:
   - a stored Supabase session (the same check today's `index.html` does, P1-01) → `bullpen-tracker.html`, unchanged;
   - any query string the picker understands (`sport`, `role`, `choose`, `join`), or any auth parameter in the query or hash (`access_token`, `refresh_token`, `type`, `code`, `error`, `error_description`) → `start.html` with the query **and** hash intact;
   - otherwise → the landing page.
2. **`start.html` is today's `index.html`**, behavior unchanged: Which sport? → Who are you? → `login.html?role=…&sport=…`. Its head keeps the manifest, icons, splash links and theme script. Links that mean "the picker" point to it:
   - `login.html:124` (`index.html?choose=1`) and `login.html:161` (Back);
   - the "Back to Knuckleball" / Back links in `join.html` (77, 151, 316) and `join-coach.html` (79, 140, 268).

   Footers that link to `index.html` as "knuckleballonline.com" (`privacy.html:194`, `terms.html:133`) keep going to the landing page, which is right for a footer. The router (1) covers anything that still passes `?sport=` to the root.
3. **Nav:**
   - the lockup on the left: the main mark, **The spot**, then the KNUCKLEBALL wordmark (amendment 1). The footer uses the same lockup;
   - How it works · Coaches · Players & parents · Pricing;
   - **Sign in** → `start.html`;
   - **Join** (primary) → `start.html?join=1`, whose role step links to the sport's sign-up pages instead of `login.html`.

   The nav is fixed, transparent over the film and solid once the page moves. Below 1020 px the links go into a menu button; below 440 px Sign in moves into that menu too, so the nav stays on one line.
4. **Hero film** (`media/`, self-hosted):
   - `<video muted autoplay playsinline preload="auto">` with the 4:5 files for `max-width: 767px` and 1080p otherwise, AV1 WebM first, then MP4, and a poster;
   - it **plays once and holds its last frame**: no `loop` attribute, no `ended` handler that seeks;
   - a visible Pause control, bottom right on desktop. A paused film stays paused; after the end it becomes Replay (from 0 s);
   - pause while the hero is off screen, but never restart an ended film;
   - `prefers-reduced-motion`: no autoplay, and the strike still as the poster;
   - desktop: copy on the left scrim. Phone: the 4:5 film on top, copy below it, never over a face;
   - the hero is `position: sticky` and the page slides up over it with angled band edges (the Whoop move).
5. **Service worker:** in the fetch handler, before any cache logic, `if (url.pathname.startsWith('/media/')) return;`. Video uses byte-range (206) requests, which `cache.put` rejects and which break Safari playback when a worker intercepts them. All landing images live under `/media/` too, so none of it enters Cache Storage. Precache `/start.html`. Bump `CACHE_VERSION`.
6. **Sections, in order** (layout, look and draft copy are in the mockup):
   1. Hero;
   2. the gold line band;
   3. How it works (three phones);
   4. The charts (crops of a real report);
   5. Coaches (two phones);
   6. Players & parents (two phones: a softball report and the trends);
   7. Arm care (built but `hidden` at launch);
   8. Pricing;
   9. FAQ (`<details>`);
   10. the closing band;
   11. footer (Privacy, Terms, Delete account, Sign in).
7. **Copy.** Joel approved these on Oct 20. Ship them exactly:

   | Where | Text |
   |---|---|
   | Hero, above the headline | At Knuckleball, we don't believe in a waste pitch. |
   | Hero headline | Every pitch has a purpose. ("purpose." in gold) |
   | Hero subline | Chart every bullpen or live game from your phone. Every pitch is recorded to form heat maps, velocity spreads and post-game reports to help you learn, grow and transform into the best pitcher possible. |
   | Gold band | Every intention. Every pitch. Every result. / Because when you practice with purpose, the results speak for themselves. |
   | How it works, subline | Tap where you aim, then tap where it lands. Knuckleball does the rest. |

   Everything else on the page is a **draft** (Claude's, from the mockup), including the button labels, section headlines, feature lists and the FAQ. Joel signs it off before production. The FAQ must agree with `privacy.html` (Version 2026-10-17, data licensing): nothing may promise "we never sell your data".
8. **Look.** Only `css/tokens.css`, `css/components.css` (`.slant-tag`), the U13 buttons and the self-hosted faces: Big Shoulders Display, Archivo, Black Ops One for the wordmark. No new colors. Dark and light bands alternate; the page is never dark the whole way down. Copy sits in max ~56ch.
9. **Images are invented test data only.** Jordan's are real app and report screens rendered from a made-up coach, team and pitchers. Joel may swap in screenshots from his own test logins. Never a real player's account, name or photo (minors use the app).
10. **Privacy.** Nothing loads from another host: no video embed, font CDN, analytics or tag scripts. Adding any of them needs a privacy-policy change first.

## Decisions made in drafting (Joel may override)

1. The picker moves whole to `start.html`. The D2 mockup's sport tray inside the sign-in form can come later as its own packet; L1 doesn't redesign sign-in.
2. Signed-in visitors skip the landing page (the P1-01 rule): opening the site on dead wifi still lands a coach in the tracker.
3. Join → `start.html?join=1`, so the role step goes to sign-up rather than log-in.
4. All landing media under `/media/`, outside the service worker. Offline, the landing page loads without its film and images, which is fine because signed-in users never see it.
5. Arm care is built but hidden at launch.
6. Pricing ships as the **Free** card plus one line, "Paid plans for families, teams and facilities are coming". The four cards (Free / Plus / Team / Facility) wait for Stage D, when Joel sets prices.
7. The hero's Replay control stays (the alternative is hiding it after the film ends).

## Open (Joel's)

- **Prices and plan names** (Stage D).
- **Draft copy:** Coaches, Players & parents, FAQ, the buttons and the closing band.
- **The hero text split:** the line "Every intention…" sits in its own gold band. Or put it all in the hero?

---

## The packet (paste for Claude Code)

```
ID:              L1
Title:           Landing page at the root; the sport picker moves to start.html
Spec:            plans/l1-landing-page.md on GitHub (pull first; work only from
                 GitHub). Reference: docs/design/landing/l1-mockup.html (layout,
                 sizes, draft copy; ignore its review notes and mockup-only
                 script). Look per docs/design/target/DESIGN.md; tokens from
                 css/tokens.css; buttons from the U13 set.
Depends on:      D2 (tokens, fonts, components), P2-05 (manifest, icons, splash on
                 the root page today), W1 (store shells open bullpen-tracker.html),
                 and Jordan's L1-media PR (media/) for Stage B.
Staging only.    Local http://localhost:8080 against staging. No database change.
                 Only Joel ships to production.

PRECONDITIONS — REPORT before code:
  1. git pull; read the top of STATUS.md. media/ holds hero-1080p.{webm,mp4},
     hero-4x5.{webm,mp4}, hero-poster{,-4x5}.jpg, hero-still{,-4x5}.jpg and
     media/landing/*.png -- if not, stop (L1-media isn't merged).
  2. Inbound-link audit. Every link, redirect or URL that reaches /,
     /index.html, ?sport=, ?role=, ?choose= -- in pages, scripts, sw.js, edge
     functions and email templates -- plus, on production AND staging: the
     Supabase Auth Site URL and redirect allow-list, the auth email
     templates, and the values of INVITE_REDIRECT_URL, VERIFY_REDIRECT_URL,
     GUARDIAN_REDIRECT_URL, EMAIL_CHANGE_REDIRECT_URL. A table: source
     (file:line or setting) -> where it lands today -> where it lands after
     L1. Known on Oct 21: login.html:124 (?choose=1) and :161; join.html
     77/151/316 and join-coach.html 79/140/268 (index.html?sport=);
     privacy.html:194, terms.html:133 (footers); sw.js precaches / and
     /index.html; report emails link login.html?sport= (not the root).
  3. Every auth flow that can arrive at the root with a token, code or error
     in the URL (sign-up confirmation, recovery, invite, magic link, email
     change) and what today's index.html does with it. Staging's Site URL
     stays http://localhost:8080 (DEPLOY.md) -- don't change it.
  4. Confirm nothing installed opens the root: manifest start_url
     (/bullpen-tracker.html), the knuckleball-app shells' server.url, and
     what a pre-P2-05 home-screen bookmark of / will do after L1.
  5. sw.js fetch handler: where the /media/ bypass goes, and proof that
     without it a visit would put the video in Cache Storage.
  6. index.html's <head> today, line by line: what start.html keeps, what the
     landing page needs (manifest, theme color, icons yes; splash links and
     the sport theme script only where they're used).
  Build nothing until Joel has read the report.

BUILD (one stage per commit; each stage testable on its own):
  A. Routing.
     - git mv index.html start.html (behavior unchanged; ?join=1 makes the
       role cards link to the sign-up pages).
     - New index.html: the before-paint router (spec 1) + a minimal page
       (wordmark, Sign in, Join).
     - Repoint the picker links (spec 2) to start.html.
     - sw.js: precache /start.html; CACHE_VERSION.
  B. Shell + hero.
     - The nav (spec 3).
     - The hero film and controls (spec 4), sticky with the slide-up, and
       the gold line band.
     - sw.js /media/ bypass (spec 5); CACHE_VERSION.
  C. Sections (spec 6-9).
     - How it works, The charts, Coaches, Players & parents, Arm care
       (hidden), Pricing (Free + "coming"), FAQ, closing band, footer.
     - Approved copy exactly as in spec 7; draft copy from the mockup.
  D. Pricing, when Joel sets prices: the four cards from the mockup.
OUT OF SCOPE: the favicon, app icon and splash images (their own packet,
  from assets/app-icon.svg via scripts/splash.js); a sign-in redesign or
  sport tray in login.html; analytics or any third-party load; copy beyond
  spec 7 and the mockup; the tracker, reports, database and edge functions
  (if the audit says one must change, escalate).
ACCEPTANCE (both sports where it applies):
  1. Every row of the precondition-2 table lands where it says after L1
     (click-path or curl + the router's decision), including
     /?sport=softball, /?choose=1, the join Back links and a report
     email's sign-in link.
  2. A stored session: / opens the tracker straight away, online and in
     airplane mode (P1-01 checks 1-3 pass).
  3. Each auth flow from precondition 3 reaches its page with the token,
     code or error intact (staging).
  4. Signed out: / shows the landing page. Sign in -> picker -> log in works
     for baseball and softball; Join -> picker -> sign-up page.
  5. Film: plays once and holds its last frame; 16:9 at >= 768 px, 4:5
     below; Pause stays paused; Replay restarts; reduced motion shows the
     strike still with no autoplay; pauses off screen, never restarts after
     the end; iOS Safari plays it.
  6. After a visit, Cache Storage has no /media/ entry; CACHE_VERSION is
     bumped; the installed app and both store shells still open the tracker.
  7. The landing page's network tab shows no request to another host.
  8. Screenshots at 390 / 375 / 768 / 1280 / 1440: no horizontal scroll,
     the copy never over a face in the film, every section in order.
  9. The approved copy (spec 7) matches character for character.
VERIFICATION: Joel on his iPhone and desktop: open / signed out and signed in;
  tap an old email link and a join link; open the installed app.
ROLLBACK: git revert (index.html becomes the picker again); CACHE_VERSION bump.
SIZE: M-L.
ESCALATE IF: any inbound link or auth flow can't be kept working; an auth
  flow or setting depends on the root page itself; the store shells or the
  installed app open the root; iOS won't play the self-hosted film; anything
  would need a third-party host, an analytics script or a privacy change.
```

### Standing constraints (in force)

No build step on the site. No fonts, scripts, video or images from other hosts. GitHub is the source of truth; pre-push checks finish before any push. Minors use the app: no real user data in any image. **Only Joel ships to production.**

## Amendments

1. **Oct 21, 2026 (Jordan + Joel): the logos.**
   - **Main logo: The spot**, design #2 of Jordan's Knuckleball Mark Concepts: the strike zone slanted like the brand tags, the low-outside pocket lit. It's the mark for the app icon, the favicon and the splash screen, and the one beside the wordmark in the nav and footer.
   - **Secondary logo: Strikeout**, design #1: home plate in true 17-inch proportions with the Black Ops One K and the spot. It's for limited uses, such as the outfield grass striping in the Live Game field.
   - **For L1:** the nav and footer use the main mark. The SVG `<symbol id="kb-mark">` is in `docs/design/landing/l1-mockup.html`. Its cells take `currentColor` and the lit pocket takes `--mark-lit` (default `--accent`), so softball gets rally pink with no extra file.
   - **Fix for `docs/cf-logo-mown.md`:** its text names #1 (Strikeout) for the outfield, which is right under this decision, but its SVG draws #2 (`kb-spot`, the keypad). The mown version should be the home plate. Correct the SVG before that change is built.
   - The favicon, app icon and splash images with the main mark are a separate packet. L1 doesn't change them.

