const fs = require("node:fs");
const path = require("node:path");
const {after, before, beforeEach, test} = require("node:test");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {get, ref, set} = require("firebase/database");

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
  await assertSucceeds(set(ref(owner, "yorumlar/station-1/report-1"), validReport));
  await assertFails(set(ref(owner, "yorumlar/station-1/report-2"), {
    ...validReport,
    uid: "other",
  }));
  await assertFails(set(ref(owner, "yorumlar/station-1/report-3"), {
    ...validReport,
    unexpected: true,
  }));
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

  await assertSucceeds(set(reportRef, report));
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
  await assertSucceeds(set(ref(owner, "search_demand_events/valid"), event));
  const {source, ...missingField} = event;
  await assertFails(set(ref(owner, "search_demand_events/missing"), missingField));
  await assertFails(set(ref(owner, "search_demand_events/extra"), {...event, latitude: 38.4}));
});

test("contribution values allow only the seven supported keys", async () => {
  const owner = testEnvironment.authenticatedContext("owner").database();
  const contribution = {
    uid: "owner", kaynak: "ios", tarih: new Date().toISOString(),
    degerler: {price: "10 TL", socket: "CCS", address: "Test", operator: "Test",
      lighting: "yes", camera: "no", open_24_hours: "yes"},
  };
  await assertSucceeds(set(ref(owner, "station_contributions/test/valid"), contribution));
  await assertFails(set(ref(owner, "station_contributions/test/extra"), {
    ...contribution, degerler: {...contribution.degerler, extra: "bad"},
  }));
  await assertFails(set(ref(owner, "station_contributions/test/empty"), {...contribution, degerler: {}}));
});
