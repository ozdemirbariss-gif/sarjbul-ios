# Uygulama Dışı Komut Kanalları

SarjBul'un kanal katmanı aynı komut çekirdeğini Telegram, WhatsApp, e-posta ve browser uzantısından çağırır. Kullanıcı konumunu paylaşarak `yakın`, `hızlı` veya `ekonomik` niyetini belirtir; yanıt en iyi üç istasyonu ve tek dokunuşla navigasyon bağlantısını içerir. iOS uygulamasının açılması gerekmez.

## Mimari

```text
Telegram ─┐
WhatsApp ─┼─> doğrulama + hız sınırı ─> channel-core ─> stations.json ─> navigasyon yanıtı
E-posta ──┤
Browser ──┘
```

- `channel-core.js` komut ayrıştırma, bounding-box ön filtreleme, haversine mesafe ve tercih sıralamasını tek yerde tutar.
- Webhook adaptörleri sağlayıcı imzalarını doğrular, tekrar gönderilen event kimliklerini eler ve yalnızca normalize komutu çekirdeğe iletir.
- Kesin konum, mesaj veya e-posta adresi veritabanına yazılmaz. Hız sınırı anahtarları SHA-256 ile tek yönlü özetlenir, dakika kovalarında tutulur ve zamanlanmış görevle temizlenir.
- Gateway rezervasyon, ödeme veya şarj başlatma iddiasında bulunmaz; bunlar yetkili operatör API'si gerektirir.

## Firebase secret'ları

Gereken kanalların secret'larını tanımlayıp yalnızca ilgili function'ları dağıt:

```bash
firebase functions:secrets:set TELEGRAM_BOT_TOKEN
firebase functions:secrets:set TELEGRAM_WEBHOOK_SECRET
firebase functions:secrets:set WHATSAPP_ACCESS_TOKEN
firebase functions:secrets:set WHATSAPP_APP_SECRET
firebase functions:secrets:set WHATSAPP_VERIFY_TOKEN
firebase functions:secrets:set WHATSAPP_PHONE_NUMBER_ID
firebase functions:secrets:set EMAIL_WEBHOOK_SECRET
firebase functions:secrets:set RESEND_API_KEY
firebase functions:secrets:set CHANNEL_EMAIL_FROM
firebase functions:secrets:set BROWSER_EXTENSION_KEY
firebase deploy --only functions
```

## Telegram

BotFather ile bot oluşturduktan sonra webhook'u Firebase URL'sine bağla. `secret_token`, `TELEGRAM_WEBHOOK_SECRET` ile aynı olmalıdır:

```bash
curl -X POST "https://api.telegram.org/bot<BOT_TOKEN>/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://europe-west1-<PROJECT>.cloudfunctions.net/telegramWebhook","secret_token":"<WEBHOOK_SECRET>","allowed_updates":["message"]}'
```

Kullanıcı `Konumumu paylaş` butonuyla tek dokunuşta konum gönderir; dengeli sonuç hemen döner. Belirli tercih için koordinatla birlikte `hızlı`, `yakın` veya `ekonomik` yazabilir. Yanıtta Google Maps ve Apple Maps butonları görünür.

## WhatsApp Cloud API

Meta uygulamasında callback URL olarak `whatsAppWebhook` URL'sini, verify token olarak `WHATSAPP_VERIFY_TOKEN` değerini tanımla. Webhook `messages` olayına abone olmalıdır. POST istekleri `X-Hub-Signature-256` ile doğrulanır; Graph API sürümü gerektiğinde `WHATSAPP_GRAPH_VERSION` ortam değişkeniyle değiştirilebilir.

## E-posta

Inbound sağlayıcının parse ettiği mesajı `emailCommand` adresine JSON POST et:

```json
{
  "from": "driver@example.com",
  "subject": "Hızlı şarj",
  "text": "38.4237, 27.1428",
  "language": "tr"
}
```

İstek `Authorization: Bearer <EMAIL_WEBHOOK_SECRET>` taşımalıdır. Yanıt Resend üzerinden `CHANNEL_EMAIL_FROM` adresinden gönderilir.

## Browser uzantısı

`Integrations/browser-extension` klasörü Manifest V3 uzantısıdır. Kurulumdan sonra seçenekler sayfasına `browserCommand` URL'si ile kanal anahtarı girilir. Browser anahtarı dağıtılan istemciden çıkarılabilir; bu nedenle yalnızca düşük riskli, salt okunur istasyon aramasına erişir ve sunucu tarafında hız sınırı vardır.

## Operasyon notları

- Telegram webhook doğrulaması resmi `X-Telegram-Bot-Api-Secret-Token` başlığını kullanır.
- WhatsApp erişim tokenını ve uygulama secret'ını istemciye koyma.
- Production'da function log alert'i ve bütçe alarmı açılmalıdır; `cleanupChannelRateLimits` eski hız sınırı kovalarını her gün temizler.
- Kanal yanıtları genel istasyon verisidir; favoriler veya kişisel geçmiş kullanıcı hesabı eşleştirmesi olmadan dış kanallara açılmaz.
