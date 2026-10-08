# App Review Notes Taslağı

Üretim yapılandırması ve gerçek cihaz testleri tamamlandığında aşağıdaki İngilizce metin App Review Notes alanına girilebilir. Hesap sahibinin iletişim bilgileri App Review Information formuna ayrıca eklenir.

## Notes

SarjBul helps drivers find EV charging stations in Türkiye. The app has no sign-in or registration form. Cloud features use a Firebase anonymous session; no reviewer login credentials are required.

To test station search from outside Türkiye:

1. Launch the app. Location permission is optional.
2. If the current location has no nearby stations, return to Home and use Choose location. Search for Güzelyalı, İzmir, Türkiye and select a result.
3. Adjust the charge level and driving values under the expandable driving profile if needed.
4. Open the suggested station or the Routes tab. The station feed and map use charging locations in Türkiye.
5. Open a route and choose Apple Maps or Google Maps. Navigation is handed off to that application. A manual starting location is included; the external app may show a route preview or request its own location permission.
6. Use the navigation control to open Profile. Cloud data can be reset there. The app displays pending progress until the server confirms cleanup; use Check deletion status to retry. A new anonymous identity is created after cleanup is confirmed and the old identity is deleted.

Charge, range and travel time are estimates. Manual battery values are not measurements from the vehicle. The station inventory is normalized exclusively from EPDK public station records. This inventory does not supply live availability or prices; unknown values are shown as unavailable. Maps and address search use Apple MapKit.

Widgets and Live Activities summarize the user's charging break and station information. Background refresh and notifications depend on iOS scheduling and permissions; the app does not require continuous background location.

Weather and elevation API clients and weather-dependent calendar suggestions/settings have been removed. Existing weather/context opt-ins are reset to off. No EventKit permission is requested by this disabled flow. HealthKit and heart-rate access remain removed from the app, capabilities and permission descriptions.

Support: sarjbul@icloud.com

Support and privacy choices: https://ozdemirbariss-gif.github.io/sarjbul-ios/support/

Privacy policy: https://ozdemirbariss-gif.github.io/sarjbul-ios/privacy/

## Yayın Öncesi Kontrol

- Bu notları gerçek Release build üzerinde uygula; çalışmayan adımı mağazaya göndermeden düzelt.
- HealthKit capability/izin metninin imzalı build içinde bulunmadığını doğrula; kaldırılan özellik yayın kapsamı dışındadır.
- Yerel veri sıfırlama ile bulut verisi sıfırlamanın sonuçlarını gerçek backend'de doğrula.
- EPDK ticari kullanım/yeniden dağıtım izni belgelenmeden ve `commercialDataUseApproved` yayın gate’i geçmeden göndermeyin. [Hak durumu](DATA_PROVIDER_TERMS.md).
- Apple üyeliği, imzalama ve App Attest etkinliği tamamlanmadan bu belgeyi test kanıtı sayma.

## First release scope — 8 October 2026

Search preserves the user's connector, power, operator, text and range conditions. A no-match result provides a way to edit filters. Station cards, Home suggestions and details show price provenance and unknown tariff confirmation dates separately from catalog dates. Availability is either a valid operator snapshot no older than 15 minutes, an explicitly historical community estimate, or unknown. Community risk reports do not assert current operator status.

The “I started charging” action starts a local 30-minute reminder only. It does not start a charger. Widget and Live Activity content is a timer with a user-selected target, not measured vehicle charge or operator-confirmed charging progress. No reservation, payment, or remote charging controls are included.

A CarPlay EV Charging entitlement request was submitted on 8 October 2026; Apple acknowledged receipt. Entitlement approval is pending. This build has no embedded CarPlay UI or entitlement and hands directions off to Maps.
