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
    .toLocaleLowerCase("tr-TR");

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

      await database.ref(`station_status/${stationKey}`).set({
        durum: state,
        etiket: latest.durum || "Belirsiz",
        toplam: reports.length,
        guncelleme_tarihi: new Date().toISOString(),
      });
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
      removals[`account_deletion_requests/${uid}`] = null;
      await database.ref().update(removals);

      try {
        await getAuth().deleteUser(uid);
      } catch (error) {
        if (error.code !== "auth/user-not-found") throw error;
      }
    },
);
