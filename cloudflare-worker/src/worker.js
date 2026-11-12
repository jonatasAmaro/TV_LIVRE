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

      if (url.pathname === '/kairou') {
        const tmdbId = url.searchParams.get('tmdbId');
        const season = url.searchParams.get('season') || '1';
        const episode = url.searchParams.get('episode') || '1';
        const title = url.searchParams.get('title') || '';
        if (!tmdbId) {
          return corsResponse(json({ error: 'missing ?tmdbId= param' }, 400));
        }
        return corsResponse(await handleKairou(tmdbId, season, episode, title));
      }

      if (url.pathname === '/tokyvideo') {
        const pageUrl = url.searchParams.get('url');
        if (!pageUrl) {
          return corsResponse(json({ error: 'missing ?url= param' }, 400));
        }
        const mode = url.searchParams.get('mode') || 'json';
        return corsResponse(await handleTokyvideo(pageUrl, mode, request));
      }

      if (url.pathname === '/saimo') {
        const seriesId = url.searchParams.get('id');
        const season = url.searchParams.get('season') || '1';
        const episode = url.searchParams.get('episode') || '1';
        if (!seriesId) {
          return corsResponse(json({ error: 'missing ?id= param' }, 400));
        }
        return corsResponse(await handleSaimo(seriesId, season, episode));
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

// ---------- Kairou Extract ----------

async function handleKairou(tmdbId, season, episode, title) {
  const extractUrl =
    `https://kairou.space/api/extract?type=series&season=${season}&episode=${episode}&tmdbId=${tmdbId}&title=${encodeURIComponent(title)}`;

  const resp = await fetch(extractUrl, {
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Referer': 'https://kairou.space/',
      'Accept': 'application/json',
    },
  });

  if (!resp.ok) {
    return json({ ok: false, error: 'kairou upstream error', status: resp.status }, 502);
  }

  const data = await resp.json();
  if (!data || !data.streams || data.streams.length === 0) {
    return json({ ok: false, error: 'no streams found' }, 404);
  }

  const stream = data.streams[0];
  let streamUrl = stream.url || '';

  // The stream URL is a relative proxy path — make it absolute
  if (streamUrl.startsWith('/')) {
    streamUrl = 'https://kairou.space' + streamUrl;
  }

  // Extract subtitles
  const subs = [];
  if (data.subtitles && Array.isArray(data.subtitles)) {
    for (const sub of data.subtitles) {
      let subUrl = sub.url || '';
      if (subUrl.startsWith('/')) {
        subUrl = 'https://kairou.space' + subUrl;
      }
      subs.push({
        lang: sub.lang || '',
        label: sub.label || '',
        url: subUrl,
      });
    }
  }

  return json({
    ok: true,
    url: streamUrl,
    quality: stream.quality || '',
    format: stream.isHls ? 'hls' : 'mp4',
    subtitles: subs,
  });
}

// ---------- Tokyvideo Extract ----------

async function handleTokyvideo(pageUrl, mode, clientReq) {
  const pageResp = await fetch(pageUrl, {
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept': 'text/html',
    },
  });

  if (!pageResp.ok) {
    return json({ ok: false, error: 'tokyvideo upstream error', status: pageResp.status }, 502);
  }

  const html = await pageResp.text();

  const mp4Match = html.match(/https?:\/\/cdn[^"'\s]+\.mp4[^"'\s]*/);
  if (!mp4Match) {
    return json({ ok: false, error: 'no mp4 found on page' }, 404);
  }

  const mp4Url = mp4Match[0].replace(/&amp;/g, '&');

  if (mode === 'redirect') {
    return new Response(null, {
      status: 302,
      headers: { 'Location': mp4Url },
    });
  }

  if (mode === 'proxy') {
    const upstreamHeaders = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Referer': pageUrl,
    };
    const rangeHeader = clientReq.headers.get('Range');
    if (rangeHeader) {
      upstreamHeaders['Range'] = rangeHeader;
    }

    const videoResp = await fetch(mp4Url, { headers: upstreamHeaders });

    if (!videoResp.ok && videoResp.status !== 206) {
      return json({ ok: false, error: 'mp4 fetch failed', status: videoResp.status }, 502);
    }

    const respHeaders = {
      'Content-Type': 'video/mp4',
      'Accept-Ranges': 'bytes',
    };
    const cl = videoResp.headers.get('Content-Length');
    if (cl) respHeaders['Content-Length'] = cl;
    const cr = videoResp.headers.get('Content-Range');
    if (cr) respHeaders['Content-Range'] = cr;

    return new Response(videoResp.body, {
      status: videoResp.status,
      headers: respHeaders,
    });
  }

  return json({
    ok: true,
    url: mp4Url,
    format: 'mp4',
    source: pageUrl,
  });
}

// ---------- Saimo Stream Resolver ----------

async function handleSaimo(seriesId, season, episode) {
  const headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Referer': 'https://saimo-tv.pages.dev/',
    'Accept': 'application/json',
  };

  for (const versao of ['dub', 'leg']) {
    const streamUrl =
      `https://saimo-tv.pages.dev/api/stream?tipo=series&id=${seriesId}&s=${season}&e=${episode}&versao=${versao}&json=1`;

    const resp = await fetch(streamUrl, { headers });
    if (!resp.ok) continue;

    const data = await resp.json();
    if (!data || !data.url) continue;

    // Skip proxy URLs that return errors
    if (data.url.includes('/api/proxy?')) {
      try {
        const check = await fetch(data.url, { method: 'HEAD', headers });
        if (!check.ok) continue;
      } catch {
        continue;
      }
    }

    return json({
      ok: true,
      url: data.url,
      format: data.url.endsWith('.m3u8') || data.url.includes('master.txt') ? 'hls' : 'mp4',
      versao,
    });
  }

  return json({ ok: false, error: 'no working stream found' }, 404);
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
