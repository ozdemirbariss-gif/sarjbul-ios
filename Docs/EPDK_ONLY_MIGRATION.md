# Yalnızca EPDK istasyon verisine geçiş

8 Ekim 2026. Kullanıcı yalnızca EPDK istasyon verisi kullanılmasını istedi. Bu değişiklik EPDK ticari kullanım/yeniden dağıtım izni değildir; `commercialDataUseApproved=false` kalır.

## Kaynak ve yeniden üretim

- Resmî `https://apigateway.epdk.gov.tr/sarjIstasyonlari` yanıtı 2026-10-08T10:34:18.525542+00:00 tarihinde alındı. Python istemcisi TLS sertifika zinciri doğrulamasında HTTP isteği gönderilmeden durdu; sistem `curl` istemcisiyle sertifika doğrulaması korunarak tek HTTP sorgusu yapıldı. Otomatik yeniden deneme yoktur.
- 16.980 istasyonun 13.129'u `HALKA_ACIK`, 3.851'i `OZEL`. Yalnızca halka açık kayıtlar üretildi; 36.391 soket bilgisi korunur. Geçersiz koordinat yoktur.
- Orijinal HTTP yanıtı SHA-256: `a3daccc3401cfd3bed5dcbf145410444cad4a565dc3d00a1563eaf5f07d80a0c`.
- Yanıtın `data` alanının sıralı JSON özeti ve gözlem zamanı [ingestion raporunda](../Data/epdk-ingestion-report.json). Ham yanıt geliştirme sırasında `/tmp/sarjbul-epdk-only-response.json` içinde tutuldu; özel istasyonlar uygulama paketine eklenmez.
- `update_epdk_stations.py` yalnızca ham EPDK yanıtını normalize eder. Önceki birleşik kayıtlar, eşleştirme, mesafe/isim eşleştirmesi, ek kaynak deposu ve `epdk-identities.json` girdi olarak kullanılmaz; eski kimlik tablosu kaldırıldı.
- Her alan EPDK yanıtından veya açık normalizasyon kurallarından üretilir. `source_ids` yalnızca EPDK numarasını, `kaynak`/`kaynaklar` yalnızca `epdk` değerini içerir. ID doğrudan `ŞRJ/123` → `epdk_123` biçimindedir. Fiyat bilinmiyor kalır; canlı durum, eski güncelleme saati veya çalışma saati aktarılmaz.

## Önceki paketle fark

Referans: `02cd7c88c32993ea77fef93fa09bdb58bac1508d`.

- Önceki 15.515 kayıttan EPDK dışı ana kaynaklı 2.398 kayıt yeni envantere alınmaz.
- Güncel EPDK yanıtında önceki 13.117 EPDK istasyonuna göre 14 yeni ve 2 kaldırılmış istasyon numarası vardır. Sonuç: 13.129 kayıt, 61 geohash tile.
- Eski EPDK kayıtlarının 8.609'unda kullanılan üçüncü taraf kökenli uygulama ID'si resmî numaraya geçti. Bu kimliklere bağlı eski favori, son rota, paylaşım bağlantısı ve topluluk eşleşmeleri otomatik taşınmaz; ilgili istasyon yeniden seçilmelidir. Kişisel favori/geçmiş verisi silinmez. EPDK ID'si zaten kanonik olan istasyonlar aynı kimlikle devam eder.
- Eski otomatik öneriler tam istasyon nesnesi içerebildiği için bir defalık migration ile kaldırılır. Kişisel şarj günlüğü ve hesap verileri korunur.

## Tekrar karışmasını önleyen kontroller

- Builder, yayın gate'i ve uygulama; EPDK dışı kaynak, ikincil kaynak ID'si, eski uygulama ID'si ve normalizasyon şeması dışındaki alanları reddeder. Tile hash/sayı kontrolü korunur.
- Manifest `source_policy=epdk-only-v1` taşır. Uygulamanın yeni cache alanı `SarjBul/EPDKStationTiles-v1`; önceki birleşik tile/tek JSON cache'i temizlenir. Uygun olmayan yeni cache çevrimdışıyken bundle'a döner. Geçersiz uzak paket son geçerli EPDK paketini değiştirmez.
- Günlük workflow özel canonical depoyu/anahtarı kullanmaz. EPDK izin gate'i geçmeden ağ sorgusu veya otomatik yayın yapmaz; aday paket yayın öncesinde tekrar denetlenir.
- Uygulama, sonuç listesi, harita ve paylaşım görselinde istasyon kaynağı EPDK'dir. Apple harita bildirimleri korunur.

## Hakların sınırı

ChargeIQ ve OSM `removed` kaydı yalnızca güncel uygulama envanteri/akışı için geçerlidir; izin alınmış veya geçmiş kamuya açık kopyaların hakları kapanmış sayılmaz. Git geçmişi yeniden yazılmadı, eski sürümler ve dış projeler geri çekilmedi. Yeni pakete ODbL etiketi veya lisansı verilmez. EPDK'nin istasyon ve işletmeci lisans verisi için ticari kullanım, çevrimdışı saklama, türev alanlar ve kamuya açık dağıtım kapsamı hâlâ doğrulanmalıdır. [Güncel hak durumu](DATA_PROVIDER_TERMS.md).
