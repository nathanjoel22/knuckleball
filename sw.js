// Offline app shell for Knuckleball (task P0-06).
//
// Job of this file: let the tracker/login pages LOAD at all with no
// network, so a coach who backgrounds the app in a dead-wifi bullpen can
// reopen it and see the P0-03 draft-restore prompt instead of the
// browser's own offline error page. It must never cache Supabase
// requests (auth, REST, storage) -- those always go to the network.
//
// Bump CACHE_VERSION whenever this file's own logic or PRECACHE_URLS
// list changes, so activate() cleans up the old cache generation. Routine
// content edits to the precached HTML/JS files do NOT need a version
// bump -- the fetch handler below refreshes each cached file in the
// background on every successful online load (stale-while-revalidate),
// so a plain reload picks up new content without any version dance.
const CACHE_VERSION = 'kb-shell-v1';

const PRECACHE_URLS = [
  '/',
  '/index.html',
  '/login.html',
  '/bullpen-tracker.html',
  '/coach-signup.html',
  '/accept-invite.html',
  '/supabase-config.js',
  '/report-config.js',
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2'
];

self.addEventListener('install', (event) => {
  // Cache each URL independently rather than cache.addAll(), which fails
  // the whole install if even one asset 404s or blips -- that would
  // silently leave the entire offline shell inactive.
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_VERSION);
    await Promise.all(PRECACHE_URLS.map(async (url) => {
      try {
        const res = await fetch(url, { cache: 'reload' });
        if (res && (res.ok || res.type === 'opaque')) await cache.put(url, res);
      } catch (e) {
        // One flaky asset shouldn't block the rest of the shell from caching.
      }
    }));
    self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((names) => Promise.all(
        names.filter((n) => n !== CACHE_VERSION).map((n) => caches.delete(n))
      ))
      .then(() => self.clients.claim())
  );
});

function isShellRequest(url) {
  if (url.origin === self.location.origin) return true;
  return url.href.indexOf('https://cdn.jsdelivr.net/npm/@supabase/supabase-js') === 0;
}

self.addEventListener('fetch', (event) => {
  const req = event.request;

  // Only ever intercept GET -- never touch POST/PUT/etc (nothing in this
  // app should hit those same-origin anyway, but this is a hard rule).
  if (req.method !== 'GET') return;

  const url = new URL(req.url);

  // Never cache or intercept Supabase (auth, REST, storage, edge
  // functions) -- always hit the network so auth state and data are
  // never served stale or from cache.
  if (url.hostname.endsWith('.supabase.co')) return;

  // Leave everything else (Google Fonts, anything unexpected) alone --
  // this worker only knows about its own enumerated shell assets.
  if (!isShellRequest(url)) return;

  event.respondWith((async () => {
    const cache = await caches.open(CACHE_VERSION);
    const cached = await cache.match(req);

    const networkFetch = fetch(req).then((res) => {
      if (res && (res.ok || res.type === 'opaque')) {
        cache.put(req, res.clone());
      }
      return res;
    }).catch(() => null);

    if (cached) {
      // Cache-first for instant offline-safe response, but always
      // refresh the cache in the background when online so the shell
      // can't get permanently stuck on stale content.
      event.waitUntil(networkFetch);
      return cached;
    }

    const fresh = await networkFetch;
    return fresh || new Response('Offline and not yet cached.', {
      status: 503,
      statusText: 'Offline',
      headers: { 'Content-Type': 'text/plain' }
    });
  })());
});
