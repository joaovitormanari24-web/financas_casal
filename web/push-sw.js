// Service worker dedicado a notificações push — registrado num escopo
// próprio ("/push-sw-scope/"), separado do service worker do Flutter que
// cuida do cache/PWA. Não intercepta fetch nem controla a página.

self.addEventListener('push', function(event) {
  var data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (e) {
    // ignora payload malformado
  }
  var title = data.title || 'Finanças do Casal';
  var options = {
    body: data.body || '',
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-192.png',
    data: { url: data.url || '/' },
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  var url = (event.notification.data && event.notification.data.url) || '/';
  event.waitUntil(
    clients.matchAll({ type: 'window' }).then(function(clientsArr) {
      for (var i = 0; i < clientsArr.length; i++) {
        if (clientsArr[i].url.indexOf(self.location.origin) === 0) {
          return clientsArr[i].focus();
        }
      }
      return clients.openWindow(url);
    })
  );
});
