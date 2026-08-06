const endpoint = document.querySelector("#endpoint");
const channelKey = document.querySelector("#channelKey");
const status = document.querySelector("#status");

chrome.storage.sync.get(["endpoint", "channelKey"], (values) => {
  endpoint.value = values.endpoint || "";
  channelKey.value = values.channelKey || "";
});

document.querySelector("#save").addEventListener("click", async () => {
  const values = {endpoint: endpoint.value.trim(), channelKey: channelKey.value.trim()};
  if (!values.endpoint.startsWith("https://") || !values.channelKey) {
    status.textContent = "HTTPS endpoint ve kanal anahtarı gerekli.";
    return;
  }
  await chrome.storage.sync.set(values);
  status.textContent = "Bağlantı kaydedildi.";
});
