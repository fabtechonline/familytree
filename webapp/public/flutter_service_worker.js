// Self-destroying service worker.
// The old Flutter web build registered a service worker at this path. This
// replacement unregisters it, clears all caches, and reloads open tabs so
// returning visitors get the new Riza web app instead of the cached old one.
self.addEventListener('install', () => self.skipWaiting())

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      try {
        const keys = await caches.keys()
        await Promise.all(keys.map((k) => caches.delete(k)))
        await self.registration.unregister()
        const clients = await self.clients.matchAll({ type: 'window' })
        for (const client of clients) client.navigate(client.url)
      } catch (e) {
        // best effort
      }
    })(),
  )
})
