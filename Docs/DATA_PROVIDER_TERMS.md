# Veri sağlayıcı koşulları — ticari yayın kontrolü

İnceleme: **8 Ekim 2026**. ŞarjBul ticari üründür. **Ticari veri kullanım onayı hâlâ yoktur**: Kullanıcı ChargeIQ/EPDK için yazılı izin bulunmadığını teyit etti; birleşik veritabanının ODbL uyumu da açık. `commercialDataUseApproved=false` kalır. Bu belge, izin verilmiş gibi yorumlanamaz.

## Güncel envanter

`23f21eb` paketinde **15.515** kayıt: EPDK 13.117, ChargeIQ 2.148, OSM 250 ana kaynaklıdır. `kaynak` ve `kaynaklar` birlikte sayıldığında ChargeIQ **10.743**, OSM **616** kayda katkı sağlar. İşletmeci lisans snapshot'ı da EPDK verisidir. Kontrol: `python3 Scripts/validate_data_rights.py --inventory`. İstasyon içeriği bu değişiklikte silinmedi/yeniden lisanslanmadı; önceki kamuya açık kopyalar da geri çekilmiş sayılmaz.

| Sağlayıcı | Resmi dayanak | Gerçek durum / uygulanan değişiklik |
| --- | --- | --- |
| Open-Meteo Forecast / Elevation | [Koşullar](https://open-meteo.com/en/terms): ücretsiz API ticari ürünlere sunulmaz. Verinin CC BY 4.0 olması API erişim hakkını değiştirmez. | **Kaldırıldı.** Forecast/Elevation ağ istemcileri, hava ayarı ve kaynak atıfları çıkarıldı. Eski hava tercihi ve hava durumuna bağlı takvim önerileri kapatılır. Rota rakım düzeltmesiz hesaplanır; arayüz bunu belirtir. Abonelik satın alınmadı. |
| ChargeIQ | [Resmi site](https://www.chargeiq.com.tr/tr), [gizlilik/çerez politikası](https://www.chargeiq.com.tr/tr/gizlilik) veri lisansı değildir. | **İzin bekleniyor.** İncelenen açık metinler ticari/türev veri dağıtım hakkı doğrulamıyor. Yazılı izin; kamuya açık JSON dağıtımı ve ODbL uyumunu kapsamalı. [Somut talep taslağı](DATA_PERMISSION_REQUESTS.md). |
| EPDK | [Resmi servisler](https://www.epdk.gov.tr/Detay/Icerik/3-0-226/web-servisler) kullanılan istasyon ve lisans endpoint'lerini listeler. | **İzin bekleniyor.** Teknik erişim, ticari yeniden dağıtım lisansı değildir. Hem istasyon hem işletmeci snapshot'ı için kapsamlı teyit gerekir. [Talep taslağı](DATA_PERMISSION_REQUESTS.md). |
| OpenStreetMap / Overpass | [OSM telif](https://www.openstreetmap.org/copyright), [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/), özellikle §§4.2–4.6. | **Harita, sonuç listesi ve paylaşım görselinde atıf mevcut; birleşik veri lisans uyumu bekleniyor.** Diğer sağlayıcıların hakları doğrulanmadan tüm pakete lisans verilmez. Aşağıdaki dağıtım yolu hazır; henüz lisanslı paket üretilmedi. |
| Apple MapKit | [Developer Agreement, Attachment 6](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/). | **Kod karşılaştırması ve düzeltmeler tamamlandı.** [Sunum/saklama karşılaştırması](MAPKIT_TERMS_REVIEW.md). Native harita, geçici oturum verisi ve eski kayıt temizliği; cihaz doğrulaması yayın planındadır. |
| Open Charge Map | [Geliştirici koşulları](https://openchargemap.io/develop): kullanıcı katkıları CC BY 4.0; ithal kaynaklar kendi lisanslarını korur. | Mevcut paket kaynaklarında yok; üst akış scraper'ında seçenek var. İleride eklenirse sağlayıcı/lisans alanları korunmalı ve görünür atıf yapılmalı. |
| Google Maps URL aktarımı | [Maps URLs](https://developers.google.com/maps/documentation/urls/get-started): yönlendirme URL'si için API anahtarı gerekmez. | SDK/veri kazıma yok; dış rota bağlantısı. Kullanıcı başlangıç noktası aktarımı politikada açıklandı. |
| Firebase | [Hizmet koşulları](https://firebase.google.com/terms), [gizlilik](https://firebase.google.com/support/privacy); kullanılan SDK manifestleri incelendi. | Üçüncü taraf teknik veri amaçları forma eklendi. Hesap/sözleşme kabulü ve üretim kurulumu bu statik incelemeyle doğrulanmış sayılmaz. |
| GitHub dosya/sayfa barındırma | [Hizmet koşulları](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service), [gizlilik](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement). | Kamuya açık depoda bulunmak, kaynak verilerin lisansını değiştirmez. Destek sayfası GitHub hesabı gerektirmeyen iletişim sunar. |
| iCloud Mail | [iCloud koşulları](https://www.apple.com/legal/internet-services/icloud/), [Apple gizlilik politikası](https://www.apple.com/legal/privacy/en-ww/). | Resmi destek posta kutusu; gönüllü iletişim açıklaması eklendi. Gönderim/teslimat testi veya yeni sözleşme kabulü yapılmadı. |

## OSM birleşik veritabanı ve dağıtım

Birleşik kayıtlar için ihtiyatlı yaklaşım türetilmiş veritabanıdır; sadece OSM satırlarını sunmak yeterli kabul edilmez. OSM verisi ticari kullanılabilir, ancak atıf, ODbL bildirimi, paylaşım ve makine tarafından okunabilir erişim yükümlülükleri korunmalıdır. Başka kaynakları ODbL ile bağdaşmayan haklarla bu bütüne eklemek uygun değildir. Bu nedenle ChargeIQ/EPDK izni gelmeden birleşik paketi ODbL olarak etiketlemiyoruz.

İzinler tamamlandıktan sonra `build_station_tiles.py --publish-licensed` her alanı içeren `StationTiles/stations-odbl.json`, ODbL bağlantılı `LICENSE.md` ve manifestte `license_url`, `attribution`, `database_offer_url` üretir. Tüm dosyalar aynı veri commit'inde, ücretsiz HTTPS erişimiyle sunulur. Uygulama kaynak ekranı bu veri erişim sayfasına bağlantı verir. Gate, indirme teklifinin bütün kayıtlara/alanlara eşitliğini denetler. Kodun lisansı bu veritabanı lisansının yerine geçmez.

## Yayın kararı ve kapatma ölçütleri

`Data/provider-rights.json` makine tarafından okunan izin kaydıdır. `Scripts/validate_data_rights.py` birincil kaynakla birlikte tüm katkı kaynaklarını, işletmeci snapshot'ını, kapsamı, kanıt dosyası/hash'ini, süreyi ve ODbL dağıtım teklifini kontrol eder. Kaynağı bilinmeyen veri kapalı kalır. Kanıtın içeriğini hukuken değerlendirmek insan incelemesidir; bir JSON değeri hak yaratmaz.

- Archive, hem `commercialDataUseApproved=true` hem de sağlayıcı gate'inin başarılı olmasını ister. Sadece plist bayrağı açmak engeli kaldırmaz.
- Günlük veri workflow'u izinler çözülene kadar yeni veri çekme/yayımlama aşamasına geçmez. Lisanslı yayın modu aday kaynağı da tekrar denetler.
- ChargeIQ/EPDK için imzalı kapsamlı izin veya yetkili kaynaktan türev izlerini de temizleyen yeniden üretim gerekir. Mevcut birleşik kayıtlardan yalnızca etiket kaldırılmaz.
- OSM için diğer sağlayıcılarla uyum, tam veri teklifi ve lisans bildirimi tamamlanır; MapKit gerçek cihaz sunum/temizlik kontrolleri yapılır. Ardından izin kaydı ve üretim bayrağı birlikte güncellenir.

13 Eylül teknik incelemesi: [EPDK kılavuzu](https://www.epdk.gov.tr/Detay/DownloadDocument?id=mqXhIJuluA8=) filtresiz sorguyu saatte bir, parametreli sorguyu dakikada bir ile sınırlar; importer bu teknik sınırı gözetir. Önceki incelemede kılavuzda açık ticari yeniden dağıtım hükmü bulunmamıştır. 8 Ekim'de servis listesi yeniden okundu; kılavuz web okuyucuda `application/octet-stream` nedeniyle açılmadı. Teknik doğrulama yeni bir izin olarak sayılmadı.
