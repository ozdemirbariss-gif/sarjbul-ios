# CarPlay EV Charging başvurusu

## 8 Ekim 2026 durumu

Apple Developer hesabında **EV Charging** kategorisi seçildi. Hesap sahibi CarPlay Entitlement Addendum sözleşmesini kendisi kabul etti. Apple başvuru sonunda **“Thank you for your submission.”** ve inceleme sonrası durum bildireceğini gösterdi. Başvuru alındı; **entitlement onayı henüz doğrulanmadı**. Ekranda başvuru numarası gösterilmedi. Bu form adımında bundle ID veya uygulama açıklaması alanı sunulmadı.

ŞarjBul'un kapsamı EV şarj istasyonu bulma, soket/güç bilgisi ve seçilen istasyona Maps aktarımıdır. Gömülü turn-by-turn navigasyon sunmadığı için başvuru kategorisi Navigation değildir. [Apple CarPlay](https://developer.apple.com/carplay/) EV charging kategorisini ayrı listeler. [Başvuru sayfası](https://developer.apple.com/contact/carplay/).

## Apple ek bilgi isterse kullanılacak açıklama

App name: SarjBul (ŞarjBul)

Bundle ID: `com.ozdemirbaris.sarjbul`

Category: EV Charging

Support: `sarjbul@icloud.com`

> SarjBul helps drivers locate EV charging stations in Türkiye. The iPhone app supports Turkish and English, nearby station discovery, connector types and power, favorites, and directions through Apple Maps or Google Maps. The proposed CarPlay experience will focus on charging station points of interest using system templates, concise charger details and a directions action. Prices and availability will be marked with their source and timestamp when available; unknown or stale information will not be presented as current. SarjBul does not provide reservations, payment or remote charging control without an authorized operator integration. It does not use HealthKit or heart-rate data. The CarPlay interface is planned and will be implemented and tested after entitlement approval.

Bu metin Apple'a gönderilmiş ek açıklama değildir; talep edilirse kullanılacak hazırlıktır. Özel navigasyon, canlı araç telemetrisi veya operatör sözleşmesi varmış gibi beyan edilmez.

## Onay sonrası yapılacaklar

1. Apple Developer hesabına bağlı e-posta adresindeki CarPlay yanıtını kontrol et. Talep edilen ek bilgileri yukarıdaki gerçek ürün kapsamıyla yanıtla. Apple'ın karar süresi veya onayı garanti edilemez.
2. Apple'ın verdiği EV Charging entitlement'ını, ilgili takım ve `com.ozdemirbaris.sarjbul` App ID ile eşleştir. Sadece başvuru alındı mesajını yetki onayı sayma.
3. Yetki onayından sonra App ID capability'sini ve development/distribution provisioning profillerini güncelle. Onaylanan anahtarı imzalı uygulamanın yetkileriyle karşılaştır.
4. `CPPointOfInterestTemplate` tabanlı şarj istasyonu yüzeyini ekle. Kapsam istasyonlar, soket/güç, kaynak/güncellik bilgisi ve yönlendirmedir. CarPlay kullanımı için iPhone'a dokunmayı zorunlu kılma; serbest metin, hesap kurulumu, ayrıntılı ayarlar ve ilgisiz POI göstermeme kurallarını uygula.
5. CarPlay Simulator ve gerçek araçta bağlantı/kopma, konum izni reddi, boş sonuç, eski veri, farklı ekran/kumanda türleri ve Maps aktarımını test et. EV Charging arayüzünü özel turn-by-turn navigasyon gibi sunma.
6. Review Notes'a CarPlay kapsamını ve onaylanan yetkiyi ekle; imzalı Archive doğrulamasını tamamla.

Onay beklenirken ana iPhone uygulaması Maps aktarımıyla kullanılabilir. Bu repo şu anda gömülü CarPlay ekranı veya CarPlay entitlement'ı içermez. Başvuru göndermek iPhone binary'sini App Store'a yüklemek değildir.
