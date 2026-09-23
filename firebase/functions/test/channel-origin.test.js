const assert = require("node:assert/strict");
const test = require("node:test");
const {isExtensionOrigin} = require("../channel-origin");

test("browser command accepts extension origins", () => {
  assert.equal(isExtensionOrigin("chrome-extension://abcdefghijklmnopabcdefghijklmnop"), true);
  assert.equal(isExtensionOrigin("moz-extension://ed1be0a4-b386-4a66-b19e-0664f015a342"), true);
});

test("browser command rejects missing and non-extension origins", () => {
  for (const origin of [undefined, null, "", "*", "https://example.com",
    "chrome-extension://", "chrome-extension://valid-id/path",
    "moz-extension://valid-id.example.com"]) {
    assert.equal(isExtensionOrigin(origin), false, String(origin));
  }
});
