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
- [x] Varsayılan kapalı, cihaz içi takvim/HealthKit bağlam motoru ve öğrenilmiş otomasyon eşiği
- [x] APNs cihaz token'ı alma, anonim UID ile güvenli Firebase kaydı ve hesap silmede temizleme hattı
- [x] Takvim, HealthKit ve APNs kullanımının uygulama içi TR/EN gizlilik özetiyle belgelenmesi
- [x] Eksik/uyumsuz Firebase ve destek yapılandırmasında Archive işlemini durduran `Scripts/validate_release.py --production`
- [x] Mağaza metni taslağı, inceleme notları ve gerçek cihaz test protokolü

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

- [ ] Gerçek `GoogleService-Info.plist` ve `AppConfig.plist` üretim yapılandırmaları; iki dosyanın bundle/API/proje eşleşmesi
- [ ] Firebase rules/functions deploy ve App Check enforcement
- [ ] App Store Connect gizlilik cevaplarını `Docs/APP_STORE_PRIVACY_ANSWERS.md` ile birebir gir
- [ ] Destek URL'si, gizlilik URL'si ve anonim veri sıfırlama akışının Review Notes'a eklenmesi
- [ ] Distribution certificate/provisioning ve archive validation
- [ ] [Gerçek cihaz test planını](DEVICE_TEST_PLAN.md) dağıtılacak build ile tamamla
- [ ] App Store ekran görüntülerinin desteklenen cihaz boyutlarında yüklenmesi
- [ ] `group.com.ozdemirbaris.sarjbul` App Group'unu App ID ve provisioning profillerinde aç
- [ ] Widget, kilit ekranı, Dynamic Island ve Siri kısayolunu gerçek cihazda test et
- [ ] Open-Meteo ticari kullanım/attribution koşullarını yayın öncesi ürün modeliyle doğrula
- [ ] App Store gizlilik formunda açık rızalı kaba konum ve ürün etkileşimi analizini beyan et; operatör çıktılarında en az 10 örnek eşiğini uygula
- [ ] HealthKit kullanımının şarj/navigasyon ürünü içindeki sağlık/fitness amacını Apple kurallarıyla değerlendir; uygunluk netleşmeden yayın hazır sayma
- [ ] HealthKit yayın kapsamında tutulursa Apple Developer App ID capability'sini aç ve distribution provisioning profilini yenile
- [ ] App Store gizlilik formunda Open-Meteo hava durumu ve rakım hesabı için üçüncü tarafa gönderilen hassas konumu beyan et
- [ ] Gerçek cihazda EventKit sahiplik kontrolü, HealthKit izni ve otomatik takvim erteleme eşiğini doğrula
- [ ] APNs sağlayıcı anahtarını bildirim gönderen backend'e tanımla ve sandbox/production silent push teslimatını gerçek cihazda doğrula

Operatör API'si veya Apple CarPlay entitlement onayı gelmeden rezervasyon, ödeme, şarj kontrolü ve gömülü CarPlay hedefi release kapsamına alınmamalıdır.

CarPlay başvurusu ilk iPhone sürümünün ön koşulu değildir; uygulama mevcut sürümde Apple/Google Maps'e aktarım yapar.

Mağaza hazırlığı: [Metinler](APP_STORE_METADATA.md), [Review Notes](APP_REVIEW_NOTES.md), [Gizlilik formu](APP_STORE_PRIVACY_ANSWERS.md).
