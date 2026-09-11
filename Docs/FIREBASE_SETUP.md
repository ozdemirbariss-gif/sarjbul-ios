# Firebase Kurulumu

1. Firebase Console'da iOS uygulamasını `com.ozdemirbaris.sarjbul` bundle kimliğiyle oluştur.
2. `GoogleService-Info.plist` dosyasını indirip `SarjBul/Resources/` altına ekle. Dosya git'e alınmaz.
3. `AppConfig.sample.plist` dosyasını `AppConfig.plist` olarak oluştur; Realtime Database URL ve Firebase iOS yapılandırmasındaki API Key alanlarını doldur. `supportEmail` alanına kullanıcılara açık destek adresini gir ve destek/gizlilik URL'lerini doğrula. `firebaseBackendReady` alanını `false` tut; yapılandırma dosyaları tek başına hizmetlerin hazır olduğunu göstermez.
4. Authentication içinde Anonymous sağlayıcısını aç. Email/Password sağlayıcısı bu sürümde kullanılmaz.
5. App Check içinde iOS uygulaması için App Attest sağlayıcısını kaydet. Debug build'in konsola yazdığı debug tokenı yalnızca geliştirme ortamına ekle.
6. [Açık backend işlerini](RELEASE_CHECKLIST.md#backend-yayını-öncesindeki-açık-işler) tamamla. Hesap sahibinin Blaze planı kararı, Firebase CLI oturumu ve doğru proje doğrulandıktan sonra yalnızca iOS işlevlerini ve kuralları dağıt:

   ```bash
   firebase deploy --project sarjbul-ios-f57e6 --only database,functions:aggregateStationStatus,functions:aggregateStationContributions,functions:aggregateSearchDemand,functions:deleteAccountData,functions:cleanupAnalyticsData
   ```

   Genel `--only functions` komutu tarayıcı/e-posta/Telegram/WhatsApp geçitlerini de kapsar; iOS hazırlığında kullanılmaz. Cloud Functions dağıtımı [Blaze gerektirir](https://firebase.google.com/docs/functions/get-started). Spark üzerindeki kilitli veritabanı kurulumu işlevlerin yayımlandığı anlamına gelmez.
7. Backend dağıtıldıktan ve test ortamında doğrulandıktan sonra yerel `firebaseBackendReady` alanını `true` yaparak cihaz testine başla. iOS build'inden doğrulanmış App Check istekleri geldiğini gördükten sonra Realtime Database için App Check enforcement'ı aç.
8. Anonim oturum oluşturma, favori, rapor, token yenileme ve Profil ekranındaki bulut verisi sıfırlama akışlarını gerçek cihazda test et.
9. Bir önceki adımdaki testlerden biri başarısızsa `firebaseBackendReady` alanını tekrar `false` yap. Üretim ayarını yalnızca tüm testler tamamlanınca hazır say. `python3 Scripts/validate_release.py --production` çalıştır. Bu kontrol bundle kimliği, API key, iOS app ID/sender ID, varsa iki dosyadaki veritabanı adresi, destek alanları ve backend hazırlık onayını doğrular. Canlı yetkilendirme veya App Check doğrulamasının yerine geçmez.

Apple Developer üyeliği olmadan Firebase Console'da iOS uygulamasını kaydedebilir ve iki yapılandırma dosyasını hazırlayabilirsin. Üretim App Attest/APNs yetkilerinin gerçek cihazda doğrulanması ise Apple imzalama adımından sonra yapılır. Firebase iOS yapılandırması istemci kimlikleri içerir; güvenlik erişim kuralları, App Check ve yetkilendirmeyle sağlanır. Servis hesabı özel anahtarı veya APNs sağlayıcı özel anahtarı uygulama paketine konulmaz.

Kurallar ham yorum ve istasyon katkılarını yalnızca kaydın sahibi için okunabilir yapar; herkese açık istemci yalnızca `station_status` ve anonim `station_insights` özetlerini okuyabilir. Bu özetlere istemciden yazılamaz, ikisi de Cloud Function tarafından üretilir. Durum raporu 60 saniye, veri doğrulaması 30 saniye, açık rızalı talep olayı 5 dakika, ürün etkileşimi olayı 60 saniye kullanıcı başı hız sınırına sahiptir. `demand_heatmap` istemciler tarafından okunamaz veya yazılamaz.

Yeni kaydın atomik `PATCH` isteği aynı UID'nin ilgili metadata yoluna `lastMutationPath` ve Firebase sunucu zamanını (`{".sv":"timestamp"}`) yazar. Hız sınırı cihazdaki eski olay tarihine değil sunucunun teslim alma zamanına göre uygulanır. Metadata silinemez, zamanı geriye alınamaz ve tek işleme birden fazla yeni kayıt eklenemez. İstemci, yetki hatası sonrasında yalnızca kendi metadata kaydında devam eden başka bir gönderim sınırı doğrulanırsa hatayı tekrar denenebilir olarak sınıflandırır; çevrimdışı kuyruk bu kaydı korur. Analiz metadata kayıtları hesap silme işleviyle veya 7 gün sonra günlük temizleme göreviyle kaldırılır.

10 Eylül 2026 konsol durumu: `sarjbul-ios-f57e6`, Spark; `https://sarjbul-ios-f57e6-default-rtdb.europe-west1.firebasedatabase.app/`, kilitli kurallar; Anonymous etkin. Yerel plistler Git dışında hazırdır. Üretim App Check, Functions, destek e-postası ve cihaz testi henüz tamamlanmamıştır.

## Sunucu onaylı silme ve analiz temizliği

- İstemci yalnızca `status: pending` olan kendi silme isteğini oluşturabilir ve kendi durumunu okuyabilir. İstek mevcutken eski UID'nin tüm özel yazımları, birebir tekrarlar dahil, engellenir.
- `deleteAccountData`, UID'ye bağlı kayıtları ve analiz olaylarıyla kimlik bağlantısını kaldıran atomik güncellemeyle birlikte `completed` onayını yazar. Hatalar yeniden denenir; temizliği yarıda kalan istek beklemede kalır. İstemci onayı Keychain'e kaydeder, sonra Authentication kimliğini siler ve yeni anonim oturum açar. Bağlantı kesilirse tekrar aynı işlem sürdürülür.
- Onay istemciye hiç ulaşmadan eski oturum tamamen geçersiz hale gelirse uygulama temizliğin tamamlandığını varsaymaz; istek destek tarafından sunucuda doğrulanmalıdır.
- `aggregateSearchDemand` aynı olayın SHA-256 özetini ve bölge sayaçlarını tek transaction içinde yazar. Ham olayın kaldırılması tekilleştirme kaydını kaldırmaz. 7 günden eski olaylar işlenmez; özetin 8 günlük saklanması gecikmiş tekrarların ikinci kez sayılmasını engeller. Transaction şu an `demand_heatmap` kökünde çalışır; trafik büyüdüğünde çekişme ve boyut izlenmelidir.
- `cleanupAnalyticsData` her 24 saatte çalışır. Ham analiz olayları ve analiz hız sınırı kayıtları 7 gün, tekilleştirme kayıtları 8 gün sonra temizliğe girer. Sayfa boyutu 500, her koleksiyon için çalışma başına sınır 20 sayfadır. Sınır aşılırsa hata ve yeniden deneme üretilir; kalıcı iş kuyruğu birikmesi operasyonel takip gerektirir.
- Tamamlanmış silme kaydı en az 7 gün tutulur; görev Authentication kimliğini idempotent biçimde siler ve bu doğrulamadan en az 2 saat sonra kaydı kaldırır. Böylece eski erişim belirteciyle yeni yazım açılamaz. Kimliksiz toplamlar kullanıcı sıfırlamasıyla kaldırılmaz.
- Yerel test: `cd firebase/functions && npm run test:rules` (Java 21; yalnızca demo emülatörü). Üretime geçmeden dağıtılan beş işlevin günlüklerini, Scheduler çalışmasını, silme onayını ve App Check davranışını gerçek cihazla doğrula.
