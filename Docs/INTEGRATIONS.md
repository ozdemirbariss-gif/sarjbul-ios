# Harici Entegrasyonlar

## Uygulama içinde tamamlananlar

- MapKit rota, trafik, adres arama ve Apple Maps aktarımı
- Google Maps HTTPS rota aktarımı
- Firebase Auth/Realtime Database, token yenileme, App Check ve Crashlytics
- Uzaktan istasyon verisi, ETag cache ve offline fallback
- Yerel şarj hatırlatıcısı
- WidgetKit, App Intents, Live Activity ve Dynamic Island
- Vision ile tamamen cihaz içinde fiş OCR
- Rakım servisi olmadan rota/enerji tahmini (rakım düzeltmesi uygulanmaz)
- EPDK şarj ağı işletmeci lisansı REST servisiyle operatör doğrulama snapshot'ı
- Telegram, WhatsApp, e-posta ve browser uzantısı için ortak salt okunur komut gateway'i
- Cihaz içi bağlam motoru altyapısı (hava sağlayıcısı kaldırıldığı için takvim önerileri kapalı)

Kanal gateway'inin sağlayıcı kurulumu ve güvenlik sınırları [CHANNEL_AUTOMATION.md](CHANNEL_AUTOMATION.md) içinde açıklanır.

## Bağlam zekası veri sınırı

Hava koşulu gerektiren bağlam/takvim önerileri bu sürümde kapalıdır; etkinleştirme ayarları kaldırılmıştır. EventKit takvim içeriği ve kişisel alışkanlık özeti cihazdan çıkarılmaz. Hava durumu ve rakım ağ istemcileri 8 Ekim 2026 tarihinde ticari erişim lisansı bulunmadığı için kaldırıldı. Eski hava durumu tercihi açılışta kapatılır.

HealthKit ve kalp atışına dayalı mola önerisi uygulamadan, domain modelinden, yetkilerden ve izin metinlerinden kaldırılmıştır. Bağlam motorunun hava sinyali `.normal` olarak kalır; yağışa bağlı takvim önerileri üretilmez. Takvim olayı, kullanıcı aynı erteleme önerisini en az iki kez kabul etmeden ve ayrıca otomatik takvim eylemini açmadan otomatik değiştirilmez. Tüm gün etkinlikleri ve başka birinin düzenlediği etkinlikler otomasyona kapalıdır.

iOS sürekli ve sınırsız arka plan çalışması garanti etmez. Değerlendirme uygulama açılışı, konum güncellemesi ve sistemin verdiği BGTask pencerelerinde yapılır. Canlı trafik yoğunluğu entegrasyonu bulunmadığı için hareket hızı yalnızca "seyir halinde" sinyali olarak kullanılır; sıkışıklık iddiası üretilmez.

## Yetkili sağlayıcı gerektirenler

Canlı soket uygunluğu, rezervasyon, QR ile şarj başlatma/durdurma, ücret tahsilatı, fatura ve şarj oturumu geçmişi yalnızca istasyon operatörünün sözleşmeli API'siyle güvenilir biçimde sunulabilir. Şu anki açık veri kümesi bu işlemler için yetki veya gerçek zaman garantisi vermez. Uygulama bu nedenle çalışmayan kontroller göstermez.

CarPlay EV Charging yetkisi 9 Ekim 2026 tarihinde onay sonrası ana App ID'de etkinleştirildi; dağıtım profili yenilendi. Ana hedef CarPlay sahnesini ve charging entitlement'ını içerir. Araç ekranı yakındaki istasyonları, favorileri ve kaynak/tarih bilgili istasyon detaylarını sistem şablonlarında gösterir; yol tarifi Apple Maps'e aktarılır.

Bir operatör entegrasyonu geldiğinde istemcinin doğrudan operatör anahtarı taşımaması gerekir. Yetki, fiyat ve ödeme işlemleri server-to-server backend üzerinden yürütülmeli; iOS yalnızca kısa ömürlü oturum ve işlem sonucunu almalıdır.

## OCPI 2.2.1 sınırı

`LiveAvailabilityClient` uygulamanın canlı uygunluk sözleşmesidir. `OCPIGatewayClient`, istasyon anahtarlarını yalnızca ŞarjBul backend'ine gönderir; operatör OCPI tokenı iOS binary'sine hiçbir zaman girmez. Gateway aşağıdaki sorumluluklara sahiptir:

- Operatör bazında OCPI 2.2.1 Locations/EVSE/Connector kimlik eşlemesi
- Token rotasyonu, rate limit, retry ve son geçerli yanıt cache'i
- `stationKey -> availableConnectors/totalConnectors/updatedAt` şeklinde normalize yanıt
- Güncelliği geçen veriyi canlı gibi sunmama ve sağlayıcı kesintisini açıkça işaretleme

`liveAvailabilityURL` boş olduğunda uygulama çalışmayan bir canlı uygunluk kontrolü göstermez; topluluk bildirimi ve açıkça etiketlenmiş yoğunluk tahminiyle devam eder.

## EPDK lisans snapshot'ı

`Scripts/update_epdk_operators.py`, EPDK'nin `sarjAgiIsletmeciLisansiSorgula` REST servisini `ONAYLANDI` durumuyla çağırır ve yalnızca lisans numarası, lisans sahibi, marka adları ile geçerlilik tarihlerini bundle'a yazar. Snapshot ağ yokken de marka eşleşmesi sağlar. Yenileme elle veya veri yayın pipeline'ından çalıştırılmalı; uygulama açılışında EPDK servisine istek atılmaz.

## Anonim talep ısı haritası

`DemandAnalyticsClient` arama talebi veri sınırıdır ve varsayılan olarak kapalıdır. Açık rıza veren, oturum açmış kullanıcıların noktaları istemci üzerinde 0,1 derece hücrelere yuvarlanır. Geçici olay kimlik veya ham koordinat taşımaz; Firebase Function aylık hücre, tercih, menzil ve sonuç sayısı kovalarına ekledikten sonra olayı siler. Kurallar kullanıcı başına beş dakikalık hız sınırı uygular ve toplu `demand_heatmap` ağacını istemcilere kapatır.

Operatörlere yönelik bir çıktı açılacaksa backend yalnızca toplamı en az 10 olan hücreleri döndürmeli, küçük örnekleri komşu hücrelerle birleştirmeli ve dışa aktarım denetim kaydı tutmalıdır. Bu katman canlı OCPI erişimi için değer önerisi üretir; bireysel sürüş geçmişi veya kullanıcı segmenti oluşturmaz.

## Rakım verisi

Open-Meteo Elevation istemcisi kaldırılmıştır. Hedefli rota rakım düzeltmesiz hesaplanır ve bu durum kullanıcıya açıkça yazılır. Yeni bir rakım sağlayıcısı ancak ticari erişim ve veri hakları doğrulanarak eklenebilir.

## CarPlay

Onay ve portal etkinleştirmesi tamamlandı. Uygulama `CPPointOfInterestTemplate` ile en fazla 12 istasyon, `CPListTemplate` ile favoriler ve `CPInformationTemplate` ile istasyon detayı sunar. Rota Apple Maps'e aktarılır. Doğrulama kayıtları ve kalan simülatör/gerçek araç kontrolleri [CARPLAY_REQUEST.md](CARPLAY_REQUEST.md) dosyasındadır.
