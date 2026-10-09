# App Store Connect kaydı ve sürüm numaraları

Kontrol tarihi: 8 Ekim 2026.

## İlk paket

| Alan | Değer |
| --- | --- |
| Version / `MARKETING_VERSION` | `1.0` |
| Build / `CURRENT_PROJECT_VERSION` | `1` |

Kalıcı kaynak `project.yml` içindeki ortak `settings.base` alanıdır. Ana uygulama ve widget'ın `Info.plist` dosyaları bu değerleri kullanır. Üretilen Xcode projesinin Debug ve Release ayarlarında `1.0 (1)` doğrulandı; hedeflerde ayrı sürüm/build override'ı yok.

Version, mağazada görünen sürümdür. İlk yükleme `1.0 (1)` olarak hazırlanır. Aynı mağaza sürümü için sonraki paketlerde `CURRENT_PROJECT_VERSION` değerini `2`, `3`, … olarak artır; `MARKETING_VERSION` değerini `1.0` olarak koru. Yeni mağaza sürümünde marketing version'ı güncelle ve build numarasını artırmaya devam et. Her değişiklikten sonra `xcodegen generate` çalıştır; uygulama ve widget aynı sürüm/build değerlerini taşımalıdır. Yalnızca mağaza kaydı oluşturmak build artışı gerektirmez.

## Mağaza kaydı

| Alan | Kaydedilen değer |
| --- | --- |
| Platform | iOS |
| Name | ŞarjBul; ad kabul edildi |
| Primary Language | Turkish (`tr`) |
| Bundle ID | `com.ozdemirbaris.sarjbul` |
| SKU | `SARJBUL-IOS-001` |
| User Access | Full Access; Limited Access seçeneği hesapta devre dışıydı |
| Apple ID | `6820571478` |
| iOS mağaza sürümü | `1.0` |
| Durum | Prepare for Submission |

SKU, App Store'da gösterilmeyen iç takip kodudur. Widget için ayrı mağaza kaydı oluşturulmaz; `com.ozdemirbaris.sarjbul.widgets` ana uygulamanın içindeki extension'dır.

8 Ekim 2026'da Baris Ozdemir hesabında uygulama listesi boş olarak doğrulandı; ardından iOS kaydı oluşturuldu. App Information sayfasında ad, ana dil, Bundle ID, SKU ve Apple ID; sürüm sayfasında `1.0 — Prepare for Submission` doğrulandı.

[App Store Connect — ŞarjBul kaydı](https://appstoreconnect.apple.com/apps/6820571478/distribution/info).

Bu işlem paket yükleme, TestFlight dağıtımı veya App Review gönderimi içermez.

## Mağaza metinleri — 8 Ekim 2026

Türkçe ve English (U.S.) adı, alt başlığı, tanıtım metni, açıklaması,
anahtar kelimeleri ve destek URL'si `1.0` sürümüne kaydedildi. Ana kategori
Navigation; copyright alanı `2026 Barış Özdemir` oldu. Gizlilik politikası ve
User Privacy Choices URL'leri App Privacy sayfasında iki dil için kaydedildi.
Tam metinler ve kaynak/üretim yapılandırması karşılaştırması
[APP_STORE_METADATA.md](APP_STORE_METADATA.md) içindedir.

Canlı müsaitlik bağlantısı boş ve üretim backend'i hazır olmadığı için fiyat
karşılaştırması, favori ve durum bildirimi vaatleri kaldırıldı. Açıklamalar canlı
soket müsaitliği ve doğrulanmış güncel tarife sunulmadığını, menzil/şarj/süre
değerlerinin tahmin olduğunu belirtir.

Bu kayıt sırasında App Store Connect'te binary yüklenmemişti; seçili bir build
ile doğrulama yapılmadı. Durum Prepare for Submission olarak kaldı. App Privacy
veri toplama anketi, yaş derecelendirmesi, ekran görüntüleri ve Review gönderimi
bu mağaza metni çalışmasının kapsamında tamamlanmadı.

Kaynak: [Apple — Add a new app](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/).

9 Ekim 2026'da destek ve gizlilik adresleri hesap sahibinin isteğiyle GitHub Pages adresine taşındı. Canlı yayın ve aynı kaynağın iOS CI kontrolleri geçti; App Store Connect URL alanları iki dilde güncellendi. Son kaydedilen adresler APP_STORE_METADATA.md içindedir.
