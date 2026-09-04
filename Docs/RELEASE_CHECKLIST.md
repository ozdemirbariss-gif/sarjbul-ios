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
- [x] Widget bundle'ına App Group `UserDefaults` için `CA92.1` neden kodlu bağımsız Privacy Manifest
- [x] App Intent / Siri hızlı şarj kısayolu
- [x] Geohash tile manifesti ve checksum tabanlı delta güncelleme
- [x] Varsayılan kapalı anonim talep paylaşımı, kaba konum hücresi ve sunucu tarafı toplama
- [x] Hassas konum, kaba konum ve açık rızalı ürün etkileşimi beyanları Privacy Manifest ve gizlilik politikasıyla eşleştirildi
- [x] Varsayılan kapalı, cihaz içi takvim/HealthKit bağlam motoru ve öğrenilmiş otomasyon eşiği
- [x] APNs cihaz token'ı alma, anonim UID ile güvenli Firebase kaydı ve hesap silmede temizleme hattı

## Hesap sahibi tarafından tamamlanacaklar

- [ ] Gerçek `GoogleService-Info.plist` ve `AppConfig.plist` release secret'ları
- [ ] Firebase rules/functions deploy ve App Check enforcement
- [ ] App Store Connect gizlilik cevaplarını `Docs/APP_STORE_PRIVACY_ANSWERS.md` ile birebir gir
- [ ] Destek URL'si, gizlilik URL'si ve anonim veri sıfırlama akışının Review Notes'a eklenmesi
- [ ] Distribution certificate/provisioning ve archive validation
- [ ] En az bir gerçek iPhone'da konum, bildirim, App Attest, auth ve rota testi
- [ ] App Store ekran görüntülerinin desteklenen cihaz boyutlarında yüklenmesi
- [ ] `group.com.ozdemirbaris.sarjbul` App Group'unu App ID ve provisioning profillerinde aç
- [ ] Widget, kilit ekranı, Dynamic Island ve Siri kısayolunu gerçek cihazda test et
- [ ] CarPlay navigasyon entitlement başvurusunu `CARPLAY_REQUEST.md` ile gönder
- [ ] Open-Meteo ticari kullanım/attribution koşullarını yayın öncesi ürün modeliyle doğrula
- [ ] App Store gizlilik formunda açık rızalı kaba konum ve ürün etkileşimi analizini beyan et; operatör çıktılarında en az 10 örnek eşiğini uygula
- [ ] Apple Developer App ID üzerinde HealthKit capability'sini aç ve distribution provisioning profilini yenile
- [ ] App Store gizlilik formunda Open-Meteo hava durumu ve rakım hesabı için üçüncü tarafa gönderilen hassas konumu beyan et
- [ ] Gerçek cihazda EventKit sahiplik kontrolü, HealthKit izni ve otomatik takvim erteleme eşiğini doğrula
- [ ] APNs sağlayıcı anahtarını bildirim gönderen backend'e tanımla ve sandbox/production silent push teslimatını gerçek cihazda doğrula

Operatör API'si veya Apple CarPlay entitlement onayı gelmeden rezervasyon, ödeme, şarj kontrolü ve gömülü CarPlay hedefi release kapsamına alınmamalıdır.
