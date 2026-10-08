# İlk sürüm teslimi — 8 Ekim 2026

## Uygulama kapsamı

- İstasyon araması seçilen soket, güç, operatör, metin ve menzil koşullarını korur. Boş sonuç, ana ekranda açıklanır ve filtreler sonuç listesi boşken de açılır. Panelde istasyon adı/adres/operatör araması, seçili operatörü kaldırma ve açık Sıfırla/Uygula adımları bulunur.
- İstasyon paketi doğrudan EPDK yanıtından yeniden üretildi: 13.129 halka açık kayıt, 61 tile. ChargeIQ/OSM ve özel kaynak deposu bağımlılıkları kaldırıldı; EPDK izni bekleniyor. [Geçiş kaydı](EPDK_ONLY_MIGRATION.md), [güncel doğrulama](DATA_RIGHTS_VALIDATION.md).
- İstemcinin katalog ve destek bağlantıları güncel `sarjbul-ios` deposuna taşındı; özel canonical veri deposu uygulamanın varsayılan HTTP kaynağı olmaktan çıkarıldı. Veri yenileme workflow ve manifest base URL'si aynı depoyla eşleşir.
- Apple Maps / Google Maps aktarımı ve navigasyon uygulaması tercihini hatırlama korunur. Manuel başlangıç konumu haritalara aktarılır; cihaz konumu seçiliyse canlı konum kullanılır.
- Ana öneri, istasyon kartı ve detay aynı fiyat/müsaitlik açıklamasını kullanır. Katalog gözlem tarihi tarife teyit tarihi değildir; fiyat tarihi bilinmiyorsa açıkça bilinmiyor gösterilir.
- Operatör akışı en fazla 15 dakikalık ve geçerli soket sayımlıysa güncel sayılır. Gelecek tarihli veya eski veri canlı sunulmaz. Topluluk tahmini ve risk bildirimi kaynak/güncellik sınırıyla açıklanır.
- Yetkili entegrasyon bulunmayan rezervasyon, ödeme veya uzaktan şarj kontrolü eklenmedi. Manuel “Şarja başladım” yalnızca 30 dakikalık yerel hatırlatıcı kurar. Widget/Live Activity süresi ölçülen şarj seviyesi değildir.
- HealthKit import/client, nabız girdileri ve mola kuralı, ayarı, hata işlemi, Debug/Release capability ve TR/EN izin metinleri kaldırıldı. Eski ayarlar yeniden yazılarak kaldırılan alan temizlenir; eski mola kayıtları takvim geçmişini silmeden elenir. Gizlilik ve Review Notes metinleri güncellendi.

## CarPlay

EV Charging başvurusu Apple tarafından alındı. Hesap sahibi bağlayıcı sözleşmeyi kendisi kabul etti; ardından Apple alındı ekranı doğrulandı. Onay bekleniyor. Başvuru alındı mesajı, CarPlay entitlement veya App Store onayı değildir. Ayrıntılar ve Apple ek bilgi isterse kullanılacak açıklama: [CARPLAY_REQUEST.md](CARPLAY_REQUEST.md).

## Yayın için kalanlar ve yapmanız gerekenler

1. **CarPlay:** Apple Developer hesabınıza bağlı e-postadaki yanıtı kontrol edin. Apple ek bilgi isterse başvuru belgesindeki açıklamayı kullanın. Yetki onayından sonra App ID/profiller ve CarPlay arayüzü eklenip araçta test edilmelidir. Apple'ın kararını bu çalışma içinde veremeyiz.
2. **İmzalama:** Portalda ücretli takım doğrulandı ve yerel takım dosyası ayarlandı; App IDs listesi boş. Xcode > Settings > Apple Accounts'a aynı hesabı ekleyin. Ana uygulama/widget App ID ve ortak App Group'u oluşturup profilleri üretin; HealthKit eklemeyin. [SIGNING_SETUP.md](SIGNING_SETUP.md).
3. **Üretim yapılandırması:** Bu çalışma kopyasında gerçek `SarjBul/Resources/AppConfig.plist` ve `GoogleService-Info.plist` yok. Doğru iOS Firebase projesinden dosyaları sağlayın. Örnek dosya veya uydurma değerle Archive kontrolü geçirilmedi. Bu dosyalar Git'e yüklenmemelidir.
4. **Backend:** Doğru üretim projesi, gerekli Functions dağıtımı ve yetki doğrulamaları tamamlanmadan `firebaseBackendReady=true` yapmayın. Bu görev backend dağıtımı yapmadı. Ücretli plan kararı gerekiyorsa hesap sahibi vermelidir. [FIREBASE_SETUP.md](FIREBASE_SETUP.md).
5. **Veri hakları:** EPDK’nin istasyon ve işletmeci lisans verileri için ticari kullanım, çevrimdışı saklama, türev alan ve yeniden dağıtım koşullarını çözün; doğrulanmadan `commercialDataUseApproved=true` yapmayın. [DATA_PROVIDER_TERMS.md](DATA_PROVIDER_TERMS.md).
6. **Mağaza:** İmzalı gerçek cihaz ve TestFlight testleri, son ekran görüntüleri, App Privacy formu ve App Review gönderimi tamamlanmalı. Bu çalışma App Store'a uygulama yüklemedi/yayımlamadı. [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md).

## İlk teslimin yerel doğrulaması

Aşağıdaki sayılar ilk teslim kaydıdır; sonraki EPDK-only değişikliğinin testleri [güncel doğrulama belgesindedir](DATA_RIGHTS_VALIDATION.md).

- Swift çekirdek testleri: 84 test / 15 suite geçti.
- Python veri ve yayın doğrulama testleri: 22 test geçti.
- iPhone 17 Pro / iOS 26.5 Simulator: 82 uygulama ve arayüz senaryosu doğrulandı. Tam koşuda 81 test geçti; kalan filtre testi, fixture'daki istasyon adı düzeltilip yeniden derlenerek ayrı koşuda geçti.
- Debug uygulama/widget ve Release Simulator derlemeleri başarılı. Release binary'sinde HealthKit framework bağlantısı yok. Bunlar imzalı cihaz Archive kontrolü değildir.
- SwiftLint: 138 dosyada sıfır ihlal. Depo gizlilik/yetki doğrulaması ve `git diff --check` başarılı.

`python3 Scripts/validate_release.py --production` şu anda `AppConfig.plist` ve `GoogleService-Info.plist` eksik olduğu ve EPDK izni belgelenmediği için başarısızdır; yayın engeli korunmuştur. GitHub teslim commit'i görev sonucunda belirtilir. GitHub'a push, backend dağıtımı veya App Store yayını anlamına gelmez.
