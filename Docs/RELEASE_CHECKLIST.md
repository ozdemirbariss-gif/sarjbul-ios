# App Store Release Kontrol Listesi

## Depoda doğrulananlar

- [x] App icon normal, dark ve tinted varyantları
- [x] Launch screen rengi ve Türkçe/İngilizce izin metni
- [x] Privacy manifest ve uygulama içi gizlilik/koşul/destek ekranları
- [x] Giriş/kayıt formu olmadan anonim oturum ve uygulama içi bulut verisi sıfırlama
- [x] App Attest tabanlı Firebase App Check entegrasyonu
- [x] Crashlytics; reklam analitiği yok
- [x] Auth token yenileme ve Keychain saklama
- [x] Offline cache ve veri kalite kapısı
- [x] Unit, UI smoke, backend lint ve bağımlılık audit CI adımları
- [x] Dynamic Type, Reduce Motion ve temel VoiceOver etiketleri
- [x] App Group tabanlı widget, Live Activity ve Dynamic Island hedefi
- [x] Uygulama ve widget App Group `UserDefaults` erişimi için `1C8F.1`; uygulamanın özel alanı için ek `CA92.1` beyanı
- [x] App Intent / Siri hızlı şarj kısayolu
- [x] Geohash tile manifesti ve checksum tabanlı delta güncelleme
- [x] Varsayılan kapalı anonim talep paylaşımı, kaba konum hücresi ve sunucu tarafı toplama
- [x] Hassas konum, kaba konum ve açık rızalı ürün etkileşimi beyanları Privacy Manifest ve gizlilik politikasıyla eşleştirildi
- [x] Varsayılan kapalı, cihaz içi takvim/hava durumu bağlam motoru ve öğrenilmiş otomasyon eşiği
- [x] APNs cihaz token'ı alma, anonim UID ile güvenli Firebase kaydı ve hesap silmede temizleme hattı
- [x] Takvim ve APNs kullanımının uygulama içi TR/EN gizlilik özetiyle belgelenmesi
- [x] Eksik/uyumsuz Firebase ve destek yapılandırmasında Archive işlemini durduran `Scripts/validate_release.py --production`
- [x] Mağaza metni taslağı, inceleme notları ve gerçek cihaz test protokolü
- [x] İlk sürüm/build `1.0 (1)`: ana uygulama ve widget'ın Debug/Release ayarları doğrulandı; [numaralandırma ve App Store Connect kayıt bilgileri](APP_STORE_CONNECT_SETUP.md) belgelendi (8 Ekim 2026).
- [x] App Store Connect'te ŞarjBul iOS kaydı oluşturuldu: Apple ID `6820571478`, sürüm `1.0`, durum `Prepare for Submission`; [kayıt bilgileri](APP_STORE_CONNECT_SETUP.md) doğrulandı (8 Ekim 2026).

## Son Doğrulanan Durum

7 Eylül 2026'da `de19e26` için [iOS CI](https://github.com/ozdemirbariss-gif/elektriklisarj-ios/actions/runs/34043948262) ve [istasyon verisi yenilemesi](https://github.com/ozdemirbariss-gif/elektriklisarj-ios/actions/runs/34106032136) başarılı olarak doğrulandı. Bu sonuç imzalı cihaz build'i, App Attest veya App Store onayı anlamına gelmez.

10 Eylül 2026'da iOS için ayrılmış `sarjbul-ios-f57e6` projesinin yapılandırma dosyaları bu çalışma kopyasına eklendi (Git dışında). Bundle ID `com.ozdemirbaris.sarjbul` ve API kimlikleri eşleştirildi. Realtime Database, Belçika (`europe-west1`) bölgesinde kilitli modda oluşturuldu; Anonymous sağlayıcısının etkin olduğu konsolda doğrulandı. Proje Spark planında; üretim kuralları ve Functions yayımlanmadı. Destek e-postası henüz seçilmedi.

Kaba konum ve ürün etkileşimi için geçici UID bağlantısı mağaza gizlilik formunda, manifestte ve TR/EN izin metninde açıkça beyan edildi.

`firebaseBackendReady` varsayılan olarak `false`: yalnızca plist dosyalarının bulunması uygulamada bulut işlemlerini açmaz. Bu alan canlı backend ve cihaz doğrulamaları tamamlanmadan değiştirilmez. Yerel kontrol:

11 Eylül hazırlığında 35 yerel Firebase testi (27 kural, 8 silme/analiz), 79 Swift çekirdek testi, 8 yayın kontrol testi, 4 kanal çekirdek testi ve iPhone 17 Pro / iOS 26.5 simülatöründe 53 iOS birim testi geçti. SwiftLint, üretim bağımlılık denetimi ve imzasız iOS Simulator Release derlemesi başarılı. İki gerçek plist Git dışında tutulur. Bunlar gerçek cihaz, imzalı Archive veya canlı Functions testi değildir. Önceki `04e519d` sürümünün [GitHub iOS CI çalışması](https://github.com/ozdemirbariss-gif/elektriklisarj-ios/actions/runs/34525419119) tüm adımlarıyla başarılıdır.

```bash
python3 Scripts/validate_release.py
python3 Scripts/validate_release.py --production
```

İlk komut depodaki manifest/yetki uyumunu denetler. İkincisi gerçek üretim dosyalarını, destek bilgilerini ve backend hazırlık onayını zorunlu tutar; eksikleri değerlerini yazdırmadan listeler. XcodeGen ile üretilen projenin Archive işlemi ikinci kontrolü otomatik çalıştırır. Normal Debug ve CI simülatör derlemeleri gerçek Firebase dosyaları gerektirmez.

## Backend Yayını Öncesindeki Açık İşler

- [ ] Cloud Functions için Blaze planı kararını hesap sahibiyle tamamla; ücretsiz hazırlık sırasında ücretli plana geçilmez.
- [x] Bulut sıfırlama sunucu onayını bekler; bekleyen işlem Keychain üzerinden sürdürülür ve eski UID yazımları engellenir.
- [x] `friction_events` için kullanıcı başına 60 saniye sunucu hız sınırı ve 7 gün sonra günlük temizlik uygulandı.
- [x] Arama talebi sayaçları ve 8 günlük tekilleştirme kaydı aynı transaction içinde güncellenir; eşzamanlı tekrar ve ham olay silme testleri eklendi.
- [ ] [Firebase kurulumundaki](FIREBASE_SETUP.md) yalnızca beş iOS işlevini ve eşleşen kuralları dağıt; kanal geçitlerini toplu Functions komutuna dahil etme.

Durum bildirimi, istasyon katkısı, arama talebi ve ürün etkileşimi kuralları artık gönderimle aynı atomik işlemde sunucu zamanı ve tam kayıt yolunu içeren hız sınırı verisini zorunlu tutar. İstemci bu veriyi silemez veya geriye alamaz. Eski istemcilerin yalnızca cihaz zamanı yazan istekleri bu kurallarla uyumlu değildir; istemci ve kurallar birlikte sürümlenir. Bulut hizmetleri, yukarıdaki açık işler kapanana kadar kapalı kalır.

## Hesap sahibi tarafından tamamlanacaklar

- [x] Gerçek `GoogleService-Info.plist` ve `AppConfig.plist` yerel olarak hazır; bundle/API/proje eşleşmesi doğrulandı (8 Ekim 2026). Backend/veri hakları gate’leri hâlâ kapalı.
- [x] Firebase Realtime Database kuralları dağıtıldı ve sunucudan geri okunarak karşılaştırıldı; App Attest sağlayıcısı kaydedildi (8 Ekim 2026).
- [ ] Beş iOS Cloud Function dağıtımı, canlı cihaz doğrulaması ve App Check enforcement; Blaze kararı bekleniyor.
- [ ] App Store Connect gizlilik cevaplarını `Docs/APP_STORE_PRIVACY_ANSWERS.md` ile birebir gir
- [x] Destek/gizlilik URL'leri ve anonim veri sıfırlama akışı Review Notes taslağına eklendi; App Review'a gönderim ayrı yayın adımıdır.
- [x] [İmzalama eşleştirmesine](SIGNING_SETUP.md) göre ücretli Developer Team, kalıcı yerel takım ayarı ve Apple Development/Apple Distribution sertifikaları (8 Ekim 2026).
- [x] İki App Store Connect dağıtım profili oluşturuldu, Xcode'a kuruldu; takım, sertifika, Bundle ID ve Release entitlement uyumu doğrulandı (8 Ekim 2026).
- [ ] İmzalı Archive/export doğrulaması: EPDK izin kaydı, ticari veri kullanım onayı ve Firebase backend hazırlığı üretim kontrolünü engelliyor. Fiziksel cihaz testi kullanıcı isteğiyle ertelendi.
- [ ] [Gerçek cihaz test planını](DEVICE_TEST_PLAN.md) dağıtılacak build ile tamamla
- [ ] App Store ekran görüntülerinin desteklenen cihaz boyutlarında yüklenmesi
- [x] `group.com.ozdemirbaris.sarjbul` App Group'unu iki App ID'ye ata (8 Ekim 2026).
- [x] App Group'un iki App Store Connect dağıtım profilinde bulunduğu doğrulandı (8 Ekim 2026).
- [ ] App Group ve diğer Release yetkilerini export edilen uygulama/widget imzalarında doğrula.
- [ ] Widget, kilit ekranı, Dynamic Island ve Siri kısayolunu gerçek cihazda test et
- [x] Open-Meteo ücretsiz Forecast/Elevation istemcilerini ticari sürümden kaldır (8 Ekim 2026).
- [ ] App Store gizlilik formunda açık rızalı kaba konum ve ürün etkileşimi analizini beyan et; operatör çıktılarında en az 10 örnek eşiğini uygula
- [ ] Güncel gizlilik cevap setini mağazaya gir: kaldırılan Open-Meteo akışı için Precise Location artık seçilmez.
- [ ] Gerçek cihazda EventKit sahiplik kontrolü ve otomatik takvim erteleme eşiğini doğrula
- [ ] APNs sağlayıcı anahtarını bildirim gönderen backend'e tanımla ve sandbox/production silent push teslimatını gerçek cihazda doğrula

Yetkili operatör entegrasyonu olmadan rezervasyon, ödeme ve şarj başlatma/durdurma yayın kapsamına alınmaz. Gömülü CarPlay arayüzü ise ayrı Apple entitlement onayı ve profil doğrulaması gerektirir.

9 Ekim 2026: CarPlay EV Charging onayı doğrulandı; ana App ID capability'si açıldı ve dağıtım profili yenilenip Xcode'a kuruldu. Projeye araç haritası/favoriler/istasyon bilgisi ve Apple Maps aktarımı eklendi. Araç bağlantı/kopma ve imzalı export doğrulaması ayrı yayın kontrolleridir. Ayrıntılar [CARPLAY_REQUEST.md](CARPLAY_REQUEST.md).

Mağaza hazırlığı: [Metinler](APP_STORE_METADATA.md), [Review Notes](APP_REVIEW_NOTES.md), [Gizlilik formu](APP_STORE_PRIVACY_ANSWERS.md).


## 11 Eylül 2026 — gizlilik ve destek incelemesi

- [x] Resmi destek e-postası `sarjbul@icloud.com` uygulama, örnek/yerel konfigürasyon ve destek belgesine eklendi.
- [x] [Gizlilik veri akışı karşılaştırması](PRIVACY_DATA_FLOW_AUDIT.md); manifest, form cevapları, politika ve TR/EN özetleri güncellendi.
- [x] Hata kaydında URL/konum/istasyon/serbest metin aktarımı kaldırıldı; gizlilik regresyon testleri eklendi.
- [x] Sağlayıcı atıfları ve lisans bağlantıları uygulamaya eklendi.
- [x] App Store Connect erişimi sağlandı; önceki `INVALIDITCUSER` engeli giderildi ve [ŞarjBul kaydı](APP_STORE_CONNECT_SETUP.md) oluşturuldu (8 Ekim 2026).
- [ ] [Gizlilik cevap setini](APP_STORE_PRIVACY_ANSWERS.md) kaydet/yayımla ve özetini doğrula.
- [ ] Ticari yayın: [sağlayıcı hakları ve sunum koşullarını](DATA_PROVIDER_TERMS.md) çöz. Open-Meteo kaldırıldı, MapKit kod karşılaştırması/düzeltmeleri tamamlandı. Güncel istasyon paketi yalnızca EPDK; ChargeIQ/OSM kaldırıldı. EPDK ticari kullanım, türev alan, çevrimdışı saklama ve yeniden dağıtım izni açık. Eski birleşik kopyaların hakları ayrı değerlendirilir.
- [ ] Kanıt dosyalarını/hash ve EPDK kapsamlarını `Data/provider-rights.json` içinde doğrula; kaynak saflığını `validate_data_rights.py --epdk-only` ile kontrol et. EPDK-only pakete ODbL lisansı verilmez. Gate geçince `commercialDataUseApproved=true` yap; tek başına bayrak yeterli değildir.
- [ ] Resmi destek posta kutusuna gerçek gönderim/yanıt testi. Bu görev kullanıcı adına e-posta göndermedi.

Bu maddeler mağaza yayını veya sağlayıcı sözleşmelerinin kabul edildiği anlamına gelmez. Önceki listelerdeki App Privacy ve destek için “hesap sahibi tarafından yapılacak” maddelerin güncel ayrıntısı bu bölümdür.

## 8 Ekim 2026 — ilk sürüm kapsamı

- [x] HealthKit veri okuma, nabız modeli/mola önerisi, ayar, telemetri işlemi, Debug/Release yetkileri ve TR/EN izin açıklamaları kaldırıldı.
- [x] Gizlilik politikası, App Privacy cevapları, Review Notes ve imzalama rehberi güncellendi.
- [x] Arama filtrelerini sessizce kaldıran fallback silindi; boş sonuçtan filtrelere erişim sağlandı.
- [x] Fiyatın kaynağı ve teyit tarihi/bilinmezliği gösterilir; katalog tarihi tarife doğrulaması sayılmaz.
- [x] Kart/detay aynı müsaitlik kuralını kullanır; eski, gelecekteki ve geçersiz sayımlı veri canlı gösterilmez.
- [x] CarPlay EV Charging başvurusu gönderildi, Apple alındı ekranı doğrulandı.
- [x] Apple CarPlay EV Charging onayı doğrulandı; capability ve yenilenmiş App Store profili eşleştirildi (9 Ekim 2026).
- [x] CarPlay sistem haritası, favoriler, AC/DC filtresi, kaynak/güncellik bilgisi ve Apple Maps aktarımı uygulandı.
- [ ] CarPlay Simulator/gerçek araç bağlantı-kopma, iPhone kapalı kullanım ve Maps aktarım testlerini dağıtılacak build üzerinde tamamla. 9 Ekim: Simulator ana ekranında simge doğrulandı; sistem uygulamaları dahil giriş yanıt vermediği için araç ekranı etkileşim testi açık. 95 uygulama/UI ve 7 tekrar CarPlay testi geçti; [doğrulama kaydı](CARPLAY_REQUEST.md#9-ekim-doğrulama-kaydı).
- [x] Ana uygulama/widget explicit App ID'leri ve ortak App Group doğru ücretli takımda oluşturuldu; grup iki App ID'ye atandı. Ana uygulamada Push Notifications ve App Attest açık, iki App ID'de HealthKit kapalı (8 Ekim 2026).
- [x] HealthKit içermeyen iki dağıtım profili oluşturuldu ve Release yetkileriyle karşılaştırıldı (8 Ekim 2026).
- [ ] Export imzalarını doğrula; geliştirme profilleri için cihaz kaydı ve cihaz testi daha sonra yapılacak.

Kod teslimi App Store yayını, operatör sözleşmesi veya üretim backend dağıtımı değildir. CarPlay onayı 9 Ekim'de ayrıca portalda doğrulanmıştır.
