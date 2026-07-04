# SarjBul iOS

SwiftUI tabanli SarjBul iOS mimarisi. Bu repo, mevcut Streamlit projesindeki ana urun mantigini native iOS katmanlarina ayirir:

- konum izni ve manuel konum akisi
- batarya kapasitesi, sarj yuzdesi ve ortalama tuketim ile guvenli menzil hesabi
- yakindaki istasyonlari filtreleme, skorlamaya ve siralama
- dikey istasyon kart akisi
- Apple Maps ile rota acma
- sarj beklerken oynanacak mini "Salon" oyunu
- Firebase REST istemcisi icin guvenli konfigurasyon noktasi

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

4. `SarjBul/Resources/AppConfig.sample.plist` dosyasini `AppConfig.plist` olarak kopyala ve Firebase/harita ayarlarini gir. Gizli anahtarlar repo'ya commit edilmemelidir.

## Veri

`SarjBul/Resources/stations.json` mevcut Python projesindeki istasyon verisi ile ayni semayi kullanir. Uygulama once bundled JSON'u okur; ileride ayni `StationRepository` protokolu uzerinden uzak API veya Firebase kaynagi eklenebilir.

## Test

Swift Package testleri:

```bash
swift test
```

`xcodebuild` icin tam Xcode kurulumu gerekir.

