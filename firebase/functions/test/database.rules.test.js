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

test("anonymous users cannot write private data", async () => {
  const anonymous = testEnvironment.unauthenticatedContext().database();
  await assertFails(set(ref(anonymous, "favoriler/anonymous/station-1"), true));
  await assertFails(set(ref(anonymous, "account_deletion_requests/anonymous"), {
    uid: "anonymous",
    requestedAt: new Date().toISOString(),
    source: "ios",
  }));
});
