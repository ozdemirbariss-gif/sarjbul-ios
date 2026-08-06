const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "public, max-age=60, stale-while-revalidate=86400"
};

export default {
  async fetch(request, env, context) {
    const url = new URL(request.url);
    if (request.method !== "GET") {
      return json({ status: "read_only", message: "Writes use the authenticated origin." }, 405);
    }
    if (url.pathname === "/health") {
      return json({ status: "ok", layer: "sarjbul-edge", time: new Date().toISOString() });
    }
    if (url.pathname === "/v1/stations") {
      return recoverJSON(request, env, context, {
        origin: env.STATIONS_ORIGIN,
        snapshotKey: "stations"
      });
    }
    if (url.pathname === "/v1/station-tiles/manifest") {
      return recoverJSON(request, env, context, {
        origin: env.TILE_MANIFEST_ORIGIN,
        snapshotKey: "station-tiles-manifest",
        transform: (value) => ({
          ...value,
          base_url: `${url.origin}/v1/station-tiles/`
        })
      });
    }
    if (url.pathname.startsWith("/v1/station-tiles/")) {
      const file = url.pathname.slice("/v1/station-tiles/".length);
      if (!/^station_tile_[a-z0-9]+\.json$/.test(file)) {
        return json({ status: "not_found" }, 404);
      }
      return recoverJSON(request, env, context, {
        origin: new URL(file, env.TILE_ORIGIN).toString(),
        snapshotKey: `tile:${file}`
      });
    }
    return json({
      status: "maintenance",
      message: "The service is recovering. Saved app data remains available."
    }, 503);
  }
};

async function recoverJSON(request, env, context, options) {
  const cache = caches.default;
  const cacheKey = new Request(request.url, request);
  const cached = await cache.match(cacheKey);

  try {
    const response = await fetch(options.origin, {
      headers: { accept: "application/json", "user-agent": "SarjBul-Edge/1" },
      signal: AbortSignal.timeout(8000)
    });
    if (!response.ok) throw new Error(`origin_${response.status}`);

    const original = await response.json();
    const value = options.transform ? options.transform(original) : original;
    const body = JSON.stringify(value);
    const stable = new Response(body, {
      headers: { ...JSON_HEADERS, "x-sarjbul-source": "origin" }
    });
    context.waitUntil(cache.put(cacheKey, stable.clone()));
    if (env.STABLE_SNAPSHOTS) {
      context.waitUntil(env.STABLE_SNAPSHOTS.put(options.snapshotKey, body, { expirationTtl: 604800 }));
    }
    return stable;
  } catch (error) {
    if (cached) return withSource(cached, "edge-cache");
    const snapshot = env.STABLE_SNAPSHOTS
      ? await env.STABLE_SNAPSHOTS.get(options.snapshotKey)
      : null;
    if (snapshot) {
      return new Response(snapshot, {
        headers: { ...JSON_HEADERS, "x-sarjbul-source": "stable-snapshot" }
      });
    }
    return json({
      status: "maintenance",
      message: "The origin is recovering. The iOS app will continue with local snapshots."
    }, 503);
  }
}

function json(value, status = 200) {
  return new Response(JSON.stringify(value), { status, headers: JSON_HEADERS });
}

function withSource(response, source) {
  const headers = new Headers(response.headers);
  headers.set("x-sarjbul-source", source);
  headers.set("x-sarjbul-recovery", "true");
  return new Response(response.body, { status: response.status, headers });
}
