# İlk sürüm durumu — 9 Ekim 2026

## Uygulama kapsamı

- İstasyon araması seçilen soket, güç, operatör, metin ve menzil koşullarını korur. Boş sonuç, ana ekranda açıklanır ve filtreler sonuç listesi boşken de açılır. Panelde istasyon adı/adres/operatör araması, seçili operatörü kaldırma ve açık Sıfırla/Uygula adımları bulunur.
- İstasyon paketi doğrudan EPDK yanıtından yeniden üretildi: 13.129 halka açık kayıt, 61 tile. ChargeIQ/OSM ve özel kaynak deposu bağımlılıkları kaldırıldı; EPDK izni bekleniyor. [Geçiş kaydı](EPDK_ONLY_MIGRATION.md), [güncel doğrulama](DATA_RIGHTS_VALIDATION.md).
- İstasyon manifesti ve 61 döşeme güncel, kamuya açık `sarjbul-ios` deposundan sunulur; özel canonical veri deposu uygulamanın varsayılan HTTP kaynağı değildir. Gizlilik, kullanım koşulları ve destek belgeleri herkese açık GitHub Pages HTTPS adreslerine taşındı; uygulama varsayılanları, örnek yapılandırma ve mağaza metinleri güncellendi. [Yayın ve erişim doğrulaması](PUBLIC_LINKS_STATUS.md).
- Apple Maps / Google Maps aktarımı ve navigasyon uygulaması tercihini hatırlama korunur. Manuel başlangıç konumu haritalara aktarılır; cihaz konumu seçiliyse canlı konum kullanılır.
- Ana öneri, istasyon kartı ve detay aynı fiyat/müsaitlik açıklamasını kullanır. Katalog gözlem tarihi tarife teyit tarihi değildir; fiyat tarihi bilinmiyorsa açıkça bilinmiyor gösterilir.
- Operatör akışı en fazla 15 dakikalık ve geçerli soket sayımlıysa güncel sayılır. Gelecek tarihli veya eski veri canlı sunulmaz. Topluluk tahmini ve risk bildirimi kaynak/güncellik sınırıyla açıklanır.
- Yetkili entegrasyon bulunmayan rezervasyon, ödeme veya uzaktan şarj kontrolü eklenmedi. Manuel “Şarja başladım” yalnızca 30 dakikalık yerel hatırlatıcı kurar. Widget/Live Activity süresi ölçülen şarj seviyesi değildir.
- HealthKit import/client, nabız girdileri ve mola kuralı, ayarı, hata işlemi, Debug/Release capability ve TR/EN izin metinleri kaldırıldı. Eski ayarlar yeniden yazılarak kaldırılan alan temizlenir; eski mola kayıtları takvim geçmişini silmeden elenir. Gizlilik ve Review Notes metinleri güncellendi.

## CarPlay

EV Charging onayı geldi; Apple portalında capability etkinleştirilip kaydedildi. Projeye CarPlay haritası, favoriler, AC/DC filtresi, istasyon bilgisi ve Apple Maps aktarımı eklendi. CarPlay onayı App Store binary onayı değildir. İmzalama ve test ayrıntıları: [CARPLAY_REQUEST.md](CARPLAY_REQUEST.md).

## Yayın için kalanlar ve yapmanız gerekenler

1. **CarPlay:** Araç ekranı uygulandı ve App ID yetkisi açıldı. Simülatörde simge göründü; ancak sistem Ayarlar simgesi dahil tıklama ve klavye girişleri uygulama açmadı. CarPlay etkileşim testi açık: yeni Simulator oturumunda veya CarPlay Simulator/gerçek araçta bağlantı-kopma, konum reddi ve Maps aktarımını dağıtılacak build üzerinde tamamlayın. Gerçek cihaz testi daha önce isteğinizle ertelenmiştir.
2. **İmzalama:** Apple hesap/takım, App ID, App Group ve dağıtım sertifikaları aradaki çalışmalarda tamamlandı. CarPlay sonrası ana uygulama dağıtım profilinin yenileme/doğrulama kaydı [SIGNING_SETUP.md](SIGNING_SETUP.md) içindedir. Cihaz geliştirme profili ve imzalı Archive/export ayrı adımlardır.
3. **Üretim yapılandırması:** Gerçek `AppConfig.plist` ve `GoogleService-Info.plist` bu Mac'te artık var; Git dışında tutulur. Bunlar ilk teslimde eksikti. Dosya varlığı backend'in hazır olduğu anlamına gelmez.
4. **Backend:** Firebase kuralları aradaki çalışmada dağıtıldı; iOS Functions dağıtımı/canlı doğrulama tamamlanmadığı için `firebaseBackendReady=false` korunur. Güncel engeller [FIREBASE_SETUP.md](FIREBASE_SETUP.md) içindedir. Bu CarPlay işi backend dağıtımı yapmaz.
5. **Veri hakları:** EPDK ticari kullanım/çevrimdışı saklama/yeniden dağıtım izin kanıtı hâlâ bekleniyor. Doğrulanmadan `commercialDataUseApproved=true` yapmayın. [DATA_PROVIDER_TERMS.md](DATA_PROVIDER_TERMS.md).
6. **Mağaza:** App Store Connect kaydı, mağaza metinleri ve herkese açık destek/gizlilik URL'leri aradaki çalışmalarda tamamlandı. İmzalı gerçek cihaz/TestFlight testleri, ekran görüntüleri, App Privacy ve App Review gönderimi kalan adımlardır. CarPlay capability açmak App Store'a binary yüklemek/yayımlamak değildir. [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md).

## 9 Ekim CarPlay doğrulaması

87 Swift çekirdek ve 36 Python testi geçti. iPhone 17 Pro / iOS 26.5 üzerinde 95 uygulama/UI testi (7 yeni CarPlay testi dahil) geçti; son konum izni/güncelleme düzeltmesi sonrasında 7 CarPlay testi tekrar geçti. Debug ve Release Simulator derlemeleri, 143 dosyada SwiftLint ve depo yayın kontrolü başarılı. CarPlay ana ekranında simge görünmesi doğrulandı; araç ekranındaki etkileşim testleri simülatör giriş engeli nedeniyle açık. [Ayrıntılı kayıt](CARPLAY_REQUEST.md#9-ekim-doğrulama-kaydı).

## İlk teslimin yerel doğrulaması

Aşağıdaki sayılar ilk teslim kaydıdır; sonraki EPDK-only değişikliğinin testleri [güncel doğrulama belgesindedir](DATA_RIGHTS_VALIDATION.md).

- Swift çekirdek testleri: 84 test / 15 suite geçti.
- Python veri ve yayın doğrulama testleri: 22 test geçti.
- iPhone 17 Pro / iOS 26.5 Simulator: 82 uygulama ve arayüz senaryosu doğrulandı. Tam koşuda 81 test geçti; kalan filtre testi, fixture'daki istasyon adı düzeltilip yeniden derlenerek ayrı koşuda geçti.
- Debug uygulama/widget ve Release Simulator derlemeleri başarılı. Release binary'sinde HealthKit framework bağlantısı yok. Bunlar imzalı cihaz Archive kontrolü değildir.
- SwiftLint: 138 dosyada sıfır ihlal. Depo gizlilik/yetki doğrulaması ve `git diff --check` başarılı.

9 Ekim’de `python3 Scripts/validate_release.py --production` EPDK izin kaydı, ticari veri hakları bayrağı ve Firebase backend hazırlığı nedeniyle başarısızdır; gerçek iki plist artık mevcuttur. Yayın engelleri korunmuştur. GitHub teslim commit'i görev sonucunda belirtilir. GitHub'a push, backend dağıtımı veya App Store yayını anlamına gelmez.
