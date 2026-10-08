# ŞarjBul imzalama kurulumu

Tarihsel durum — 13 Eylül 2026: proje otomatik imzalamaya hazırlandı; **Apple takım/profil kurulumu henüz tamamlanmadı**. Xcode > Settings > Apple Accounts hesabın ekli olmadığını gösterdi. Yerel denetimde geçerli kod imzalama kimliği ve kurulu provisioning profili bulunmadı. Sonraki arayüz kontrolünde macOS ekran erişimini reddetti.

Güncel durum — 8 Ekim 2026: ücretli takım doğrulandı, iki explicit App ID ve ortak App Group portalda oluşturuldu. App Group iki App ID'ye de atandı. Gerçek takım kimliği Git dışında tutulan yerel imzalama dosyasında kayıtlı; yeniden üretilen projenin iki hedefi Debug ve Release'te bu takımı kullanıyor. Xcode hesabına giriş tamamlandı ve doğru takıma ait geçerli Apple Development imzalama kimliği doğrulandı. **Takımda kayıtlı cihaz olmadığı için iki geliştirme profili üretilemiyor; imzalı derleme henüz başarılı değil.**

## Hedef ve yetki eşleştirmesi

| Ayar | SarjBul | SarjBulWidgets |
| --- | --- | --- |
| Bundle ID | `com.ozdemirbaris.sarjbul` | `com.ozdemirbaris.sarjbul.widgets` |
| Team | Doğrulanmış ücretli takım; yerel dosyadan miras alınır | Ana uygulamayla aynı doğrulanmış takım |
| Signing | Automatic | Automatic |
| Apple Development sertifikası | Doğru takıma ait geçerli yerel kimlik; 8 Ekim 2027'ye kadar | Aynı yerel kimlik kullanılacak |
| iOS App Development profili | Kayıtlı fiziksel cihaz bekleniyor | Kayıtlı fiziksel cihaz bekleniyor |
| App Store Connect dağıtım profili | Bu explicit App ID için ayrı profil; bekliyor | Widget explicit App ID için ayrı profil; bekliyor |
| App Group | `group.com.ozdemirbaris.sarjbul`; portalda atandı | `group.com.ozdemirbaris.sarjbul`; portalda atandı |
| Push Notifications | Debug `development`, Release `production` | Kullanılmıyor |
| App Attest | Release `production` | Kullanılmıyor |
| HealthKit | Kaldırıldı; talep edilmez | Kullanılmıyor |

Debug sürümü `FirebaseBootstrap` içinde App Check Debug Provider kullanır; bu yapılandırmaya App Attest yetkisi eklenmedi. Release App Attest kullanır. Widget yalnızca paylaşılan App Group'a erişir.

## Kalıcı takım ayarı

`SarjBul.xcodeproj` XcodeGen ile üretilir ve git dışında tutulur. Yalnızca Xcode'un hedef ekranında yapılan seçim yeniden üretimde kaybolabilir. `project.yml` hem Debug hem Release için `Config/Signing.xcconfig` dosyasını bağlar; uygulama ve widget takımı proje seviyesinden miras alır.

Hesaba giriş yapıldıktan sonra doğrulanmış Team ID, `Config/Signing.local.xcconfig.example` örneğinden oluşturulacak `Config/Signing.local.xcconfig` içine yazılmalıdır:

```xcconfig
DEVELOPMENT_TEAM = <Xcode'da doğrulanan Team ID>
```

Yer tutucu gerçek takım değildir; dosyaya aynen yazılmamalıdır. Yerel dosya, sertifika özel anahtarları ve provisioning profilleri git'e alınmaz. `xcodegen generate` ardından iki hedefin Signing & Capabilities ekranında aynı ücretli takım görünmelidir. Otomatik imzalamada profil adı/UUID veya Release için elle `Apple Distribution` build kimliği sabitlenmez; dağıtım yeniden imzalaması export sırasında yapılır.

## Kalan işlem

1. Xcode hesabına giriş ve ücretli takımın Certificates, Identifiers & Profiles erişimi 8 Ekim'de doğrulandı. Takımın On Device Testing ekranı `0 Provisioned Devices` gösteriyor. Test iPhone/iPad'ini veri aktarımı destekleyen USB kablosuyla bağla, kilidini aç ve cihazdaki "Bu bilgisayara güven" onayını/parolayı tamamla. Xcode > Window > Devices and Simulators > Devices listesinde görünmesini bekle. Cihaz isterse Developer Mode adımını cihaz üzerinde tamamla.
2. Portal kayıtları 8 Ekim 2026'da tamamlandı: ana uygulamada App Groups, Push Notifications, App Attest; widget'ta App Groups etkin. Ortak App Group iki App ID'ye de atandı. Xcode'da doğru takımın seçili olduğunu ve capability eşleşmesini kontrol et.
3. HealthKit portalda da kapalı; uygulamanın entitlement dosyalarında HealthKit yok. Fiziksel cihaz görününce doğru takım altında kayıt edilmesine izin ver; Xcode'da iki hedef için Try Again kullan veya `xcodebuild` çağrısına `-allowProvisioningUpdates -allowProvisioningDeviceRegistration` ekleyip bağlı cihazı destination olarak seç. Xcode otomatik imzalama ile iki hedefin geliştirme profillerini üretsin/yenilesin. App Store Connect dağıtımında ana uygulama ve widget için ayrı, doğru App ID'ye bağlı dağıtım profilleri kullanılsın.
4. Export edilen uygulama ve gömülü `PlugIns/SarjBulWidgets.appex` için imza, profil bitiş tarihi, takım, application-identifier, App Group ve yukarıdaki Release yetkilerini karşılaştır. Dağıtım profilinde `get-task-allow` false olmalı. Gerçek profil UUID/son kullanma bilgileri görülmeden bu adımı tamamlandı işaretleme.

App Group eklemek Apple hesabında kaydı oluşturmaz; entitlement dosyaları yalnızca uygulamanın istediği yetkileri belirtir. Profil oluşturma/yenileme için Apple hesabına erişim gerekir. APNs sağlayıcı anahtarının backend'e kurulması ve Firebase App Check kaydı, iOS imzalama işleminden ayrı işlerdir.

Mevcut üretim kontrolündeki `firebaseBackendReady=false` ve `commercialDataUseApproved=false` ayrıca Archive'ı engeller; imzalama kontrolü için bu doğrulamalar atlanmamalıdır.

## Yerel doğrulama

- `xcodegen generate` ve `python3 Scripts/validate_release.py` başarılı.
- Üretilen PBXProject incelendi: iki hedefte Debug/Release `CODE_SIGN_STYLE=Automatic`, `ProvisioningStyle=Automatic`, doğru bundle ve entitlement yolları var; proje yapılandırmaları ortak Signing.xcconfig dosyasına bağlı.
- İlk `xcodebuild -showBuildSettings` denemesi sandbox içindeki Xcode önbelleği yazma izinlerinde durdu. Gerekli yerel erişimle yapılan 8 Ekim denetiminde uygulama ve widget için Debug/Release build settings başarıyla okundu: aynı gerçek `DEVELOPMENT_TEAM`, `CODE_SIGN_STYLE=Automatic`, doğru Bundle ID ve entitlement dosyaları doğrulandı.
- Gerçek iOS Debug derlemesi iki hedefte de `No profiles ... were found` hatası verdi. Bu deneme provisioning güncellemelerini açmadan çalıştırıldı; hata metnindeki otomatik profil üretiminin devre dışı olduğu ifadesi CLI çağrısına aittir, projenin `Automatic` ayarına değil. Hesaba girişten sonra `-allowProvisioningUpdates` ile yeniden doğrulanmalıdır.
- Hesaba girişten sonraki `xcodebuild ... -allowProvisioningUpdates build` Apple'a erişti ve iki hedefte de `Your team has no devices from which to generate a provisioning profile` / `No profiles ... were found` hatalarıyla durdu. Xcode Signing & Capabilities ekranları da aynı engeli gösteriyor; iki hedefte Automatic Signing, aynı ücretli takım, doğru Bundle ID ve seçili ortak App Group doğrulandı.
- Sandbox içindeki `security find-identity` çağrısı `0 valid identities` döndürdü; bu ortam anahtar zincirinin gerçek durumunu göstermedi. Gerekli erişimle yapılan denetim **1 geçerli Apple Development imzalama kimliği** buldu. Sertifikanın OU alanı doğrulanmış Team ID ile aynı; geçerlilik 8 Ekim 2026–8 Ekim 2027. Özel anahtar dışa aktarılmadı.
- `devicectl list devices`, `xctrace list devices` ve Xcode Devices listesi fiziksel iPhone/iPad göstermedi. Apple tarafından verilmiş geliştirme profilleri, gerçek cihaz derlemesi ve dağıtım/export denetimi bekleniyor.

## Kaynaklar

- [Apple: Otomatik dağıtım imzalaması](https://help.apple.com/xcode/mac/current/en.lproj/devff5ececf8.html)
- [Apple: App Store Connect provisioning profili](https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile)
- [Apple: App ID yetkileri ve profil yenileme](https://developer.apple.com/help/account/identifiers/enable-app-capabilities/)
- [Apple: App Group kaydı](https://developer.apple.com/help/account/identifiers/register-an-app-group/)
- [Apple: App Attest hazırlığı](https://developer.apple.com/documentation/devicecheck/preparing-to-use-the-app-attest-service)
- [Apple: Geliştirme profili için cihaz kaydı](https://developer.apple.com/help/account/devices/register-a-single-device)
- [Apple: Cihazda Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)

## 8 Ekim 2026 — portal kurulumu

Apple Developer portalında aktif ücretli üyelik ve takım doğrulandı. Doğrulanan takım yerel `Config/Signing.local.xcconfig` dosyasında kayıtlı; bu dosya Git dışında kalır. Başlangıçta App IDs ve App Groups listeleri boştu. Aşağıdaki kayıtlar aynı takım altında oluşturuldu ve kaydedilen yapılandırmalar yeniden açılarak doğrulandı:

| Portal kaydı | Doğrulanan durum |
| --- | --- |
| `com.ozdemirbaris.sarjbul` | Explicit App ID; App Groups, Push Notifications, App Attest açık; HealthKit kapalı |
| `com.ozdemirbaris.sarjbul.widgets` | Explicit App ID; App Groups açık; Push/App Attest/HealthKit kapalı |
| `group.com.ozdemirbaris.sarjbul` | SarjBul Shared App Group; iki App ID'nin App Group Assignment ekranında seçili |

Xcode Apple Accounts listesi başlangıçta boştu. Hesap ekleme akışındaki Apple giriş penceresi boş ekranda takıldı. Açık dosyalar Save All ile kaydedildi; kullanıcı onayıyla Xcode zorla kapatılıp yeniden açıldı. Kullanıcı Apple girişini tamamladı; Xcode'da Baris Ozdemir ücretli Developer Team ve Certificates, Identifiers & Profiles erişimi doğrulandı. Parola ve doğrulama kodları proje dosyalarına veya sohbete yazılmadı.

Kalan işlem: fiziksel test cihazını Mac'e bağla ve güven/eşleşme işlemini tamamla. Takımda cihaz kaydı yapılınca iki hedef için otomatik geliştirme profillerini üret ve imzalı derlemenin başarılı olduğunu doğrula. Sonrasında dağıtım profili ve export imzaları ayrıca denetlenmelidir. HealthKit eklenmemelidir. CarPlay EV Charging başvurusu alındı; onay gelmeden CarPlay capability eklenmez. Başarılı hesap girişi ve sertifika doğrulaması, imzalı dağıtım kanıtı değildir.
