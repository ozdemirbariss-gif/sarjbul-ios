const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;

function observedTime(record, now, maximumAge) {
  const time = record.observedAtMilliseconds;
  const received = record.receivedAtMilliseconds;
  if (!record.uid || !Number.isFinite(time) || !Number.isFinite(received) ||
      time > received + 5000 || received > now + 5000 || time < now - maximumAge || time > now + 5000) return null;
  return time;
}

function aggregateReports(records, classify, now = Date.now()) {
  const recent = records.map((record) => ({record, time: observedTime(record, now, 90 * DAY)}))
      .filter((item) => item.time !== null).sort((a, b) => b.time - a.time);
  const latestByUser = new Map();
  const occupancy = {};
  const bucketUsers = new Set();
  for (const {record, time} of recent) {
    if (time >= now - DAY && !latestByUser.has(record.uid)) latestByUser.set(record.uid, {record, time});
    const date = new Date(time + 3 * HOUR);
    const key = `${date.getUTCDay() + 1}-${date.getUTCHours()}`;
    const userBucket = `${record.uid}:${key}`;
    if (bucketUsers.has(userBucket)) continue;
    bucketUsers.add(userBucket);
    occupancy[key] ||= {busy: 0, available: 0};
    const state = classify(record);
    if (state === "mesgul") occupancy[key].busy++;
    if (state === "bos") occupancy[key].available++;
  }
  const latest = [...latestByUser.values()][0];
  // A fresh fault must never be masked by an older majority. Status describes the latest observation.
  const status = latest ? {
    durum: classify(latest.record) === "mesgul" ? "riskli" : classify(latest.record) === "bos" ? "aktif" : "belirsiz",
    etiket: latest.record.durum || "Belirsiz",
    toplam: latestByUser.size,
    observedAtMilliseconds: latest.time,
    validUntilMilliseconds: latest.time + DAY,
    guncelleme_tarihi: new Date(latest.time).toISOString(),
  } : null;
  return {status, occupancy, occupancyObservedAtMilliseconds: recent[0]?.time ?? null};
}

module.exports = {observedTime, aggregateReports, DAY};
