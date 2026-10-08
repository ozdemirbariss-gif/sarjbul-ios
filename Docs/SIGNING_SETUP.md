# ŞarjBul imzalama kurulumu

Tarihsel durum — 13 Eylül 2026: proje otomatik imzalamaya hazırlandı; **Apple takım/profil kurulumu henüz tamamlanmadı**. Xcode > Settings > Apple Accounts hesabın ekli olmadığını gösterdi. Yerel denetimde geçerli kod imzalama kimliği ve kurulu provisioning profili bulunmadı. Sonraki arayüz kontrolünde macOS ekran erişimini reddetti.

## Hedef ve yetki eşleştirmesi

| Ayar | SarjBul | SarjBulWidgets |
| --- | --- | --- |
| Bundle ID | `com.ozdemirbaris.sarjbul` | `com.ozdemirbaris.sarjbul.widgets` |
| Team | Aynı doğrulanmış ücretli Developer Team ID; bekliyor | Ana uygulamayla aynı; bekliyor |
| Signing | Automatic | Automatic |
| App Store Connect dağıtım profili | Bu explicit App ID için ayrı profil; bekliyor | Widget explicit App ID için ayrı profil; bekliyor |
| App Group | `group.com.ozdemirbaris.sarjbul` | `group.com.ozdemirbaris.sarjbul` |
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

## Hesap erişimi sağlanınca kalan işlem

1. Xcode'a ilgili Apple Developer hesabıyla giriş yap; takım ve Certificates, Identifiers & Profiles erişimini doğrula.
2. Aynı takım altında iki explicit App ID'yi ve ortak App Group'u doğrula/kaydet. Ana uygulamada App Groups, Push Notifications, App Attest; widget'ta App Groups etkin olmalı. App Group iki App ID'ye de atanmalı.
3. Ana App ID üzerinde HealthKit önceden açılmışsa kaldır ve profilleri yenile; uygulamanın entitlement dosyalarında HealthKit yok. Xcode otomatik imzalama ile iki hedefin profillerini yenilesin. App Store Connect dağıtımında ana uygulama ve widget için ayrı, doğru App ID'ye bağlı dağıtım profilleri kullanılsın.
4. Export edilen uygulama ve gömülü `PlugIns/SarjBulWidgets.appex` için imza, profil bitiş tarihi, takım, application-identifier, App Group ve yukarıdaki Release yetkilerini karşılaştır. Dağıtım profilinde `get-task-allow` false olmalı. Gerçek profil UUID/son kullanma bilgileri görülmeden bu adımı tamamlandı işaretleme.

App Group eklemek Apple hesabında kaydı oluşturmaz; entitlement dosyaları yalnızca uygulamanın istediği yetkileri belirtir. Profil oluşturma/yenileme için Apple hesabına erişim gerekir. APNs sağlayıcı anahtarının backend'e kurulması ve Firebase App Check kaydı, iOS imzalama işleminden ayrı işlerdir.

Mevcut üretim kontrolündeki `firebaseBackendReady=false` ve `commercialDataUseApproved=false` ayrıca Archive'ı engeller; imzalama kontrolü için bu doğrulamalar atlanmamalıdır.

## Yerel doğrulama

- `xcodegen generate` ve `python3 Scripts/validate_release.py` başarılı.
- Üretilen PBXProject incelendi: iki hedefte Debug/Release `CODE_SIGN_STYLE=Automatic`, `ProvisioningStyle=Automatic`, doğru bundle ve entitlement yolları var; proje yapılandırmaları ortak Signing.xcconfig dosyasına bağlı.
- `xcodebuild -showBuildSettings` Swift paket çözümlemesinde `sandbox-exec: sandbox_apply: Operation not permitted` ile durdu. İmzalı derleme/export doğrulanmadı.
- Takım, sertifika ve Apple tarafından verilmiş profiller bekleniyor; sahte Team ID veya profil adı yazılmadı.

## Kaynaklar

- [Apple: Otomatik dağıtım imzalaması](https://help.apple.com/xcode/mac/current/en.lproj/devff5ececf8.html)
- [Apple: App Store Connect provisioning profili](https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile)
- [Apple: App ID yetkileri ve profil yenileme](https://developer.apple.com/help/account/identifiers/enable-app-capabilities/)
- [Apple: App Group kaydı](https://developer.apple.com/help/account/identifiers/register-an-app-group/)
- [Apple: App Attest hazırlığı](https://developer.apple.com/documentation/devicecheck/preparing-to-use-the-app-attest-service)

## 8 Ekim 2026 — hesap doğrulaması

Apple Developer portalında aktif ücretli üyelik ve takım doğrulandı. Doğrulanan takım yerel `Config/Signing.local.xcconfig` dosyasına eklendi; bu dosya Git dışında kalır. Portalın Identifiers > App IDs listesi boş göründü: ana uygulama ve widget için kayıtlı App ID bulunmadı. Bu nedenle portalda kaldırılacak bir ŞarjBul HealthKit capability'si de bulunmadı.

Kalan işlem: Xcode > Settings > Apple Accounts altında aynı hesabı ekle; iki explicit App ID'yi ve ortak App Group'u oluştur, ana hedefte App Groups/Push/App Attest ile widget App Group yetkilerini eşleştir ve profilleri üret. HealthKit eklenmemelidir. CarPlay EV Charging başvurusu alındı; onay gelmeden CarPlay capability eklenmez. Portal oturumu Xcode oturumu veya imzalı dağıtım kanıtı değildir.
