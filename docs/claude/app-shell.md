# App shell: pages, chrome, History, installable app — Knuckleball

Moved word for word from CLAUDE.md on 2026-11-05 (card 015). CLAUDE.md's rules apply here too; read it first.

## Pages (from Architecture)

- **Pages (L1, Oct 21 2026; `plans/l1-landing-page.md`):** `index.html` = the marketing landing page at `/` (no service-worker registration, no Supabase, nothing from another host; an inline script forwards a signed-in device or an auth link -- `?code=` / `#access_token=` -- to `signin.html` with `location.replace`, except the page's own `#section` anchors; hero film and screenshots in `media/`, never cached by `sw.js`). `signin.html` = the Which sport? / Pitcher-Coach picker, formerly `index.html` (forwards a signed-in device to `bullpen-tracker.html`; `#signup` sends its cards to the sign-up pages; `noindex`). Sign-in itself is `login.html`. Every landing "Sign in" → `signin.html`, every Join → `signin.html#signup`; policy-page brand links → `/`.

## App chrome and History (Joel, Oct 8–9 2026; v188–v194)

- **History cards (v188):** every pen and game card shows the report's first chart (`renderHistoryPlot`): dots by pitch type in the PITCHER'S view (Amendment 16), a grey translucent ring, a cream 3×3 strike zone, no zone numbers and no heat shading, above a drawn home plate (`renderPerspectivePlate`, our own drawing -- no stock images). Games also get a per-type table (`gameHistoryTypeTable`).
- **Wordmark (v189):** "KNUCKLEBALL" in all caps in Black Ops One, no diamond or period, on every page -- `privacy.html` / `terms.html` too since D2 Stage C (Joel approved, Oct 13 2026). The font is self-hosted (`vendor/fonts/BlackOpsOne-Regular.ttf`, `@font-face` in `vendor/fonts/fonts.css`, license `vendor/fonts/OFL.txt`) and precached by `sw.js` so it shows offline. The Noto files were tried and removed (Oct 8).
- **Coach dock (v190–v193):** coaches on phones (≤500px, `coachDockShown`), never during the charting screen (`phoneSessionMode`), get a translucent bar fixed to the bottom (`renderCoachDock`, `dockGo`): **Home** (house) → New Session's "What will we be charting today?"; **Charts** (clipboard) → History; **Roster** (person) → opens the pitcher list and scrolls to the top of the page; **Profile** (gear) → the coach profile. Home / Charts / Profile roll the roster up and land with the pitcher's header box at the top of the screen (Profile: the top of the page content). It slides away scrolling down and returns scrolling up (its own jumps don't hide it); a highlight pill glides under a finger sliding along the bar and snaps to the nearest button on release; taps glide it too. Pure UI, no network. iPad and laptop have no dock; since Oct 26 pitchers get one too (Home · Charts · Trends · Profile), see Trends below.
- **Trends (Joel, Oct 26 2026, v310):** a tab after History: the selected pitcher's saved sessions added up (All / Bullpen / Live Game) -- strike % and peak velocity per pitch type, one point per session, and one pitcher's-view 5x5 plot per pitch type of every pitch. Built on every render from History's data (`renderTrendsView`); no report, no network. Home (same day) is four squares -- Charting, History, Trends, Profile (Armcare / Mental Game kept as concepts, not shown) -- and the phone bottom bar is Home · Charts · History · Trends · Roster · Profile for coaches, Home · Charts · History · Trends · Profile for pitchers (`dockKeys()`); Charts opens the Bullpen / Live Game question (or Resume), History opens History. **Since Oct 29 (Joel), History and Trends share one button, Analysis** (History's icon): it opens History and stays lit on History and Trends, so the bar is Home · Charts · Analysis · Roster · Profile (coaches) / Home · Charts · Analysis · Profile (pitchers); Trends is in the page's tabs and on Home.
- **Navigation (Joel, Nov 5 2026, v331; supersedes the dock and tab details above where they differ):** phones and
  iPads (touch screens, or any window ≤500px; `dockDevice()`) always show the bottom bar, never sliding away, hidden
  only on the charting screen; they have **no tab bar** under the pitcher's name (charting included). Bar: coaches
  Charts · Analysis · Chat (in a facility) · Roster; players, parents and teens Charts · Analysis · Chat ("Soon" outside
  a facility: a coming-soon page); view-only friends and family Analysis · Profile (`dockKeys()`). History / Trends sit
  above All / Bullpen / Live Game there (`analysisTray`). Computers keep the tab bar. **Leaderboard is hidden for now**
  (no tab; `renderLeaderboardView` kept). The KNUCKLEBALL wordmark goes Home (`goHome`); Profile is in the account menu
  (`acctGoProfile`) and a Home tile; a coach taps the pitcher's name or photo for Player Profile. Every bar button lands at the very top of the page (the
  banner in view; v335); A coach's open roster list (phones / iPads,
  `rosterCanCollapse`) stands alone: nothing below it, not even the footer or Sign out, until a pitcher is picked or
  another button is tapped (v336).
- **One "‹ Back" (F1-D, Joel, Oct 29 2026; `plans/f1d-preconditions.md`; v324):** top left of the page (in the account
  row on phones; its own row when the account sits in the pitcher header), every size, browser and installed. It goes
  to the section's first screen, never browser history: start questions → "Bullpen or Live Game?"; (an opened History
  session → the list: gone with the History feed, Nov 5); a chat thread → the chat list; the accuracy painter or Add a player → the
  top of Profile; a coach's Player Profile → the roster. **Never on the charting screen**, not even before the first
  pitch, and never on a section's first screen (`headerBackTarget` / `headerBack`). It replaced the chooser's own
  "‹ Back" buttons and the chat thread's "‹ Chats". The phone bar is unchanged (decision A).
- **History is a feed (Joel, Nov 5 2026, v328; `plans/hf1-preconditions.md`):** no tap to open a session and no "View
  report" tab. Every saved session's frozen report is drawn under its card as History scrolls (fetched as it nears the
  screen, drawn inert in a shadow root, kept on the device in IndexedDB `kb-reports`, max 100, cleared at sign-out,
  so it opens offline after that); 20 sessions at a time, "Show older sessions" for more. Sessions started from Nov 5
  get their report made the first time they're on screen (same call and gate as before); older ones without a report
  keep **Create report** (and the card's plot and table). **Copy Report URL** copies the link and opens nothing; the
  link still opens `report.html` as before; Email report is unchanged; the installed app keeps Share. **No new coaches'
  notes** (Chat is the direction): the comment box is gone; existing notes show read-only in History and on the report
  page; `session_notes` is untouched. A row's "New" dot clears once its card is on screen. **Each session's bar (date, pitches, strikes, accuracy...) opens and
  closes its report on tap / click / Enter** (open by default, an arrow shows which; closed ones stay closed for that page
  load; Nov 5, v330). Phones get **↑ Back to
  top** at the end of History and Trends.
- **Roster on phones (v191, v194):** the list stays rolled up until Roster is tapped (dock or the Roster bar; team load and leaving a session start it rolled up); picking a pitcher or another dock button rolls it up. Open, it shows EVERY pitcher (no 220px inner scroll box at ≤860px) -- the page scrolls.

## Installable app (P2-05, Joel, Oct 15 2026; `plans/p2-05-pwa-install.md`, decisions in `plans/p2-05-preconditions.md`)

- **Manifest:** `manifest.webmanifest` (start and id `/bullpen-tracker.html`, scope `/`, standalone, theme `#061A12`, background `#F3F5F2`), linked from all 15 pages along with the iOS home-screen tags, the 180 Apple icon, a favicon and `css/standalone.css`. Every page sets `viewport-fit=cover`.
- **Icons and splash** come from ONE source, `assets/app-icon.svg`: since Oct 22, 2026 the main logo, "The spot" (white cells, the gold pocket, on brand green; it replaced the Oct 15 "KB" placeholder). `node scripts/splash.js` redraws `icons/` (192, 512, 512 maskable, 180, 32) and `splash/` (40 iOS splash images, 20 devices × 2 orientations, plus `splash/links.html`, the tags carried by index, login and the tracker). It uses this Mac's Chrome and `sips`: no package, no outside service, and the output is committed. After changing the icon, re-run it and bump CACHE_VERSION. All of it is precached.
- **`css/standalone.css`:** the safe-area insets go on `:root` (pages set their own body padding). Installed, a strip in the sport's `--brand-bg` sits behind the black-translucent status bar.
- **Install banner** (Home only, once per device, `kb:install` = dismissed / installed): Android uses `beforeinstallprompt` (one Install button); iOS explains Share → Add to Home Screen, and only when the outbox is empty, because a home-screen app's storage is separate from Safari's. **It is OFF** (Joel, Oct 23, 2026: "I don't like or want it there"; `window.KB_INSTALL_BANNER = false` in the tracker's head), and Chrome's own install prompt is always held back too. It was on Oct 22-23, after the real logo ("The spot") replaced the placeholder icon.
- **Updates:** an installed app is rarely reloaded, so a worker that takes over from an older one shows "A new version of Knuckleball is ready · Reload" (never on the charting screen). The app also checks for a new version whenever it comes back to the front.
- No pull-to-refresh on the charting screen (`html.charting`). Report, privacy and terms show "‹ Back" only when installed (report: a plain link, because its CSP allows no inline script).
