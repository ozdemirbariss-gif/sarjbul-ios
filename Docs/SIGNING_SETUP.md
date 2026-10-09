# ŞarjBul imzalama kurulumu

## Güncel durum — 9 Ekim 2026

Xcode Apple hesabına giriş tamamlandı ve ücretli Baris Ozdemir takımı doğrulandı. İki explicit App ID ile ortak App Group doğru takım altında oluşturuldu; grup iki App ID'ye atandı. Apple Development ve Apple Distribution sertifikalarının bu Mac'te özel anahtarlarıyla kullanılabilir olduğu doğrulandı. İki App Store Connect dağıtım profili oluşturuldu, indirildi, Xcode'a kuruldu ve Release yetkileriyle karşılaştırıldı.

9 Ekim'de CarPlay EV Charging onayı doğrulandı ve ana App ID capability'si açıldı. Eski ana dağıtım profili geçersiz kaldı; aynı App ID ve mevcut dağıtım sertifikasıyla yeniden üretildi, indirildi ve Xcode'a kuruldu. Yeni UUID `321fd27f-330c-4dd3-8ccc-b9466d336b3f`, bitiş 8 Ekim 2027 13:16:14 UTC. Profilde `com.apple.developer.carplay-charging=true`, doğru takım/Bundle ID, App Group, Push ve App Attest izinleri doğrulandı; yerel özel anahtarı olan sertifikayla eşleşti. Widget'ın mevcut profili değişmedi. HealthKit yok. Bu işlem imzalı Archive/export değildir.

**Kablo gerektirmeyen imzalama kurulumu tamamlandı.** Kullanıcı fiziksel cihaz testini erteledi. Takımda kayıtlı cihaz olmadığı için otomatik geliştirme profilleri hâlâ üretilemiyor; imzalı cihaz derlemesi yapılmadı. İmzalı Archive/export ise aşağıdaki üretim engelleri kapanmadan tamamlanmış sayılmaz.

## Hedef ve yetki eşleştirmesi

| Ayar | SarjBul | SarjBulWidgets |
| --- | --- | --- |
| Bundle ID | `com.ozdemirbaris.sarjbul` | `com.ozdemirbaris.sarjbul.widgets` |
| Team | Yerel dosyada kayıtlı doğrulanmış ücretli takım | Aynı takım |
| Signing | Automatic; Debug ve Release doğrulandı | Automatic; Debug ve Release doğrulandı |
| App Group | `group.com.ozdemirbaris.sarjbul`; App ID ve dağıtım profilinde var | Aynı grup; App ID ve dağıtım profilinde var |
| Push Notifications | Debug `development`, Release ve dağıtım profili `production` | Kullanılmıyor |
| App Attest | Release `production`; dağıtım profili bu ortamı destekliyor | Kullanılmıyor |
| HealthKit | Koddan kaldırıldı; App ID ve profilde yok | Kullanılmıyor |
| CarPlay EV Charging | App ID açık; Debug/Release ve yenilenmiş dağıtım profili `com.apple.developer.carplay-charging=true` | Kullanılmıyor |
| Geliştirme profili | Cihaz kaydı bekleniyor; ertelendi | Cihaz kaydı bekleniyor; ertelendi |
| App Store Connect profili | `SarjBul App Store`; kuruldu ve doğrulandı | `SarjBulWidgets App Store`; kuruldu ve doğrulandı |

Debug sürümü `FirebaseBootstrap` içinde App Check Debug Provider kullanır; Debug entitlement dosyasına App Attest eklenmedi. Release App Attest kullanır. Widget'ın proje tarafından istediği tek yetki paylaşılan App Group'tur.

## Kalıcı takım ayarı

`SarjBul.xcodeproj` XcodeGen ile üretilir ve Git dışında tutulur. Yalnızca Xcode hedef ekranında yapılan takım seçimi yeniden üretimde kaybolabilir. `project.yml` hem Debug hem Release için `Config/Signing.xcconfig` dosyasını bağlar; bu dosya yerel takım dosyasını içerir.

Bu Mac'te `Config/Signing.local.xcconfig`, `Config/Signing.local.xcconfig.example` temel alınarak gerçek ve portalda doğrulanmış Team ID ile dolduruldu. Yeni bir Mac'te örneği yerel dosyaya kopyalayıp Xcode/Developer portalında doğrulanan takım kimliğini gir:

```xcconfig
DEVELOPMENT_TEAM = <doğrulanan gerçek Team ID>
```

Yer tutucuyu aynen kullanma. Yerel takım dosyası, sertifika özel anahtarları ve provisioning profilleri Git'e alınmaz. Otomatik imzalamada profil adı/UUID veya Release için elle `Apple Distribution` build kimliği sabitlenmez; dağıtım yeniden imzalaması export sırasında yapılır.

8 Ekim'de `xcodegen generate` sonrasında dört hedef/yapılandırma birleşiminin gerçek build settings çıktısı kontrol edildi: iki hedefin Debug ve Release ayarlarında aynı yerel `DEVELOPMENT_TEAM`, `CODE_SIGN_STYLE=Automatic`, doğru Bundle ID ve entitlement dosyaları korundu; sabit profil seçimi bulunmadı.

## Dağıtım sertifikası ve profilleri

Apple Development ve Apple Distribution sertifikaları 8 Ekim 2026–8 Ekim 2027 arasında geçerli. Dağıtım sertifikası Xcode > Settings > Apple Accounts > Baris Ozdemir > Manage Certificates üzerinden oluşturuldu. Anahtar zinciri denetimi iki geçerli imzalama kimliği gösterdi; sertifikaların takım alanları yerel Team ID ile eşleşti. Özel anahtarlar dışa aktarılmadı.

| Hedef | App Store Connect profil adı | Profil UUID | Bitiş (UTC) |
| --- | --- | --- | --- |
| SarjBul | `SarjBul App Store` (9 Ekim CarPlay yenilemesi) | `321fd27f-330c-4dd3-8ccc-b9466d336b3f` | 8 Ekim 2027 13:16:14 |
| SarjBulWidgets | `SarjBulWidgets App Store` | `59146f57-f9c7-4f28-a437-0f18b655a2d4` | 8 Ekim 2027 13:16:14 |

Profiller Apple Developer > Profiles altında aynı takımda oluşturuldu. Xcode'da **Download Manual Profiles** çalıştırıldı. Kurulu dosyalar Xcode 26.6'nın `~/Library/Developer/Xcode/UserData/Provisioning Profiles/` dizininde UUID adlarıyla doğrulandı.

İndirilen ve kurulu profil dosyalarının denetiminde:

- Team Identifier ve `application-identifier` her hedefin gerçek takım/Bundle ID eşleşmesini sağladı.
- İki profil aynı Apple Distribution sertifikasını içerdi; sertifikanın SHA-256 özeti yerel imzalama kimliğiyle eşleşti.
- Ortak App Group iki profilde de bulundu; `get-task-allow=false`, `beta-reports-active=true` ve geçerlilik tarihleri doğrulandı. Cihaz listesi veya tüm cihazlara dağıtım yetkisi bulunmadı.
- Ana uygulamada `aps-environment=production` bulundu. App Attest profilinin izin verdiği ortamlar `development` ve `production`; uygulamanın Release isteği `production` bunların içindedir.
- Widget profili Push veya App Attest istemedi. İki profilde de HealthKit bulunmadı.
- Projenin iki Release entitlement dosyasındaki bütün isteklerin profil tarafından karşılandığı doğrulandı.

Bu denetim profil/sertifika uyumunu doğrular; export edilmiş uygulama imzasının veya cihaz çalışmasının yerine geçmez. App Store Connect dağıtım profili oluşturmak için bağlı ya da kayıtlı iPhone gerekmez.

## Ertelenen cihaz işlemi

Takımın On Device Testing ekranı `0 Provisioned Devices` gösteriyor. Hesaba girişten sonraki `xcodebuild ... -allowProvisioningUpdates build`, iki hedefte de `Your team has no devices from which to generate a provisioning profile` / `No profiles ... were found` hatalarıyla durdu. Xcode Signing & Capabilities ekranındaki geliştirme profili hataları da bu nedenden kaynaklanıyor; dağıtım profili hazırlığı bu hataları kaldırmaz.

Cihaz testi yeniden ele alındığında:

1. Test iPhone/iPad'ini Mac ile eşleştir; gerekirse veri aktarabilen USB kablosu kullan, cihazın kilidini aç, güven onayını ve Developer Mode adımını tamamla.
2. Cihazın Xcode Devices listesinde görünmesini ve doğru takıma kaydedilmesini sağla. Cihazın gerçek UDID'si zaten biliniyorsa portalda manuel kayıt da yapılabilir.
3. İki hedefte Automatic Signing ve aynı takım seçiliyken Xcode'un geliştirme profillerini üretmesini sağla; ardından imzalı cihaz derlemesi ve cihaz testlerini tamamla.

Cihaz engeli geliştirme profiline aittir; App Store/TestFlight dağıtımının cihaz gerektirdiği anlamına gelmez. HealthKit eklenmemelidir. CarPlay EV Charging onayı 9 Ekim'de doğrulandı, capability açıldı ve dağıtım profili yenilendi. Cihaz kaydından sonra üretilecek geliştirme profilleri de CarPlay yetkisini içermelidir.

## Archive/export için açık üretim engelleri

8 Ekim'de `python3 Scripts/validate_release.py` başarılı oldu. `python3 Scripts/validate_release.py --production --bundle-id com.ozdemirbaris.sarjbul` üç açık engel bildirdi:

- EPDK veri izin kaydı `pending_permission`: ticari kullanım/yeniden dağıtım izin kanıtı eksik.
- `commercialDataUseApproved=false`: sağlayıcı hakları tamamlanmadı.
- `firebaseBackendReady=false`: canlı backend dağıtımı ve doğrulaması tamamlanmadı.

Veri izin kanıtını [veri sağlayıcı koşullarına](DATA_PROVIDER_TERMS.md), backend dağıtımı ve doğrulamasını [Firebase kurulumuna](FIREBASE_SETUP.md) göre tamamla. Bayrakları yalnızca bu işler gerçekten doğrulandıktan sonra aç; imzalamayı kontrol etmek için Archive korumasını atlama.

Üretim kontrolü geçince imzalı Archive/export yap. Export edilen uygulama ile gömülü `PlugIns/SarjBulWidgets.appex` için imza geçerliliği, gömülü profil, takım, Bundle ID, App Group, bitiş tarihi ve Release yetkilerini ayrıca karşılaştır. **Archive/export ve TestFlight/App Store yüklemesi bu görevde tamamlanmadı.**

APNs sağlayıcı anahtarının backend'e kurulması, Firebase App Check/enforcement ve gerçek cihazda bildirim/App Attest testi iOS sertifika/profil kurulumundan ayrı işlerdir.

## Kaynaklar

- [Apple: Otomatik dağıtım imzalaması](https://help.apple.com/xcode/mac/current/en.lproj/devff5ececf8.html)
- [Apple: App Store Connect provisioning profili](https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile)
- [Apple: App ID yetkileri ve profil yenileme](https://developer.apple.com/help/account/identifiers/enable-app-capabilities/)
- [Apple: App Group kaydı](https://developer.apple.com/help/account/identifiers/register-an-app-group/)
- [Apple: App Attest hazırlığı](https://developer.apple.com/documentation/devicecheck/preparing-to-use-the-app-attest-service)
- [Apple: Cihaz kaydı](https://developer.apple.com/help/account/devices/register-a-single-device)
- [Apple: Cihazda Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)
