# Veri izni talepleri — gönderilmeye hazır taslaklar

8 Ekim 2026. Bu metinler gönderilmedi; yanıt/izin alınmış sayılmaz. Sözleşme yapacak kişi/şirket adı talepte gerçek hak sahibi olarak belirtilmelidir. Uygulamanın ücretsiz indirilmesi ticari niteliğini değiştirmez.

## ChargeIQ

Muhatap: Borusan Otomotiv / ChargeIQ — [resmi iletişim](https://www.chargeiq.com.tr/tr/contact), info@chargeiq.com.tr.

Konu: ŞarjBul için ticari veri kullanımı ve yeniden dağıtım lisansı

ŞarjBul, iOS üzerinde sunulması planlanan ticari bir şarj istasyonu bulma ürünüdür. ChargeIQ kökenli istasyon kayıtları ve diğer kaynaklarla eşleşmiş alanlar için aşağıdaki kapsamda yazılı izin/sözleşme talep ediyoruz:

- İstasyon adı, konum, adres, operatör, soket, güç ve varsa fiyat/özellik alanlarının hangi yetkili arayüzden ve hangi sorgu sınırlarıyla alınabileceği.
- Verinin normalize edilmesi, eşleştirilmesi, tekilleştirilmesi, tahmin/puanlama alanlarında kullanılması ve türev alanların oluşturulması.
- iOS bundle'ı, çevrimdışı cache ve kamuya açık GitHub JSON/tile indirmeleri üzerinden ticari yeniden dağıtım.
- OpenStreetMap katkılarıyla birleşen veritabanının tamamının ODbL 1.0 altında, makine tarafından okunabilir ve ücretsiz indirilebilir biçimde sunulabilmesi. Yalnızca uygulama içinde görüntüleme izni bu dağıtım modelini karşılamaz.
- Üçüncü taraf içeriklerini lisanslama yetkiniz, gerekli atıflar, süre/bölge, güncelleme, saklama, sona erme ve geçmişte alınmış kopyaların kapsamı.

Mevcut incelemede 15.515 istasyonun 10.743'ünde ChargeIQ katkı izi vardır; ana kaynağı ChargeIQ olan kayıt sayısı 2.148'dir. Bu envanter izin verildiği anlamına gelmez. Uygun lisans yoksa ChargeIQ katkıları, eşleşmiş kayıtlardaki türev alanlar dahil yeniden oluşturularak kaldırılacaktır. Kullanılabilir lisans teklifinizi ve yetkili imzalı teyidinizi rica ederiz.

## EPDK

Başvuru: [EPDK Bilgi Edinme](https://www.epdk.gov.tr/Detay/Icerik/3-35291/bilgi-edinme). Teknik kaynak: [resmi servis listesi](https://www.epdk.gov.tr/Detay/Icerik/3-0-226/web-servisler).

Konu: Şarj istasyonu ve işletmeci lisans servislerinin ticari yeniden kullanım koşulları

ŞarjBul iOS ticari ürününde `sarjIstasyonlari` ve `sarjAgiIsletmeciLisansiSorgula` çıktılarının kullanımı için uygulanacak yazılı lisans/izin koşullarını rica ediyoruz. Teknik erişim, filtre ve sorgu sıklığı sınırlarından ayrı olarak aşağıdaki hakların tanınıp tanınmadığının belirtilmesini talep ediyoruz:

- Halka açık istasyon konumu/adresi, soket/güç bilgileri ile işletmeci unvanı, marka, lisans numarası ve geçerlilik bilgilerinin normalize edilmesi ve diğer kaynaklarla eşleştirilmesi.
- Ticari uygulamada gösterim, çevrimdışı saklama, iOS paketine dahil etme ve kamuya açık GitHub üzerinden JSON/tile yeniden dağıtımı.
- OSM ile birleşen veritabanının ODbL 1.0 altında tüm alanlarıyla ücretsiz indirilebilir sunulması; bu model için ek izin veya farklı bir mimari gerekip gerekmediği.
- Atıf, güncelleme/saklama, doğruluk, geri çekme, süre/bölge ve üçüncü taraf haklarına ilişkin zorunluluklar.

İncelenen pakette EPDK ana kaynaklı 13.117 istasyon ve ayrıca işletmeci lisans snapshot'ı vardır. Servislerin kamuya açık olması yeniden dağıtım izni olarak kabul edilmemektedir. İzin varsa dayanak metni ve kapsamını, yoksa yetkili başvuru sürecini bildirmenizi rica ederiz.

## Yanıt geldiğinde

İzin belgesinin aslı ve kapsam incelemesi güvenli biçimde saklanır. `Data/provider-rights.json` içindeki ilgili kayda kanıt dosyasının çalışma alanına göre yolu, SHA-256 değeri, `reviewed_at`, varsa `valid_until` ve doğrulanmış `scopes` yazılır. Gizli sözleşme dosyası kamuya açık repoya eklenmez; üretim doğrulamasına güvenli yolla sağlanır. `approved` ancak ticari kullanım, yeniden dağıtım, türev alanlar ve ODbL uyumu gerçekten kapsandığında kullanılır. İzin yoksa etiket silmek yerine yetkili ham kaynaktan yeniden üretim yapılır.
