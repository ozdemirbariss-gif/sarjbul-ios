const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const {after, before, beforeEach, test} = require("node:test");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {get, ref, set, update, serverTimestamp} = require("firebase/database");

const projectId = "demo-sarjbul";
let testEnvironment;

before(async () => {
  const rulesPath = path.resolve(__dirname, "../../../database.rules.json");
  testEnvironment = await initializeTestEnvironment({
    projectId,
    database: {rules: fs.readFileSync(rulesPath, "utf8")},
  });
});

beforeEach(async () => testEnvironment.clearDatabase());
after(async () => testEnvironment.cleanup());

const cooldownKinds = [
  {
    name: "reports", root: "yorumlar", meta: "kullanici_yorum_meta",
    timeKey: "son_yorum_zamani_ms", dateKey: "son_yorum_zamani", cooldown: 60_000,
    payload: (uid, date) => ({
      kullanici: "Doğrulanmış Sürücü", yorum: "Çalışıyor", durum: "Uygun",
      durum_sinifi: "bos", sinif_kaynagi: "ios_write_rule_v1", tarih: date.toISOString(), uid,
    }),
  },
  {
    name: "contributions", root: "station_contributions", meta: "kullanici_dogrulama_meta",
    timeKey: "son_dogrulama_zamani_ms", dateKey: "son_dogrulama_zamani", cooldown: 30_000,
    payload: (uid, date) => ({uid, kaynak: "ios", tarih: date.toISOString(), degerler: {price: "10 TL"}}),
  },
  {
    name: "demand events", root: "search_demand_events", meta: "search_demand_meta",
    timeKey: "son_olay_zamani_ms", cooldown: 300_000,
    payload: (_uid, date) => ({
      coarseCell: "38.4:27.1", preference: "nearest", radiusBucketKm: 25,
      resultBucket: "1-5", createdAtMilliseconds: date.getTime(), source: "ios_opt_in",
    }),
  },
];

const mutationPath = (kind, id, station = "station-1") =>
  kind.dateKey ? `${kind.root}/${station}/${id}` : `${kind.root}/${id}`;

function atomicMutation(kind, id, payload, uid = "owner", station = "station-1") {
  const recordPath = mutationPath(kind, id, station);
  const metadata = {[kind.timeKey]: serverTimestamp(), lastMutationPath: recordPath};
  if (kind.dateKey) metadata[kind.dateKey] = payload.tarih;
  return {[recordPath]: payload, [`${kind.meta}/${uid}`]: metadata};
}

test("public station summaries are readable but immutable", async () => {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await set(ref(context.database(), "station_status/example"), {durum: "aktif"});
  });
  const anonymous = testEnvironment.unauthenticatedContext().database();
  await assertSucceeds(get(ref(anonymous, "station_status/example")));
  await assertFails(set(ref(anonymous, "station_status/example"), {durum: "riskli"}));
});

test("favorites are isolated by Firebase auth uid", async () => {
  const owner = testEnvironment.authenticatedContext("owner").database();
  const other = testEnvironment.authenticatedContext("other").database();
  await assertSucceeds(set(ref(owner, "favoriler/owner/station-1"), true));
  await assertSucceeds(get(ref(owner, "favoriler/owner")));
  await assertFails(get(ref(other, "favoriler/owner")));
  await assertFails(set(ref(other, "favoriler/owner/station-2"), true));
});

test("push tokens are isolated by uid and require the canonical schema", async () => {
  const owner = testEnvironment.authenticatedContext("owner").database();
  const other = testEnvironment.authenticatedContext("other").database();
  const registration = {
    token: "a".repeat(64),
    platform: "ios",
    environment: "sandbox",
    updatedAtMilliseconds: Date.now(),
  };

  await assertSucceeds(set(ref(owner, "push_tokens/owner"), registration));
  await assertSucceeds(get(ref(owner, "push_tokens/owner")));
  await assertFails(get(ref(other, "push_tokens/owner")));
  await assertFails(set(ref(other, "push_tokens/owner"), registration));
  await assertFails(set(ref(owner, "push_tokens/owner"), {
    ...registration,
    environment: "unknown",
  }));
  await assertFails(set(ref(owner, "push_tokens/owner"), {
    ...registration,
    unexpected: true,
  }));
});

test("reports require the authenticated uid and canonical schema", async () => {
  const owner = testEnvironment.authenticatedContext("owner").database();
  const validReport = {
    kullanici: "Doğrulanmış Sürücü",
    yorum: "Çalışıyor",
    durum: "Uygun",
    durum_sinifi: "bos",
    sinif_kaynagi: "ios_write_rule_v1",
    tarih: new Date().toISOString(),
    uid: "owner",
  };
  const kind = cooldownKinds[0];
  await assertFails(update(ref(owner), atomicMutation(kind, "report-2", {
    ...validReport,
    uid: "other",
  })));
  await assertFails(update(ref(owner), atomicMutation(kind, "report-3", {
    ...validReport,
    unexpected: true,
  })));
  await assertSucceeds(update(ref(owner), atomicMutation(kind, "report-1", validReport)));
});

test("idempotency keys accept identical replay and reject conflicting overwrite", async () => {
  const owner = testEnvironment.authenticatedContext("owner").database();
  const reportRef = ref(owner, "yorumlar/station-1/08e750b8-idempotency-key");
  const report = {
    kullanici: "Doğrulanmış Sürücü",
    yorum: "Çalışıyor",
    durum: "Uygun",
    durum_sinifi: "bos",
    sinif_kaynagi: "ios_write_rule_v1",
    tarih: new Date(Date.now() - 86_400_000).toISOString(),
    uid: "owner",
  };

  await assertSucceeds(update(ref(owner), atomicMutation(cooldownKinds[0], "08e750b8-idempotency-key", report)));
  await assertSucceeds(set(reportRef, report));
  await assertFails(set(reportRef, {...report, durum: "Arızalı"}));
});

test("anonymous users cannot write private data", async () => {
  const anonymous = testEnvironment.unauthenticatedContext().database();
  await assertFails(set(ref(anonymous, "favoriler/anonymous/station-1"), true));
  await assertFails(set(ref(anonymous, "push_tokens/anonymous"), {
    token: "a".repeat(64),
    platform: "ios",
    environment: "sandbox",
    updatedAtMilliseconds: Date.now(),
  }));
  await assertFails(set(ref(anonymous, "account_deletion_requests/anonymous"), {
    uid: "anonymous",
    requestedAt: new Date().toISOString(),
    source: "ios",
  }));
});

test("friction analytics accepts only anonymous opt-in buckets", async () => {
  const owner = testEnvironment.authenticatedContext("owner").database();
  const anonymous = testEnvironment.unauthenticatedContext().database();
  const event = {
    kind: "outcomeReady",
    elapsedBucket: "1_3s",
    journeyPhase: "decision",
    createdAtMilliseconds: Date.now(),
    source: "ios_opt_in",
  };

  await assertSucceeds(set(ref(owner, "friction_events/event-1"), event));
  await assertFails(get(ref(owner, "friction_events/event-1")));
  await assertFails(set(ref(anonymous, "friction_events/event-2"), event));
  await assertFails(set(ref(owner, "friction_events/event-3"), {
    ...event,
    latitude: 38.4,
  }));
  const {source, ...missingField} = event;
  await assertFails(set(ref(owner, "friction_events/event-4"), missingField));
});

test("demand events require all fields and reject extra fields", async () => {
  const owner = testEnvironment.authenticatedContext("owner").database();
  const event = {
    coarseCell: "38.4:27.1", preference: "nearest", radiusBucketKm: 25,
    resultBucket: "1-5", createdAtMilliseconds: Date.now(), source: "ios_opt_in",
  };
  const kind = cooldownKinds[2];
  const {source, ...missingField} = event;
  await assertFails(update(ref(owner), atomicMutation(kind, "missing", missingField)));
  await assertFails(update(ref(owner), atomicMutation(kind, "extra", {...event, latitude: 38.4})));
  await assertSucceeds(update(ref(owner), atomicMutation(kind, "valid", event)));
});

test("contribution values allow only the seven supported keys", async () => {
  const owner = testEnvironment.authenticatedContext("owner").database();
  const contribution = {
    uid: "owner", kaynak: "ios", tarih: new Date().toISOString(),
    degerler: {price: "10 TL", socket: "CCS", address: "Test", operator: "Test",
      lighting: "yes", camera: "no", open_24_hours: "yes"},
  };
  const kind = cooldownKinds[1];
  await assertFails(update(ref(owner), atomicMutation(kind, "extra", {
    ...contribution, degerler: {...contribution.degerler, extra: "bad"},
  })));
  await assertFails(update(ref(owner), atomicMutation(kind, "empty", {...contribution, degerler: {}})));
  await assertSucceeds(update(ref(owner), atomicMutation(kind, "valid", contribution)));
});

for (const kind of cooldownKinds) {
  test(`${kind.name} require atomic cooldown metadata and reject rapid new records`, async () => {
    const owner = testEnvironment.authenticatedContext("owner").database();
    const payload = kind.payload("owner", new Date());
    await assertFails(set(ref(owner, mutationPath(kind, "without-meta")), payload));
    const first = atomicMutation(kind, "first", payload);
    await assertSucceeds(update(ref(owner), first));
    await assertFails(set(ref(owner, mutationPath(kind, "without-meta-2")), payload));
    await assertFails(update(ref(owner), atomicMutation(kind, "second", payload)));
  });

  test(`${kind.name} cannot delete, backdate, forge or steal cooldown metadata`, async () => {
    const owner = testEnvironment.authenticatedContext("owner").database();
    const other = testEnvironment.authenticatedContext("other").database();
    const payload = kind.payload("owner", new Date());
    const first = atomicMutation(kind, "first", payload);
    const metaPath = `${kind.meta}/owner`;
    await assertFails(set(ref(owner, metaPath), first[metaPath])); // No referenced record.
    const forged = atomicMutation(kind, "first", payload);
    forged[metaPath][kind.timeKey] = Date.now() - kind.cooldown;
    await assertFails(update(ref(owner), forged));
    const wrongPath = atomicMutation(kind, "first", payload);
    wrongPath[metaPath].lastMutationPath = mutationPath(kind, "unrelated");
    await assertFails(update(ref(owner), wrongPath));
    await assertSucceeds(update(ref(owner), first));
    await assertFails(set(ref(other, metaPath), first[metaPath]));
    await assertFails(set(ref(owner, metaPath), null));
    await assertFails(set(ref(owner, `${metaPath}/${kind.timeKey}`), null));
    await assertFails(set(ref(owner, `${metaPath}/lastMutationPath`), null));
    await assertFails(set(ref(owner, `${metaPath}/${kind.timeKey}`), Date.now() - kind.cooldown));
    await assertFails(update(ref(owner), {
      [metaPath]: null,
      [mutationPath(kind, "after-delete")]: payload,
    }));
    if (kind.dateKey) {
      const otherMutation = atomicMutation(kind, "first", payload, "other");
      await assertFails(set(ref(other, `${kind.meta}/other`), otherMutation[`${kind.meta}/other`]));
    }
  });

  test(`${kind.name} cannot batch multiple new records into one cooldown`, async () => {
    const owner = testEnvironment.authenticatedContext("owner").database();
    const payload = kind.payload("owner", new Date());
    await assertFails(update(ref(owner), {
      ...atomicMutation(kind, "first", payload),
      [mutationPath(kind, "second")]: payload,
    }));
    if (kind.dateKey) {
      await assertFails(update(ref(owner), {
        ...atomicMutation(kind, "same-id", payload),
        [mutationPath(kind, "same-id", "station-2")]: payload,
      }));
    }
  });

  test(`${kind.name} use receipt time for offline writes and preserve identical replay`, async () => {
    const owner = testEnvironment.authenticatedContext("owner").database();
    const payload = kind.payload("owner", new Date(Date.now() - 86_400_000));
    const startedAt = Date.now();
    const first = atomicMutation(kind, "offline", payload);
    await assertSucceeds(update(ref(owner), first));
    const saved = (await get(ref(owner, `${kind.meta}/owner`))).val();
    assert.ok(saved[kind.timeKey] >= startedAt);
    await assertFails(update(ref(owner), atomicMutation(kind, "offline-2", payload)));
    await assertSucceeds(update(ref(owner), first));
    await assertSucceeds(set(ref(owner, mutationPath(kind, "offline")), payload));
    const conflicting = {...payload};
    if (kind.name === "reports") conflicting.yorum = "Different report";
    else if (kind.name === "contributions") conflicting.degerler = {price: "20 TL"};
    else conflicting.resultBucket = "21+";
    await assertFails(update(ref(owner), atomicMutation(kind, "offline", conflicting)));
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await set(ref(context.database(), `${kind.meta}/owner/${kind.timeKey}`), Date.now() - kind.cooldown - 1000);
    });
    // An old, untouched marker still cannot authorize a new record-only write.
    await assertFails(set(ref(owner, mutationPath(kind, "after-cooldown")), payload));
    await assertSucceeds(update(ref(owner), atomicMutation(kind, "after-cooldown", payload)));
    // A delayed replay must not conflict with the newer record's cooldown marker.
    await assertSucceeds(update(ref(owner), first));
  });
}
