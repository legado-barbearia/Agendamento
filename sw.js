const CACHE = "legado-v47-reserva-supabase";
const ASSETS = [
  "./", "./index.html", "./admin.html", "./privacidade.html", "./styles.css", "./admin.css", "./core.js", "./app.js", "./admin.js", "./supabase-bridge.js", "./manifest.webmanifest",
  "./assets/logo.png", "./assets/logo-192.png", "./assets/favicon.png", "./assets/gilliel-apresentacao.webp", "./assets/corte.webp", "./assets/barba.webp", "./assets/produtos.webp", "./assets/agendamento.webp",
  "./assets/admin-app-background.png",
  "./assets/app-icon-192.png", "./assets/app-icon-512.png", "./assets/app-icon-1024.png",
  "./assets/legado-atendimento-classico.jpg", "./assets/legado-barba-degrade.jpg", "./assets/legado-barba-social.jpg", "./assets/legado-degrade-costas.jpg", "./assets/legado-degrade-duplo.jpg",
  "./assets/legado-gilliel-atendimento-infantil.jpg", "./assets/legado-gilliel-fundador.jpg",
  "./assets/legado-infantil-degrade-processo.jpg", "./assets/legado-infantil-desenho.jpg", "./assets/legado-infantil-social.jpg", "./assets/legado-tesoura-detalhe.jpg"
];
self.addEventListener("install", event => event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(ASSETS)).then(() => self.skipWaiting())));
self.addEventListener("activate", event => event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key !== CACHE).map(key => caches.delete(key)))).then(() => self.clients.claim())));
self.addEventListener("fetch", event => {
  if (event.request.method !== "GET") return;
  event.respondWith(caches.match(event.request).then(cached => cached || fetch(event.request).then(response => {
    const copy = response.clone(); caches.open(CACHE).then(cache => cache.put(event.request, copy)); return response;
  }).catch(() => caches.match("./index.html"))));
});
