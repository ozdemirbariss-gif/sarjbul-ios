# App Store ikon ve ekran görüntüleri — 9 Ekim 2026

Uygulama: ŞarjBul, `com.ozdemirbaris.sarjbul`, **1.0 (1)**.

Türkçe (`tr`) ve English (U.S.) (`en-US`) için beşer ekran, iPhone 17 Pro Max / iOS 26.5 üzerinde **Release** derlemesinden alındı. Her PNG **1320 × 2868**, RGB, alpha kanalsızdır. Çekimler yeniden boyutlandırılmadı, kırpılmadı veya rötuşlanmadı. Simülatörün tamamen opak alpha kanalı varsa yalnızca bu kanal kaldırıldı; RGB pikselleri korundu.

| Sıra | Dosya | Gerçek sürümde gösterilen özellik |
| --- | --- | --- |
| 1 | `01-home.png` | Ana ekran ve istasyon/rota önerisi |
| 2 | `02-stations-map.png` | İstasyon haritası, şarj gücü işaretleri |
| 3 | `03-filters.png` | Güç, soket ve menzil filtreleri; mevcut orta boy panel kaydırılarak gösterilir |
| 4 | `04-route.png` | İstasyon kartı, gerçek MapKit rotası, mesafe, tahmini süre/varış şarjı |
| 5 | `05-charging-break.png` | Uygulama içinden başlatılan manuel 30 dakikalık hatırlatıcı |

Test istasyonları, hayali tarife/müsaitlik veya Debug öneri fixture'ları kullanılmadı. Kaynak, dağıtılacak uygulamanın yapılandırılmış istasyon deposu ve paketlenmiş EPDK kayıtlarıdır. Başlangıç konumu simülatörde İzmir merkezine ayarlanmıştır; bir kullanıcının kişisel konumu değildir. Uygulamanın mevcut TR/EN metinleri ve koyu görünümü kullanılır. Görsellerdeki menzil, süre ve varış yüzdesi tahmindir; fiyat/müsaitlik belirsizliği gerçek arayüzde korunur.

## İkon bağlantısı

- `project.yml` ana uygulama hedefi: `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`; üretilen Xcode projesinin Debug ve Release yapılandırmalarında aynı seçim bulunur.
- Derlenen Release `Info.plist`: `CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconName = AppIcon`. `Assets.car` ve `AppIcon60x60` türevi derlenen pakette doğrulandı. Simülatör ana ekranında uygulama simgesi de göründü.
- `icon/` içindeki üç 1024 × 1024 PNG, mevcut asset catalog dosyalarının birebir kopyasıdır. Varsayılan pazarlama ikonu ve tinted varyant alpha içermez. Dark varyantın sistem arka planını göstermek için kullanılan transparan zemini korunur; bu, mağaza ekran görüntülerine uygulanan alpha yasağından ayrıdır. [Apple ikon yapılandırması](https://developer.apple.com/documentation/xcode/configuring-your-app-icon).
- İkon App Store Connect'e ekran görüntüsü olarak yüklenmez; uygulama binary'sinin asset catalog'undan gelir. Bu çalışma binary yüklemesi veya App Review gönderimi değildir.

## App Store Connect

[ŞarjBul 1.0 Media Manager](https://appstoreconnect.apple.com/apps/6820571478/distribution/ios/version/inflight/media-manager/iphone) içinde her dilin **iPhone with Dynamic Island (large display)** alanına bu sırayla beş görsel eklendi. Orta boy zorunlu alan, büyük boy seti **Using Existing Assets** olarak otomatik kullanır; eski 1206 × 2622 çekimler ve 1600 × 1040 README kolajı yüklenmedi.

Ölçüler, 1–10 görsel sınırı ve alpha yasağı [Apple'ın güncel ekran görüntüsü ölçülerine](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) göre kontrol edildi. `preview-tr.jpg` ve `preview-en-US.jpg` yalnızca inceleme kolajıdır; mağazaya yüklenenler dil klasörlerindeki beşer PNG'dir.

## Yeniden üretim ve doğrulama

Xcode, iOS Simulator, XcodeGen, Python 3 ve Pillow gerekir. Makinede yerel üretim yapılandırma plist'leri varsa kullanılır; bu dosyalar Git'e eklenmez. Ağ erişimi ve istasyon/MapKit servisleri gerekir.

```sh
Scripts/capture_app_store.sh
```

Varsayılan cihaz iPhone 17 Pro Max'tir. Başka bir yerel **1320 × 2868** cihazı `SARJBUL_SCREENSHOT_DEVICE` ile, mevcut paket önbelleğini `SARJBUL_PACKAGE_CACHE` ile seçebilirsin. Script Release için yalnızca UI testlerini içeren `SarjBulStoreScreenshots` şemasını kullanır. Normal Debug test koşuları mağaza çekimlerini atlar.

İki dilin çekim testi geçti (`test-results.json`). `capture.json`, kaynak commit'ini, Xcode sürümünü, derlenen ikon bağlantısını ve her dosyanın SHA-256 değerini içerir. Dışa aktarıcı eksik ekran, yanlış boyut, transparan piksel veya yanlış derlenmiş ikon bağlantısında hata verir. On görsel ayrıca görsel olarak incelendi.

Bu kayıt Simulator arayüz doğrulamasıdır; imzalı cihaz Archive/TestFlight doğrulaması veya App Store yayını yerine geçmez.
