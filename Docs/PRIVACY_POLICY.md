# ŞarjBul Gizlilik Politikası

Son güncelleme: 6 Ağustos 2026

ŞarjBul, yakındaki şarj istasyonlarını bulmak ve rota/varış şarjı hesaplamak için cihaz konumunu yalnızca kullanıcı isteğiyle kullanır. Varsayılan durumda konum bilgisi Firebase'e yazılmaz ve reklam amacıyla kullanılmaz. Kullanıcı konum izni vermeden adres, şehir veya koordinatla devam edebilir.

Hesap ekranındaki "Anonim talep paylaşımı" ayarı varsayılan olarak kapalıdır. Kullanıcı bu ayarı açarsa arama noktası cihaz üzerinde yaklaşık 11 km'lik hücreye yuvarlanır; Firebase'e ham enlem/boylam, e-posta veya kullanıcı kimliği içermeyen geçici bir olay gönderilir. Sunucu olayı aylık bölge toplamına ekledikten sonra siler. İstemciler bu toplamları okuyamaz. Operatörlerle yapılabilecek analizlerde yalnızca yeterli örnek sayısına ulaşmış toplu bölgeler kullanılmalıdır; bireysel hareket veya kullanıcı profili paylaşılmaz.

ŞarjBul giriş veya kayıt formu göstermez; e-posta ve şifre işlemez. Uygulama, favorileri ve bildirimleri güvenli biçimde ayırmak için ilk kullanımda anonim bir Firebase kimliği oluşturur ve oturumu cihazın Keychain alanında saklar. Kullanıcının gönderdiği istasyon durum bildirimi, bütünlük ve kötüye kullanım önlemleri için bu anonim kimlikle ilişkilendirilir. Diğer kullanıcılar ham kimliği ve kişisel kayıtları okuyamaz.

Fiyat, soket, adres ve gece güvenliği doğrulamaları kötüye kullanımı önlemek ve bağımsız kullanıcı sayısını hesaplamak için Firebase kullanıcı kimliğiyle ilişkilendirilir. Diğer kullanıcılar ham katkıları veya kimliği okuyamaz; yalnızca Cloud Function'ın ürettiği anonim doğrulama sayısı, güncellik ve güven özeti herkese açıktır.

Şarj fişi fotoğrafı Apple Vision ile cihaz üzerinde işlenir ve fotoğraf ŞarjBul sunucusuna yüklenmez. Okunan enerji ve harcama geçmişi cihazda saklanır. Kullanıcı fişi bir istasyonla eşleştirip katkı göndermeyi seçerse yalnızca hesaplanan birim fiyat istasyon doğrulama akışına yazılır.

Uzun yol planında rakım etkisini hesaplamak için rotadan örneklenmiş enlem/boylam noktaları Open-Meteo Elevation API'ye gönderilebilir. Bu isteğe e-posta, Firebase kimliği veya reklam tanımlayıcısı eklenmez. Ana ekran widget'ı ve Live Activity, en yakın istasyon özeti ile şarj bitiş zamanını Apple App Group alanında cihaz içinde paylaşır.

Kullanıcı Telegram, WhatsApp, e-posta veya browser uzantısı entegrasyonunu tercih ederse mesaj metni ve paylaştığı konum, istasyon aramasını yanıtlamak için ilgili kanal sağlayıcısından ŞarjBul Cloud Function'ına iletilir. ŞarjBul bu mesajı, kesin konumu veya e-posta adresini veritabanına kaydetmez. Kötüye kullanım sınırı için kanal kullanıcı değeri tek yönlü SHA-256 özeti halinde kısa süreli dakika kovasında tutulur ve zamanlanmış görevle silinir. Telegram, Meta/WhatsApp, e-posta sağlayıcısı ve browser kendi gizlilik koşullarına göre ayrıca veri işleyebilir; kullanıcı kullanacağı kanalı kendisi seçer.

Firebase Crashlytics, uygulama çökmesi ve teknik hata bilgilerini uygulama kararlılığını iyileştirmek amacıyla işleyebilir. ŞarjBul reklam takibi yapmaz, verileri reklam ağına satmaz ve üçüncü taraflar arası takip için kullanmaz. Firebase App Check, yetkisiz istemcilerin backend'e erişimini azaltmak için cihaz bütünlüğü belirteci kullanır.

Kullanıcı Profil ekranından bulut verilerini sıfırlayabilir. Bu işlem anonim Firebase kimliğini, favorileri, kullanıcı metasını, durum bildirimlerini, anonim talep paylaşımı hız sınırı metasını ve kimlikle ilişkili istasyon doğrulamalarını temizleyen sunucu işini başlatır; ardından uygulama kesintisiz kullanım için yeni bir anonim kimlik oluşturur. Cihazdaki şarj günlüğü uygulama silindiğinde veya uygulama verileri temizlendiğinde kaldırılır.

Sorular ve veri talepleri uygulamadaki Destek bağlantısı üzerinden iletilebilir.
