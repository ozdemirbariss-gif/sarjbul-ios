# Veri sağlayıcı koşulları — ticari yayın kontrolü

İnceleme: **8 Ekim 2026**. ŞarjBul ticari üründür. Güncel istasyon paketi **yalnızca EPDK** kullanır. **EPDK ticari kullanım/yeniden dağıtım izni henüz belgelenmediği için `commercialDataUseApproved=false` kalır.** Teknik yeniden üretim izin yerine geçmez.

## Güncel envanter

8 Ekim EPDK yanıtından **13.129 halka açık istasyon ve 36.391 soket**, 61 geohash tile üretildi. Ana ve tüm katkı kaynakları yalnızca `epdk` değerini taşır. İşletmeci lisans snapshot'ı da EPDK verisidir. Yeniden üretim, hash ve eski paketle karşılaştırma: [EPDK geçiş kaydı](EPDK_ONLY_MIGRATION.md). Kontroller:

```sh
python3 Scripts/validate_data_rights.py --inventory
python3 Scripts/validate_data_rights.py --epdk-only
python3 Scripts/validate_data_rights.py
```

İlk iki komut kaynak/sayı/bütünlük incelemesidir, ticari izin vermez. Son komut EPDK izni bulunmadığı için başarısız olmalıdır.

| Sağlayıcı | Resmî dayanak | Gerçek durum / uygulanan değişiklik |
| --- | --- | --- |
| EPDK | [Resmî servisler](https://www.epdk.gov.tr/Detay/Icerik/3-0-226/web-servisler) kullanılan istasyon ve işletmeci lisans endpoint'lerini listeler. | **İzin bekleniyor.** Kullanıcı yazılı izin olmadığını teyit etti. Ticari kullanım, çevrimdışı saklama, türev alanlar ve kamuya açık JSON/tile yeniden dağıtımı hem istasyon hem işletmeci snapshot'ı için doğrulanmalı. [Talep taslağı](DATA_PERMISSION_REQUESTS.md). |
| ChargeIQ | [Resmî site](https://www.chargeiq.com.tr/tr), [gizlilik/çerez politikası](https://www.chargeiq.com.tr/tr/gizlilik) veri lisansı değildir. | **Güncel istasyon paketinden ve güncelleme akışından kaldırıldı.** EPDK ham yanıtından yeniden üretim; eski eşleştirmeler/alanlar/kaynak ID'leri aktarılmadı. Yazılı izin alınmadı; eski kamuya açık kopyaların hak durumu çözülmüş sayılmaz. |
| OpenStreetMap / Overpass | [OSM telif](https://www.openstreetmap.org/copyright), [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/). | **Güncel istasyon paketinden ve güncelleme akışından kaldırıldı.** Yeni EPDK paketi OSM katkısı içermez; ODbL olarak etiketlenmez. Eski birleşik veritabanının ODbL yükümlülükleri ve dış kopyaları ayrıca açık kalır. |
| Open-Meteo Forecast / Elevation | [Koşullar](https://open-meteo.com/en/terms): ücretsiz API ticari ürünlere sunulmaz. | **Kaldırıldı.** Forecast/Elevation istemcileri, hava ayarı ve atıfları yoktur; hava önerileri kapalıdır. Rota rakım düzeltmesiz hesaplanır. Abonelik satın alınmadı. |
| Apple MapKit | [Developer Agreement, Attachment 6](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/). | **Kod karşılaştırması/düzeltmeler tamamlandı.** Harita, rota ve adres araması devam eder. [Sunum/saklama karşılaştırması](MAPKIT_TERMS_REVIEW.md); gerçek cihaz doğrulaması yayın planındadır. |
| Open Charge Map | [Geliştirici koşulları](https://openchargemap.io/develop): kullanıcı katkıları CC BY 4.0; ithal kaynaklar kendi lisanslarını korur. | Mevcut paket kaynaklarında yok; üst akış scraper'ında seçenek var. İleride eklenirse sağlayıcı/lisans alanları korunmalı ve görünür atıf yapılmalı. |
| Google Maps URL aktarımı | [Maps URLs](https://developers.google.com/maps/documentation/urls/get-started): yönlendirme URL'si için API anahtarı gerekmez. | SDK/veri kazıma yok; dış rota bağlantısı. Kullanıcı başlangıç noktası aktarımı politikada açıklandı. |
| Firebase | [Hizmet koşulları](https://firebase.google.com/terms), [gizlilik](https://firebase.google.com/support/privacy); kullanılan SDK manifestleri incelendi. | Üçüncü taraf teknik veri amaçları forma eklendi. Hesap/sözleşme kabulü ve üretim kurulumu bu statik incelemeyle doğrulanmış sayılmaz. |
| GitHub dosya/sayfa barındırma | [Hizmet koşulları](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service), [gizlilik](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement). | Kamuya açık depoda bulunmak, kaynak verilerin lisansını değiştirmez. Destek sayfası GitHub hesabı gerektirmeyen iletişim sunar. |
| iCloud Mail | [iCloud koşulları](https://www.apple.com/legal/internet-services/icloud/), [Apple gizlilik politikası](https://www.apple.com/legal/privacy/en-ww/). | Resmi destek posta kutusu; gönüllü iletişim açıklaması eklendi. Gönderim/teslimat testi veya yeni sözleşme kabulü yapılmadı. |


## EPDK yayın kararı

`Data/provider-rights.json` izin kaydıdır. `Scripts/validate_data_rights.py` EPDK-only kaynak şemasını, tile hash/sayılarını, işletmeci snapshot'ını, kapsamı, kanıt dosyası/hash'ini ve süreyi kontrol eder. Kapsamlar: `commercial_use`, `redistribution`, `derived_fields`, `offline_storage`. Yeni veri OSM içermediği için EPDK izninde ODbL uyumu şartı aranmaz; EPDK'nin kendi koşulları uygulanır. Lisans/atıf koşulları yanıt geldiğinde olduğu gibi kaydedilir, izin uydurulmaz.

- Archive için hem `commercialDataUseApproved=true` hem sağlayıcı gate'inin başarılı olması gerekir; tek başına plist bayrağı engeli kaldırmaz.
- Günlük workflow EPDK izni çözülene kadar sorgu/yayın yapmaz. Özel birleşik veri deposu ve deploy key bağımlılığı kaldırıldı.
- `build_station_tiles.py --publish-licensed` izinleri doğrular, ancak veriye kendiliğinden ODbL veya başka bir lisans vermez. Normal geliştirme build'i de EPDK dışı kaynağı reddeder.
- Kullanıcıya görünür EPDK kaynak bilgisi ile Apple bildirimleri korunur. Kanıtın içerik/kapsam değerlendirmesi insan incelemesidir; JSON değeri hak yaratmaz.
- EPDK izni ve MapKit cihaz kontrolleri tamamlandıktan sonra üretim bayrağı ve izin kaydı birlikte güncellenir. Yeni pakete geçmek önceki kamuya açık kopyaların hak durumunu kapatmaz.

## Teknik erişim sınırları

[EPDK kılavuzu](https://www.epdk.gov.tr/Detay/DownloadDocument?id=mqXhIJuluA8=) filtresiz sorguyu saatte bir, parametreli sorguyu dakikada bir ile sınırlar; importer filtresiz tek sorgu yapar ve otomatik tekrar denemez. Kamuya açık erişim ticari yeniden dağıtım izni değildir. İşletmeci snapshot'ı için de ayrı kullanılan endpoint'in koşulları gözetilir.
