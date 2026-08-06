const crypto = require("node:crypto");
const {defineSecret} = require("firebase-functions/params");
const {onRequest} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {getDatabase} = require("firebase-admin/database");
const {formatReply, parseCommand, searchStations} = require("./channel-core");

const STATION_DATA_URL = "https://raw.githubusercontent.com/ozdemirbariss-gif/elektriklisarj/main/stations.json";
const CACHE_LIFETIME_MS = 15 * 60 * 1000;
const MAX_REQUESTS_PER_MINUTE = 15;
const telegramBotToken = defineSecret("TELEGRAM_BOT_TOKEN");
const telegramWebhookSecret = defineSecret("TELEGRAM_WEBHOOK_SECRET");
const whatsAppAccessToken = defineSecret("WHATSAPP_ACCESS_TOKEN");
const whatsAppAppSecret = defineSecret("WHATSAPP_APP_SECRET");
const whatsAppVerifyToken = defineSecret("WHATSAPP_VERIFY_TOKEN");
const whatsAppPhoneNumberID = defineSecret("WHATSAPP_PHONE_NUMBER_ID");
const emailWebhookSecret = defineSecret("EMAIL_WEBHOOK_SECRET");
const resendAPIKey = defineSecret("RESEND_API_KEY");
const emailFrom = defineSecret("CHANNEL_EMAIL_FROM");
const browserExtensionKey = defineSecret("BROWSER_EXTENSION_KEY");

let stationCache = {stations: [], expiresAt: 0};

const safeEqual = (left, right) => {
  const first = Buffer.from(String(left || ""));
  const second = Buffer.from(String(right || ""));
  return first.length === second.length && crypto.timingSafeEqual(first, second);
};

const loadStations = async () => {
  if (stationCache.expiresAt > Date.now() && stationCache.stations.length) {
    return stationCache.stations;
  }
  const response = await fetch(STATION_DATA_URL, {
    headers: {Accept: "application/json", "User-Agent": "SarjBul-Channel-Gateway/1"},
  });
  if (!response.ok) throw new Error(`Station data returned ${response.status}`);
  const stations = await response.json();
  if (!Array.isArray(stations) || stations.length < 1000) throw new Error("Station data is incomplete");
  stationCache = {stations, expiresAt: Date.now() + CACHE_LIFETIME_MS};
  return stations;
};

const actorHash = (channel, actor) => crypto
    .createHash("sha256")
    .update(`${channel}:${actor}`)
    .digest("hex")
    .slice(0, 32);

const enforceRateLimit = async (channel, actor) => {
  const minute = Math.floor(Date.now() / 60000);
  const key = actorHash(channel, actor);
  const reference = getDatabase().ref(`channel_rate_limits/${minute}/${key}`);
  const result = await reference.transaction((value) => {
    const count = Number(value || 0);
    return count >= MAX_REQUESTS_PER_MINUTE ? undefined : count + 1;
  });
  return result.committed;
};

const claimEvent = async (channel, eventID) => {
  if (!eventID) return true;
  const key = actorHash(channel, eventID);
  const reference = getDatabase().ref(`channel_event_dedup/${key}`);
  const result = await reference.transaction((value) => value ? undefined : Date.now());
  return result.committed;
};

const executeCommand = async ({text, location, language}) => {
  const command = parseCommand({text: String(text || "").slice(0, 500), location, language});
  if (command.intent === "help" || !command.location) {
    return {command, results: [], reply: formatReply(command, [])};
  }
  const results = searchStations(await loadStations(), command);
  return {command, results, reply: formatReply(command, results)};
};

const locationFromTelegram = (message) => message.location ? {
  latitude: Number(message.location.latitude),
  longitude: Number(message.location.longitude),
} : null;

const telegramWebhook = onRequest({
  region: "europe-west1",
  secrets: [telegramBotToken, telegramWebhookSecret],
}, async (request, response) => {
  if (request.method !== "POST" || !safeEqual(
      request.get("X-Telegram-Bot-Api-Secret-Token"),
      telegramWebhookSecret.value(),
  )) {
    response.sendStatus(401);
    return;
  }
  const message = request.body?.message || request.body?.edited_message;
  if (!message?.chat?.id) {
    response.sendStatus(204);
    return;
  }
  if (!await enforceRateLimit("telegram", message.from?.id || message.chat.id)) {
    response.status(429).send("Too many requests");
    return;
  }
  if (!await claimEvent("telegram", request.body?.update_id)) {
    response.sendStatus(204);
    return;
  }
  const result = await executeCommand({
    text: message.text || message.caption || "",
    location: locationFromTelegram(message),
    language: message.from?.language_code?.startsWith("en") ? "en" : "tr",
  });
  const first = result.results[0];
  const replyMarkup = first ? {
    inline_keyboard: [[
      {text: result.command.language === "en" ? "Navigate" : "Rotayı aç", url: first.googleMapsURL},
      {text: "Apple Maps", url: first.appleMapsURL},
    ]],
  } : {
    keyboard: [[{
      text: result.command.language === "en" ? "Share my location" : "Konumumu paylaş",
      request_location: true,
    }]],
    resize_keyboard: true,
    one_time_keyboard: true,
  };
  const telegramResponse = await fetch(
      `https://api.telegram.org/bot${telegramBotToken.value()}/sendMessage`,
      {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({
          chat_id: message.chat.id,
          text: result.reply,
          disable_web_page_preview: true,
          reply_markup: replyMarkup,
        }),
      },
  );
  if (!telegramResponse.ok) throw new Error(`Telegram returned ${telegramResponse.status}`);
  response.sendStatus(204);
});

const verifyWhatsAppSignature = (request) => {
  const signature = request.get("X-Hub-Signature-256");
  if (!signature || !request.rawBody) return false;
  const expected = `sha256=${crypto.createHmac("sha256", whatsAppAppSecret.value())
      .update(request.rawBody)
      .digest("hex")}`;
  return safeEqual(signature, expected);
};

const whatsAppWebhook = onRequest({
  region: "europe-west1",
  secrets: [
    whatsAppAccessToken,
    whatsAppAppSecret,
    whatsAppVerifyToken,
    whatsAppPhoneNumberID,
  ],
}, async (request, response) => {
  if (request.method === "GET") {
    if (request.query["hub.mode"] === "subscribe" &&
        safeEqual(request.query["hub.verify_token"], whatsAppVerifyToken.value())) {
      response.status(200).send(request.query["hub.challenge"]);
    } else {
      response.sendStatus(403);
    }
    return;
  }
  if (request.method !== "POST" || !verifyWhatsAppSignature(request)) {
    response.sendStatus(401);
    return;
  }
  const value = request.body?.entry?.[0]?.changes?.[0]?.value;
  const message = value?.messages?.[0];
  if (!message) {
    response.sendStatus(204);
    return;
  }
  if (!await enforceRateLimit("whatsapp", message.from)) {
    response.status(429).send("Too many requests");
    return;
  }
  if (!await claimEvent("whatsapp", message.id)) {
    response.sendStatus(204);
    return;
  }
  const location = message.location ? {
    latitude: Number(message.location.latitude),
    longitude: Number(message.location.longitude),
  } : null;
  const result = await executeCommand({
    text: message.text?.body || "",
    location,
    language: "tr",
  });
  const graphVersion = process.env.WHATSAPP_GRAPH_VERSION || "v23.0";
  const whatsAppResponse = await fetch(
      `https://graph.facebook.com/${graphVersion}/${whatsAppPhoneNumberID.value()}/messages`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${whatsAppAccessToken.value()}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          messaging_product: "whatsapp",
          recipient_type: "individual",
          to: message.from,
          type: "text",
          text: {body: result.reply, preview_url: true},
        }),
      },
  );
  if (!whatsAppResponse.ok) throw new Error(`WhatsApp returned ${whatsAppResponse.status}`);
  response.sendStatus(204);
});

const bearerToken = (request) => String(request.get("Authorization") || "").replace(/^Bearer\s+/i, "");
const validEmail = (value) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value) && value.length <= 254;

const emailCommand = onRequest({
  region: "europe-west1",
  secrets: [emailWebhookSecret, resendAPIKey, emailFrom],
}, async (request, response) => {
  if (request.method !== "POST" || !safeEqual(bearerToken(request), emailWebhookSecret.value())) {
    response.sendStatus(401);
    return;
  }
  const sender = String(request.body?.from || "").trim().toLowerCase();
  if (!validEmail(sender)) {
    response.status(400).json({error: "valid_sender_required"});
    return;
  }
  const emailEventID = request.get("X-Webhook-ID") || request.body?.messageId;
  if (!await claimEvent("email", emailEventID)) {
    response.status(200).json({ok: true, duplicate: true});
    return;
  }
  if (!await enforceRateLimit("email", sender)) {
    response.status(429).json({error: "rate_limited"});
    return;
  }
  const result = await executeCommand({
    text: `${request.body?.subject || ""} ${request.body?.text || ""}`,
    location: request.body?.location,
    language: request.body?.language,
  });
  const resendResponse = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${resendAPIKey.value()}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: emailFrom.value(),
      to: [sender],
      subject: result.command.language === "en" ? "Your charging route is ready" : "Şarj rotan hazır",
      text: result.reply,
    }),
  });
  if (!resendResponse.ok) throw new Error(`Email provider returned ${resendResponse.status}`);
  response.status(200).json({ok: true, results: result.results});
});

const browserCommand = onRequest({
  region: "europe-west1",
  secrets: [browserExtensionKey],
}, async (request, response) => {
  const origin = request.get("Origin") || "*";
  const isExtensionOrigin = origin === "*" || /^(chrome|moz)-extension:\/\/[a-z0-9-]+$/i.test(origin);
  if (!isExtensionOrigin) {
    response.sendStatus(403);
    return;
  }
  response.set("Access-Control-Allow-Origin", origin);
  response.set("Vary", "Origin");
  response.set("Access-Control-Allow-Headers", "Content-Type, X-SarjBul-Channel-Key");
  response.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  if (request.method === "OPTIONS") {
    response.sendStatus(204);
    return;
  }
  if (request.method !== "POST" ||
      !safeEqual(request.get("X-SarjBul-Channel-Key"), browserExtensionKey.value())) {
    response.sendStatus(401);
    return;
  }
  const actor = request.get("X-Forwarded-For")?.split(",")[0] || request.ip || "browser";
  if (!await enforceRateLimit("browser", actor)) {
    response.status(429).json({error: "rate_limited"});
    return;
  }
  const result = await executeCommand(request.body || {});
  response.status(200).json(result);
});

const cleanupChannelRateLimits = onSchedule({
  region: "europe-west1",
  schedule: "every day 03:15",
  timeZone: "Europe/Istanbul",
}, async () => {
  const currentMinute = Math.floor(Date.now() / 60000);
  const snapshot = await getDatabase().ref("channel_rate_limits").get();
  const removals = {};
  snapshot.forEach((child) => {
    if (Number(child.key) < currentMinute - 120) removals[child.key] = null;
  });
  if (Object.keys(removals).length) {
    await getDatabase().ref("channel_rate_limits").update(removals);
  }
  const eventSnapshot = await getDatabase().ref("channel_event_dedup").get();
  const eventRemovals = {};
  eventSnapshot.forEach((child) => {
    if (Number(child.val()) < Date.now() - 24 * 60 * 60 * 1000) eventRemovals[child.key] = null;
  });
  if (Object.keys(eventRemovals).length) {
    await getDatabase().ref("channel_event_dedup").update(eventRemovals);
  }
});

module.exports = {
  browserCommand,
  cleanupChannelRateLimits,
  emailCommand,
  telegramWebhook,
  whatsAppWebhook,
};
