// EMERGENCY ROLLBACK for P0-06's offline app shell (sw.js).
//
// Reverting the registration code in bullpen-tracker.html/login.html is
// NOT enough on its own -- a browser that already installed the real
// sw.js keeps running it indefinitely (service workers persist per
// origin until something replaces or unregisters them), so already-hit
// devices would stay on a stale, un-updatable shell even after a plain
// git revert.
//
// To roll back for real:
//   1. Copy this file's contents over sw.js (same path, same filename --
//      the browser only re-checks/installs when the byte content served
//      at /sw.js changes).
//   2. git revert the registration-code commit(s) in bullpen-tracker.html
//      and login.html too, so no page tries to re-register a worker.
//   3. Commit and push both changes together, then deploy.
// Every device that still has the old worker installed will pick this
// version up on its normal update check, at which point it deletes every
// cache this app created, unregisters itself, and reloads any open tabs
// so they go back to plain network requests with no worker involved.
self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((names) => Promise.all(names.map((n) => caches.delete(n))))
      .then(() => self.registration.unregister())
      .then(() => self.clients.matchAll({ type: 'window' }))
      .then((clients) => clients.forEach((client) => client.navigate(client.url)))
  );
});
