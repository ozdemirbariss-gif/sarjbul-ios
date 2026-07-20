const {setGlobalOptions} = require("firebase-functions/v2");
const {onValueCreated, onValueWritten} = require("firebase-functions/v2/database");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getDatabase} = require("firebase-admin/database");

initializeApp();
setGlobalOptions({region: "europe-west1", maxInstances: 10});

const normalize = (value) => String(value || "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLocaleLowerCase("tr-TR")
    .replace(/ı/g, "i");

const normalizeContributionValue = (field, value) => {
  const text = normalize(String(value).trim()).replace(/\s+/g, " ");
  if (field === "price") {
    const match = text.match(/\d[\d.,]*/);
    if (match) {
      const raw = match[0];
      const decimal = raw.includes(",") ? raw.replace(/\./g, "").replace(",", ".") : raw;
      const number = Number(decimal);
      if (Number.isFinite(number)) return `price:${number.toFixed(2)}`;
    }
  }
  if (["lighting", "camera", "open_24_hours"].includes(field)) {
    return ["yes", "evet", "true", "var"].includes(text) ? "yes" : "no";
  }
  if (field === "socket") return text.replace(/[^a-z0-9]/g, "");
  return text.replace(/[^a-z0-9 ]/g, "").trim();
};

const classify = (report) => {
  if (["bos", "mesgul", "belirsiz"].includes(report.durum_sinifi)) {
    return report.durum_sinifi;
  }
  const text = normalize(`${report.durum} ${report.yorum}`);
  if (["uygun", "bos", "sorunsuz", "aktif"].some((word) => text.includes(word))) {
    return "bos";
  }
  if (["sorun", "ariza", "bozuk", "calismiyor", "sira", "dolu", "bekleme", "mesgul"]
      .some((word) => text.includes(word))) {
    return "mesgul";
  }
  return "belirsiz";
};

exports.aggregateStationStatus = onValueWritten(
    "/yorumlar/{stationKey}/{reportId}",
    async (event) => {
      const stationKey = event.params.stationKey;
      const database = getDatabase();
      const reportsSnapshot = await database.ref(`yorumlar/${stationKey}`)
          .orderByChild("tarih")
          .limitToLast(120)
          .get();

      if (!reportsSnapshot.exists()) {
        await database.ref(`station_status/${stationKey}`).remove();
        return;
      }

      const reports = Object.values(reportsSnapshot.val() || {});
      reports.sort((left, right) => String(right.tarih || "").localeCompare(String(left.tarih || "")));
      const latest = reports[0] || {};
      const classes = reports.map(classify);
      const busyCount = classes.filter((value) => value === "mesgul").length;
      const availableCount = classes.filter((value) => value === "bos").length;
      const state = busyCount > availableCount ? "riskli" : availableCount > 0 ? "aktif" : "belirsiz";

      const occupancy = {};
      reports.forEach((report) => {
        const date = new Date(report.tarih || "");
        if (Number.isNaN(date.getTime())) return;
        const turkeyDate = new Date(date.getTime() + 3 * 60 * 60 * 1000);
        const key = `${turkeyDate.getUTCDay() + 1}-${turkeyDate.getUTCHours()}`;
        occupancy[key] ||= {busy: 0, available: 0};
        const reportClass = classify(report);
        if (reportClass === "mesgul") occupancy[key].busy += 1;
        if (reportClass === "bos") occupancy[key].available += 1;
      });

      const updatedAt = new Date().toISOString();
      await Promise.all([
        database.ref(`station_status/${stationKey}`).set({
          durum: state,
          etiket: latest.durum || "Belirsiz",
          toplam: reports.length,
          guncelleme_tarihi: updatedAt,
        }),
        database.ref(`station_insights/${stationKey}`).update({
          saatlik_yogunluk: occupancy,
          guncelleme_tarihi: updatedAt,
        }),
      ]);
    },
);

exports.aggregateStationContributions = onValueWritten(
    "/station_contributions/{stationKey}/{contributionId}",
    async (event) => {
      const stationKey = event.params.stationKey;
      const database = getDatabase();
      const snapshot = await database.ref(`station_contributions/${stationKey}`)
          .orderByChild("tarih")
          .limitToLast(300)
          .get();

      if (!snapshot.exists()) {
        await database.ref(`station_insights/${stationKey}/alanlar`).remove();
        return;
      }

      const latestByUserAndField = new Map();
      Object.values(snapshot.val() || {}).forEach((contribution) => {
        const uid = String(contribution.uid || "");
        const values = contribution.degerler || {};
        Object.entries(values).forEach(([field, value]) => {
          const key = `${uid}:${field}`;
          const previous = latestByUserAndField.get(key);
          if (!previous || String(contribution.tarih).localeCompare(String(previous.date)) > 0) {
            latestByUserAndField.set(key, {
              uid,
              field,
              value: String(value).trim(),
              normalized: normalizeContributionValue(field, value),
              date: contribution.tarih,
            });
          }
        });
      });

      const byField = {};
      latestByUserAndField.forEach((item) => {
        byField[item.field] ||= {};
        byField[item.field][item.normalized] ||= {users: new Set(), values: [], dates: []};
        byField[item.field][item.normalized].users.add(item.uid);
        byField[item.field][item.normalized].values.push(item.value);
        byField[item.field][item.normalized].dates.push(item.date);
      });

      const fields = {};
      Object.entries(byField).forEach(([field, groups]) => {
        const winner = Object.values(groups).sort((left, right) => right.users.size - left.users.size)[0];
        const count = winner.users.size;
        fields[field] = {
          deger: winner.values[winner.values.length - 1],
          onay_sayisi: winner.values.length,
          bagimsiz_kullanici_sayisi: count,
          guven: Math.min(0.98, 0.38 + count * 0.2),
          dogrulandi: count >= 2,
          son_onay_zamani: winner.dates.sort().at(-1),
        };
      });

      await database.ref(`station_insights/${stationKey}`).update({
        alanlar: fields,
        guncelleme_tarihi: new Date().toISOString(),
      });
    },
);

exports.aggregateSearchDemand = onValueCreated(
    "/search_demand_events/{eventId}",
    async (event) => {
      const payload = event.data.val() || {};
      const createdAt = new Date(Number(payload.createdAtMilliseconds));
      if (Number.isNaN(createdAt.getTime())) return;

      const month = createdAt.toISOString().slice(0, 7);
      const cell = String(payload.coarseCell || "unknown").replace(/[.#$\[\]\/]/g, "_");
      const preference = String(payload.preference || "balanced");
      const radius = String(payload.radiusBucketKm || "unknown");
      const resultBucket = String(payload.resultBucket || "unknown");
      const database = getDatabase();
      const aggregateRef = database.ref(`demand_heatmap/${month}/${cell}`);

      await aggregateRef.transaction((current) => {
        const value = current || {};
        value.total = Number(value.total || 0) + 1;
        value.preferences ||= {};
        value.preferences[preference] = Number(value.preferences[preference] || 0) + 1;
        value.radius_buckets ||= {};
        value.radius_buckets[radius] = Number(value.radius_buckets[radius] || 0) + 1;
        value.result_buckets ||= {};
        value.result_buckets[resultBucket] = Number(value.result_buckets[resultBucket] || 0) + 1;
        value.updated_at = new Date().toISOString();
        return value;
      });

      await event.data.ref.remove();
    },
);

exports.deleteAccountData = onValueCreated(
    "/account_deletion_requests/{uid}",
    async (event) => {
      const uid = event.params.uid;
      const database = getDatabase();
      const commentsSnapshot = await database.ref("yorumlar").get();
      const removals = {};

      commentsSnapshot.forEach((stationSnapshot) => {
        stationSnapshot.forEach((reportSnapshot) => {
          if (reportSnapshot.child("uid").val() === uid) {
            removals[`yorumlar/${stationSnapshot.key}/${reportSnapshot.key}`] = null;
          }
        });
      });

      removals[`favoriler/${uid}`] = null;
      removals[`kullanici_yorum_meta/${uid}`] = null;
      removals[`kullanici_dogrulama_meta/${uid}`] = null;
      removals[`search_demand_meta/${uid}`] = null;
      const contributionsSnapshot = await database.ref("station_contributions").get();
      contributionsSnapshot.forEach((stationSnapshot) => {
        stationSnapshot.forEach((contributionSnapshot) => {
          if (contributionSnapshot.child("uid").val() === uid) {
            removals[`station_contributions/${stationSnapshot.key}/${contributionSnapshot.key}`] = null;
          }
        });
      });
      removals[`account_deletion_requests/${uid}`] = null;
      await database.ref().update(removals);

      try {
        await getAuth().deleteUser(uid);
      } catch (error) {
        if (error.code !== "auth/user-not-found") throw error;
      }
    },
);
