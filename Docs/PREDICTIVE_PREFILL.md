# Tahmine Dayalı Ön Doldurma

SarjBul, istasyon arama ekranına girildiğinde kullanıcının daha önce aynı zaman bağlamında kullandığı parametreleri cihaz üzerinde değerlendirir. Güven eşiği sağlanırsa tercih, minimum güç, soket, operatör ve menzil filtresi arama başlamadan doldurulur.

## Güven kapısı

Ön doldurma yalnızca aşağıdaki koşulların tamamında çalışır:

- Aynı `hafta içi/hafta sonu + gün bölümü` bağlamında en az 6 gözlem
- Gözlemlerin en az 5 farklı güne yayılması
- Son 60 gündeki aynı bağlam gözlemlerinin en az %90'ında birebir aynı parametre seti
- Arama ekranının boş durumda olması

Eşik sağlanmazsa uygulama mevcut parametreleri değiştirmez. Gösterilen yüzde ölçülmüş geçmiş eşleşme oranıdır; gelecekteki davranış için istatistiksel garanti değildir.

## Güvenli sınır

- Şarj yüzdesi tahmin edilmez; aracın güncel değeri kullanılır.
- Hedef konum geçmişten otomatik seçilmez.
- Durum bildirimi, ödeme, rezervasyon ve şarj başlatma gibi sonuç doğuran işlemler otomatik doldurulmaz veya gönderilmez.
- Kullanıcı tahmini değiştirebilir veya `Geri al` ile önceki filtrelerine dönebilir.
- Gözlemler `UsageHabitEvent` içinde yalnızca cihazda tutulur ve mevcut 90 günlük saklama sınırına tabidir.

## Mimari

`PredictiveIntentEngine`, UI ve kalıcılıktan bağımsız saf bir Core bileşenidir. `HabitStore` cihazdaki olayları zaman bağlamına dönüştürür. `HomeView` yalnızca güven kapısından geçen sonucu `StationFilters` üzerine uygular. Bu ayrım, tahmin mantığının birim testleriyle doğrulanmasını ve ileride başka düşük riskli işlem parametrelerine kontrollü biçimde genişletilmesini sağlar.
