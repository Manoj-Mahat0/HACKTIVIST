// Custom Service Worker for Indoor Navigation PWA
// This extends Flutter's default service worker with advanced caching strategies

const CACHE_NAME = 'indoor-navigation-v1';
const RUNTIME_CACHE = 'indoor-navigation-runtime-v1';
const API_CACHE = 'indoor-navigation-api-v1';

// Assets to cache on install
const PRECACHE_ASSETS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/icons/Icon-maskable-192.png',
  '/icons/Icon-maskable-512.png',
  '/favicon.png'
];

// Install event - precache essential assets
self.addEventListener('install', (event) => {
  console.log('[ServiceWorker] Install');
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('[ServiceWorker] Precaching app shell');
        return cache.addAll(PRECACHE_ASSETS);
      })
      .then(() => self.skipWaiting())
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  console.log('[ServiceWorker] Activate');
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME && 
              cacheName !== RUNTIME_CACHE && 
              cacheName !== API_CACHE) {
            console.log('[ServiceWorker] Removing old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

// Fetch event - implement caching strategies
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Skip cross-origin requests
  if (url.origin !== location.origin) {
    // API requests - Network First strategy
    if (url.pathname.includes('/api/')) {
      event.respondWith(networkFirstStrategy(request, API_CACHE));
      return;
    }
    return;
  }

  // HTML requests - Network First
  if (request.headers.get('accept').includes('text/html')) {
    event.respondWith(networkFirstStrategy(request, RUNTIME_CACHE));
    return;
  }

  // Static assets - Cache First
  if (request.url.match(/\.(js|css|png|jpg|jpeg|svg|gif|woff|woff2|ttf|eot)$/)) {
    event.respondWith(cacheFirstStrategy(request, RUNTIME_CACHE));
    return;
  }

  // Default - Network First
  event.respondWith(networkFirstStrategy(request, RUNTIME_CACHE));
});

// Cache First Strategy - for static assets
async function cacheFirstStrategy(request, cacheName) {
  const cache = await caches.open(cacheName);
  const cached = await cache.match(request);
  
  if (cached) {
    return cached;
  }

  try {
    const response = await fetch(request);
    if (response.status === 200) {
      cache.put(request, response.clone());
    }
    return response;
  } catch (error) {
    console.log('[ServiceWorker] Fetch failed:', error);
    // Return offline page if available
    return cache.match('/offline.html') || new Response('Offline');
  }
}

// Network First Strategy - for dynamic content
async function networkFirstStrategy(request, cacheName) {
  const cache = await caches.open(cacheName);
  
  try {
    const response = await fetch(request);
    if (response.status === 200) {
      cache.put(request, response.clone());
    }
    return response;
  } catch (error) {
    console.log('[ServiceWorker] Network request failed, trying cache:', error);
    const cached = await cache.match(request);
    return cached || new Response('Offline', { status: 503 });
  }
}

// Background Sync for offline actions
self.addEventListener('sync', (event) => {
  console.log('[ServiceWorker] Background sync:', event.tag);
  
  if (event.tag === 'sync-navigation-data') {
    event.waitUntil(syncNavigationData());
  }
});

async function syncNavigationData() {
  // Implement your sync logic here
  console.log('[ServiceWorker] Syncing navigation data');
  // This would sync any offline navigation requests when back online
}

// Push Notifications
self.addEventListener('push', (event) => {
  console.log('[ServiceWorker] Push received');
  
  const options = {
    body: event.data ? event.data.text() : 'New navigation update available',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    vibrate: [200, 100, 200],
    data: {
      dateOfArrival: Date.now(),
      primaryKey: 1
    },
    actions: [
      {
        action: 'explore',
        title: 'View',
        icon: '/icons/Icon-192.png'
      },
      {
        action: 'close',
        title: 'Close',
        icon: '/icons/Icon-192.png'
      }
    ]
  };

  event.waitUntil(
    self.registration.showNotification('Indoor Navigation', options)
  );
});

// Notification click handler
self.addEventListener('notificationclick', (event) => {
  console.log('[ServiceWorker] Notification click:', event.action);
  event.notification.close();

  if (event.action === 'explore') {
    event.waitUntil(
      clients.openWindow('/')
    );
  }
});

// Message handler for communication with app
self.addEventListener('message', (event) => {
  console.log('[ServiceWorker] Message received:', event.data);
  
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
  
  if (event.data && event.data.type === 'CACHE_URLS') {
    event.waitUntil(
      caches.open(RUNTIME_CACHE).then((cache) => {
        return cache.addAll(event.data.urls);
      })
    );
  }
});
