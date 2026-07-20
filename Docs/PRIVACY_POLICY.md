# ŞarjBul Gizlilik Politikası

Son güncelleme: 19 Temmuz 2026

ŞarjBul, yakındaki şarj istasyonlarını bulmak ve rota/varış şarjı hesaplamak için cihaz konumunu yalnızca kullanıcı isteğiyle kullanır. Varsayılan durumda konum bilgisi Firebase hesabına yazılmaz ve reklam amacıyla kullanılmaz. Kullanıcı konum izni vermeden adres, şehir veya koordinatla devam edebilir.

Hesap ekranındaki "Anonim talep paylaşımı" ayarı varsayılan olarak kapalıdır. Kullanıcı bu ayarı açarsa arama noktası cihaz üzerinde yaklaşık 11 km'lik hücreye yuvarlanır; Firebase'e ham enlem/boylam, e-posta veya kullanıcı kimliği içermeyen geçici bir olay gönderilir. Sunucu olayı aylık bölge toplamına ekledikten sonra siler. İstemciler bu toplamları okuyamaz. Operatörlerle yapılabilecek analizlerde yalnızca yeterli örnek sayısına ulaşmış toplu bölgeler kullanılmalıdır; bireysel hareket veya kullanıcı profili paylaşılmaz.

Hesap açıldığında e-posta adresi ve Firebase kullanıcı kimliği; giriş, oturum yenileme, favori eşitleme ve durum bildirimi işlevleri için işlenir. Kullanıcının gönderdiği istasyon durum bildirimi, bildirimin bütünlüğünü ve kötüye kullanım önlemlerini sağlamak için kullanıcı kimliğiyle ilişkilendirilir. Diğer kullanıcılar ham kullanıcı kimliğini ve kişisel yorum kayıtlarını okuyamaz.

Fiyat, soket, adres ve gece güvenliği doğrulamaları kötüye kullanımı önlemek ve bağımsız kullanıcı sayısını hesaplamak için Firebase kullanıcı kimliğiyle ilişkilendirilir. Diğer kullanıcılar ham katkıları veya kimliği okuyamaz; yalnızca Cloud Function'ın ürettiği anonim doğrulama sayısı, güncellik ve güven özeti herkese açıktır.

Şarj fişi fotoğrafı Apple Vision ile cihaz üzerinde işlenir ve fotoğraf ŞarjBul sunucusuna yüklenmez. Okunan enerji ve harcama geçmişi cihazda saklanır. Kullanıcı fişi bir istasyonla eşleştirir ve hesabıyla katkı göndermeyi seçerse yalnızca hesaplanan birim fiyat istasyon doğrulama akışına yazılır.

Uzun yol planında rakım etkisini hesaplamak için rotadan örneklenmiş enlem/boylam noktaları Open-Meteo Elevation API'ye gönderilebilir. Bu isteğe e-posta, Firebase kimliği veya reklam tanımlayıcısı eklenmez. Ana ekran widget'ı ve Live Activity, en yakın istasyon özeti ile şarj bitiş zamanını Apple App Group alanında cihaz içinde paylaşır.

Firebase Crashlytics, uygulama çökmesi ve teknik hata bilgilerini uygulama kararlılığını iyileştirmek amacıyla işleyebilir. ŞarjBul reklam takibi yapmaz, verileri reklam ağına satmaz ve üçüncü taraflar arası takip için kullanmaz. Firebase App Check, yetkisiz istemcilerin backend'e erişimini azaltmak için cihaz bütünlüğü belirteci kullanır.

Kullanıcı uygulama içindeki Hesap ekranından hesabını silebilir. Bu işlem Firebase hesabını, favorileri, kullanıcı metasını, durum bildirimlerini, anonim talep paylaşımı hız sınırı metasını ve kullanıcı kimliğiyle ilişkili istasyon doğrulamalarını temizleyen sunucu işini başlatır. Cihazdaki şarj günlüğü uygulama silindiğinde veya uygulama verileri temizlendiğinde kaldırılır.

Sorular ve veri talepleri uygulamadaki Destek bağlantısı üzerinden iletilebilir.
