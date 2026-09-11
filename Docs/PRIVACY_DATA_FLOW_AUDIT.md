# Gizlilik veri akışı karşılaştırması

11 Eylül 2026. Temel sürüm: `a990a04`; Firebase SDK: `12.16.0`.

Bu inceleme kaynak kodu ve yerel yapılandırma incelemesidir. Üretim ağ yakalaması, App Store beyan yayını veya gerçek cihaz izin testi değildir. Yerel AppConfig'te backend henüz hazır işaretli değildir; aşağıdaki bulut akışları üretim kurulumu açıldığında çalışır. FirebaseBootstrap Crashlytics'i bundan bağımsız açar.

| Akış / kod | Cihaz dışına çıkan veri ve alıcı | Kontrol / beyan sonucu |
| --- | --- | --- |
| `FirebaseRESTClient`, `AuthStore`, `KeychainStore` | Firebase anonim UID, oturum belirteçleri; kişisel kayıtlar UID yolunda | User ID, linked; Keychain oturumu cihazda |
| `FavoritesStore`, `StationDataStore`, `OfflineSyncCoordinator` | Firebase'e favori istasyon, durum ve doğrulama katkısı | Other User Content; Product Interaction işlevsellik |
| `SearchDemandEvent`, `SearchCoordinator`, `FrictionAnalyticsEvent`, `FrictionTelemetryStore` | Firebase'e hücre/tercih/menzil/sonuç kovası ve olay/evre/süre | Opt-in; Coarse Location, Search History, Product Interaction; UID hız sınırı kaydı nedeniyle linked |
| `PushTokenRegistrationStore`, `SarjBulAppDelegate` | APNs cihaz token'ı ve platform UID altında Firebase'e | Device ID linked; FCM SDK kullanılmıyor |
| `FirebaseBootstrap`, `AppTelemetry` | Crashlytics'e çökme ve sade teknik hata; kurulum/teknik SDK ölçümleri | Eksik Other Diagnostic Data eklendi; SDK amaçları birleştirildi |
| `AppTelemetry` eski akış | Ham NSError userInfo/URL ve offline mutation anahtarı teknik hata kaydına girebiliyordu | Düzeltildi: sabit operation allowlist + güvenli hata domain/kodu; diğer alanlar aktarılmaz |
| `UserContextClients`, `JourneyRouteService` | Open-Meteo'ya hava/rota koordinatları | Precise Location; [saklama ve ticari kullanım kararı](DATA_PROVIDER_TERMS.md) |
| `TiledStationRepository`, `CachedRemoteStationRepository` | GitHub'a dosya URL'si, IP ve HTTP teknik verisi | Kimlik eklenmez; tüm güncel tile dosyaları indirilir, kullanıcının koordinatı URL'ye konmaz |
| `PlaceSearchSheet`, `RouteStore`, `RangeIsochroneService` | MapKit üzerinden Apple'a arama/rota noktaları | Apple hizmeti; uygulamanın kalıcı adres/rota saklaması ayrıca lisans açısından incelenmeli |
| `SearchCoordinator`, `NavigationCoordinator` | Kullanıcı seçerse Apple/Google Maps'e rota noktaları | Dış uygulama aktarımı; politika açıklandı |
| `ContextIntelligenceStore`, `UserContextClients` | Sağlık ve takvim içeriği dışarı gönderilmez | Health/Fitness/Contacts seçilmedi; izin/App Review uygunluğu ayrı |
| `ReceiptOCRService`, `ChargingHistoryStore` | Fiş OCR ve harcama cihazda; yalnız isteğe bağlı birim fiyat katkısı Firebase'e | Fotoğraf/ödeme verisi toplanmıyor; fiyat katkısı Other User Content |
| `WidgetSnapshot`, `Persistence` | App Group ve özel UserDefaults cihaz içinde | Manifestlerde 1C8F.1 / CA92.1 doğrulandı |
| `LegalView` destek bağlantısı | Kullanıcı gönderirse iCloud Mail'e adres/mesaj/ek | Email Address + Customer Support; kimlikle bağlantılı işlevsellik |
| `firebase/functions/channel-gateway.js` | Ayrı Telegram/WhatsApp/e-posta/browser hizmetleri | iOS çağrı zincirinde değil; bu sürüm formuna etkin iOS özelliği gibi eklenmedi |

## Saklama ve silme sınırı

Analiz ham olayları ve UID hız sınırı kayıtları 7 gün sonunda günlük temizliğe uygundur; arama toplaması başarılı olunca ham olay daha erken silinir. Tekrarlı sayımı önleme kayıtları 8 gün sonra temizlenir. Hesap silme işi favori, token, bildirim, katkı ve UID meta kayıtlarını temizler. Kalıcı toplamlarda UID yoktur. Silme onayı ve Authentication temizliği önceki backend çalışmasında uygulanmıştır; bu görev backend deploy yapmaz.

Destek e-postası ve üçüncü taraf teknik günlükleri aynı sıfırlama işinin parçası değildir. Politikadaki bu ayrım açıklandı. Anonim UID, olay kimliği veya istasyon bilgisi Crashlytics'e artık özel metadata olarak eklenmez. Önceki sürümlerin varsa gönderilmiş günlükleri bu kod değişikliğiyle geriye dönük silinmez.

## Tamamlananlar ve dış bağımlılıklar

- Uygulama ve örnek/yerel konfigürasyonda resmi destek e-postası; herkese açık okunabilir destek belgesi.
- Manifest, form cevap seti, TR/EN uygulama özeti ve politika eşleştirildi.
- Teknik hata veri sızıntısı sınırı düzeltildi; regresyon testleri eklendi.
- Uygulama içi Open-Meteo/Copernicus ve haritalarda OSM kaynak/lisans bağlantıları eklendi.
- Apple girişinden sonra `INVALIDITCUSER` hatası doğrulandı: hesap App Store Connect için etkin değil. App Privacy çevrimiçi formu doldurulamadı; etkin hesap/uygun uygulama erişimi gerekiyor.
- Ticari sağlayıcı hakları henüz tamamlanmış değil: [kontrol sonuçları](DATA_PROVIDER_TERMS.md).
- Destek adresini kullanıcı resmi adres olarak verdi. Bu görev e-posta göndermedi; gerçek gelen kutusu teslimatı test edilmedi.


## Doğrulama sonuçları

- Xcode iPhone 17 Pro / iOS 26.5 simülatöründe derleme ve 5 test başarılı: 2 AppTelemetryPrivacyTests, 3 AppConfigurationTests; atlanan/başarısız test yok.
- Release validation Python testleri: 9 başarılı.
- SwiftLint proje kaynakları: başarılı (DerivedData içindeki üçüncü taraf kaynakları kapsam dışı).
- `validate_release.py`: başarılı; `--production` beklendiği gibi hem çözülmemiş ticari haklar hem önceki tamamlanmamış Firebase kurulumunu bildiriyor. Bu iki bayrak açılmadı.
- `git diff --check`, yerel belge bağlantıları, manifest/plist ve resmi destek alanları doğrulandı.
