# W1 — Knuckleball in the App Store and Google Play (Oct 14, 2026)

**Joel, Oct 14, 2026.** Knuckleball ships as a native app on iOS and Android: a thin shell (Capacitor) that loads knuckleballonline.com, with the icon, splash and offline behavior from P2-05. The web app stays the product; the store apps are a second front door. Joel owns the Apple and Google accounts and every submission; Jordan or Claude Code builds the shell.

## Start today, in parallel with A1 and P2-05 (these take days, not minutes)

1. **Apple Developer Program** — enroll as **Knuckleball LLC** (organization, not individual; needs the LLC's D-U-N-S number, which Apple can look up or issue in a few days). $99/year. Enable two-factor on the Apple ID.
2. **Google Play Console** — register as an organization. $25 one-time. Google now requires a D-U-N-S for organization accounts too, and a verification step.
3. **A Mac with Xcode** (Joel's) — the iOS build and upload can only happen there. Android builds anywhere; Android Studio on the same Mac is simplest.
4. **A demo account for reviewers** on production: a coach login on a throwaway team with a few sessions, both sports reachable. Apple and Google both require working credentials in the review notes.

## What the shell does

- **Loads the live site** (`https://knuckleballonline.com`) in the app's web view; no bundled copy of the site, so every web ship reaches the apps with no store update. The service worker keeps it working offline inside the shell exactly as in Safari.
- **Native pieces:** app icon and splash (from P2-05's assets), status-bar color, safe areas, external links opening in the system browser, and the share sheet for report links. Nothing else native in v1 — no push, no camera, no payments (payments stay on the web; see "Store rules").
- **Two targets from one project** (`ios/`, `android/`), versioned with the site's CACHE_VERSION in the build number so a store build can be traced to a web version.
- **Separate repository** `knuckleball-app`, because the shell has a build step (npm, Xcode, Gradle) and the site's CLAUDE.md forbids adding one to the site repo. The site repo stays plain.

## Store rules this has to satisfy (the ones that reject web-wrapped apps)

| Rule | How Knuckleball meets it |
|---|---|
| Apple 4.2 "minimum functionality" — not just a website | Offline charting on the mound, home-screen install, the outbox that syncs later; the listing and review notes lead with this. |
| Apple 5.1.1(v) account deletion in-app | A1. |
| Apple 5.1.1 privacy policy URL + App Privacy "nutrition label" | privacy.html; the label declares: name, email, team/roster data, pitch data; no tracking, no third-party SDKs (true since P1-10 self-hosting). |
| Apple 3.1.1 in-app purchase | v1 sells nothing in the app and shows no purchase links inside it. When Phase 3 adds plans, selling to teams on the website stays allowed; the app must not link to it (reader-app style). Decide then. |
| Apple 1.2 / Google: user-generated content | Coach notes and names are visible only to a team; no public UGC. Note in review notes. |
| Age rating | 4+ / Everyone; the app's own age gate (P1-10) is stricter than the store's. |
| Google: Data safety form, target API level, 64-bit | Capacitor defaults meet these; fill the form from the same list as Apple's label. |
| Both: reviewer login | The demo account above, in the review notes. |

## Listing (Joel approves every word)

- **Name:** Knuckleball. **Subtitle (Apple, 30 chars):** "Pitch charting for coaches" (draft). **Category:** Sports.
- **Screenshots** in the D2 look: iPhone 6.7" and 6.1", iPad 12.9"; Android phone and tablet. The sign-in page, the bullpen chart, the Live Game diamond, a report, History. Produced from staging with the demo account.
- **Description** draft and keywords: separate short doc for Joel to edit; nothing promises data is "tamper-proof" or anything the privacy page doesn't say.
- **Support URL:** the getting-started/help page (P2-06) with the support email.

## Decisions made in drafting (Joel may override)

1. iOS and Android together; same project, one extra afternoon for Android.
2. Shell loads the live site rather than bundling it — simpler updates, one source of truth. (If Apple pushes back on "just a web view," the fallback is bundling the app shell locally with the same service worker; the packet's escalation covers it.)
3. Separate `knuckleball-app` repo with its own CLAUDE.md; Jordan can hold write access there.
4. No purchases, no purchase links in v1.

---

## The packet (paste for Claude Code, in the new repo)

```
ID:              W1
Title:           Native shells for iOS and Android (Capacitor) loading the live
                 site; store assets; submission checklist
Spec:            knuckleball-app/plans/w1-app-store-wrapper.md (this file; also
                 kept in the site repo under plans/ for the record).
Depends on:      A1 (account deletion) and P2-05 (manifest, icons, splash,
                 standalone polish) live on production before submission;
                 P2-06 (help page) before submission. The shell can be built
                 before those ship; submission waits.
Repo:            NEW knuckleball-app (private). The site repo gets no build step.
                 Joel creates the repo and the Apple/Google accounts; only Joel
                 uploads builds.

PRECONDITIONS — REPORT before code:
  1. Capacitor's current version and the iOS/Android minimums it supports;
     Xcode and Android Studio versions needed on Joel's Mac; whether his Mac
     meets them.
  2. How the site's service worker behaves inside a Capacitor web view
     (origin, scope, offline cold start) — a one-screen proof on a device
     simulator before anything else.
  3. Apple 4.2 and 5.1.1(v) guideline text, quoted, and Google's equivalent
     policies, with the line in this spec that answers each.
  4. What the App Privacy label and Google Data safety form must declare,
     from the list of data the site stores (profiles, contacts, pitches,
     notes, guardian emails) and the fact that nothing third-party loads.
  5. External-link handling: which site links must open in the system
     browser (privacy, terms, report links) and how Capacitor does it.
  Build nothing until Joel has read the report.

BUILD:
  - Capacitor project: bundle id com.knuckleballonline.app (confirm with
    Joel), app name Knuckleball, server URL https://knuckleballonline.com,
    allowNavigation limited to the site and Supabase hosts; icon/splash from
    P2-05's SVG via the Capacitor assets tool; status bar brand color; safe
    areas; external links → system browser; share sheet for report links.
  - Build number = site CACHE_VERSION at build time; version 1.0.0.
  - Scripts: one command each for iOS archive and Android AAB; a README for
    Joel with the exact Xcode and Play Console click paths.
  - Store assets folder: screenshots (from staging, demo account, D2 look),
    listing copy draft, review notes (demo login, offline-charting pitch).
  - knuckleball-app/CLAUDE.md: what the shell is and isn't; "only Joel
    uploads builds"; no product logic in the shell.
OUT OF SCOPE: push notifications; in-app purchases; bundling the site;
  native camera/video (Track V); any change to the site repo beyond P2-05.
ACCEPTANCE:
  1. iOS simulator and Joel's iPhone (TestFlight): cold launch offline shows
     Home and a pen can be charted and saved to the outbox; sign-in, Live
     Game, a report, account deletion screens all work; external links open
     in Safari; safe areas clean; icon and splash right.
  2. Android emulator and one physical Android device: same list.
  3. A web ship (CACHE_VERSION bump) reaches both apps without a store
     update, within one launch.
  4. App Privacy label and Data safety form filled from precondition 4; Joel
     approves listing copy and screenshots.
  5. TestFlight build and a Play internal-testing build installed by Joel and
     Jordan.
  6. Submission checklist complete; Joel submits both.
VERIFICATION: TestFlight on Joel's phone for a week of real use before
  submission.
ROLLBACK: the store apps are a shell; a bad web ship is rolled back on the
  site. A bad shell build is withdrawn in the store console and the previous
  build re-submitted.
SIZE: M build · review timing is Apple's (plan two weeks of back-and-forth).
ESCALATE IF: the service worker doesn't run inside the web view (then the
  fallback is bundling the shell locally — a different packet); Apple's
  review rejects on 4.2 (then prepare the bundled fallback and a response
  citing offline charting); the D-U-N-S / enrollment blocks for more than two
  weeks (submit Android first).
```

### Standing constraints (in force)

The site repo gets no build step. No product logic in the shell. Service-role keys never near the shell. The privacy label says exactly what the privacy page says. **Only Joel ships to production and only Joel uploads store builds.**
