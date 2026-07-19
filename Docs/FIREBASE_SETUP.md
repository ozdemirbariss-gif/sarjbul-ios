# Firebase Kurulumu

1. Firebase Console'da iOS uygulamasını `com.ozdemirbaris.sarjbul` bundle kimliğiyle oluştur.
2. `GoogleService-Info.plist` dosyasını indirip `SarjBul/Resources/` altına ekle. Dosya git'e alınmaz.
3. `AppConfig.sample.plist` dosyasını `AppConfig.plist` olarak oluştur; Realtime Database URL ve Web API Key alanlarını doldur.
4. Authentication içinde Email/Password sağlayıcısını aç ve e-posta enumerasyon korumasını etkinleştir.
5. App Check içinde iOS uygulaması için App Attest sağlayıcısını kaydet. Debug build'in konsola yazdığı debug tokenı yalnızca geliştirme ortamına ekle.
6. Blaze planı ve Firebase CLI hazır olduğunda proje kökünde `firebase deploy --only database,functions` çalıştır. Bu adım `database.rules.json`, durum özeti tetikleyicisi ve hesap verisi temizleme işini yayınlar.
7. iOS build'inden doğrulanmış App Check istekleri geldiğini gördükten sonra Realtime Database için App Check enforcement'ı aç.
8. Auth, favori, rapor, token yenileme ve uygulama içi hesap silme akışlarını gerçek cihazda test et.

Kurallar ham yorumları yalnızca kaydın sahibi için okunabilir yapar; herkese açık istemci yalnızca `station_status` özetini okuyabilir. İstasyon özetine istemciden yazılamaz, özet Cloud Function tarafından üretilir.
