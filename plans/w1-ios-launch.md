# W1-iOS — Getting Knuckleball into the App Store (launch plan, Nov 10, 2026)

**Joel, Nov 10: "focus on getting Knuckleball in the iOS App Store next."** Updated the same day with Joel's answers: **the Knuckleball LLC Apple Developer membership was approved around Nov 1**, Joel's phone is now an **iPhone 17 Pro Max**, and **the app icon is "The spot"** (the main logo: the slanted 3×3 zone with one lit pocket, `kb-mark` on the landing page) drawn as **white cells with the gold pocket on the brand field green**. This plan builds on `plans/w1-app-store-wrapper.md` (Oct 14), `plans/w1-preconditions.md` (offline-in-WKWebView proof passed Oct 15) and the `knuckleball-app` repo, where the iOS shell has been built since late October. Android continues in parallel but is not the focus here.

**Nov 10, evening:** step 1 below is done through the simulator — signing with Knuckleball LLC is set, the project builds, the film → spot card → sign-in sequence and the status-bar edge look right on the iPhone 17 Pro Max simulator. Xcode shows "Your team has no devices" until the phone is plugged in once; that is expected. The project opens from `ios/App/App.xcodeproj` (Swift Package Manager; there is no `.xcworkspace`).

## What stands between today and "Ready for Sale"

| Gate | Owner | State Nov 10 | What unblocks it |
|---|---|---|---|
| **G1 Apple Developer Program membership** (Knuckleball LLC) | — | ✅ **Approved ~Nov 1** | Nothing. Sign every build with the LLC team from the first run; no Personal Team detour. |
| **G2 The shell on a real iPhone** | Joel + Claude Code | Builds and runs on the simulator; phone install waits on the cable | Plug in → Trust → Developer Mode → Run, then the device check. |
| **G3 App icon** | Claude Code from the repo | ✅ **Decided Nov 10:** The spot, white cells, gold pocket, on brand green; generated from the landing page's `kb-mark` SVG by the Capacitor assets tool; no wordmark in the icon | Part of the Claude Code prompt below. The same file becomes the P2-05 web icon and un-holds the install banner. |
| **G4 App Store Connect record + TestFlight** | Joel, Claude Code prepares | Can start now | Steps 6–12. |
| **G5 Review** | Apple | After G4 | Submit; typical first review 1–3 days; the 4.2 answer is prepared (step 15). |

## Step by step

### Phase 1 — this week

1. **Sign with the LLC and install on the phone (G2).** Xcode → Settings → Accounts → + → Apple ID → sign in with the enrolled Apple ID; the team list shows your personal team and **Knuckleball LLC**; select Knuckleball LLC → Manage Certificates → + → Apple Development. Open `ios/App/App.xcodeproj` → the blue "App" at the top of the sidebar → Signing & Capabilities → tick Automatically manage signing → Team: Knuckleball LLC → Bundle Identifier `com.knuckleballonline.app`. A yellow "Your team has no devices" warning stays until a phone is connected once. Plug in the iPhone 17 Pro Max and tap Trust; Developer Mode appears under Settings → Privacy & Security only after the phone has met Xcode once (Window → Devices and Simulators registers it) → turn it on → restart → confirm. In Xcode pick the iPhone as the run destination → Run (▶). If the phone says "Untrusted Developer": Settings → General → VPN & Device Management → trust Knuckleball LLC.
2. **Device check on the iPhone 17 Pro Max**, results written by Claude Code in `knuckleball-app/plans/w1-ios-device-check.md`: airplane mode on → force-quit → reopen → the app comes up with sessions, a short pen charts and waits in the outbox; airplane off → it syncs; sign out and in; a Live Game with Intent on; a report opens; Profile → Delete account to the confirm step and back; Privacy/Terms/report links open in Safari, not inside the shell; nothing draws under the status bar on any page (the Oct 15 inset bug); icon and splash (placeholder until step 3's icon is generated); after a site ship, the "new version ready" bar appears and a reload picks it up without reinstalling (W1 acceptance 3).
3. **The icon (G3).** Claude Code renders the spot from `kb-mark` — white cells, gold pocket, brand green (`--brand-bg` `#061A12`) background, the mark at about 70% of the square, no wordmark, no transparency, no rounded corners (Apple masks) — as the 1024×1024 App Store icon and every iOS size via `@capacitor/assets`, plus the 512 maskable and 192 for the web manifest. Joel looks at the 1024 and the icon on the phone's home screen before it is committed; if the pocket disappears at 60 px, the gold pocket gets a touch larger in the icon only.
4. **Reviewer demo account.** Refresh the production reviewer account from Oct 17: a coach login on a throwaway team with 3–4 saved pens and one Live Game in each sport, a generated report; write the password in the review notes; confirm sign-in from a signed-out phone.
5. **Claude Code prepares the paperwork (prompt below).**

### Phase 2 — App Store Connect (can start today)

6. **Accept agreements** in App Store Connect (the Free Apps agreement; no banking/tax forms until there's a paid plan).
7. **Register the bundle ID** `com.knuckleballonline.app` if Xcode didn't already (Certificates, Identifiers & Profiles → Identifiers); no extra capabilities in v1 (push comes with F1-C2b as a new build, not a new app).
8. **Create the app record:** name Knuckleball, primary language English (U.S.), bundle ID above, SKU `knuckleball-ios`, category Sports, price Free, availability per decision 1.
9. **Add Jordan** (Users and Access) as App Manager per decision 2; Joel stays Account Holder and the only one who presses Submit.
10. **Fill the forms** from Claude Code's worksheet: **App Privacy** (collected: name, email, user content = pitch data / notes / messages, identifiers = user ID; purpose: app functionality; no tracking; nothing linked to third parties — true because nothing third-party loads); **Age Rating** questionnaire (no mature categories; not the Kids category; under-13 players are parent-managed records, not child users — repeat in review notes); **Export compliance**: HTTPS only, `ITSAppUsesNonExemptEncryption = NO` in Info.plist; **Content rights**: none third-party; **Privacy Policy URL** `https://knuckleballonline.com/privacy.html`; **Support URL** `https://knuckleballonline.com/help.html`.
11. **First archive and upload:** Xcode → Product → Archive → Distribute App → App Store Connect → Upload. Build number = the site's CACHE_VERSION at build time, version 1.0.0. Processing 10–30 minutes; the build appears under TestFlight.
12. **TestFlight internal testing** (no Apple review for internal testers): Joel, Jordan, one Cairn coach. Re-run the device check on the TestFlight build; that build is the one submitted.

### Phase 3 — listing and submission (G5)

13. **Screenshots** from staging with the demo account in the D2 look, captured on or at the size of the iPhone 17 Pro Max (the largest-iPhone class App Store Connect asks for; smaller sizes scale down) and the 13" iPad size. Five, in order: the Live Game diamond, the bullpen chart with the voice call captioned, a report, History, the facility QR join. Captions in Big Shoulders; no "tamper-proof" or any claim the privacy page doesn't make.
14. **Listing text** (Joel approves every word): subtitle "Pitch charting for coaches" (30 chars), promotional text, description leading with offline charting on the mound and the bullpen-to-game bridge, keywords, What's New for 1.0.
15. **Review notes** — the 4.2 paragraph: what the app does that a website doesn't (works with no signal on a field, home-screen app with its own outbox, native share of report links, the voice call), demo credentials, no purchase anywhere in the app, under-13 players never sign in, account deletion is in Profile; attach a 60-second screen recording of an offline pen.
16. **Submit** with manual release. If Apple rejects on **4.2 (minimum functionality)**: the W1 fallback — bundle the app shell locally with the same service worker and add the native pieces already planned (push with F1-C2b, share sheet) — then resubmit; a week, not a redesign. A **2.1** rejection almost always means the demo account failed; test it from a signed-out phone the morning of submission.

### Phase 4 — the morning it's approved

17. Release; check the live listing on a phone; update `STATUS.md` and the board with the App Store build and site version; turn the P2-05 install banner on (the icon is real now); App Store badge on the landing page (small L1 change, own PR); tell the pilot facility.

## Not needed, so nobody chases them

Sign in with Apple (only required with third-party social login; Knuckleball is email + password); in-app purchase and banking forms (nothing sold in the app in v1); Kids Category (not used; rated 4+); a separate delete-account web page (Google's requirement, already met by `delete-account.html`).

## Paste into Claude Code (in the `knuckleball-app` repo)

> Save this plan verbatim as `plans/w1-ios-launch.md` on a branch `w1-ios-launch` before anything else; if a copy already exists on main, use that one and tell me if the two differ. Pull `origin/main` first. Read the repo's `CLAUDE.md`, `plans/w1-app-store-wrapper.md` and `plans/w1-preconditions.md`. Facts: the Knuckleball LLC Apple Developer membership is approved; Joel's phone is an iPhone 17 Pro Max; the app icon is **The spot** — the landing page's `kb-mark` SVG drawn as white cells with the gold pocket on the brand green `#061A12`, about 70% of the square, no wordmark. Goal: **everything for an App Store submission prepared so Joel can create the record, upload and submit in one sitting.** Only Joel signs, uploads or submits; you prepare files and instructions.
>
> **Report first, then build:** (1) iOS config audit — `Info.plist` has `WKAppBoundDomains` with knuckleballonline.com, `ITSAppUsesNonExemptEncryption` = NO, display name Knuckleball, bundle id `com.knuckleballonline.app`, version 1.0.0, build = the live site's CACHE_VERSION; the status-bar inset issue from the Oct 15 proof is fixed; external links go through `Browser.open()`; report links share through the system share sheet; (2) the icon — the spot rendered as described into `resources/icon.png` (1024, opaque, square corners) and `@capacitor/assets` generating every iOS size, plus a 512 maskable and 192 PNG handed to Joel for the site's manifest (site change goes through the site repo, not here); show Joel the 1024 and a home-screen mock before committing; (3) the archive script (`npm run ios:archive`) and a README section with the exact Xcode click paths for signing with the LLC team, installing on the iPhone 17 Pro Max, and archiving/uploading to App Store Connect; (4) `plans/w1-ios-device-check.md` — the device checklist with a result column for Joel; (5) `store/privacy-label.md` — every App Privacy question answered from the data the site stores (profiles, emails, pitch data, notes, chat messages, player links, device tokens later), "no tracking, no third-party SDKs" justified; (6) `store/listing.md` — subtitle, promotional text, description, keywords, What's New, age-rating answers, support and privacy URLs, all marked draft for Joel; (7) `store/review-notes.md` — the 4.2 paragraph, demo-account placeholder, offline-video note, under-13 explanation, no-purchase statement; (8) `store/screenshots/PLAN.md` — the five shots, staging pages and demo data, the iPhone 17 Pro Max and 13" iPad sizes App Store Connect currently asks for, and the capture steps; (9) `store/SUBMIT.md` — a one-page checklist in the order of Phases 2–3. Stop after the report; build (1)–(9) on approval; open a PR; do not merge.

## Decisions for Joel

1. **Availability:** U.S. only at launch (recommended) or worldwide.
2. **Jordan in App Store Connect:** App Manager (recommended) or Joel-only.
3. **Manual release** on approval (recommended) or automatic.
4. ~~The logo~~ — decided Nov 10: The spot, white cells, gold pocket, on brand green.
