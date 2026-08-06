let preference = "nearest";
const findButton = document.querySelector("#find");
const status = document.querySelector("#status");
const results = document.querySelector("#results");

document.querySelectorAll(".preference").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelectorAll(".preference").forEach((item) => item.classList.remove("active"));
    button.classList.add("active");
    preference = button.dataset.preference;
  });
});

document.querySelector("#settings").addEventListener("click", () => chrome.runtime.openOptionsPage());

const currentPosition = () => new Promise((resolve, reject) => navigator.geolocation.getCurrentPosition(
    resolve,
    reject,
    {enableHighAccuracy: false, timeout: 8000, maximumAge: 60000},
));

const escapeHTML = (value) => String(value || "").replace(/[&<>'"]/g, (character) => ({
  "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", "\"": "&quot;",
})[character]);

const render = (stations) => {
  results.replaceChildren();
  stations.forEach((station) => {
    const article = document.createElement("article");
    article.className = "station";
    article.innerHTML = `<h2>${escapeHTML(station.name)}</h2>` +
      `<p>${station.distanceKm} km · ${escapeHTML(station.power)} · ${escapeHTML(station.price)}</p>` +
      `<a href="${encodeURI(station.googleMapsURL)}" target="_blank" rel="noreferrer">Rotayı aç →</a>`;
    results.append(article);
  });
};

findButton.addEventListener("click", async () => {
  findButton.disabled = true;
  results.replaceChildren();
  status.textContent = "Konum alınıyor…";
  try {
    const config = await chrome.storage.sync.get(["endpoint", "channelKey"]);
    if (!config.endpoint || !config.channelKey) {
      status.textContent = "Önce bağlantı ayarlarını tamamla.";
      chrome.runtime.openOptionsPage();
      return;
    }
    const position = await currentPosition();
    status.textContent = "İstasyonlar değerlendiriliyor…";
    const response = await fetch(config.endpoint, {
      method: "POST",
      headers: {"Content-Type": "application/json", "X-SarjBul-Channel-Key": config.channelKey},
      body: JSON.stringify({
        text: preference,
        location: {
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
        },
        language: "tr",
      }),
    });
    if (!response.ok) throw new Error(`Gateway ${response.status}`);
    const payload = await response.json();
    status.textContent = payload.results.length ? "Rotan hazır." : payload.reply;
    render(payload.results);
  } catch (error) {
    status.textContent = error.code === 1 ? "Konum izni olmadan arama yapılamıyor." : "Şu an rota hazırlanamadı.";
  } finally {
    findButton.disabled = false;
  }
});
