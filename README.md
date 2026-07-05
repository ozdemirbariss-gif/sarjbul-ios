# SarjBul iOS

SwiftUI tabanli SarjBul iOS mimarisi. Bu repo, mevcut Streamlit projesindeki ana urun mantigini native iOS katmanlarina ayirir:

- konum izni ve manuel konum akisi
- batarya kapasitesi, sarj yuzdesi ve ortalama tuketim ile guvenli menzil hesabi
- Python projesindeki bounded aday arama, skorlamaya ve siralama mantigi
- dikey istasyon kart akisi
- Apple Maps ile rota acma
- Firebase Auth, favoriler ve durum bildirimi icin REST entegrasyonu
- sarj beklerken oynanacak mini "Salon" oyunu
- Firebase REST istemcisi icin guvenli konfigurasyon noktasi

## Ekran Goruntuleri

![SarjBul iOS ekranlari](Docs/screenshots/sarjbul-ios-preview.png)

Tasarim degisikligi yapildiginda bu README gorseli ayni degisiklikle birlikte guncellenir. Gorseli yeniden uretmek icin:

```bash
python3 Scripts/render_readme_preview.py
```

Uygulama renkleri, radius degerleri, golge token'lari ve README preview gorseli `SarjBul/Resources/design-tokens.json` dosyasindan beslenir. Web tarafindaki `style.css` beyaz/neon paleti bu dosyada tek kaynak olarak tutulur.

## Mimari

```text
SarjBul/                 SwiftUI uygulama hedefi
SarjBulCore/             UI'dan bagimsiz domain, model ve servis katmani
SarjBulTests/            Core hesaplama ve siralama testleri
project.yml              XcodeGen proje tanimi
Package.swift            SarjBulCore icin Swift Package
```

## Kurulum

1. Xcode 16 veya uzeri kurulu olmalidir.
2. XcodeGen kur:

```bash
brew install xcodegen
```

3. Projeyi uret:

```bash
xcodegen generate
open SarjBul.xcodeproj
```

4. `SarjBul/Resources/AppConfig.sample.plist` dosyasini `AppConfig.plist` olarak kopyala ve Firebase ayarlarini gir. Gizli anahtarlar repo'ya commit edilmemelidir.

## Veri

`SarjBul/Resources/stations.json` mevcut Python projesindeki istasyon verisi ile ayni semayi kullanir. iOS bundle'daki veri, Streamlit reposundaki guncel scrape ciktisindan minify edilerek uretilir.

Arama motoru Python tarafiyla ayni ana yaklasimi izler: once konuma gore bounding-box adaylari daraltir, yalnizca ust adaylari skorlar, Firebase `station_status` ozetlerini risk/aktif durum olarak skora ve rozetlere katar.

## Test

Swift Package testleri:

```bash
swift test
```

`xcodebuild` icin tam Xcode kurulumu gerekir.
