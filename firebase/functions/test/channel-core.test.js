const assert = require("node:assert/strict");
const test = require("node:test");
const {formatReply, parseCommand, parseCoordinates, searchStations} = require("../channel-core");

const stations = [
  {
    id: "near-ac",
    isim: "Yakın AC",
    enlem: 38.42,
    boylam: 27.15,
    hiz: "22 kW AC",
    fiyat: "9,50 TL/kWh",
  },
  {
    id: "fast-dc",
    isim: "Hızlı DC",
    enlem: 38.46,
    boylam: 27.18,
    hiz: "180 kW DC",
    fiyat: "12,00 TL/kWh",
  },
  {
    id: "cheap",
    isim: "Ekonomik",
    enlem: 38.44,
    boylam: 27.16,
    hiz: "60 kW DC",
    fiyat: "7,25 TL/kWh",
  },
];

test("command parser understands Turkish intent and coordinates", () => {
  const command = parseCommand({text: "38.4237, 27.1428 hızlı şarj"});
  assert.equal(command.preference, "fastest");
  assert.deepEqual(command.location, {latitude: 38.4237, longitude: 27.1428});
});

test("invalid coordinates are rejected", () => {
  assert.equal(parseCoordinates("120, 240"), null);
});

test("channel search respects nearest, fastest and economical intent", () => {
  const location = {latitude: 38.4237, longitude: 27.1428};
  const nearest = searchStations(stations, {location, preference: "nearest"}, 1);
  const fastest = searchStations(stations, {location, preference: "fastest"}, 1);
  const economical = searchStations(stations, {location, preference: "economical"}, 1);
  assert.equal(nearest[0].id, "near-ac");
  assert.equal(fastest[0].id, "fast-dc");
  assert.equal(economical[0].id, "cheap");
});

test("reply completes the task with a navigation URL", () => {
  const command = parseCommand({
    text: "yakın",
    location: {latitude: 38.4237, longitude: 27.1428},
  });
  const reply = formatReply(command, searchStations(stations, command, 1));
  assert.match(reply, /Yakın AC/);
  assert.match(reply, /google\.com\/maps\/dir/);
});
