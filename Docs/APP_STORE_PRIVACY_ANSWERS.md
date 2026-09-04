# App Store Connect Gizlilik Cevapları

Bu belge, üretim uygulamasının `PrivacyInfo.xcprivacy` dosyası ve gizlilik politikasıyla aynı tutulmalıdır. App Store Connect'te "Evet, bu uygulamadan veri topluyoruz" seçeneğiyle aşağıdaki veri türlerini girin.

| Veri türü | Amaç | Kimlikle bağlantılı | Takip |
| --- | --- | --- | --- |
| Precise Location | App Functionality | Hayır | Hayır |
| Coarse Location | Analytics | Hayır | Hayır |
| Product Interaction | Analytics | Hayır | Hayır |
| User ID | App Functionality | Evet | Hayır |
| Device ID | App Functionality | Evet | Hayır |
| Other User Content | App Functionality | Evet | Hayır |
| Crash Data | App Functionality | Hayır | Hayır |

## Uygulama Notları

- `Precise Location`: Hava durumu bağlamı için üç ondalıklı mevcut konum ve uzun yol rakım hesabı için beş ondalıklı örnek rota noktaları Open-Meteo'ya gönderilebilir. E-posta, anonim Firebase UID veya reklam tanımlayıcısı eklenmez.
- `Coarse Location`: Kullanıcı varsayılan kapalı "Anonim talep paylaşımı" ayarını açarsa yaklaşık 11 km'lik hücre analiz amacıyla gönderilir.
- `Product Interaction`: Aynı açık rıza altında olay türü, yolculuk aşaması ve süre kovası gönderilir. Payload kesin konum, istasyon, yolculuk kimliği ve Firebase UID içermez.
- `User ID`: Favori, bildirim ve katkıları izole eden anonim Firebase UID'dir.
- `Device ID`: Uzaktan ve sessiz bildirim teslimatı için APNs cihaz token'ı anonim Firebase UID ile ilişkilendirilir. Reklam veya takip amacıyla kullanılmaz.
- `Other User Content`: Kullanıcının gönderdiği istasyon durumları ve doğrulama katkılarıdır.
- `Crash Data`: Firebase Crashlytics tarafından uygulama kararlılığı amacıyla işlenebilir.
- Hiçbir veri reklam, çapraz uygulama takibi veya veri satışı amacıyla kullanılmaz.

App Store Connect cevaplarını Firebase ve Open-Meteo'nun yayın anındaki veri saklama uygulamalarıyla son kez karşılaştırın. Üretim veri akışı değiştiğinde bu belgeyi, manifesti ve gizlilik politikasını aynı sürümde güncelleyin.
