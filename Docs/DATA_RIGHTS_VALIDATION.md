# Veri hakları değişikliği doğrulaması

8 Ekim 2026. Bu kayıt teknik doğrulamadır; sağlayıcı izni veya mağaza yayını değildir. Kullanıcı ChargeIQ/EPDK yazılı izni bulunmadığını teyit etti.

- Python: `python3 -m unittest discover -s Scripts/tests -q` — **37 test başarılı**. Kaynak/türev kaynak, bilinmeyen kaynak, kanıt/hash/süre/kapsam, ODbL tam veri teklifi, lisanslı builder ve plist bayrağıyla engel aşma regresyonları dahil.
- Çekirdek: `swift test --scratch-path /tmp/sarjbul-data-rights-core` — **84 test başarılı**.
- iOS: iPhone 17 Pro / iOS 26.5 simülatöründe **65 test başarılı, 0 başarısız, 0 atlanan**. `SarjBulUnitTests` ve `AppSmokeUITests/testStationStoryImageOpensShareSheet`. Eski adres/belirsiz başlangıç temizliği, Apple kökenli konumun kalıcı kayda girmemesi, Google'a Apple başlangıcı aktarılmaması ve eski hava/bağlam tercihlerinin kapatılması dahil.
- `xcodebuild build-for-testing`, `swiftlint --strict`, plist lint ve `git diff --check` başarılı. Bu yerel derlemede çözümlenen Firebase sürümü 12.19.2; önceki gizlilik incelemesindeki 12.16.0 bir sürüm sabitlemesi değildir. Üretim binary'sinin SDK manifestleri yayın kontrolünde yeniden karşılaştırılmalıdır.
- Testin ürettiği 1080×1920 mantıksal boyutlu paylaşım görseli açılıp incelendi: native Apple haritasının alt bildirimi görünür; OSM atfı ve telif URL'si görselde okunur. Adres aramasının canlı servis sonucu/pin eşleşmesi ve gerçek cihaz arka plan yaşam döngüsü için [cihaz planı](DEVICE_TEST_PLAN.md) korunur.
- `validate_release.py` kaynak kontrolü başarılı. Sağlayıcı gate'i **beklendiği gibi başarısız**: `chargeiq=pending_permission`, `epdk=pending_permission`, `osm=pending_compatibility`. Bu engeller kaldırılmadı; `commercialDataUseApproved` örnek yapılandırmada false kalır.
- Bu çalışma alanında üretim `AppConfig.plist` ve `GoogleService-Info.plist` yoktur; `--production` bu eksikleri de bildirir. Backend deploy veya App Store binary yayını yapılmadı.

İstasyon kayıtları ve işletmeci snapshot'ı bu görevde değiştirilmedi. Lisanslı builder'ın başarılı yolu yalnızca açıkça test olarak etiketlenen geçici fixture izinleriyle sınandı; gerçek veriye/sözleşmeye izin verilmiş sayılmaz. İzinler gelene kadar günlük veri workflow'u yeni kaynak çekip yayımlamaz.
