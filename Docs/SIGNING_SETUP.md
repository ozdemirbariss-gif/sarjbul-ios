# ŞarjBul imzalama kurulumu

Tarihsel durum — 13 Eylül 2026: proje otomatik imzalamaya hazırlandı; **Apple takım/profil kurulumu henüz tamamlanmadı**. Xcode > Settings > Apple Accounts hesabın ekli olmadığını gösterdi. Yerel denetimde geçerli kod imzalama kimliği ve kurulu provisioning profili bulunmadı. Sonraki arayüz kontrolünde macOS ekran erişimini reddetti.

Güncel durum — 8 Ekim 2026: ücretli takım doğrulandı, iki explicit App ID ve ortak App Group portalda oluşturuldu. App Group iki App ID'ye de atandı. Gerçek takım kimliği Git dışında tutulan yerel imzalama dosyasında kayıtlı; yeniden üretilen projenin iki hedefi Debug ve Release'te bu takımı kullanıyor. Xcode hesabına giriş, sertifika/profil üretimi ve imzalı derleme doğrulaması henüz tamamlanmadı.

## Hedef ve yetki eşleştirmesi

| Ayar | SarjBul | SarjBulWidgets |
| --- | --- | --- |
| Bundle ID | `com.ozdemirbaris.sarjbul` | `com.ozdemirbaris.sarjbul.widgets` |
| Team | Doğrulanmış ücretli takım; yerel dosyadan miras alınır | Ana uygulamayla aynı doğrulanmış takım |
| Signing | Automatic | Automatic |
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

## Hesap erişimi sağlanınca kalan işlem

1. Xcode'a ilgili Apple Developer hesabıyla giriş yap; takım ve Certificates, Identifiers & Profiles erişimini doğrula.
2. Portal kayıtları 8 Ekim 2026'da tamamlandı: ana uygulamada App Groups, Push Notifications, App Attest; widget'ta App Groups etkin. Ortak App Group iki App ID'ye de atandı. Xcode'da doğru takımın seçili olduğunu ve capability eşleşmesini kontrol et.
3. HealthKit portalda da kapalı; uygulamanın entitlement dosyalarında HealthKit yok. Xcode otomatik imzalama ile iki hedefin profillerini üretsin/yenilesin. App Store Connect dağıtımında ana uygulama ve widget için ayrı, doğru App ID'ye bağlı dağıtım profilleri kullanılsın.
4. Export edilen uygulama ve gömülü `PlugIns/SarjBulWidgets.appex` için imza, profil bitiş tarihi, takım, application-identifier, App Group ve yukarıdaki Release yetkilerini karşılaştır. Dağıtım profilinde `get-task-allow` false olmalı. Gerçek profil UUID/son kullanma bilgileri görülmeden bu adımı tamamlandı işaretleme.

App Group eklemek Apple hesabında kaydı oluşturmaz; entitlement dosyaları yalnızca uygulamanın istediği yetkileri belirtir. Profil oluşturma/yenileme için Apple hesabına erişim gerekir. APNs sağlayıcı anahtarının backend'e kurulması ve Firebase App Check kaydı, iOS imzalama işleminden ayrı işlerdir.

Mevcut üretim kontrolündeki `firebaseBackendReady=false` ve `commercialDataUseApproved=false` ayrıca Archive'ı engeller; imzalama kontrolü için bu doğrulamalar atlanmamalıdır.

## Yerel doğrulama

- `xcodegen generate` ve `python3 Scripts/validate_release.py` başarılı.
- Üretilen PBXProject incelendi: iki hedefte Debug/Release `CODE_SIGN_STYLE=Automatic`, `ProvisioningStyle=Automatic`, doğru bundle ve entitlement yolları var; proje yapılandırmaları ortak Signing.xcconfig dosyasına bağlı.
- İlk `xcodebuild -showBuildSettings` denemesi sandbox içindeki Xcode önbelleği yazma izinlerinde durdu. Gerekli yerel erişimle yapılan 8 Ekim denetiminde uygulama ve widget için Debug/Release build settings başarıyla okundu: aynı gerçek `DEVELOPMENT_TEAM`, `CODE_SIGN_STYLE=Automatic`, doğru Bundle ID ve entitlement dosyaları doğrulandı.
- Gerçek iOS Debug derlemesi iki hedefte de `No profiles ... were found` hatası verdi. Bu deneme provisioning güncellemelerini açmadan çalıştırıldı; hata metnindeki otomatik profil üretiminin devre dışı olduğu ifadesi CLI çağrısına aittir, projenin `Automatic` ayarına değil. Hesaba girişten sonra `-allowProvisioningUpdates` ile yeniden doğrulanmalıdır.
- Geçerli yerel kod imzalama kimliği bulunmadı. Sertifika ve Apple tarafından verilmiş profiller bekleniyor; imzalı derleme/export tamamlandı sayılmaz.

## Kaynaklar

- [Apple: Otomatik dağıtım imzalaması](https://help.apple.com/xcode/mac/current/en.lproj/devff5ececf8.html)
- [Apple: App Store Connect provisioning profili](https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile)
- [Apple: App ID yetkileri ve profil yenileme](https://developer.apple.com/help/account/identifiers/enable-app-capabilities/)
- [Apple: App Group kaydı](https://developer.apple.com/help/account/identifiers/register-an-app-group/)
- [Apple: App Attest hazırlığı](https://developer.apple.com/documentation/devicecheck/preparing-to-use-the-app-attest-service)

## 8 Ekim 2026 — portal kurulumu

Apple Developer portalında aktif ücretli üyelik ve takım doğrulandı. Doğrulanan takım yerel `Config/Signing.local.xcconfig` dosyasında kayıtlı; bu dosya Git dışında kalır. Başlangıçta App IDs ve App Groups listeleri boştu. Aşağıdaki kayıtlar aynı takım altında oluşturuldu ve kaydedilen yapılandırmalar yeniden açılarak doğrulandı:

| Portal kaydı | Doğrulanan durum |
| --- | --- |
| `com.ozdemirbaris.sarjbul` | Explicit App ID; App Groups, Push Notifications, App Attest açık; HealthKit kapalı |
| `com.ozdemirbaris.sarjbul.widgets` | Explicit App ID; App Groups açık; Push/App Attest/HealthKit kapalı |
| `group.com.ozdemirbaris.sarjbul` | SarjBul Shared App Group; iki App ID'nin App Group Assignment ekranında seçili |

Xcode Apple Accounts listesi boştu. Hesap ekleme akışındaki Apple giriş penceresi boş ekranda takıldı. Açık dosyalar Save All ile kaydedildi; kullanıcı onayıyla Xcode zorla kapatılıp yeniden açıldı ve temiz giriş akışı yeniden başlatıldı. Parola ve iki aşamalı doğrulama kullanıcı tarafından Xcode'da tamamlanmalıdır; bu bilgiler proje dosyalarına veya sohbete yazılmaz.

Kalan işlem: Xcode > Settings > Apple Accounts altında aynı hesabın girişini tamamla. Ardından iki hedefin Signing & Capabilities ekranında aynı ücretli takımı seç, otomatik profil/sertifika üretimine izin ver ve gerçek cihaz derlemesiyle hata kalmadığını doğrula. Geliştirme profili için kayıtlı bir iPhone/iPad gerekiyorsa cihazı bağla. Sonrasında dağıtım profili ve export imzaları ayrıca denetlenmelidir. HealthKit eklenmemelidir. CarPlay EV Charging başvurusu alındı; onay gelmeden CarPlay capability eklenmez. Portal oturumu Xcode oturumu veya imzalı dağıtım kanıtı değildir.
