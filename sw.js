/* IGProspect — Service Worker para notificações push.
   Recebe a push (mesmo com o sistema fechado) e mostra na tela do celular. */
self.addEventListener('install', e => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));

self.addEventListener('push', event => {
  let d = {};
  try { d = event.data ? event.data.json() : {}; } catch (e) { d = { body: event.data && event.data.text() }; }
  const title = d.title || 'IGProspect';
  const opts = {
    body: d.body || '',
    icon: d.icon || 'icon-192.png',
    badge: 'badge.png',
    tag: d.tag || undefined,          // agrupa notificações do mesmo tipo
    renotify: !!d.tag,
    data: { url: d.url || '/' },
    vibrate: [80, 40, 80]
  };
  event.waitUntil(self.registration.showNotification(title, opts));
});

self.addEventListener('notificationclick', event => {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.url) || '/';
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(list => {
      for (const c of list) { if ('focus' in c) { c.navigate && c.navigate(url); return c.focus(); } }
      if (self.clients.openWindow) return self.clients.openWindow(url);
    })
  );
});
