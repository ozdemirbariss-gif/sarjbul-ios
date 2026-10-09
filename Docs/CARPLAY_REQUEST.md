# CarPlay EV Charging

## 9 Ekim 2026 — onay ve uygulama

Hesap sahibi Apple onayının geldiğini bildirdi. Doğru ücretli takımın `com.ozdemirbaris.sarjbul` App ID sayfasında **CarPlay EV Charging App** seçeneğinin kullanılabilir olduğu görüldü. Capability etkinleştirildi, kaydedildi ve sayfa yeniden açılarak işaretli durumu doğrulandı. Debug ve Release entitlement dosyaları `com.apple.developer.carplay-charging=true` ister. Widget bu yetkiyi istemez.

8 Ekim'de EV Charging başvurusu gönderilmiş ve Apple alındısı doğrulanmıştı. Bu kayıt artık onay bekliyor durumunda değildir. CarPlay yetkisi, App Store binary incelemesi veya operatör rezervasyon/ödeme/şarj kontrolü yetkisi değildir.

## Araç ekranı

- `CPTemplateApplicationScene` ve `CarPlaySceneDelegate` sahnesi SwiftUI iPhone sahnesiyle aynı uygulama durumunu kullanır. CarPlay soğuk açılışında istasyon kataloğu iPhone ekranı açılmadan yüklenir; giriş formu gerekmez.
- Yakındaki şarj istasyonları `CPPointOfInterestTemplate` üzerinde en fazla 12 nokta olarak gösterilir. Haritayı kaydırınca bölgeye göre arama yapılır; 80 km dışında kalan sonuçlar yakınmış gibi sunulmaz. Araç ekranında AC + DC / DC 50+ kW filtresi ve Yenile bulunur. Telefonun gizli metin/operatör/menzil filtreleri CarPlay'e uygulanmaz.
- Favoriler sistem liste şablonunda gösterilir; seçim istasyon bilgisine açılır. Yeni hesap kurulumu, serbest metin veya ayrıntılı araç ayarları gerekmez.
- İstasyon bilgisi soket/güç, fiyat kaynağı/tarihi, müsaitlik ve adresi gösterir. EPDK tarifesi ve canlı müsaitlik sağlamaz; bilinmeyen değerler açıkça bilinmiyor sunulur. Telefonla aynı kanıt kuralları kullanılır. Açık detay dahil müsaitlik 60 saniyede yeniden değerlendirilir; 15 dakikadan eski veya gelecekteki operatör verisi güncel sayılmaz.
- Yol tarifi Apple Maps'e aktarılır; başlangıç sürücünün güncel konumudur, telefonun eski manuel başlangıcı değildir. Bu bir turn-by-turn navigasyon uygulaması değildir.
- Konum erişimi zaten verilmişse bağlantı süresince konum güncellenir; bağlantı kopunca takip ve görevler durur. CarPlay yeni konum izni istemez. Konum izni geri alınırsa önbellekteki konum da kullanılmaz. Güncel cihaz konumu yoksa haritada gezinme ve favoriler kullanılabilir; eski/manuel konum güncel sürücü konumu sayılmaz.
- Rezervasyon, ödeme, uzaktan şarj başlatma/durdurma ve HealthKit yoktur.

## İmzalama ve test

Capability değişikliği ana uygulamanın eski `SarjBul App Store` profilini geçersiz kıldı. Yenilenen profilin CarPlay anahtarı, takım, Bundle ID, App Group, sertifika ve Release yetkileriyle uyumu ayrıca doğrulanır; sonuç [imzalama belgesindedir](SIGNING_SETUP.md). Widget profili CarPlay istemediği için değişmez.

Yerel doğrulama sonuçları aşağıdaki kayıtta belirtilir. Şablon/presenter testleri gerçek CarPlay bağlantısının yerine geçmez. Araç testleri daha önce hesap sahibinin isteğiyle ertelenmiştir. 9 Ekim'de iPhone geliştirme imzalaması ve normal uygulama açılışı ayrıca tamamlandı; araç bağlantı testi açık kalır.

Yayın öncesinde CarPlay Simulator/gerçek araçta soğuk açılış, iPhone ekranı kapalı kullanım, bağlantı/kopma/yeniden bağlantı, konum reddi, boş sonuç, favoriler, AC/DC filtresi, fiyat/müsaitlik güncelliği ve Apple Maps aktarımı kontrol edilmelidir. Dokunmatik ve döner kumandalı ekranlar ayrıca denenmelidir. Üretim veri hakları/backend gate'leri geçmeden imzalı Archive/export veya App Store yayını tamamlanmış sayılmaz.

## 9 Ekim doğrulama kaydı

- Swift çekirdeği: 87 test / 15 suite geçti. Python veri, yayın ve public pages doğrulamaları: 36 test geçti.
- iPhone 17 Pro / iOS 26.5 üzerinde uygulama birim ve UI testleri: 95/95 geçti. Bu sayı yeni 7 CarPlay presenter/konum/kanıt/sahne kayıt testini içerir; araç ekranının elle kullanım testi değildir. Son konum izni ve `@Published` güncelleme düzeltmesinden sonra 7 CarPlay testi yeniden geçti.
- Debug uygulama/widget ve Release Simulator derlemeleri başarılı. SwiftLint: 143 dosya, sıfır ihlal. Depo yayın kontrolü ve `git diff --check` başarılı.
- Simülatör için ad hoc imzalanan uygulamanın gömülü simüle entitlement dosyasında charging yetkisi doğrulandı; kurulumdan sonra CarPlay ana ekranında ŞarjBul simgesi göründü. Bu imzalı cihaz/export kanıtı değildir.
- **Etkileşim testi açık:** Mac'teki Xcode Simulator CarPlay ekranında ŞarjBul ve sistem Ayarlar simgelerine tıklama ile klavye girdisi uygulama açmadı. Hesap sahibi de tıklayamadığını bildirdi. ŞarjBul araç sahnesi açılışı, favoriler, filtre ve Maps aktarımı bu oturumda çalıştırılmış sayılmadı; uygulama kaynaklı bir çökme doğrulanmadı. Yeni bir Simulator oturumu veya geliştirme profili hazırlanmış iPhone ile CarPlay Simulator/gerçek araçta test protokolünü tamamlayın. 9 Ekim'de iPhone 14 Plus / iOS 26.6.2 için charging yetkisini içeren otomatik geliştirme profili üretildi; uygulama/widget imzaları, telefona kurulum ve normal iPhone ana ekran açılışı doğrulandı. Bu işlem araç sahnesinin bağlantı/etkileşim testi değildir; araç test protokolü açık kalır.
- Kurulu ana dağıtım profili charging yetkisini içerir; widget profili içermez. İkisinde de HealthKit yoktur.
- Üretim kontrolü yalnızca açık EPDK izin kaydı, `commercialDataUseApproved=false` ve `firebaseBackendReady=false` nedeniyle durur. İmzalı Archive/export ve TestFlight yüklemesi yapılmadı; bu gate'ler atlanmadı.

## Resmî kaynaklar

- [Apple CarPlay ve geliştirme rehberi](https://developer.apple.com/carplay/)
- [EV Charging entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.carplay-charging)
- [Point of Interest şablonu](https://developer.apple.com/documentation/carplay/cppointofinteresttemplate)
- [En fazla 12 harita noktası](https://developer.apple.com/documentation/carplay/cppointofinterest)
