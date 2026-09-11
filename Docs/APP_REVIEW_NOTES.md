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

Charge, range and travel time are estimates. Manual battery values are not measurements from the vehicle. Missing live availability and prices are shown as unavailable.

Widgets and Live Activities summarize the user's charging break and station information. Background refresh and notifications depend on iOS scheduling and permissions; the app does not require continuous background location.

Optional context settings are off by default. If enabled with system permission, EventKit evaluates upcoming events on-device. HealthKit access, if separately allowed, reads heart rate and resting heart rate samples on-device for contextual break recommendations. These features are not medical diagnosis or stress measurement. Calendar changes require acceptance of a suggestion or separately enabled automation after the app's historical acceptance threshold is reached. No HealthKit samples or event titles are sent to our servers.

## Yayın Öncesi Kontrol

- Bu notları gerçek Release build üzerinde uygula; çalışmayan adımı mağazaya göndermeden düzelt.
- HealthKit'in sağlık/fitness amacı koşulunu bu ürün için çözümle. Gizlilik metni eklemek tek başına uygunluk sağlamaz.
- Yerel veri sıfırlama ile bulut verisi sıfırlamanın sonuçlarını gerçek backend'de doğrula.
- Apple üyeliği, imzalama ve App Attest etkinliği tamamlanmadan bu belgeyi test kanıtı sayma.
