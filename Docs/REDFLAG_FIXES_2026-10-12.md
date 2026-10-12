# Red flag düzeltmeleri — 12 Ekim 2026

İncelenen başlangıç: `b29cf9b498780c7ae583ee3b3d7678b3cab17b70`.

| Bulgu | Uygulanan düzeltme | Regresyon kanıtı |
|---|---|---|
| R1 — Tahmini mesafeyle güvenli menzil kararı | Yakın istasyonlar MapKit yol mesafesiyle filtrelenip sıralanır. Arama, kart ve asistan aynı RouteStore/RoadRouteValidator kullanır. Navigasyon öncesi güncel profil, yol mesafesi ve risk tekrar kontrol edilir. Riskli, doğrulanmamış veya menzil dışı aday hazır öneri/widget olamaz. | Gerçek yolun yakın tahmini elemesi; rota bulunamadığında öneri olmaması; tüm istasyonlar riskliyken hazır öneri bulunmaması. |
| R2 — Sapma maliyetinin kaybolması | Rota üzerindeki ilerleme ve istasyona erişim mesafesi ayrıldı. Gidiş/dönüş sapması enerji, sürüş süresi ve toplam mesafeye eklenir. Seçilen etaplar ölçülür; gerekirse alternatif duraklarla yeniden planlanır. Tüm etapları ölçülmeyen plan yayımlanmaz. | 40 km sapmanın toplamı 200 → 240 km artırması; gerçek etap mesafesiyle erişilemezlik; alternatif durağa geçiş. |
| R3 — İlk 120 adayın ilerideki durakları gizlemesi | Yolculuk araması tüm koridor adaylarını planlayıcıya verir. Konumsal dağıtım planlayıcıda, ekrandaki 24 kart sınırından önce yapılır. | 120 şehir içi + 3 uzak istasyondan gerekli uzak duraklarla plan üretimi. |
| R4 — Kısmi Firebase şeması ve patch kaybı | Bağımsız içgörü alanları eksikken varsayılan boş koleksiyonlar kullanılır. SSE bağlantısı belge durumunu saklar; alan, iç içe alan ve çoklu yol patch'lerini birleştirir. Bozuk payload silme sayılmaz. | Altı SSE/decoder testi; eksik diğer kanal, alanların korunması, gerçek silme ve bozuk patch sonrası sağlam durum. |
| R5 — Eski/tekrarlanan raporların yeni arızayı bastırması | Sayısal gözlem zamanı, sunucu teslim zamanı ve değişmez gözlem kuralları eklendi. Güncel durum 24 saatlik kullanıcı başına son gözlemden, son durum en yeni gözlemden üretilir. Yoğunluk 90 gün ve kullanıcı/saat başına bir örnekle sınırlıdır. İstemci ve günlük sunucu temizliği eskimeyi uygular. | Eski olumlu çoğunluk/yeni arıza; tekrar kullanıcı; geçersiz/gelecek/eski/değiştirilen zaman; eskimiş özet temizliği; istemci TTL. |
| R6 — Canlı değişiklikte eski kararın korunması | Tüm planlama adayları yeniden puanlanıp sıralanır. Eski plan hemen kaldırılır ve güncel adaylarla hesaplanır. Sürüm/arama bağlamı kontrolü eski async sonucun geri yazılmasını önler. Durum süresi dolunca da karar yenilenir. | Hazır istasyon arızalı olduğunda alternatifin ilk sıraya geçmesi; tüm risklilerin öneriden çıkarılması; konum/filtre değişimi ve askıda kalan arama testleri. |
| R7 — Auth silindikten sonra silme onayının kurtarılamaması | Keychain'de 32 rastgele baytlık anahtar tutulur. Sunucu atomik temizlikte kişisel veri içermeyen `completed` kanıtını bu anahtar altında yazar. UID makbuzu ve Auth silindikten sonra da okunabilir; kökü listelenemez, istemci yazamaz. | Auth ve UID makbuzu silindikten sonra kurtarma; kanıt yokken başarı iddia edilmemesi; anonim okuma, listeleme/yazma yasağı. |
| R8 — Yetkisiz canlı uygunluk akışının sonsuz tekrarı | Kurallarda bulunmayan `live_availability` SSE akışı kaldırıldı; OCPI yolu korundu. HTTP 401/403 ve SSE cancel/auth_revoked yeni oturum/yapılandırma ile açıkça başlatılana kadar yeniden denenmez. | SSE şema testleri, derleme ve kaynak akışı kontrolü. |

Şarj süresi modelindeki 7,4/3,6 kW yapay alt sınırları ve batarya × 3 güç varsayımı kaldırıldı. Kullanıcıya ayarlanabilir araç AC/DC kabul sınırları eklendi (başlangıç değerleri 11/150 kW). Eski profiller geçişte korunur; araç/güç paylaşımı/sıcaklık belirsizliği ve tahmin niteliği arayüzde belirtilir. “En hızlı plan” iddiası “tahmini sürüş ve şarj planı” olarak daraltıldı. Sıfır şarj başlangıcı artık yapay %5 enerji kazanmaz. Her yolculuk etabı, kalkış şarjına uygulanan kullanıcı güvenlik payını da korur. Enerji harcaması %1 hassasiyette yukarı yuvarlanır; önceki %5 yuvarlamasının güvenlik payı içinde kalan alternatifleri elemesi önlenir.

## Doğrulama

- Swift çekirdek: **101 test**, 16 suite, geçti.
- Firebase: **10 birim + 40 emülatör/kural/backend testi**, geçti. Java 21 geçici klasörde kullanıldı; demo projeleri üretim verisinden ayrıdır.
- Python veri/yayın: **36 test**, geçti.
- iOS tam simülatör koşusu: **104 test**, geçti. Son davranış değişikliklerinden sonra **85 test** (tüm uygulama birim testleri + etkilenen dört arayüz akışı) yeniden geçti. Asistan kabul/yenileme kontrolünden sonra **82 test** (tüm uygulama birim testleri + asistan arayüz akışı) de geçti. Son güvenlik payı değişikliği **14 arama/rota testi** ile tekrar kontrol edildi.
- SwiftLint strict: 0 ihlal. Üretim npm bağımlılık denetimi: 0 açık.
- Debug uygulama/test ve Release derlemeleri geçti.

## Teslim ve açık dış bağımlılıklar

- Realtime Database kuralları `sarjbul-ios-f57e6` / `sarjbul-ios-f57e6-default-rtdb` üzerine dağıtıldı; sunucudan geri okunan JSON depoyla eşleşti. Kanonik SHA-256: `b489e6fac6ee13f67b4cd9a8d405eb5d43bfe7201c683c3ec8cfbd88956f6587`.
- Cloud Functions listesi Google API'den **403 / SERVICE_DISABLED** döndürüyor. İşlevler canlıya alınmadı. Cloud Functions API/faturalandırma kurulumu tamamlanınca beş iOS işlevi `npm run deploy:ios` ile dağıtılıp canlı silme/TTL akışı doğrulanmalı. `firebaseBackendReady=false` korunur.
- Üretim yayın kontrolü hâlâ EPDK `pending_permission`, çözümlenmemiş ticari veri izni ve backend hazırlığı nedeniyle durur. İzin kanıtı yerine bayrak değiştirilmedi; günlük veri yenileme bu izin çözülene kadar engelli kalır.
- Yeni zaman şeması uygulama, kurallar ve işlevlerle birlikte sürümlenmelidir. Eski sürümlerin zaman alanı eksik yeni raporları reddedilir. Eski kayıtlardaki metin tarihlerine tazelik atfedilmez.
- Yeni kurtarma anahtarı bulunmayan eski sürüm silme isteklerinde, Auth çoktan silinmişse sunucu onayı destek üzerinden doğrulanmalıdır. Kanıt olmadan temizlik tamamlandı denmez.
- İmzalı fiziksel cihaz, TestFlight, gerçek App Attest ve CarPlay etkileşim testi yapılmadı. Git push veya veritabanı dağıtımı App Store binary yayını değildir.
