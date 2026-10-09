# App Store Metinleri — 1.0

Bu metinler ilk iPhone sürümü `1.0 (1)` için hazırlanmıştır. 8 Ekim 2026'da [App Store Connect kaydına](APP_STORE_CONNECT_SETUP.md) Türkçe ve English (U.S.) yerelleştirmeleri kaydedildi. Ana dil Türkçe, ana kategori Navigation'dır. Destek ve gizlilik bağlantıları 9 Ekim 2026'da GitHub Pages adreslerine güncellendi.
App Review iletişim bilgileri, fiyat, dağıtım ülkeleri ve yaş derecelendirmesi ayrıca tamamlanır.

## Türkçe

- Ad: ŞarjBul
- Alt başlık: Elektrikli araç şarj noktaları
- Anahtar kelimeler: elektrikli,araç,istasyon,menzil,rota,batarya,soket,şarj
- Ana kategori: Navigation
- Tanıtım metni: Türkiye'deki şarj noktalarını keşfet, soket ve güce göre filtrele, tahmini menzilini hesapla ve seçtiğin istasyona yol tarifi aç.

ŞarjBul ile Türkiye'deki elektrikli araç şarj noktalarını bul, sürüş değerlerine göre karşılaştır ve seçtiğin istasyona rota aç.

Şarj yüzdesi, batarya kapasitesi ve ortalama tüketimini girerek tahmini menzilini ve varış şarjını görebilirsin. Konum izni verebilir veya başlangıç konumunu kendin seçebilirsin.

- İstasyonları mesafe ve şarj gücüne göre karşılaştır.
- Soket ve güç filtreleriyle aramanı daralt.
- Rotayı Apple Maps veya Google Maps'te aç.
- Manuel şarj hatırlatıcısı kur; widget ve Live Activity ile tahmini süreyi gör.
- Türkçe ve İngilizce kullan; bağlantı olmadığında son indirilen istasyon verilerine eriş.

Giriş veya kayıt formu gerekmez. Menzil, varış şarjı ve süre değerleri tahmindir; aracından veya şarj cihazından ölçüm alınmaz. Bu sürüm canlı soket müsaitliği veya doğrulanmış güncel tarife sunmaz. Yola çıkmadan önce fiyatı ve müsaitliği istasyon operatöründen doğrula. Uygulama üzerinden rezervasyon, ödeme veya şarj başlatma yapılmaz. Güncel yol tarifi ve istasyon verilerinin yenilenmesi internet bağlantısı gerektirir.

## English

- Name: ŞarjBul
- Subtitle: Find EV charging stations
- Keywords: electric,vehicle,charging,station,range,route,battery,connector
- Primary category: Navigation
- Promotional text: Discover EV charging stations in Türkiye, filter by connector and power, estimate your range, and open directions to your selected stop.

Find EV charging stations in Türkiye, compare them using your driving profile, and open directions to your selected stop.

Enter your charge level, battery capacity and average consumption to estimate your range and arrival charge. Use your device location or choose a starting point manually.

- Compare stations by distance and charging power.
- Refine your search with connector and power filters.
- Open directions in Apple Maps or Google Maps.
- Set a manual charging reminder and view the estimated timer with widgets and Live Activities.
- Use Turkish or English and access previously downloaded station data offline.

No sign-in or registration form is required. Range, arrival charge and time values are estimates; the app does not read measurements from your vehicle or charger. This version does not provide live connector availability or verified current tariffs. Confirm pricing and availability with the station operator before you travel. The app does not reserve, pay for or start charging sessions. Current directions and station data updates require an internet connection.

## Bağlantılar ve hak sahibi

- Destek e-postası: **sarjbul@icloud.com**.
- Destek URL'si: https://ozdemirbariss-gif.github.io/sarjbul-ios/support/
- Gizlilik URL'si: https://ozdemirbariss-gif.github.io/sarjbul-ios/privacy/
- User Privacy Choices URL: https://ozdemirbariss-gif.github.io/sarjbul-ios/support/
- Kullanım koşulları URL'si: https://ozdemirbariss-gif.github.io/sarjbul-ios/terms/
- Copyright: **2026 Barış Özdemir**. App Store Connect geliştirici hesabındaki gerçek kişi adı kullanılır; uygulama adı hak sahibi yerine yazılmaz.

## Sürümle karşılaştırma

Özellik karşılaştırmasının kaynağı: `c368967`; GitHub Pages/URL güncellemesinin kaynağı: `31b4560`; `project.yml` sürümü `1.0`, build numarası `1`. Bu çalışma sırasında App Store Connect'te henüz yüklenmiş/seçilmiş binary yoktu. Karşılaştırma kaynak kodu ve yerel üretim yapılandırmasıyla yapıldı; bu, yüklenmiş binary testi değildir.

- `AppConfig.plist` içinde `liveAvailabilityURL` boş; `AppConfiguration.configuredLiveAvailabilityClient` bu durumda `UnavailableLiveAvailabilityClient` kullanır. EPDK envanteri fiyat ve canlı müsaitlik sağlamaz. Bu nedenle fiyat karşılaştırması vaadi kaldırıldı, canlı müsaitlik ve doğrulanmış güncel tarife bulunmadığı iki dilde açıklandı.
- `firebaseBackendReady=false`; üretim Cloud Functions dağıtımı tamamlanmadı. Favori ve durum bildirimi vaatleri açıklamalardan çıkarıldı. Bu metin değişikliği backend'i etkinleştirmez.
- Arama, soket/güç filtreleri, manuel sürüş değerleri, haritalara yönlendirme, önceden indirilen istasyon verisi, manuel hatırlatıcı, widget ve Live Activity kaynaklarda mevcut. Hatırlatıcı/süre araç veya şarj cihazından ölçüm değildir.
- Rezervasyon, ödeme, uzaktan şarj başlatma, CarPlay ve sürekli arka plan çalışması vaat edilmez.
- `commercialDataUseApproved=false` korunur; metinlerin kaydı veri kullanım izni veya uygulama yayını değildir.

9 Ekim 2026'da Türkçe ve English (U.S.) için beşer **1320 × 2868**, RGB/alpha kanalsız gerçek Release ekranı App Store Connect büyük iPhone alanına eklendi. Orta boy alan aynı seti otomatik kullanır. [İkon bağlantısı, görseller ve çekim kaydı](app-store/README.md).

## Tamamlanacak Alanlar

- App Review iletişim kişisi, telefon ve e-posta; kamuya açık destek adresinden ayrı bir formdur.
- Güncel yaş derecelendirmesi anketi: uygulamada gerçekten sunulan özelliklere göre cevapla.
- Fiyat ve dağıtım ülkeleri; Avrupa Birliği seçilecekse DSA durumunu tamamla.

Doğrulanmış operatör bağlantısı olmadan canlı soket garantisi, rezervasyon, ödeme, uzaktan araç batarya okuma veya kesintisiz arka plan çalışması vaat edilmez. Mağaza sürümündeki görünür özellikler bu metinle son kez karşılaştırılır.
