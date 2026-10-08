# Gerçek iPhone Yayın Testi

Bu liste bir test protokolüdür; tamamlanmış test sonucu değildir.
TestFlight'a gönderilecek aynı Release build ile uygulanır.

Build / commit:
Tarih:
Cihaz / iOS:
Test eden:

| Akış | Beklenen sonuç | Durum |
| --- | --- | --- |
| Temiz kurulum | Ana sayfa açılır; giriş/kayıt formu yoktur | Bekliyor |
| Konum izni kabul | Güncel cihaz konumu kullanılır, manuel alan gizlenir | Bekliyor |
| Konum izni ret | Konum seçimiyle İzmir gibi desteklenen bölgede istasyon bulunur | Bekliyor |
| İzin ayarlardan değiştirilir | Uygulamaya dönüşte konum akışı toparlanır | Bekliyor |
| Manuel başlangıç + Apple Maps | Seçilen başlangıç ve istasyon birlikte açılır | Bekliyor |
| Manuel başlangıç + Google Maps | Seçilen başlangıç ve istasyon birlikte açılır | Bekliyor |
| Cihaz konumu + navigasyon | Haritanın güncel konumu kullanılır; eksik harita izni kendi uygulamasında alınır | Bekliyor |
| Google Maps kurulu değil | Bağlantı erişilebilir web hedefinde açılır; uygulama çökmez | Bekliyor |
| Şarj/güç/soket filtreleri | Arama sonuçları yeni değerlere uyar; eski öneri kalmaz | Bekliyor |
| Ağ kesilir ve geri gelir | Son veri kullanılabilir; kuyruktaki işlemler mükerrer yazılmadan tamamlanır | Bekliyor |
| Favori ve durum bildirimi | Kullanıcı izolasyonu korunur; güncelleme doğru istasyona gider | Bekliyor |
| Oturum bir saatten uzun sürer | Token yenilenir; kullanıcıda hayalet oturum oluşmaz | Bekliyor |
| Bulut verilerini sıfırla | Eski anonim kayıtlar/APNs kaydı temizlenir; yeni oturum çalışır | Bekliyor |
| Production App Attest | Gerçek imzalı build App Check enforcement açıkken hizmet alır | Bekliyor |
| APNs ve etkileşimli bildirim | Production token kaydı ve bildirimin doğru rota aksiyonu doğrulanır | Bekliyor |
| Widget / Live Activity | App Group verisi paylaşılır; şarj başlangıç/bitişinde özet güncellenir | Bekliyor |
| Kaldırılan hava/rakım ve takvim bağlamı | Hava/rakım isteği ve ilgili ayarlar yok; eski opt-in kapalı | Bekliyor |
| Apple adres arama sonuçları | Her adres sonucu için eşleşen Apple haritası/pin görünür; Apple bildirimleri örtülmez | Bekliyor |
| Apple arama seçimi + arka plan/yeniden açılış | Geçici seçim/cache temizlenir; eski kayıtlı adres ve belirsiz başlangıç geri yüklenmez | Bekliyor |
| Apple arama başlangıcı + Google Maps | Apple kaynaklı başlangıç aktarılmaz; istasyon hedefi aktarılır | Bekliyor |
| TR / EN, büyük yazı, VoiceOver | Metinler taşmaz; kontroller adlandırılmış ve erişilebilirdir | Bekliyor |
| Sheet ve sekmeler | Kapatma/geri, klavye ve alt navigasyon erişilebilir kalır | Bekliyor |
| Şarj hikayesi | 1080x1920 önizleme, paylaşım ve iptal akışları çalışır | Bekliyor |
| Çökme takibi | Kontrol edilen deneme hatası Crashlytics'e düşer; hassas içerik içermez | Bekliyor |

En az bir gerçek iPhone gerekir. Küçük ekran ve büyük yazı kontrollerini ek cihaz/simülatörle tamamla. Hata bulunan satırı tamamlandı sayma; build değişince etkilenen akışı tekrar dene.
