const {test, before, beforeEach, after} = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const {initializeTestEnvironment} = require("@firebase/rules-unit-testing");
const assert = require("node:assert/strict");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getDatabase} = require("firebase-admin/database");
const backend = require("../ios-backend");

if (!process.env.FIREBASE_DATABASE_EMULATOR_HOST) throw new Error("Local database emulator required");
const app = initializeApp({projectId: "demo-sarjbul-backend", databaseURL: "https://demo-sarjbul-backend.firebaseio.com"}, "backend-tests");
const database = getDatabase(app);
const DAY = 86400000;
let testEnvironment;
before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId: "demo-sarjbul-backend",
    database: {rules: fs.readFileSync(path.resolve(__dirname, "../../../database.rules.json"), "utf8")},
  });
});
beforeEach(async () => database.ref().set(null));
after(async () => { await deleteApp(app); await testEnvironment.cleanup(); });

test("cleanup acknowledges only the requested UID and preserves its write barrier", async () => {
  await database.ref().set({
    account_deletion_requests: {owner: {uid: "owner", status: "pending"}},
    favoriler: {owner: {one: true}, other: {two: true}},
    push_tokens: {owner: {token: "private"}},
    yorumlar: {station: {one: {uid: "owner"}, two: {uid: "other"}}},
    station_contributions: {station: {one: {uid: "owner"}, two: {uid: "other"}}},
    search_demand_meta: {owner: {lastMutationPath: "search_demand_events/owned"}},
    search_demand_events: {owned: {source: "ios_opt_in"}, other: {source: "ios_opt_in"}},
    friction_meta: {owner: {lastMutationPath: "friction_events/owned"}},
    friction_events: {owned: {source: "ios_opt_in"}},
  });
  await backend.deleteAccountData(database, "owner", 1000);
  await backend.deleteAccountData(database, "owner", 2000);
  const result = (await database.ref().get()).val();
  assert.equal(result.account_deletion_requests.owner.status, "completed");
  assert.equal(result.account_deletion_requests.owner.completedAtMilliseconds, 1000);
  assert.equal(result.favoriler.owner, undefined);
  assert.equal(result.favoriler.other.two, true);
  assert.equal(result.yorumlar.station.one, undefined);
  assert.equal(result.yorumlar.station.two.uid, "other");
  assert.equal(result.station_contributions.station.one, undefined);
  assert.equal(result.search_demand_meta, undefined);
  assert.equal(result.search_demand_events.owned.source, "ios_opt_in");
  assert.equal(result.search_demand_events.other.source, "ios_opt_in");
  assert.equal(result.friction_meta, undefined);
  assert.equal(result.friction_events.owned.source, "ios_opt_in");
  assert.equal(result.push_tokens, undefined);
});

test("interrupted cleanup leaves a pending request that can be retried", async () => {
  await database.ref().set({account_deletion_requests: {owner: {uid: "owner", status: "pending"}}, favoriler: {owner: {one: true}}});
  const failingDatabase = {ref(path) {
    if (path === "station_contributions") return {get: async () => { throw new Error("temporary outage"); }};
    return database.ref(path);
  }};
  await assert.rejects(backend.deleteAccountData(failingDatabase, "owner"), /temporary outage/);
  assert.equal((await database.ref("account_deletion_requests/owner/status").get()).val(), "pending");
  await backend.deleteAccountData(database, "owner");
  assert.equal((await database.ref("account_deletion_requests/owner/status").get()).val(), "completed");
});

test("deletion cannot erase a raw event through a forged analytics metadata path", async () => {
  await database.ref().set({
    account_deletion_requests: {owner: {uid: "owner", status: "pending"}},
    friction_meta: {owner: {lastMutationPath: "friction_events/another-event"}},
    friction_events: {"another-event": {source: "ios_opt_in"}},
  });
  await backend.deleteAccountData(database, "owner");
  assert.equal((await database.ref("friction_events/another-event").get()).exists(), true);
  assert.equal((await database.ref("friction_meta/owner").get()).exists(), false);
});

const demand = (now) => ({createdAtMilliseconds: now, coarseCell: "38p4_27p1", preference: "nearest", radiusBucketKm: 25, resultBucket: "1-5"});

test("concurrent retries and conflicting replays count one demand event only", async () => {
  const now = Date.now();
  await Promise.all(Array.from({length: 8}, () => backend.aggregateSearchDemand(database, "event-one", demand(now), now)));
  await backend.aggregateSearchDemand(database, "event-one", {...demand(now), coarseCell: "other"}, now);
  await backend.aggregateSearchDemand(database, "event-two", demand(now), now);
  const month = new Date(now).toISOString().slice(0, 7);
  const value = (await database.ref(`demand_heatmap/${month}`).get()).val();
  assert.equal(value["38p4_27p1"].total, 2);
  assert.equal(value["38p4_27p1"].preferences.nearest, 2);
  assert.equal(value.other, undefined);
});

test("raw event deletion does not remove its deduplication receipt", async () => {
  const now = Date.now();
  const payload = demand(now);
  await database.ref("search_demand_events/one").set(payload);
  await backend.aggregateSearchDemand(database, "one", payload, now);
  await database.ref("search_demand_events/one").remove();
  await backend.aggregateSearchDemand(database, "one", payload, now + DAY);
  const month = new Date(now).toISOString().slice(0, 7);
  assert.equal((await database.ref(`demand_heatmap/${month}/38p4_27p1/total`).get()).val(), 1);
  await backend.cleanupAnalyticsData(database, {deleteUser: async () => {}}, now + 9 * DAY);
  await backend.aggregateSearchDemand(database, "one", payload, now + 9 * DAY);
  assert.equal((await database.ref(`demand_heatmap/${month}/38p4_27p1/total`).get()).val(), 1);
});

test("retention removes expired raw data and lets deleted identity tokens expire", async () => {
  const now = Date.now();
  await database.ref().set({
    friction_events: {old: {createdAtMilliseconds: now - 8 * DAY}, fresh: {createdAtMilliseconds: now}},
    search_demand_meta: {old: {son_olay_zamani_ms: now - 8 * DAY}},
    account_deletion_requests: {
      pending: {uid: "pending", status: "pending"},
      owner: {uid: "owner", status: "completed", completedAtMilliseconds: now - 8 * DAY},
    },
  });
  const deleted = [];
  const auth = {deleteUser: async (uid) => deleted.push(uid)};
  await backend.cleanupAnalyticsData(database, auth, now);
  assert.deepEqual(deleted, ["owner"]);
  assert.equal((await database.ref("friction_events/old").get()).exists(), false);
  assert.equal((await database.ref("friction_events/fresh").get()).exists(), true);
  assert.equal((await database.ref("account_deletion_requests/owner").get()).exists(), true);
  await backend.cleanupAnalyticsData(database, auth, now + 60 * 60 * 1000);
  assert.equal((await database.ref("account_deletion_requests/owner").get()).exists(), true);
  await backend.cleanupAnalyticsData(database, auth, now + DAY);
  assert.equal((await database.ref("account_deletion_requests/owner").get()).exists(), false);
  assert.equal((await database.ref("account_deletion_requests/pending").get()).exists(), true);
});


test("retention drains pages and pending receipts do not starve completed ones", async () => {
  const now = Date.now();
  const data = {};
  for (let index = 0; index < 501; index++) {
    data[`friction_events/old-${index}`] = {createdAtMilliseconds: now - 8 * DAY};
    data[`account_deletion_requests/pending-${index}`] = {status: "pending"};
    data[`account_deletion_requests/completed-${index}`] = {status: "completed", completedAtMilliseconds: now - 8 * DAY};
  }
  await database.ref().update(data);
  const deleted = [];
  await backend.cleanupAnalyticsData(database, {deleteUser: async (uid) => deleted.push(uid)}, now);
  assert.equal((await database.ref("friction_events").get()).exists(), false);
  assert.equal(deleted.length, 501);
  assert.equal(new Set(deleted).size, 501);
  assert.equal((await database.ref("account_deletion_requests/pending-0").get()).exists(), true);
});


test("retention preserves a cooldown refreshed after the expiry query", async () => {
  const now = Date.now();
  await database.ref("friction_meta/owner").set({son_olay_zamani_ms: now - 8 * DAY});
  let refreshed = false;
  const racingDatabase = {ref(path) {
    const reference = database.ref(path);
    if (path !== "friction_meta") return reference;
    return {orderByChild(field) {
      const query = reference.orderByChild(field);
      return {startAt(start) { return {endAt(end) { return {limitToFirst(limit) { return {get: async () => {
        const snapshot = await query.startAt(start).endAt(end).limitToFirst(limit).get();
        if (!refreshed) {
          refreshed = true;
          await database.ref("friction_meta/owner").set({son_olay_zamani_ms: now});
        }
        return snapshot;
      }}; }}; }}; }};
    }};
  }};
  await backend.cleanupAnalyticsData(racingDatabase, {deleteUser: async () => {}}, now);
  assert.equal((await database.ref("friction_meta/owner/son_olay_zamani_ms").get()).val(), now);
});
