# MapKit geliştirici koşulları karşılaştırması

8 Ekim 2026. Kaynak: [Apple Developer Program License Agreement, Attachment 6](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/).

| Hüküm | Uygulama karşılığı |
| --- | --- |
| §1.1, §1.2 — MapKit üzerinden uygulama işlevi | Native MapKit arama, harita ve rota kullanılır. |
| §2.1 — Apple bildirimleri görünür kalır | Native harita alt kenarı örtülmez; EPDK istasyon kaynak bağlantısı üst köşededir. Paylaşım görselindeki harita snapshot'ı panelin üstünde bütünüyle korunur; alt bildirimleri örten degrade kaldırılmıştır; istasyon kaynak dipnotu EPDK olarak güncellenmiştir. |
| §2.4 — adres sonucu ilgili Apple haritasıyla sunulur | `PlaceSearchSheet` arama sonuçları koordinatlı `MKMapItem` olarak alınır; listeyle birlikte eşleşen pinler gösterilir. Seçili başlangıç/hedef için Home/TripPlan içinde Apple haritası bulunur. |
| §2.2, §2.5 — türev veritabanı yok; geçici/sınırlı saklama | Hedef adres diske yazılmaz; eski `journeyDestination` silinir. Apple arama koordinatları `.appleMaps` kökeniyle işaretlenir; kayıtlı konum/otonom öneri ve talep analizine girmez. Eski belirsiz manuel konum ve bağlı öneriler tek sefer temizlenir. Rota cache'i bellekte en fazla 5 dakika, arka plana geçince temizlenir; yolculuk rota cache'i kaldırılmıştır. Arama seçimi arka plana geçince silinir. Google aktarımında Apple kökenli başlangıç gönderilmez. |

Bu karşılaştırma kaynak kodu kapsamındadır; Apple hesabının geçerli üyeliği ve kabul ettiği sözleşme ayrıca hesap sahibinin sorumluluğundadır. Gerçek cihazda arama sonucu/pin eşleşmesi, Apple bildirimlerinin görünürlüğü ve arka plan temizliği yayın kontrolünde doğrulanmalıdır.
