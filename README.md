# SarjBul iOS

SarjBul, Türkiye genelindeki elektrikli araç şarj noktalarını menzil, rota, güç, fiyat ve kullanıcı durum bildirimleriyle sıralayan native SwiftUI uygulamasıdır. Web sürümündeki domain mantığı iOS'a taşınmış; arayüz, rota ve cihaz yetenekleri Apple platformlarına uygun katmanlara ayrılmıştır.

## Ekran Görüntüleri

![SarjBul iOS ekranları](Docs/screenshots/sarjbul-ios-preview.png)

Tasarım değiştiğinde bu görsel de aynı değişiklikle güncellenir. Renk, radius, gölge ve tipografi tokenları `SarjBul/Resources/design-tokens.json` içinde tek kaynaktır.

## Ürün Özellikleri

- Cihaz konumu, adres/POI arama ve manuel koordinat akışı
- İsteğe bağlı hedef ile rota koridorundaki istasyonları bulma
- Batarya kapasitesi, şarj yüzdesi, tüketim ve güvenlik payıyla varış şarjı hesabı
- Yakın, hızlı, ekonomik ve dengeli sıralama; soket, güç ve menzil filtreleri
- Gerçek `MKDirections` rotası, trafik katmanlı MapKit görünümü ve Apple/Google Maps aktarımı
- Dikey snap kart akışı ile bütün istasyonları gösteren harita arasında geçiş
- ETag destekli uzaktan istasyon verisi, kalite kapısı, yerel cache ve bundle fallback
- Firebase Auth token yenileme, favori senkronizasyonu, durum bildirimi ve uygulama içi hesap silme
- Firebase App Check/App Attest, Crashlytics, sıkı Realtime Database kuralları ve sunucu tarafı özetleme
- Favoriler, son açılan rotalar, paylaşılabilir `sarjbul://station/...` bağlantıları
- Doğrusal olmayan şarj eğrisi, rakım etkisi ve toplam süre optimizasyonlu uzun yol planı
- Yol ağına göre 16 yönlü erişilebilir menzil poligonu; dairesel menzil yanılsaması yok
- Fiyat/soket/adres doğrulama, zamanla azalan güven ve gece güvenliği katkıları
- Varsayılan kapalı, kaba hücreli anonim arama talebi toplama altyapısı
- EPDK'nin resmi lisans servisinden üretilen çevrimdışı operatör/lisans doğrulama snapshot'ı
- Saatlik durum örneklerinden açıkça etiketlenmiş yoğunluk tahmini
- Vision tabanlı cihaz içi fiş OCR, şarj günlüğü, yıllık özet ve 81 il koleksiyonu
- WidgetKit, App Intent, Live Activity ve Dynamic Island şarj geri sayımı
- Şarj molasında 400 metre içindeki kahve, market, park ve diğer yürüyüş noktaları
- Şarj hatırlatıcısı ve kısa Salon oyunu
- Türkçe/İngilizce, Dynamic Type, Reduce Motion, VoiceOver etiketleri ve çevrimdışı durum

## Mimari

```text
SarjBul/App/              Composition root, Observable store'lar, router, persistence ve cihaz servisleri
SarjBul/Features/         SwiftUI özellik ekranları
SarjBul/DesignSystem/     Ortak native bileşenler ve üretilmiş token tüketimi
SarjBul/Generated/        design-tokens.json kaynağından üretilen Swift değerleri
SarjBulCore/              UI'dan bağımsız skor, planlayıcı, güven/yoğunluk motoru, spatial index ve client protokolleri
SarjBulWidgets/           Ana ekran/kilit ekranı widget'ı, Live Activity ve Dynamic Island sunumu
SarjBulTests/             Domain testleri
SarjBulUnitTests/         Auth state-machine ve persistence migrasyon testleri
SarjBulUITests/           Kritik misafir akışı smoke testi
firebase/functions/       Durum/veri/talep özetleri ve hesap verisi temizleme işleri
database.rules.json       auth.uid tabanlı Realtime Database izolasyonu
```

## Kurulum

Gereksinimler: güncel Xcode, Homebrew ve XcodeGen.

```bash
brew install xcodegen
xcodegen generate
open SarjBul.xcodeproj
```

`SarjBul/Resources/AppConfig.sample.plist` dosyasını `AppConfig.plist` adıyla oluştur ve Firebase değerlerini ekle. Firebase kullanılacaksa Console'dan indirilen gerçek `GoogleService-Info.plist` dosyasını aynı klasöre koy. İki dosya da `.gitignore` kapsamındadır.

Ayrıntılı kurulum ve deploy sırası: [Docs/FIREBASE_SETUP.md](Docs/FIREBASE_SETUP.md).

## Veri

Uygulama 12.936 istasyonu tek bir JSON yerine 63 geohash döşemesi ve bir manifestten yükler. Uzak manifest ETag ile sorgulanır; yalnızca SHA-256 değeri değişen hücreler indirilir. Yeni manifest 1.000 kaydın veya bundle sayısının yüzde 70'inin altındaysa cache'e yazılmaz.

`Scripts/update_epdk_operators.py`, EPDK'nin yürürlükteki şarj ağı işletmeci lisanslarını resmi REST servisinden yeniler ve `epdk-licensed-operators.json` snapshot'ını üretir. İstasyon kartındaki lisans eşleşmesi bu snapshot'a dayanır; birkaç elle yazılmış marka adına güvenmez.

Veri pipeline actor'ü yükleme sırasında 12 bin üzeri istasyon için hücre tabanlı bir spatial index'i bir kez kurar. Arama motoru yalnızca ilgili hücrelerdeki adaylar için haversine, skor ve rozet hesaplarını çalıştırır. Hedef seçilmişse adaylar yolculuk koridoru ve sapma maliyetine göre değerlendirilir.

`AppState` yalnızca bağımlılıkları kuran composition root'tur. Auth, favoriler, istasyon verisi, arama ve deep link akışları ayrı `@Observable` store/router nesnelerindedir. Firebase REST istemcisi `AuthClient`, `FavoritesClient`, `StatusClient` ve `DemandAnalyticsClient` protokollerinin arkasındadır; oturum `.guest`, `.signedIn` ve `.refreshing` durumlarıyla yönetilir.

Tasarım tokenları için `SarjBul/Resources/design-tokens.json` tek kaynaktır. Xcode build phase `Scripts/generate_design_tokens.py` ile `SarjBul/Generated/DesignTokens.generated.swift` dosyasını üretir.

## Doğrulama

```bash
swift test
xcodegen generate
xcodebuild -project SarjBul.xcodeproj -scheme SarjBul -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
cd firebase/functions && npm ci --ignore-scripts && npm run lint && npm audit --audit-level=moderate
```

GitHub Actions aynı çekirdek testleri, SwiftLint'i, plist/privacy manifest doğrulamasını, bağımlılık denetimini, uygulama + widget derlemesini ve UI smoke testini çalıştırır.

## Yayın

- [Gizlilik politikası](Docs/PRIVACY_POLICY.md)
- [Kullanım koşulları](Docs/TERMS_OF_USE.md)
- [Release kontrol listesi](Docs/RELEASE_CHECKLIST.md)
- [Harici entegrasyon sınırları](Docs/INTEGRATIONS.md)

Rezervasyon, şarj başlatma/durdurma, ödeme ve canlı soket uygunluğu sahte butonlarla taklit edilmez. Bu kontroller yalnızca operatörün yetkili API'si ve ticari izinleri bağlandığında açılmalıdır.
