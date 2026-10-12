const {test} = require("node:test");
const assert = require("node:assert/strict");
const {aggregateReports, DAY} = require("../community-aggregation");
const now = Date.UTC(2026, 9, 12, 12, 30);
const report = (uid, state, time = now) => ({uid, durum: state, durum_sinifi: state,
  observedAtMilliseconds: time, receivedAtMilliseconds: now});
const classify = (record) => record.durum_sinifi;

test("old positives cannot mask a fresh fault or be presented as fresh", () => {
  const {status} = aggregateReports([report("old", "bos", now - 2000 * DAY), report("fault", "mesgul")], classify, now);
  assert.equal(status.durum, "riskli");
  assert.equal(status.toplam, 1);
  assert.equal(status.validUntilMilliseconds, now + DAY);
});
test("one user has one current observation and one vote per occupancy bucket", () => {
  const {status, occupancy} = aggregateReports([
    report("a", "bos", now - 1000), report("a", "mesgul"), report("a", "bos", now - 2000),
  ], classify, now);
  assert.equal(status.toplam, 1);
  assert.equal(status.durum, "riskli");
  assert.deepEqual(Object.values(occupancy), [{busy: 1, available: 0}]);
});
test("expired, future, invalid and undated observations cannot become current status", () => {
  const {status} = aggregateReports([
    report("expired", "bos", now - 2 * DAY), report("future", "bos", now + DAY),
    {...report("invalid", "bos"), observedAtMilliseconds: "tomorrow"}, {uid: "legacy", tarih: "2099-01-01"},
  ], classify, now);
  assert.equal(status, null);
});
test("reaggregation does not renew an observation expiry", () => {
  const records = [report("a", "bos", now - 1000)];
  assert.equal(aggregateReports(records, classify, now).status.validUntilMilliseconds,
      aggregateReports(records, classify, now + 10_000).status.validUntilMilliseconds);
});
