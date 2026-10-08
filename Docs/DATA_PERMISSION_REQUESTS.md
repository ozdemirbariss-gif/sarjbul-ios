# EPDK veri izni talebi — gönderilmeye hazır taslak

8 Ekim 2026. Bu metin gönderilmedi; yanıt/izin alınmış sayılmaz. Başvuruda uygulamanın sahibi kişi/şirket adı kullanılmalıdır. Uygulamanın ücretsiz indirilmesi ticari niteliğini değiştirmez.

Güncel istasyon envanteri yalnızca EPDK içerir; ChargeIQ/OSM için yeni kullanım izni talebi bu sürümün yayın koşulu değildir. Geçmiş birleşik kopyaların hak durumu [geçiş kaydında](EPDK_ONLY_MIGRATION.md) ayrıca açık tutulur.

## Başvuru

[EPDK Bilgi Edinme](https://www.epdk.gov.tr/Detay/Icerik/3-35291/bilgi-edinme) sayfasındaki “Bilgi Edinme Başvurusu Yap” bağlantısı CİMER'e yönlendirir. Teknik kaynak: [resmî servis listesi](https://www.epdk.gov.tr/Detay/Icerik/3-0-226/web-servisler).

Konu: Şarj istasyonu ve işletmeci lisans servislerinin ticari yeniden kullanım koşulları

ŞarjBul iOS ticari ürününde `sarjIstasyonlari` ve `sarjAgiIsletmeciLisansiSorgula` çıktılarının kullanımına uygulanacak mevcut lisans/izin koşullarını ve ilgili dayanak belgelerini talep ediyoruz. Teknik erişim ve sorgu sıklığı sınırlarından ayrı olarak aşağıdaki kullanımların kapsamda olup olmadığının belirtilmesini rica ediyoruz:

- Halka açık istasyon adı, konumu, adresi, işletmeci, soket ve güç bilgilerinin normalize edilmesi, özetlenmesi, filtre/sıralama/puanlama ve rota planlama için türev alanlar oluşturulması.
- İşletmeci unvanı, marka, lisans numarası ve geçerlilik bilgilerinin uygulamada lisans doğrulama amacıyla kullanılması.
- Ticari iOS uygulamasında gösterim, çevrimdışı saklama ve uygulama paketine dahil etme.
- Uygulama güncellemesi için kamuya açık GitHub üzerinden makine tarafından okunabilir JSON/tile dosyaları şeklinde yeniden dağıtım. Yalnızca uygulama içi gösterim izni bu modeli karşılamayacaktır.
- Atıf, güncelleme/saklama, doğruluk, geri çekme, süre/bölge, üçüncü taraf hakları ve geçmişte alınmış/yayımlanmış kopyalara ilişkin koşullar.

8 Ekim 2026 paketinde 13.129 halka açık EPDK istasyonu ve ayrıca EPDK işletmeci lisans snapshot'ı vardır. Güncel paket başka istasyon veri tabanıyla birleştirilmez; OSM katkısı veya ODbL lisansı kullanılmaz. Harita/rota/adres araması Apple MapKit ile ayrı olarak sağlanır.

Servislerin kamuya açık olması ticari yeniden dağıtım izni olarak kabul edilmemektedir. Bu kullanımlara izin veren mevcut koşulları ve belgeleri; ek izin gerekiyorsa yetkili birim ve başvuru sürecini bildirmenizi rica ederiz.

## Yanıt geldiğinde

İzin belgesinin aslı ve kapsam incelemesi güvenli biçimde saklanır. `Data/provider-rights.json` EPDK kaydına kanıtın çalışma alanındaki yolu, SHA-256 değeri, `reviewed_at`, varsa `valid_until` ve doğrulanmış `commercial_use`, `redistribution`, `derived_fields`, `offline_storage` kapsamları yazılır. Gizli sözleşme dosyası kamuya açık repoya eklenmez; doğrulama ortamına güvenli biçimde sağlanır. `approved` yalnızca kapsam gerçekten karşılanıyorsa kullanılır. EPDK-only paket için ODbL uyumu istenmez; EPDK'nin yanıtındaki şartlar aynen uygulanır. İzin tamamlanmadan `commercialDataUseApproved` açılmaz.
