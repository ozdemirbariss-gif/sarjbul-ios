# Veri sağlayıcı koşulları — ticari yayın kontrolü

İnceleme: 11 Eylül 2026. Kullanıcı ŞarjBul'un **ticari ürün** olacağını doğruladı. Sonuç: **tüm sağlayıcılar için ticari kullanım onayı henüz yok**. Teknik erişim, lisans/yeniden dağıtım yetkisi yerine geçmez.

## Envanter kanıtı

`a990a04` istasyon paketinde 15.471 kayıt bulunuyor: ana kaynak EPDK 13.071, ChargeIQ 2.150, OSM 250. Birleştirilmiş `kaynaklar` alanında ChargeIQ 10.780, OSM 619 kayda katkı sağlıyor. Yalnızca `kaynak=chargeiq` kayıtlarını çıkarmak tüm ChargeIQ türevlerini temizlemez. Veri dosyaları bu görevde değiştirilmedi.

| Sağlayıcı | Resmi koşul ve mevcut kullanım | Sonuç / tamamlanması gereken |
| --- | --- | --- |
| Open-Meteo Forecast / Elevation | [Koşullar](https://open-meteo.com/en/terms): ücretsiz servis ticari kullanıma açık değil. Uygulama doğrudan `api.open-meteo.com` çağırıyor. | **Ticari yayın engeli:** ticari abonelik ve lisanslı bağlantı veya bu iki özelliğin kaldırılması gerekir. Satın alma yapılmadı. |
| Open-Meteo / Copernicus | [Lisans](https://open-meteo.com/en/licence), [rakım kaynağı](https://open-meteo.com/en/docs/elevation-api): veri atfı/lisans bağlantısı gerekir. | Uygulama içinde bağlantılar eklendi. Bu atıf, ücretsiz API'nin ticari kullanım sınırını kaldırmaz. |
| ChargeIQ | [Resmi site](https://www.chargeiq.com.tr/tr), [gizlilik metni](https://www.chargeiq.com.tr/tr/gizlilik); incelenen belgelerde üçüncü taraf ticari yeniden dağıtım izni bulunamadı. | **İzin doğrulanamadı:** yazılı veri lisansı gerekir veya bu kaynaktan gelen tüm türev alanlar/veriler yetkili kaynakla değiştirilmelidir. Gizlilik metni veri lisansı değildir. |
| EPDK istasyon/lisans servisleri | [Resmi servis listesi](https://www.epdk.gov.tr/Detay/Icerik/3-0-226/web-servisler) kullanılan iki endpoint'i doğruluyor. | Teknik servis meşru listede; ticari yeniden dağıtım şartları incelenen sayfada açık değil. Yetki/koşul teyidi kayda alınmalı. |
| OpenStreetMap / Overpass | [OSM telif ve lisans](https://www.openstreetmap.org/copyright): ODbL, katkıcı atfı ve türetilmiş veritabanının paylaşım yükümlülükleri. Telefon Overpass çağırmaz; veriler CI'da alınır. | Haritalara ve koşullara atıf eklendi. Birleşik veritabanının ODbL kapsamında sunuluşu ve diğer kaynaklarla lisans uyumu henüz doğrulanmadı; kod lisansı bunu karşılamaz. |
| Open Charge Map | [Geliştirici koşulları](https://openchargemap.io/develop): kullanıcı katkıları CC BY 4.0; ithal kaynaklar kendi lisanslarını korur. | Mevcut paket kaynaklarında yok; üst akış scraper'ında seçenek var. İleride eklenirse sağlayıcı/lisans alanları korunmalı ve görünür atıf yapılmalı. |
| Apple MapKit | [Developer Agreement, Attachment 6](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/): Apple haritası ile sunum ve sınırlı geçici saklama. | Native MapKit kullanılıyor. `PlaceSearchSheet` adres sonuçlarını haritasız listeliyor; adres/rota saklama (`Persistence`, `JourneyDestination`) kapsamı yayından önce düzeltilmeli/değerlendirilmeli. Genel Maps tüketici koşulları tek başına geliştirici lisansı değildir. |
| Google Maps URL aktarımı | [Maps URLs](https://developers.google.com/maps/documentation/urls/get-started): yönlendirme URL'si için API anahtarı gerekmez. | SDK/veri kazıma yok; dış rota bağlantısı. Kullanıcı başlangıç noktası aktarımı politikada açıklandı. |
| Firebase | [Hizmet koşulları](https://firebase.google.com/terms), [gizlilik](https://firebase.google.com/support/privacy); kullanılan SDK manifestleri incelendi. | Üçüncü taraf teknik veri amaçları forma eklendi. Hesap/sözleşme kabulü ve üretim kurulumu bu statik incelemeyle doğrulanmış sayılmaz. |
| GitHub dosya/sayfa barındırma | [Hizmet koşulları](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service), [gizlilik](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement). | Kamuya açık depoda bulunmak, kaynak verilerin lisansını değiştirmez. Destek sayfası GitHub hesabı gerektirmeyen iletişim sunar. |
| iCloud Mail | [iCloud koşulları](https://www.apple.com/legal/internet-services/icloud/), [Apple gizlilik politikası](https://www.apple.com/legal/privacy/en-ww/). | Resmi destek posta kutusu; gönüllü iletişim açıklaması eklendi. Gönderim/teslimat testi veya yeni sözleşme kabulü yapılmadı. |

EPDK sorgu sıklığı ve importer uygulaması [EPDK_STATION_DATA.md](EPDK_STATION_DATA.md) içinde belgeli: günlük CI bir sorgu yapar; hata halinde API'yi tekrar tekrar çağırmaz. Önceki rehberde filtresiz sorgu için saatte bir sınırı kaydedilmiştir. Rehber indirme bağlantısı bu incelemede yeniden açılamadı; bu sınırın yeniden doğrulandığı iddia edilmez.

Mevcut Open-Meteo istemcileri bu görevde ücretli servise bağlanmadı. Ticari haklar çözümlenmeden üretim Archive için `commercialDataUseApproved` açılmamalıdır. Bu alan yalnızca bütün kaynakların izin/atıf/sunum koşulları kanıtlandığında true yapılır; bir abonelik anahtarı veya izin belgesi yerine geçmez.
