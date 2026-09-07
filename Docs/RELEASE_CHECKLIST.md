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

Bu çalışma kopyasında `AppConfig.plist` ve `GoogleService-Info.plist` henüz yok. Yerel kontrol:

```bash
python3 Scripts/validate_release.py
python3 Scripts/validate_release.py --production
```

İlk komut depodaki manifest/yetki uyumunu denetler. İkincisi gerçek üretim dosyalarını zorunlu tutar ve eksik bilgileri değerlerini yazdırmadan listeler. XcodeGen ile üretilen projenin Archive işlemi ikinci kontrolü otomatik çalıştırır. Normal Debug ve CI simülatör derlemeleri gerçek Firebase dosyaları gerektirmez.

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
