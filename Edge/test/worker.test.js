import assert from "node:assert/strict";
import test from "node:test";
import worker from "../src/worker.js";

test("health remains available without the origin", async () => {
  const response = await worker.fetch(new Request("https://edge.example/health"), {}, context());
  assert.equal(response.status, 200);
  assert.equal((await response.json()).layer, "sarjbul-edge");
});

test("manifest keeps tile traffic on the recovery edge", async () => {
  globalThis.caches = {
    default: {
      match: async () => null,
      put: async () => undefined
    }
  };
  globalThis.fetch = async () => new Response(JSON.stringify({
    base_url: "https://origin.example/tiles/",
    tiles: []
  }));
  const environment = {
    TILE_MANIFEST_ORIGIN: "https://origin.example/manifest.json"
  };

  const response = await worker.fetch(
    new Request("https://edge.example/v1/station-tiles/manifest"),
    environment,
    context()
  );
  const manifest = await response.json();

  assert.equal(response.headers.get("x-sarjbul-source"), "origin");
  assert.equal(manifest.base_url, "https://edge.example/v1/station-tiles/");
});

function context() {
  return { waitUntil: () => undefined };
}
