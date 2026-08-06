# Otonom Şarj Ajanı

## Hedef

Kullanıcıdan istasyon aramasını istemek yerine, güvenilir veri bulunduğunda işi arka planda tamamlayıp onaya hazır bir rota sunmak. Ajan navigasyonu kendiliğinden başlatmaz; sürüş güvenliği ve yanlış telemetri riskine karşı son karar kullanıcıdadır.

## Veri Akışı

```text
VehicleTelemetryClient
        |
        v
VehicleTelemetrySnapshot + son bilinen konum
        |
        v
StationDataStore -> StationSearchEngine
        |
        v
AutonomousChargingDecisionEngine
        |
        v
AutonomousChargingProposal
        |
        +--> cihaz içi persistence
        +--> eylemli yerel bildirim
        +--> ana sayfada hazır rota kartı
```

## Güvenlik Sınırları

- Özellik açık kullanıcı onayı olmadan çalışmaz.
- Şarj eşik üzerindeyse bildirim üretmez.
- Riskli, erişilemez veya düşük skorlu istasyonu önermez.
- Aynı karar 12 saat içinde tekrar bildirilmez.
- Telemetri altı saatten eskiyse kullanılmaz.
- Arka plan görevinin ne zaman çalışacağına iOS karar verir; uygulama bunu kesin zamanlayıcı gibi kullanmaz.
- Navigasyon ancak kullanıcı bildirim veya kart eylemine dokunduğunda açılır.
- Bildirim, uygulamayı açmadan 15 dakika erteleme ve gün sonuna kadar susturma aksiyonlarını uygular; rota aksiyonu hazırlanmış istasyonu tek dokunuşla açar.

## Araç Entegrasyonu

`VehicleTelemetryClient` üretici API'si ve MFi/External Accessory entegrasyonları için sınırdır. Bugünkü varsayılan istemci, kullanıcının cihazda tuttuğu sürüş profilini kullanır ve bunu arayüzde açıkça belirtir. Üretici istemcisi eklendiğinde `manufacturerAPI` veya `externalAccessory` kaynağıyla güncel batarya, kapasite ve tüketim değerini döndürür; karar ve UI kodu değişmez.

CarPlay bağlantısı genel amaçlı bir araç batarya API'si sağlamaz. Gerçek telemetri için araç üreticisinin izin verdiği API ya da MFi protokolü gerekir. CarPlay EV-charging arayüzü ve navigasyon deneyimi ayrıca Apple entitlement onayına tabidir.

## Sonraki Sağlayıcılar

1. OAuth tabanlı üretici istemcileri ve Keychain token saklama.
2. Sağlayıcı webhook/push olaylarıyla `vehicleConnected` değerlendirmesi.
3. CarPlay EV-charging entitlement sonrası `CPPointOfInterestTemplate` üzerinde hazır istasyon.
4. Sunucu tarafı canlı doluluk değişince mevcut öneriyi yeniden doğrulayan sessiz push.
