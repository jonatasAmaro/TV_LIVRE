/**
 * TV Livre Catalog Worker
 *
 * Routes:
 *   GET /catalog.json  — cached proxy of the GitHub catalog
 *   GET /stream?url=X  — follows redirects and returns the final URL (for Roku HTTPS→HTTP)
 *   GET /health        — alive check
 */

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') {
      return corsResponse(new Response(null, { status: 204 }));
    }

    try {
      if (url.pathname === '/catalog.json') {
        return corsResponse(await handleCatalog(env));
      }

      if (url.pathname === '/stream') {
        const target = url.searchParams.get('url');
        if (!target) {
          return corsResponse(json({ error: 'missing ?url= param' }, 400));
        }
        return corsResponse(await handleStream(target));
      }

      if (url.pathname === '/health') {
        return corsResponse(json({ status: 'ok', ts: Date.now() }));
      }

      return corsResponse(json({ error: 'not found' }, 404));
    } catch (err) {
      return corsResponse(json({ error: err.message }, 500));
    }
  },
};

// ---------- Catalog ----------

async function handleCatalog(env) {
  const catalogUrl = env.CATALOG_URL;
  const cacheTtl = parseInt(env.CACHE_TTL) || 300;

  const cache = caches.default;
  const cacheKey = new Request(catalogUrl, { method: 'GET' });
  let cached = await cache.match(cacheKey);
  if (cached) {
    const resp = new Response(cached.body, cached);
    resp.headers.set('X-Cache', 'HIT');
    return resp;
  }

  const resp = await fetch(catalogUrl, {
    headers: { 'User-Agent': 'TV-Livre-Worker/1.0' },
    cf: { cacheTtl: 0 },
  });

  if (!resp.ok) {
    return json({ error: 'upstream error', status: resp.status }, 502);
  }

  const body = await resp.text();
  const result = new Response(body, {
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': `public, max-age=${cacheTtl}`,
      'X-Cache': 'MISS',
    },
  });

  const toCache = new Response(body, {
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': `public, max-age=${cacheTtl}`,
      'X-Cache': 'HIT',
    },
  });
  await cache.put(cacheKey, toCache);

  return result;
}

// ---------- Stream Resolver ----------

async function handleStream(targetUrl) {
  const resp = await fetch(targetUrl, {
    method: 'HEAD',
    headers: { 'User-Agent': 'Mozilla/5.0' },
    redirect: 'follow',
  });

  const finalUrl = resp.url;
  const contentType = resp.headers.get('content-type') || '';
  const status = resp.status;

  return json({
    original: targetUrl,
    resolved: finalUrl,
    contentType,
    status,
    ok: status >= 200 && status < 400,
  });
}

// ---------- Helpers ----------

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
}

function corsResponse(resp) {
  const headers = new Headers(resp.headers);
  headers.set('Access-Control-Allow-Origin', '*');
  headers.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  headers.set('Access-Control-Allow-Headers', 'Content-Type');
  return new Response(resp.body, {
    status: resp.status,
    headers,
  });
}
