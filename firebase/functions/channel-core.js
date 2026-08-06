const DEFAULT_LANGUAGE = "tr";

const fold = (value) => String(value || "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLocaleLowerCase("tr-TR")
    .replace(/ı/g, "i");

const numberFrom = (value) => {
  const match = String(value || "").match(/\d+(?:[.,]\d+)?/);
  return match ? Number(match[0].replace(",", ".")) : null;
};

const parseCoordinates = (text) => {
  const match = String(text || "").match(
      /(-?\d{1,2}(?:[.,]\d+)?)\s*[,;\s]\s*(-?\d{1,3}(?:[.,]\d+)?)/,
  );
  if (!match) return null;
  const latitude = Number(match[1].replace(",", "."));
  const longitude = Number(match[2].replace(",", "."));
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude) ||
      latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    return null;
  }
  return {latitude, longitude};
};

const parseCommand = ({text = "", location, language = DEFAULT_LANGUAGE}) => {
  const normalized = fold(text);
  let preference = "balanced";
  if (["hizli", "fast", "dc"].some((word) => normalized.includes(word))) {
    preference = "fastest";
  } else if (["ekonomik", "ucuz", "cheap", "economic"].some((word) => normalized.includes(word))) {
    preference = "economical";
  } else if (["yakin", "nearest", "near"].some((word) => normalized.includes(word))) {
    preference = "nearest";
  }

  const coordinates = validLocation(location) ? location : parseCoordinates(text);
  return {
    intent: normalized.includes("yardim") || normalized.includes("help") ? "help" : "find_station",
    preference,
    location: coordinates,
    language: language === "en" ? "en" : "tr",
  };
};

const validLocation = (location) => location &&
  Number.isFinite(Number(location.latitude)) &&
  Number.isFinite(Number(location.longitude)) &&
  Number(location.latitude) >= -90 && Number(location.latitude) <= 90 &&
  Number(location.longitude) >= -180 && Number(location.longitude) <= 180;

const radians = (degrees) => degrees * Math.PI / 180;

const distanceKm = (origin, station) => {
  const latitude = Number(station.enlem);
  const longitude = Number(station.boylam);
  const deltaLatitude = radians(latitude - origin.latitude);
  const deltaLongitude = radians(longitude - origin.longitude);
  const first = radians(origin.latitude);
  const second = radians(latitude);
  const value = Math.sin(deltaLatitude / 2) ** 2 +
    Math.cos(first) * Math.cos(second) * Math.sin(deltaLongitude / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(value), Math.sqrt(1 - value));
};

const powerKW = (station) => {
  const parsed = numberFrom(station.hiz);
  if (parsed !== null) return parsed;
  const normalized = fold(station.hiz);
  if (normalized.includes("ac")) return normalized.includes("standart") ? 22 : 11;
  return 0;
};

const priceValue = (station) => {
  const parsed = numberFrom(station.fiyat);
  return parsed === null ? Number.POSITIVE_INFINITY : parsed;
};

const compareCandidates = (left, right, preference) => {
  if (preference === "fastest") {
    return right.powerKW - left.powerKW || left.distanceKm - right.distanceKm;
  }
  if (preference === "economical") {
    return left.priceValue - right.priceValue || left.distanceKm - right.distanceKm;
  }
  if (preference === "nearest") return left.distanceKm - right.distanceKm;
  const leftScore = left.distanceKm - Math.min(left.powerKW, 180) * 0.08;
  const rightScore = right.distanceKm - Math.min(right.powerKW, 180) * 0.08;
  return leftScore - rightScore;
};

const searchStations = (stations, command, limit = 3) => {
  if (!command.location) return [];
  const origin = {
    latitude: Number(command.location.latitude),
    longitude: Number(command.location.longitude),
  };
  const latitudeDelta = 1.1;
  const longitudeDelta = 1.1 / Math.max(Math.cos(radians(origin.latitude)), 0.2);

  return stations
      .filter((station) => Number.isFinite(Number(station.enlem)) && Number.isFinite(Number(station.boylam)))
      .filter((station) => Math.abs(Number(station.enlem) - origin.latitude) <= latitudeDelta &&
        Math.abs(Number(station.boylam) - origin.longitude) <= longitudeDelta)
      .map((station) => ({
        station,
        distanceKm: distanceKm(origin, station),
        powerKW: powerKW(station),
        priceValue: priceValue(station),
      }))
      .filter((candidate) => candidate.distanceKm <= 120)
      .sort((left, right) => compareCandidates(left, right, command.preference))
      .slice(0, limit)
      .map(({station, distanceKm: distance, powerKW: power}) => ({
        id: station.id,
        name: station.isim || "Şarj istasyonu",
        operator: station.operator || "Bilinmiyor",
        address: station.adres || "Adres bilgisi yok",
        latitude: Number(station.enlem),
        longitude: Number(station.boylam),
        distanceKm: Number(distance.toFixed(1)),
        powerKW: power,
        power: station.hiz || "Bilinmiyor",
        price: station.fiyat || "Bilinmiyor",
        socket: station.soket || "Bilinmiyor",
        googleMapsURL: `https://www.google.com/maps/dir/?api=1&destination=${station.enlem},${station.boylam}`,
        appleMapsURL: `https://maps.apple.com/?daddr=${station.enlem},${station.boylam}&dirflg=d`,
        appURL: `sarjbul://station/${encodeURIComponent(station.id)}`,
      }));
};

const formatReply = (command, results) => {
  const english = command.language === "en";
  if (command.intent === "help") {
    return english ?
      "Share your location and write nearest, fast or economical." :
      "Konumunu paylaş ve yakın, hızlı veya ekonomik yaz.";
  }
  if (!command.location) {
    return english ?
      "I need your location. Share it or send coordinates such as 38.4237, 27.1428." :
      "Konumuna ihtiyacım var. Konumunu paylaş veya 38.4237, 27.1428 gibi koordinat gönder.";
  }
  if (!results.length) {
    return english ? "I could not find a charging station within 120 km." :
      "120 km içinde uygun bir şarj istasyonu bulamadım.";
  }
  const heading = english ? "Best charging options" : "En uygun şarj seçenekleri";
  const rows = results.map((result, index) => {
    const power = result.powerKW > 0 ? `${result.powerKW} kW` : result.power;
    return `${index + 1}. ${result.name}\n` +
      `${result.distanceKm} km · ${power} · ${result.price}\n` +
      `${result.googleMapsURL}`;
  });
  return `${heading}\n\n${rows.join("\n\n")}`;
};

module.exports = {
  formatReply,
  parseCommand,
  parseCoordinates,
  searchStations,
};
