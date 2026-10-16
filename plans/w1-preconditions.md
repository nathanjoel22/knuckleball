# W1 preconditions report (Oct 15, 2026)

Packet: `plans/w1-app-store-wrapper.md` (site repo, GitHub 4dd8cb8). The packet says to work in a new `knuckleball-app` repo; **that repo doesn't exist yet** (`gh repo view nathanjoel22/knuckleball-app`: not found), so this report sits in the site repo's `plans/` for now. Nothing has been built.

## 1. Versions and Joel's Mac

| | Current (npm registry, Oct 15 2026) | Needs |
|---|---|---|
| Capacitor (`core`, `cli`, `ios`, `android`) | **8.5.3** | Node ≥ 22 (this Mac: 26.7 ✓) |
| `@capacitor/assets` (icons / splash from one source) | 3.0.5 | — |
| `@capacitor/status-bar` · `browser` · `share` · `splash-screen` | 8.0.4 · 8.0.5 · 8.0.3 · 8.0.2 | — |
| iOS | **iOS 15+** supported (Capacitor docs) | **Xcode 26.0+** |
| Android | **API 24+ (Android 7)**; WebView Chrome 60+ | Android Studio (current) with its bundled JDK |

**This Mac:** macOS 26.6.2 on Apple Silicon (arm64), Node 26.7, npm 11.19. **No Xcode** (only Apple's Command Line Tools: `xcodebuild` refuses). **No Android Studio.** No CocoaPods. `/usr/bin/java` is Apple's placeholder, not a JDK. macOS 26 runs Xcode 26, so the Mac qualifies; it just needs the installs:
- **Xcode** from the Mac App Store (free, ~15 GB; then open it once to accept the licence and install the iOS simulator);
- **Android Studio** from developer.android.com (free; it brings its own JDK and the emulator).

These are Joel's installs (they're apps on his Mac, with licences to accept).

## 2. The service worker inside the app (the proof the packet wants first)

**Not yet runnable:** it needs Xcode (the iOS simulator) and Android Studio (the emulator). What's known, to be proven on the simulator:

- **iOS (WKWebView):** a service worker runs for a site in an app's web view **only if that site is an "App-Bound Domain"**:
  - `WKAppBoundDomains` in Info.plist listing `knuckleballonline.com`, plus `limitsNavigationsToAppBoundDomains: true` in Capacitor's iOS config;
  - side effect (Capacitor docs): it "blocks navigation outside the domains in the `WKAppBoundDomains` list" (at most 10). Supabase calls are requests, not navigations, so they should be unaffected; that's part of the proof.
  - Without this, the app can't open offline on iOS. That is the packet's escalation case.
- **Android (WebView):** service workers are supported in the Chrome-based WebView; the site's own worker should behave as in Chrome.
- **Origin:** loading `https://knuckleballonline.com` directly means the app *is* that origin. The service worker, cache and sign-in storage belong to the app's web view, separate from Safari's and from a home-screen copy (the same "sign in once" situation as P2-05).

**Important (packet decision 2):** Capacitor's own docs say of `server.url`, loading a live remote site: *"This is intended for use with live-reload servers. This is not intended for use in production."* It works, and many apps do it, but it's outside what Capacitor supports. It's also exactly the shape App Store 4.2 reviewers look for. See escalation 1.

## 3. Store rules, quoted, and the answer to each

- **Apple 4.2 Minimum Functionality:** *"Your app should include features, content, and UI that elevate it beyond a repackaged website."*
  - The spec's answer: offline charting on the mound, the outbox that syncs later, and the home-screen-style app experience. The review notes lead with offline charting.
  - Note: with the live-site design, the "app" downloads nothing until first launch online, which makes the 4.2 case weaker. See escalation 1.
- **Apple 5.1.1(v) Account Sign-In:** *"If your app supports account creation, you must also offer account deletion within the app."* The answer is A1 (Profile → Your data → Delete my account; live).
- **Google Play, account deletion:** apps must *"provide users with an in-app path to delete their app accounts and associated data; **and** provide a web link resource where users can request app account deletion."* Google asks for both, unlike Apple.
  - In-app: A1.
  - The web link: today the site's own Profile → Your data works in any browser, after sign-in. Google's form wants a URL a person can use **without the app**. Proposal: a small public page (e.g. `delete-account.html`: "sign in here to delete, or email us") — a site change, so it needs Joel's OK; or the privacy page's deletion section.
- **Google Play, webview spam:** Google removes apps that are *"just webviews of existing websites"* made mainly to drive traffic. The answer is the same as Apple 4.2 (offline charting, outbox). The same risk applies.
- **Apple 3.1.1 IAP:** nothing sold in v1, and no purchase links. Nothing to do.
- **UGC (Apple 1.2, Google):** coach notes and names are visible only within a team; nothing is public. One line in the review notes.

## 4. App Privacy label (Apple) / Data safety (Google), from the privacy page

Collected, linked to the person, **not used for tracking, not shared**, all for **app functionality**:

| Category (Apple's names) | What (privacy.html "What we collect") |
|---|---|
| Contact info: name, email address | account name and email; a 13–17 player's guardian email; up to 3 report contact emails |
| User content: other user content | charting data (pitches, sessions, live-game plays), coach notes, team names / rosters |
| User content: photos | the optional profile photo |
| Identifiers: user ID | the account id |
| Other: age bracket | adult / 13–17 (never a date of birth) |

- **Not collected:** location, health, financial info, browsing history, purchase history, diagnostics / crash data, advertising data.
- **Tracking: none.** No third-party SDKs; nothing loads from another host (P1-10). The shell adds only Capacitor's own plugins, which collect nothing.
- **Encryption in transit:** yes (HTTPS / TLS).
- **Deletion:** in-app (A1) plus the web link (item 3).
- **Children:** under-13 players exist only as parent-added profiles with parental consent. Apple's age rating questionnaire is answered for that, and the Kids category is **not** used (it would ban things like the report links). 4+ / Everyone as the spec says.

Both forms are filled from this one table, and every line maps to a sentence on the privacy page.

## 5. Outside links in the app

| Link | Today (site) | In the app |
|---|---|---|
| privacy.html / terms.html (footers, sign-up) | same site, `target="_blank"` | must open in the **system browser** (or an in-app Safari sheet) so the app never loses its place |
| View report (`report.html?r=…`, 3 places) | same site, `target="_blank"` | same; the spec also wants the **share sheet** for report links (`@capacitor/share`) |
| `mailto:` | mail app | mail app (the OS handles it) |
| Supabase (`*.supabase.co`) | requests only | allowed host (`allowNavigation`), never opened |

- **Capacitor's default:** links to hosts outside `allowNavigation` open in the external browser. **But privacy, terms and reports are the same host as the app**, so they'd navigate *inside* the app's web view. And a WKWebView ignores `target="_blank"` unless the app handles it; what Capacitor 8 does with a same-host `_blank` isn't documented clearly. This needs the simulator.
- The likely answer is a small piece of the site's JS, used only when it's running inside the app (`window.Capacitor` present): call `Browser.open()` for those links, and `Share.share()` for report links. That is a **site change** (a few lines, no build step) and needs Joel's OK when we get there.

## Escalations and decisions for Joel

1. **Live site vs bundled (packet decision 2).** Capacitor says `server.url` is "not intended for use in production", and both stores single out apps that are just a live website. Options:
   - **(a) as the packet says:** load the live site, prove offline on the simulator, and lean on offline charting in the review notes. Every web ship reaches the apps instantly. Risk: a 4.2 / webview-spam rejection, and a setup Capacitor doesn't support.
   - **(b) bundled:** copy the site's files into the app at build time (from the site repo, by a script in `knuckleball-app`). The app works offline from the first launch with no service worker at all, which is Capacitor's supported mode and a much stronger 4.2 case. Cost: the app's copy only updates with a store release, so the site and the app can differ for days. One-time sign-in data lives inside the app either way.
   - **My recommendation: build (a) first, as the packet says** (it's quick), and **prove it on the simulator**. Keep (b) ready as the packet's own fallback if the service worker fails on iOS or Apple rejects on 4.2. The packet already plans two weeks of review back-and-forth.
2. **Before anything can run:**
   - (i) create the private repo `knuckleball-app` on GitHub;
   - (ii) install Xcode and Android Studio on this Mac;
   - (iii) the Apple Developer (Knuckleball LLC, D-U-N-S) and Google Play Console enrolments, which take days, so start now if they aren't started.

   I can't do any of these: they're your accounts and installs.
3. **Bundle id:** `com.knuckleballonline.app` as the packet proposes? It can never change once the app is in a store.
4. **Google's deletion web link:** a small public "Delete your account" page on the site, or point the form at the privacy page's deletion section? The privacy page is the smaller change, but Google may want a page that explains the steps.
5. **Site changes W1 will need** (the packet says "no change to the site repo beyond P2-05"; these are small and only run inside the app):
   - outside / report links through `Browser.open()` / `Share.share()`;
   - possibly the deletion web page;
   - the demo reviewer account (production data: a throwaway coach login and team).

   Each comes to you before it's made.

## Joel's answers (Oct 15, 2026)

1. **Live site first** (packet decision 2): load `https://knuckleballonline.com`, prove offline on the simulator first; bundling the site's files stays the fallback if iOS won't run the service worker or Apple rejects on 4.2.
2. **Bundle id:** `com.knuckleballonline.app` (permanent once in a store).
3. **Google's deletion web link:** a small public page on the site (`delete-account.html`: how to delete in the app or on the web, plus the support email). It's a site change, so the page comes to Joel before it's made.

**Still blocking the build (Joel's):** create the private `knuckleball-app` repo; install Xcode and Android Studio on this Mac; the Apple Developer (Knuckleball LLC, D-U-N-S) and Google Play enrolments.

## Precondition 2 — the proof (Oct 15, 2026): PASSED on both platforms

Shell: `knuckleball-app` c5bd7d6 (Capacitor 8.5.3, `server.url` https://knuckleballonline.com/bullpen-tracker.html,
iOS `WKAppBoundDomains` + `limitsNavigationsToAppBoundDomains`, Swift Package Manager). Signed out, so the app lands on
the sign-in page; that's expected.

- **Android** (emulator, Android 17 / API 37, the app's WebView over its DevTools socket):
  - online: the site's worker controls the page, cache `kb-shell-v247`;
  - **airplane mode on** (ping fails), the app force-stopped and reopened: a fresh page load (16 s old, type "navigate") **served by the worker, 0 bytes from the network**.
- **iOS** (simulator, iPhone 18 Pro, iOS 27, Xcode 27.0):
  - online: WebKit's log shows the site's worker installed and activated inside WKWebView (App-Bound Domain);
  - **knuckleballonline.com blocked on the Mac** (`/etc/hosts`, Joel; curl 000), the app terminated and relaunched: the sign-in page opened, every request answered by the worker. Block removed afterwards (0 lines left, site 200 again).
- **Found for the build:**
  - iOS draws the page under the status bar inside the app (the page isn't in "standalone" display mode, so P2-05's inset doesn't apply). Fix in the shell config (content inset / status bar), not the site.
  - Android needs JDK 21 (Homebrew `openjdk@21`, Joel OK'd); Android Studio's JDK 25 is too new for Gradle 8.14.
- So the packet's escalation ("the service worker doesn't run inside the web view") **did not trigger**; the live-site design stands.
