# CarPlay Navigasyon Yetkisi

CarPlay navigasyon uygulaması entitlement'ı Apple tarafından manuel incelenir. Kod hedefi, onay ve provisioning gelmeden ana projeye eklenmemelidir.

## Başvuru paketi

1. Apple Developer hesabında `com.ozdemirbaris.sarjbul` App ID'sinin sahibiyle giriş yap.
2. CarPlay entitlement request formunda uygulamayı “navigation” kategorisiyle gönder.
3. Kullanım senaryosunu “Türkiye genelinde EV şarj duraklı rota, varış şarjı ve güvenli sürüş yönlendirmesi” olarak açıkla.
4. Şarj istasyonu arama ve rota seçiminin sürüşten önce iPhone'da tamamlandığını; CarPlay yüzeyinde yalnızca güvenli navigasyon kontrolleri gösterileceğini belirt.
5. Apple onayından sonra App ID capability, provisioning profile ve `.entitlements` anahtarlarını Xcode hedefinde etkinleştir.
6. Gerçek CarPlay head unit veya CarPlay Simulator ile rota başlatma, yeniden yönlendirme, sesli talimat ve bağlantı kopması testlerini tamamla.

Onay gelene kadar uygulama Apple Maps'e rota aktarımını kullanır; sahte veya dağıtılamayan bir CarPlay ekranı yayınlanmaz.
