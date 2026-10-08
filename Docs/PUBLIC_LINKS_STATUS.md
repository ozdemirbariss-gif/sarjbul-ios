# Kamuya açık bağlantılar — 8 Ekim 2026

| Alan | Üretim adresi |
| --- | --- |
| Gizlilik politikası | https://sarjbul-destek.ozdemirbariss.chatgpt.site/privacy/ |
| Kullanım koşulları | https://sarjbul-destek.ozdemirbariss.chatgpt.site/terms/ |
| Destek / Privacy Choices | https://sarjbul-destek.ozdemirbariss.chatgpt.site/support/ |
| İstasyon manifesti | https://raw.githubusercontent.com/ozdemirbariss-gif/sarjbul-ios/main/SarjBul/Resources/StationTiles/station-tiles-manifest.json |
| Destek e-postası | sarjbul@icloud.com |

## Yayın

Belgeler herkese açık ChatGPT Sites üzerinde yayımlandı. Site kimliği
`appgprj_6ac77a7518bc81918b466a277e2814c1`; kaynak commit'i
`b47f3793144d99ac80a503a4974c5f7ff356b184`, kaydedilmiş sürüm
`appgprj_6ac77a7518bc81918b466a277e2814c1~appgver_9693b772559481919e7b8e234965cb32`.
Üretim dağıtımı `appgdep_6ac77b83c83881919d19600b54fc6b32`, sonucu `succeeded`.
Erişim politikası `public`; ziyaretçinin hesap açması gerekmez.

Kaynak belgeler `Docs/PRIVACY_POLICY.md`, `Docs/TERMS_OF_USE.md` ve `Docs/SUPPORT.md`.
`python3 Scripts/build_public_pages.py --output <site-checkout>/dist` bu üç belgeden
statik HTML üretir. Sites kaynak kopyası çalışma alanındaki `sarjbul-public-site`
dizinindedir; kendi Git deposu ve `.openai/hosting.json` kimliği korunmalıdır.
Sonraki güncellemelerde belgeler ve üretim betiği bu kaynak kopyasına eşitlenip
Sites becerisinin kaynak eşitleme, paketleme ve dağıtım akışı çalıştırılmalıdır.
Sadece iOS deposuna push yapmak web sitesini güncellemez.

Manifest ve 61 veri döşemesi mevcut kamuya açık `sarjbul-ios` deposundan sunulur.
Manifestteki `base_url` ve veri yenileme workflow'u aynı HTTPS veri dizinini kullanır.
Bu görev veri içeriğini veya sağlayıcı izin kapısını değiştirmedi.

## Doğrulama

- Üç belge çerez, Authorization başlığı veya kullanıcı oturumu olmadan HTTPS 200 döndü.
- Safari **Özel Dolaşma** penceresinde gizlilik, koşullar ve destek sayfaları açıldı;
  giriş ekranı olmadan belge içeriği, iletişim adresi ve belge gezinmesi görüldü.
- Mobil genişlikte destek sayfasının düzeni ve e-posta bağlantısı kontrol edildi.
- Manifest ve tüm 61 döşeme oturumsuz indirildi. SHA-256 değerleri, döşeme kayıt
  sayıları ve toplam **13.129** kayıt eşleşti; kaynak politikası `epdk-only-v1`.
- Örnek plist ile uygulamanın varsayılan URL/e-posta alanları eşleşiyor.
- iPhone 17 Pro / iOS 26.5 Simulator: mevcut 5 `AppConfigurationTests` testi geçti.
- 10 yayın doğrulama testi, 2 Edge testi, plist ve `git diff --check` kontrolleri geçti.

## Uygulama ve mağaza teslimi

Uygulamanın varsayılan bağlantıları, `AppConfig.sample.plist`, App Store metinleri,
App Privacy cevapları ve App Review notları bu adreslere güncellendi.
Bu çalışma kopyasında gerçek `AppConfig.plist` yoktur; oluşturulurken örnekteki
adresler kullanılmalıdır. Edge manifest/döşeme origin ayarlarındaki eski depo adı
da düzeltildi. Varsayılan uygulama akışı doğrudan doğrulanmış veri adresini kullanır;
bu görev Cloudflare Edge Worker'ı dağıtmadı.

App Store Connect'e metin veya binary gönderilmedi. Veri sağlayıcı izinleri,
üretim Firebase kurulumu ve imzalı cihaz yayını için mevcut kapılar geçerlidir.

## GitHub kontrolündeki mevcut bağımlılık engeli

İlk PR kontrolünde üretim bağımlılık denetimi, önceki `main` kontrolünde de bulunan
5 güvenlik bulgusu nedeniyle başarısız oldu. Ana Firebase paket sürüm aralıkları
korunarak `@fastify/busboy` 3.2.2, `@grpc/grpc-js` 1.14.5, `brace-expansion` 5.0.12
ve `proxy-addr` 2.0.8 düzeltmeleri kilit dosyasına işlendi.
`brace-expansion` override değeri 5.0.12 oldu; `minimatch` bulgusu da bu geçişli
bağımlılık düzeltmesiyle kapandı. Yerel sözdizimi ve 6 backend çekirdek testi geçti;
`npm audit --omit=dev --audit-level=moderate` sıfır güvenlik bulgusu döndürdü.
Bu değişiklik Functions dağıtımı yapmaz.
