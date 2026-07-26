# Harici Entegrasyonlar

## Uygulama içinde tamamlananlar

- MapKit rota, trafik, adres arama ve Apple Maps aktarımı
- Google Maps HTTPS rota aktarımı
- Firebase Auth/Realtime Database, token yenileme, App Check ve Crashlytics
- Uzaktan istasyon verisi, ETag cache ve offline fallback
- Yerel şarj hatırlatıcısı
- WidgetKit, App Intents, Live Activity ve Dynamic Island
- Vision ile tamamen cihaz içinde fiş OCR
- Open-Meteo Elevation API / Copernicus DEM ile rota rakım profili
- EPDK şarj ağı işletmeci lisansı REST servisiyle operatör doğrulama snapshot'ı

## Yetkili sağlayıcı gerektirenler

Canlı soket uygunluğu, rezervasyon, QR ile şarj başlatma/durdurma, ücret tahsilatı, fatura ve şarj oturumu geçmişi yalnızca istasyon operatörünün sözleşmeli API'siyle güvenilir biçimde sunulabilir. Şu anki açık veri kümesi bu işlemler için yetki veya gerçek zaman garantisi vermez. Uygulama bu nedenle çalışmayan kontroller göstermez.

CarPlay navigasyon uygulaması yetkisi Apple tarafından ayrı değerlendirilir. Entitlement onaylanmadan CarPlay hedefi eklemek derlenen fakat dağıtılamayan bir özellik oluşturacağından ana hedefe dahil edilmez. Mevcut uygulama rotayı CarPlay destekli Apple Maps'e aktarır.

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

Hedefli rota oluşturulduğunda en fazla 80 örnek koordinat Open-Meteo Elevation API'ye gönderilir. Yanıtta Copernicus DEM GLO-90 rakımları kullanılır; e-posta, Firebase UID veya istasyon katkısı gönderilmez. Servis başarısızsa plan rakım düzeltmesiz hesaplanır ve bu durum kullanıcıya açıkça yazılır.

## CarPlay

Kod tarafı rotayı CarPlay destekli Apple Maps'e aktarır. Gömülü CarPlay navigasyon hedefi için Apple entitlement onayı zorunludur. Başvuru, bundle kimliği ve navigasyon kullanım senaryosuyla [CARPLAY_REQUEST.md](CARPLAY_REQUEST.md) adımlarına göre paralel yürütülmelidir.
