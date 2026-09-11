# App Store Connect — doldurulmuş gizlilik cevapları

Kontrol tarihi: 11 Eylül 2026. Bundle ID: `com.ozdemirbaris.sarjbul`.

**Durum:** Cevap seti kaynak kodu, Firebase 12.16.0 manifestleri ve sağlayıcı belgeleriyle karşılaştırılarak dolduruldu. Apple hesabıyla giriş denendi; Apple “Your Apple Account isn’t enabled for App Store Connect” (`INVALIDITCUSER`) hatası verdi. Uygulama ve App Privacy formuna erişilemedi; çevrimiçi kaydetme/yayımlama yapılmadı. Bu belge formun Apple'a gönderildiği anlamına gelmez.

Bu tablo mevcut özellikleri içeren hedef üretim sürümü içindir. Yerel `firebaseBackendReady=false` yapılandırmasında REST bulut yazımları kapalıdır; GoogleService dosyası varsa Crashlytics ayrı çalışır. Dağıtılacak binary ve backend son kez karşılaştırılmalıdır. Ticari yayın için ücretsiz Open-Meteo bağlantısı değiştirilir veya kaldırılırsa ilgili cevaplar yeniden güncellenmelidir.

## Temel form alanları

- Do you or your third-party partners collect data from this app? **Yes, we collect data from this app.**
- Privacy Policy URL: `https://github.com/ozdemirbariss-gif/elektriklisarj-ios/blob/main/Docs/PRIVACY_POLICY.md`
- Privacy Choices URL (isteğe bağlı): `https://github.com/ozdemirbariss-gif/elektriklisarj-ios/blob/main/Docs/SUPPORT.md`
- Support URL (sürüm bilgileri alanı): `https://github.com/ozdemirbariss-gif/elektriklisarj-ios/blob/main/Docs/SUPPORT.md`
- Destek e-postası: **sarjbul@icloud.com**.
- Her veri türünde tracking sorusu: **No**.
- Third-Party Advertising, Developer’s Advertising or Marketing, Product Personalization, Other Purposes: **seçili değil**. Cihaz içi kişiselleştirme sunucu verisi değildir.

## Veri türleri ve alt form cevapları

| Apple veri türü | Seçilecek amaçlar | Linked to the user | Tracking |
| --- | --- | --- | --- |
| Contact Info → Email Address | App Functionality | Yes | No |
| Location → Precise Location | App Functionality | No | No |
| Location → Coarse Location | Analytics | Yes | No |
| User Content → Customer Support | App Functionality | Yes | No |
| User Content → Other User Content | App Functionality | Yes | No |
| Search History | Analytics | Yes | No |
| Identifiers → User ID | App Functionality, Analytics | Yes | No |
| Identifiers → Device ID | App Functionality | Yes | No |
| Usage Data → Product Interaction | App Functionality, Analytics | Yes | No |
| Diagnostics → Crash Data | App Functionality | No | No |
| Diagnostics → Other Diagnostic Data | App Functionality, Analytics | No | No |

## Cevapların gerekçesi

- **Email Address / Customer Support:** Kullanıcı resmi adrese kendi isteğiyle yazarsa gönderen adresi, mesajı ve seçtiği ekler iCloud Mail'e ulaşır. Giriş için e-posta toplanmaz. Dış e-posta uygulaması mesajı gönderilmeden gösterir. Optional disclosure istisnasına dayanılmadan destek verisi beyan edildi.
- **Precise Location:** Hava durumu üç ondalıklı konum; rakım hesabı beş ondalıklı en fazla 80 rota noktası gönderir. Üç ondalık Apple tanımında hassas konumdur. Open-Meteo koordinat içerebilen günlükleri 90 gün tutabildiğinden anlık işleme istisnası uygulanmadı. ŞarjBul kimlik eklemez; ücretsiz API'nin kimliğe bağlamama açıklaması esas alındı. Lisanslı servis/proxy gelince bu karar yeniden incelenmelidir.
- **Coarse Location / Search History:** Varsayılan kapalı talep paylaşımında 0,1 derecelik hücre, arama tercihi, menzil/sonuç sayısı kovası ve zaman gönderilir; arama metni gönderilmez. Son olay yolu anonim UID altında hız sınırı kaydına bağlıdır; bu yüzden linked=Yes.
- **User ID:** Favori, bildirim, katkı, APNs ve silme isteği anonim Firebase UID kullanır. Analiz hız sınırı kayıtları da aynı UID'yi kullandığından Analytics eklendi. Anonim oturum kimlikle bağlantısız anlamına gelmez.
- **Device ID:** APNs token'ı UID ile kaydedilir; Firebase kurulum tanımlayıcıları ve App Attest doğrulama belirteçleri de işlenir. iOS hedefinde FirebaseMessaging/FCM SDK yoktur; APNs kaydı REST kullanır.
- **Other User Content / Product Interaction:** Favoriler, durum/yoğunluk bildirimleri, doğrulamalar ve isteğe bağlı birim fiyat katkıları işlevsellik içindir. İzinli olay/evre/süre kovaları analize gider. FirebaseSessions teknik oturum etkileşimleri de işler; App Functionality amacı bu nedenle dahildir.
- **Crash Data / Other Diagnostic Data:** Crashlytics çökme ve sadeleştirilmiş teknik hataları; SDK'lar cihaz/işletim sistemi/sürüm ve iletim ölçümlerini işler. Crashlytics manifesti App Functionality, FirebaseInstallations ve GoogleDataTransport manifestleri tanı verisinde Analytics bildirir. SDK manifestleri linked=No belirtir; ŞarjBul Crashlytics'e UID, istasyon, rota, konum veya serbest metin eklemez. Teknik kurulum kimlikleri Auth UID'ye uygulama tarafından bağlanmaz. `AppTelemetry` ham NSError userInfo, URL, mesaj ve metadata aktarımını kaldırır. Teknik SDK ölçümleri isteğe bağlı talep paylaşımından ayrıdır.

## Seçilmeyen türler

Health, Fitness, Contacts, Photos or Videos, Payment Info, Purchase History, Browsing History, Audio Data ve diğer türler uygulama tarafından sunucuda toplanmıyor. HealthKit/EventKit içeriği, fiş OCR ve şarj harcama geçmişi cihazdadır. Kullanıcının destek yazışmasına eklediği içerik Customer Support altında açıklanır. Birim fiyat katkısı Other User Content'tir; fiş fotoğrafı yüklenmez.

MapKit arama/rota işleme ve dış Apple/Google Maps aktarımı politikada açıklanır. Apple'ın kendisinin topladığı veriyi geliştiricinin ayrıca beyan etmesi gerekmez; ŞarjBul'un ayrıca kaydettiği veri bu istisnaya girmez. Telegram/WhatsApp/browser/e-posta gateway'leri iOS hedefinde çağrılmıyor; sonradan bağlanırsa ayrı inceleme gerekir.

Uygulama ve widget UserDefaults App Group erişimi `1C8F.1`; uygulamanın özel alanı `CA92.1`. Widget sunucuya veri göndermiyor.

[Veri akışı karşılaştırması](PRIVACY_DATA_FLOW_AUDIT.md) · [Sağlayıcı koşulları](DATA_PROVIDER_TERMS.md).

Kaynaklar: [Apple App Privacy](https://developer.apple.com/app-store/app-privacy-details/), [Firebase veri toplama rehberi](https://firebase.google.com/docs/ios/app-store-data-collection), [Firebase gizlilik ve saklama](https://firebase.google.com/support/privacy), [Open-Meteo koşulları](https://open-meteo.com/en/terms). Kullanılan 12.16.0 SDK manifestleri ayrıca incelendi.
