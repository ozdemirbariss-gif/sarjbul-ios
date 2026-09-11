const {createHash} = require("node:crypto");

const DAY = 24 * 60 * 60 * 1000;

async function aggregateSearchDemand(database, eventId, payload, now = Date.now()) {
  const createdAt = new Date(Number(payload.createdAtMilliseconds));
  if (!Number.isFinite(createdAt.getTime()) || createdAt.getTime() < now - 7 * DAY ||
      createdAt.getTime() > now + 5000) return;
  const month = createdAt.toISOString().slice(0, 7);
  const cell = String(payload.coarseCell || "unknown").replace(/[.#$\[\]\/]/g, "_");
  const receiptKey = createHash("sha256").update(eventId).digest("hex");
  // The receipt and all counters commit together, including concurrent function retries.
  await database.ref("demand_heatmap").transaction((current) => {
    const value = current || {};
    if (value._processed?.[receiptKey]) return;
    value._processed ||= {};
    value._processed[receiptKey] = {expiresAtMilliseconds: now + 8 * DAY};
    value[month] ||= {};
    const aggregate = value[month][cell] ||= {};
    aggregate.total = Number(aggregate.total || 0) + 1;
    for (const [field, key] of [
      ["preferences", payload.preference],
      ["radius_buckets", String(payload.radiusBucketKm)],
      ["result_buckets", payload.resultBucket],
    ]) {
      aggregate[field] ||= {};
      aggregate[field][key] = Number(aggregate[field][key] || 0) + 1;
    }
    aggregate.updated_at = new Date(now).toISOString();
    return value;
  });
}

async function deleteAccountData(database, uid, now = Date.now()) {
  const requestRef = database.ref(`account_deletion_requests/${uid}`);
  const request = (await requestRef.get()).val();
  if (!request || request.uid !== uid || request.status === "completed") return;
  const removals = {};
  for (const collection of ["yorumlar", "station_contributions"]) {
    const stations = await database.ref(collection).get();
    stations.forEach((station) => station.forEach((record) => {
      if (record.child("uid").val() === uid) removals[`${collection}/${station.key}/${record.key}`] = null;
    }));
  }
  // Analytics payloads have no UID. Drop the identity link below, but never delete
  // a raw event using a client-supplied path that could refer to another event.
  // Detached raw events expire through scheduled retention.
  for (const collection of ["favoriler", "kullanici_yorum_meta", "kullanici_dogrulama_meta",
    "search_demand_meta", "friction_meta", "push_tokens"]) {
    removals[`${collection}/${uid}`] = null;
  }
  // Keep the receipt: it blocks all writes with the old UID, even with a still-valid ID token.
  removals[`account_deletion_requests/${uid}/status`] = "completed";
  removals[`account_deletion_requests/${uid}/completedAtMilliseconds`] = now;
  await database.ref().update(removals);
}

async function removeExpired(database, path, field, cutoff) {
  // Drain multiple pages, excluding entries that lack a numeric timestamp.
  for (let page = 0; page < 20; page++) {
    const snapshot = await database.ref(path).orderByChild(field)
        .startAt(0).endAt(cutoff).limitToFirst(500).get();
    const removals = {};
    snapshot.forEach((child) => { removals[child.key] = null; });
    if (snapshot.numChildren() === 0) return;
    if (path.endsWith("_meta")) {
      // A new event may refresh this UID after the query; never erase its new cooldown.
      await Promise.all(Object.keys(removals).map((key) => database.ref(`${path}/${key}`).transaction((value) => {
        if (value && typeof value[field] === "number" && value[field] <= cutoff) return null;
        return undefined;
      })));
    } else {
      await database.ref(path).update(removals);
    }
    if (snapshot.numChildren() < 500) return;
  }
  throw new Error(`Retention backlog remains at ${path}; retry required`);
}

async function cleanupAnalyticsData(database, auth, now = Date.now()) {
  await Promise.all([
    removeExpired(database, "friction_events", "createdAtMilliseconds", now - 7 * DAY),
    removeExpired(database, "search_demand_events", "createdAtMilliseconds", now - 7 * DAY),
    removeExpired(database, "search_demand_meta", "son_olay_zamani_ms", now - 7 * DAY),
    removeExpired(database, "friction_meta", "son_olay_zamani_ms", now - 7 * DAY),
    removeExpired(database, "demand_heatmap/_processed", "expiresAtMilliseconds", now),
  ]);
  let cursor;
  for (let page = 0; page < 20; page++) {
    let query = database.ref("account_deletion_requests").orderByChild("completedAtMilliseconds");
    query = cursor ? query.startAfter(cursor.time, cursor.uid) : query.startAt(0);
    const completed = await query.endAt(now - 7 * DAY).limitToFirst(500).get();
    const receipts = [];
    completed.forEach((child) => { receipts.push([child.key, child.val()]); });
    for (const [uid, receipt] of receipts) {
      cursor = {time: receipt.completedAtMilliseconds, uid};
      if (receipt.status !== "completed") continue;
      const reference = database.ref(`account_deletion_requests/${uid}`);
      if (!receipt.authDeletedAtMilliseconds) {
        try { await auth.deleteUser(uid); } catch (error) {
          if (error.code !== "auth/user-not-found") throw error;
        }
        await reference.child("authDeletedAtMilliseconds").set(now);
      } else if (receipt.authDeletedAtMilliseconds <= now - 2 * 60 * 60 * 1000) {
        // Every ID token issued before Auth deletion must expire before removing the write block.
        await reference.remove();
      }
    }
    if (completed.numChildren() < 500) return;
  }
  throw new Error("Account deletion receipt backlog remains; retry required");
}

module.exports = {aggregateSearchDemand, deleteAccountData, cleanupAnalyticsData};
