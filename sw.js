const CACHE = "legado-v74-admin-barber-edit";
const CORE_ASSETS = [
  "./",
  "./index.html",
  "./admin.html",
  "./privacidade.html",
  "./styles.css",
  "./admin.css",
  "./core.js",
  "./app.js",
  "./admin.js",
  "./supabase-bridge.js",
  "./manifest.webmanifest",
  "./assets/app-icon-192.png",
  "./assets/app-icon-512.png",
  "./assets/corte.webp",
  "./assets/barba.webp",
  "./assets/produtos.webp",
  "./assets/agendamento.webp",
  "./assets/gilliel-apresentacao.webp"
];

const OPTIONAL_ASSETS = [
  "./assets/logo.png",
  "./assets/logo-192.png",
  "./assets/favicon.png",
  "./assets/admin-app-background.png",
  "./assets/app-icon-1024.png",
  "./assets/legado-atendimento-classico.jpg",
  "./assets/legado-barba-degrade.jpg",
  "./assets/legado-barba-social.jpg",
  "./assets/legado-degrade-costas.jpg",
  "./assets/legado-degrade-duplo.jpg",
  "./assets/legado-gilliel-atendimento-infantil.jpg",
  "./assets/legado-gilliel-fundador.jpg",
  "./assets/legado-infantil-degrade-processo.jpg",
  "./assets/legado-infantil-desenho.jpg",
  "./assets/legado-infantil-social.jpg",
  "./assets/legado-tesoura-detalhe.jpg"
];

function isSupabaseRequest(url) {
  return /supabase\.co\/(rest|auth|storage)\/v1/i.test(url.href);
}

function isAppShellRequest(request) {
  return request.mode === "navigate" || /\.(html|css|js|json|webmanifest)$/i.test(new URL(request.url).pathname);
}

async function cacheResponse(request, response) {
  if (!response || !response.ok || response.type === "opaque") return response;
  const cache = await caches.open(CACHE);
  cache.put(request, response.clone()).catch(() => {});
  return response;
}

self.addEventListener("install", event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    await cache.addAll(CORE_ASSETS);
    await Promise.allSettled(OPTIONAL_ASSETS.map(asset => cache.add(asset)));
    await self.skipWaiting();
  })());
});

self.addEventListener("activate", event => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter(key => key !== CACHE).map(key => caches.delete(key)));
    await self.clients.claim();
  })());
});

self.addEventListener("fetch", event => {
  const { request } = event;
  if (request.method !== "GET") return;
  const url = new URL(request.url);
  if (isSupabaseRequest(url) || url.origin !== self.location.origin) return;

  if (isAppShellRequest(request)) {
    event.respondWith(
      fetch(request)
        .then(response => cacheResponse(request, response))
        .catch(() => caches.match(request).then(cached => cached || caches.match("./index.html")))
    );
    return;
  }

  event.respondWith(
    caches.match(request).then(cached => cached || fetch(request).then(response => cacheResponse(request, response)))
  );
});
