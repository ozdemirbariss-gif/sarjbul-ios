# App Store Connect Gizlilik Cevapları

Bu belge, üretim uygulamasının `PrivacyInfo.xcprivacy` dosyası ve gizlilik politikasıyla aynı tutulmalıdır. App Store Connect'te "Evet, bu uygulamadan veri topluyoruz" seçeneğiyle aşağıdaki veri türlerini girin.

| Veri türü | Amaç | Kimlikle bağlantılı | Takip |
| --- | --- | --- | --- |
| Precise Location | App Functionality | Hayır | Hayır |
| Coarse Location | Analytics | Evet | Hayır |
| Product Interaction | Analytics | Evet | Hayır |
| User ID | App Functionality | Evet | Hayır |
| Device ID | App Functionality | Evet | Hayır |
| Other User Content | App Functionality | Evet | Hayır |
| Crash Data | App Functionality | Hayır | Hayır |

## Uygulama Notları

- `Precise Location`: Hava durumu bağlamı için üç ondalıklı mevcut konum ve uzun yol rakım hesabı için beş ondalıklı örnek rota noktaları Open-Meteo'ya gönderilebilir. E-posta, anonim Firebase UID veya reklam tanımlayıcısı eklenmez.
- `Coarse Location`: Kullanıcı varsayılan kapalı "Anonim talep paylaşımı" ayarını açarsa yaklaşık 11 km'lik hücre analiz amacıyla gönderilir.
- `Product Interaction`: Aynı açık rıza altında olay türü, yolculuk aşaması ve süre kovası gönderilir. Payload kesin konum, istasyon, yolculuk kimliği ve Firebase UID içermez.
- İki analiz türü de son olayın kayıt yolunu anonim UID'ye bağlayan geçici hız sınırı kaydı nedeniyle kimlikle bağlantılı beyan edilir. Olay gövdesinde UID bulunmaması bu bağlantıyı ortadan kaldırmaz. Bu değerlendirme [Apple'ın kimlikle bağlantılı veri açıklamasına](https://developer.apple.com/app-store/app-privacy-details/#data-linked-to-the-user) ve uygulamanın mevcut veri akışına dayanır. Reklam takibi yapılmaz.
- `User ID`: Favori, bildirim ve katkıları izole eden anonim Firebase UID'dir.
- `Device ID`: Uzaktan ve sessiz bildirim teslimatı için APNs cihaz token'ı anonim Firebase UID ile ilişkilendirilir. Reklam veya takip amacıyla kullanılmaz.
- `Other User Content`: Kullanıcının gönderdiği istasyon durumları ve doğrulama katkılarıdır.
- `Crash Data`: Firebase Crashlytics tarafından uygulama kararlılığı amacıyla işlenebilir.
- Hiçbir veri reklam, çapraz uygulama takibi veya veri satışı amacıyla kullanılmaz.

## Yalnızca Cihazda İşlenen Veriler

- EventKit takvim başlıkları/zamanları ve HealthKit kalp atış hızı/dinlenik kalp atış hızı örnekleri cihazda değerlendirilir. Mevcut uygulama bunları dışarı göndermediğinden bu tabloya sunucuda toplanan sağlık veya takvim verisi olarak eklenmez. Sistem izinleri, mağaza veri toplama beyanından ayrı gerekliliklerdir.
- Sağlık ve takvim erişiminin kullanım amacı gizlilik politikasında açıklanmıştır. HealthKit'in bu ürünün kullanım amacıyla uygunluğu yayın öncesi ayrıca değerlendirilmelidir; cihazda işlemek tek başına App Review uygunluğunu garanti etmez.
- App Group UserDefaults için uygulama ve widget manifestlerinde `1C8F.1` bulunur. Uygulama kendi özel UserDefaults alanı için ayrıca `CA92.1` bildirir.

App Store Connect cevaplarını Firebase ve Open-Meteo'nun yayın anındaki veri saklama uygulamalarıyla son kez karşılaştırın. Üretim veri akışı değiştiğinde bu belgeyi, manifesti ve gizlilik politikasını aynı sürümde güncelleyin.
