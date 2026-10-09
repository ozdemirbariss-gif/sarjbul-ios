# Kamuya açık bağlantılar — 9 Ekim 2026

| Alan | Üretim adresi |
| --- | --- |
| Gizlilik politikası | https://ozdemirbariss-gif.github.io/sarjbul-ios/privacy/ |
| Kullanım koşulları | https://ozdemirbariss-gif.github.io/sarjbul-ios/terms/ |
| Destek / Privacy Choices | https://ozdemirbariss-gif.github.io/sarjbul-ios/support/ |
| İstasyon manifesti | https://raw.githubusercontent.com/ozdemirbariss-gif/sarjbul-ios/main/SarjBul/Resources/StationTiles/station-tiles-manifest.json |
| Destek e-postası | sarjbul@icloud.com |

## Yayın

Hesap sahibinin isteğiyle belgeler GitHub Pages adresine taşındı. Repo kamuya
açık ve GitHub Pages, HTTPS zorunlu olacak şekilde etkinleştirildi.
`.github/workflows/public-pages.yml` yalnızca destek, gizlilik, koşullar ve ilgili
üretim betiği değiştiğinde sayfaları üretip yayımlar. Derleme ve yayım adımları
ayrıdır; yayımlama yetkileri yalnızca deployment işinde verilir.

Kaynak belgeler `Docs/PRIVACY_POLICY.md`, `Docs/TERMS_OF_USE.md` ve `Docs/SUPPORT.md`.
`python3 Scripts/build_public_pages.py --output <dizin>` bu üç belgeden statik
HTML üretir. Gezinti, CSS, belge içi bağlantılar ve canonical URL'ler
`/sarjbul-ios/` proje yolunu kullanır. Üretilen dosyalarda önceki barındırmanın
adı veya adresi bulunmaz. Gizlilik politikası, belge barındırmasını GitHub Pages
olarak açıklar ve GitHub gizlilik bildirimine yönlendirir.

## Doğrulama ve teslim

- Üretilen tüm sayfalardaki yerel bağlantılar ve CSS dosyası proje yolu altında
  gerçek dosyalara çözülür; otomatik sayfa testi geçti.
- 10 mevcut yayın yapılandırması testi ve `git diff --check` geçti.
- Uygulamanın varsayılan bağlantıları, örnek ve yerel üretim plist'i, mağaza
  metinleri, gizlilik cevap taslağı ve Review notları yeni adreslere güncellendi.
- [GitHub Pages dağıtımı](https://github.com/ozdemirbariss-gif/sarjbul-ios/actions/runs/37795800863)
  `31b4560779cc270e010c4568dfbc2f4d54cfe5ef` kaynağından başarıyla tamamlandı.
- 9 Ekim 2026'da ana sayfa, destek, gizlilik, koşullar ve CSS oturumsuz HTTPS
  200 döndü. Canlı yanıtların hiçbirinde önceki barındırmanın adı yoktu.
- [iOS CI](https://github.com/ozdemirbariss-gif/sarjbul-ios/actions/runs/37795800764)
  aynı kaynak için başarılı; backend ve iOS işleri geçti.
- App Store Connect'te destek, gizlilik ve User Privacy Choices URL'leri Türkçe
  ve English (U.S.) için GitHub Pages adreslerine kaydedildi.

İstasyon manifesti ve 61 döşemenin mevcut kamuya açık depo adresleri korunur.
Bu değişiklik istasyon verisini, veri sağlayıcı izin kapısını veya Firebase
backend durumunu değiştirmez. EPDK ticari kullanım izni ve üretim Functions
kurulumu tamamlanmadan App Store yayını yapılmamalıdır.
