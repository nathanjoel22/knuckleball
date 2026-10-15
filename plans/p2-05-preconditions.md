# P2-05 preconditions report (Oct 15, 2026)

Packet: `plans/p2-05-pwa-install.md` (GitHub, 4dd8cb8). Branch `p2-05-pwa-install`. Nothing has been built.

## 1. Manifest, meta tags, icons, service worker, updates

- **No manifest, no icons, no iOS tags, no favicon** on any of the 15 pages. Every page has a plain viewport tag (`width=device-width, initial-scale=1.0`, e.g. `bullpen-tracker.html:5`). Only `report.html:13` adds `viewport-fit=cover`.
- **`sw.js`** (147 lines):
  - precaches 39 files (`sw.js:20–56`): 14 pages, both config files, `vendor/supabase.js`, the fonts, `css/tokens.css`, `css/components.css`, `buttons.css` and the five Home tile icons. `report.html` is **not** precached (a report needs the network anyway).
  - Strategy (`sw.js:90–147`): cache-first for those files, with a background refresh when online. Supabase is never intercepted.
  - Install: each file is cached separately, then `skipWaiting()` (`:72`). Activate deletes old caches and calls `clients.claim()` (`:76–82`).
- **How an update reaches an installed app today:** a new `CACHE_VERSION` installs and takes control at once, but the page that's already open keeps running its old code until it reloads. In standalone mode nothing reloads it: there's no browser refresh, and iOS keeps a home-screen app alive in the background. So someone can run old code for days.
- **There is no "update available" message** anywhere (no `updatefound` / `controllerchange` handling).
- **Registration:** only `login.html:36` and `bullpen-tracker.html:32` register the service worker. `index.html`, the landing page, does not.

## 2. Pages a standalone user can reach; Back; outside links

| Page | Reached from | Way back today |
|---|---|---|
| bullpen-tracker.html (the app) | everywhere | its own navigation |
| index.html (Which sport?) | sign-out, policy footers | it's the start |
| login.html, the 4 sign-up pages, reset-password, verify-email | index / email links | each has a Back or "already have an account" link |
| join.html, join-coach.html, accept-invite.html | invite links | links back to sign-in |
| guardian-consent.html | a guardian's email only | none, and none is needed (a guardian opens it from email, in Safari) |
| privacy.html, terms.html | footers (`target="_blank"`) and sign-up pages | **only a footer link to index.html**, no Back to where you were |
| report.html | "View report" (3 places, `target="_blank"`: tracker 5552, 9824, 9951) | **none** |

- Outside links: `mailto:` on privacy / terms / guardian-consent / the tracker. No other off-site links.
- `target="_blank"` in standalone mode: iOS opens same-site links in an in-app browser sheet with **Done**; Android opens a Chrome Custom Tab with a close button. Either way the person can get back. But it is not "the system browser" the spec asks for, and on iOS there's no reliable way to force Safari from a home-screen app.
- **Recommendation:** keep `target="_blank"` for reports and policy pages (the sheet has Done, which is a way back), and add a "Back to Knuckleball" link on report, privacy and terms for the case where one is opened in the app's own window. Emailed report links always open in Safari or the mail app, never in the installed app (iOS doesn't route links into home-screen apps).

## 3. Safe areas today

- The coach dock (`bullpen-tracker.html:982`, `1005–1006`), the modals (`:580–581`), the phone sheet (`:144`) and the tabs (`:458`) already use `env(safe-area-inset-*)`. **But all of it is inert:** the tracker's viewport has no `viewport-fit=cover` (its own comment says so, `:455`).
- With `black-translucent` the page draws under the status bar, so the top of every screen needs a top inset: the sidebar brand box, the phone session header, the A1 scheduled screen and the overlays.
- Nothing sets `overscroll-behavior`. A downward swipe can pull-to-refresh where the browser allows it.

## 4. iOS splash images

Apple matches `apple-touch-startup-image` by an exact media query (device width × height in CSS px, pixel ratio, orientation). There is no single size. Current sizes, portrait (landscape = swapped), in pixels:

| Devices | CSS size @ ratio | Splash px |
|---|---|---|
| iPhone 16 / 17 Pro Max | 440×956 @3 | 1320×2868 |
| iPhone Air | 420×912 @3 | 1260×2736 |
| iPhone 16 / 17 Pro, 17 | 402×874 @3 | 1206×2622 |
| iPhone 14 Pro Max, 15 Plus / Pro Max, 16 Plus | 430×932 @3 | 1290×2796 |
| iPhone 14 Pro, 15, 15 Pro, 16 | 393×852 @3 | 1179×2556 |
| iPhone 12 / 13 Pro Max, 14 Plus | 428×926 @3 | 1284×2778 |
| iPhone 12, 13, 14, 12 / 13 Pro | 390×844 @3 | 1170×2532 |
| iPhone X, XS, 11 Pro, 12 / 13 mini | 375×812 @3 | 1125×2436 |
| iPhone XS Max, 11 Pro Max | 414×896 @3 | 1242×2688 |
| iPhone XR, 11 | 414×896 @2 | 828×1792 |
| iPhone 8 Plus | 414×736 @3 | 1242×2208 |
| iPhone SE 2 / 3, 8 | 375×667 @2 | 750×1334 |
| iPad Pro 13" (M4) | 1032×1376 @2 | 2064×2752 |
| iPad Pro 12.9" | 1024×1366 @2 | 2048×2732 |
| iPad Pro 11" (M4) | 834×1210 @2 | 1668×2420 |
| iPad Pro 11", iPad Air 11" | 834×1194 @2 | 1668×2388 |
| iPad Air 10.9", iPad 10th | 820×1180 @2 | 1640×2360 |
| iPad 10.2" (7th–9th) | 810×1080 @2 | 1620×2160 |
| iPad mini 6 / 7 | 744×1133 @2 | 1488×2266 |
| iPad mini 5, 9.7" | 768×1024 @2 | 1536×2048 |

That's 20 sizes × 2 orientations = **40 PNGs**, and 40 `<link>` tags. They go only on the pages someone would add to the home screen (index, login, the tracker), not on all 15. The 2025–26 sizes (Air, 17 family) are from Apple's published specs; I'll re-check them on the day of the build.

**Script plan (no third-party service):** `scripts/splash.js` (Node, run by hand). It writes one small HTML page per size, with the source SVG (the icon art on `--brand-bg`, with the wordmark) centred. It renders each page with the **Chrome already installed on this Mac** in headless mode at exactly that pixel size. The PNGs go in `/splash/`, are committed, and are precached. The same script writes the 192 / 512 / 512-maskable / 180 icons and the `<link>` block to paste. That's no npm package and no build step.

## 5. Install flow: iOS vs Android

| | iOS Safari (iPhone, iPad) | Android Chrome |
|---|---|---|
| Install prompt | **None.** No `beforeinstallprompt`; nothing the page can trigger. | `beforeinstallprompt` fires when the site is installable (manifest with 192/512 icons, `display: standalone`, HTTPS, a service worker with a fetch handler). The page can keep it and call `prompt()` from our Install button, once. |
| What our banner can do | Explain: tap Share, then "Add to Home Screen", with the Share glyph drawn by us. On iOS 16.4+ the same works from Chrome / Edge's share menu. | One **Install** button opens the system dialog; `appinstalled` tells us it worked. |
| Knowing it's installed | `navigator.standalone` / `display-mode: standalone` when **launched from** the icon; Safari can't tell that an icon exists. So "installed" = we're running standalone, or the banner was dismissed. | `appinstalled`, plus the `display-mode` media query. |
| Firefox / others | — | No prompt; the banner falls back to "use your browser's menu". |

## Escalations and questions for Joel

1. **There is no Knuckleball "mark" to make the icon from.** The packet says icons are "the Knuckleball mark on the brand green", but the design files have only the KNUCKLEBALL wordmark (Black Ops One text). Spelled out, it won't read at icon size (an iPhone icon is about 60 pt). I'll draw 3 options as a PNG sheet for you to pick from before anything else is built:
   - a **K** in Black Ops One, gold on green, with the slanted-tag stripe;
   - a stitched **ball** with knuckle seams;
   - **KB** on the slanted gold tag.

   This becomes the App Store icon too (W1).
2. **The staging site can't be installed or tested offline on a phone.** It's served at `http://192.168.1.15:8000`, plain HTTP on the home Wi-Fi. Phones only allow service workers and installs on HTTPS (or `localhost` on the same machine). So acceptance 2–4 and 6 can't run on staging. Options:
   - (a) I check everything I can on this Mac's Chrome at `http://localhost:8000` (installable, offline launch, update message, standalone layout in the device emulator), and you do the phone and iPad checks on production right after it ships. A revert is one push. **Recommended.**
   - (b) A temporary second GitHub Pages site for staging. That's a new environment and a hosting change, so it's your call.
3. **"Lighthouse PWA audit" no longer exists.** Google removed the PWA category from Lighthouse in version 12 (2024). Substitute: Chrome DevTools' Application → Manifest "Installability" check (no errors), plus an offline cold load of `start_url` on localhost, with screenshots as evidence.
4. **On iPhone, the home-screen app has its own storage, separate from Safari's.** After installing, the person signs in once (online), and **anything still waiting in Safari's outbox stays in Safari.** That doesn't break the outbox, but it can strand an unsynced pen. Proposal:
   - the iOS install banner shows only when this device's outbox is empty;
   - it says "Sign in once in the new icon while you have signal";
   - Android shares storage with Chrome, so it's not affected there.
   - Bonus: home-screen apps are exempt from Safari's 7-day storage clean-up, so offline drafts are safer once installed.
5. **The update message.** Proposal: when a new version has taken over, a quiet bar says "A new version is ready" with a **Reload** button. It never appears on the charting screen (it waits until the session is saved); drafts autosave, so a reload is safe.
6. **`start_url`:** `/bullpen-tracker.html`, which sends a signed-out person to sign-in. Scope `/`, `id` `/bullpen-tracker.html`. The landing page stays out of the installed app's start.
7. **The P1-01 checks 1–3 aren't written down in the repo** (P1-01 predates `plans/`). I'll use: (1) a cold launch with no signal opens the app; (2) a pen charted offline saves to the outbox; (3) back online, it syncs. Say if they were different.

## Joel's answers (Oct 15, 2026)

1. **Icon:** the logo comes later. Build now with a placeholder icon (a K on the brand green) from one source SVG; swapping the logo = replace the SVG, re-run `scripts/splash.js`, bump CACHE_VERSION. Because iOS keeps the icon it was installed with, the install banner ships **off** until the real logo is in (a flag), so nobody is invited to install the placeholder.
2. **Testing:** agreed -- everything checkable on this Mac's Chrome at localhost; Joel's iPhone / iPad checks on production right after it ships.
3. **Lighthouse:** Chrome DevTools' installability check replaces the retired Lighthouse PWA audit.
4. **iOS storage:** agreed -- the iOS banner shows only with an empty outbox and says to sign in once while there's signal.
