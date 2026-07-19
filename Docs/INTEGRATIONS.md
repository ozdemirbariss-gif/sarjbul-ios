# Harici Entegrasyonlar

## Uygulama içinde tamamlananlar

- MapKit rota, trafik, adres arama ve Apple Maps aktarımı
- Google Maps HTTPS rota aktarımı
- Firebase Auth/Realtime Database, token yenileme, App Check ve Crashlytics
- Uzaktan istasyon verisi, ETag cache ve offline fallback
- Yerel şarj hatırlatıcısı

## Yetkili sağlayıcı gerektirenler

Canlı soket uygunluğu, rezervasyon, QR ile şarj başlatma/durdurma, ücret tahsilatı, fatura ve şarj oturumu geçmişi yalnızca istasyon operatörünün sözleşmeli API'siyle güvenilir biçimde sunulabilir. Şu anki açık veri kümesi bu işlemler için yetki veya gerçek zaman garantisi vermez. Uygulama bu nedenle çalışmayan kontroller göstermez.

CarPlay navigasyon uygulaması yetkisi Apple tarafından ayrı değerlendirilir. Entitlement onaylanmadan CarPlay hedefi eklemek derlenen fakat dağıtılamayan bir özellik oluşturacağından ana hedefe dahil edilmez. Mevcut uygulama rotayı CarPlay destekli Apple Maps'e aktarır.

Bir operatör entegrasyonu geldiğinde istemcinin doğrudan operatör anahtarı taşımaması gerekir. Yetki, fiyat ve ödeme işlemleri server-to-server backend üzerinden yürütülmeli; iOS yalnızca kısa ömürlü oturum ve işlem sonucunu almalıdır.
