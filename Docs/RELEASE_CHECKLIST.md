# App Store Release Kontrol Listesi

## Depoda doğrulananlar

- [x] App icon normal, dark ve tinted varyantları
- [x] Launch screen rengi ve Türkçe/İngilizce izin metni
- [x] Privacy manifest ve uygulama içi gizlilik/koşul/destek ekranları
- [x] Uygulama içi hesap silme
- [x] App Attest tabanlı Firebase App Check entegrasyonu
- [x] Crashlytics; reklam analitiği yok
- [x] Auth token yenileme ve Keychain saklama
- [x] Offline cache ve veri kalite kapısı
- [x] Unit, UI smoke, backend lint ve bağımlılık audit CI adımları
- [x] Dynamic Type, Reduce Motion ve temel VoiceOver etiketleri
- [x] App Group tabanlı widget, Live Activity ve Dynamic Island hedefi
- [x] App Intent / Siri hızlı şarj kısayolu
- [x] Geohash tile manifesti ve checksum tabanlı delta güncelleme
- [x] Varsayılan kapalı anonim talep paylaşımı, kaba konum hücresi ve sunucu tarafı toplama

## Hesap sahibi tarafından tamamlanacaklar

- [ ] Gerçek `GoogleService-Info.plist` ve `AppConfig.plist` release secret'ları
- [ ] Firebase rules/functions deploy ve App Check enforcement
- [ ] App Store Connect gizlilik cevaplarının `PrivacyInfo.xcprivacy` ile eşleştirilmesi
- [ ] Destek URL'si, gizlilik URL'si ve hesap silme akışının Review Notes'a eklenmesi
- [ ] Distribution certificate/provisioning ve archive validation
- [ ] En az bir gerçek iPhone'da konum, bildirim, App Attest, auth ve rota testi
- [ ] App Store ekran görüntülerinin desteklenen cihaz boyutlarında yüklenmesi
- [ ] `group.com.ozdemirbaris.sarjbul` App Group'unu App ID ve provisioning profillerinde aç
- [ ] Widget, kilit ekranı, Dynamic Island ve Siri kısayolunu gerçek cihazda test et
- [ ] CarPlay navigasyon entitlement başvurusunu `CARPLAY_REQUEST.md` ile gönder
- [ ] Open-Meteo ticari kullanım/attribution koşullarını yayın öncesi ürün modeliyle doğrula
- [ ] App Store gizlilik formunda açık rızalı kaba konum analizini beyan et; operatör çıktılarında en az 10 örnek eşiğini uygula

Operatör API'si veya Apple CarPlay entitlement onayı gelmeden rezervasyon, ödeme, şarj kontrolü ve gömülü CarPlay hedefi release kapsamına alınmamalıdır.
