import Foundation

public enum ChargingReceiptParser {
    public static func parse(_ text: String) -> ParsedChargingReceipt {
        let normalized = text.replacingOccurrences(of: "₺", with: " TL ")
        let energy = firstNumber(
            in: normalized,
            patterns: [
                #"(?i)([0-9][0-9., ]*)\s*kwh"#,
                #"(?i)(?:enerji|tuketim|tüketim)\s*[:\-]?\s*([0-9][0-9., ]*)"#
            ]
        )
        let unitPrice = firstNumber(
            in: normalized,
            patterns: [
                #"(?i)([0-9][0-9., ]*)\s*(?:tl)?\s*/\s*kwh"#,
                #"(?i)(?:birim\s*fiyat|kwh\s*fiyati|kwh\s*fiyatı)\s*[:\-]?\s*([0-9][0-9., ]*)"#
            ]
        )
        let total = firstNumber(
            in: normalized,
            patterns: [
                #"(?i)(?:toplam|tutar|odenecek|ödenecek)\s*[:\-]?\s*([0-9][0-9., ]*)\s*(?:tl)?"#,
                #"(?i)([0-9][0-9., ]*)\s*tl"#
            ]
        )
        let derivedUnitPrice: Double? = if let energy, let total, energy > 0 {
            total / energy
        } else {
            nil
        }
        return ParsedChargingReceipt(
            energyKWh: plausible(energy, range: 0.1...300),
            totalCostTRY: plausible(total, range: 0.1...100_000),
            unitPriceTRY: plausible(unitPrice ?? derivedUnitPrice, range: 0.1...200)
        )
    }

    private static func firstNumber(in text: String, patterns: [String]) -> Double? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(
                    in: text,
                    range: NSRange(text.startIndex..., in: text)
                  ),
                  match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text) else { continue }
            if let value = NumberParser.firstDecimal(in: String(text[range])) { return value }
        }
        return nil
    }

    private static func plausible(_ value: Double?, range: ClosedRange<Double>) -> Double? {
        guard let value, range.contains(value) else { return nil }
        return value
    }
}

public enum ChargingHistoryAnalytics {
    public static func summary(
        records: [ChargingSessionRecord],
        profile: DrivingProfile,
        year: Int,
        calendar: Calendar = .current
    ) -> ChargingYearSummary {
        let selected = records.filter { calendar.component(.year, from: $0.date) == year }
        let energy = selected.reduce(0) { $0 + $1.energyKWh }
        let cost = selected.reduce(0) { $0 + $1.totalCostTRY }
        let distance = profile.consumptionKWhPer100Km > 0
            ? energy / profile.consumptionKWhPer100Km * 100
            : 0
        let operatorCounts = Dictionary(grouping: selected.compactMap(\.operatorName), by: { $0 })
            .mapValues(\.count)
        let favoriteOperator = operatorCounts.max { $0.value < $1.value }?.key
        return ChargingYearSummary(
            year: year,
            sessionCount: selected.count,
            energyKWh: energy,
            totalCostTRY: cost,
            estimatedDistanceKm: distance,
            avoidedCO2Kg: distance * 0.12,
            favoriteOperator: favoriteOperator,
            visitedProvinces: Set(selected.compactMap(\.province))
        )
    }
}

public enum TurkishProvinceDetector {
    public static let provinces = [
        "Adana", "Adıyaman", "Afyonkarahisar", "Ağrı", "Amasya", "Ankara", "Antalya", "Artvin", "Aydın",
        "Balıkesir", "Bilecik", "Bingöl", "Bitlis", "Bolu", "Burdur", "Bursa", "Çanakkale", "Çankırı",
        "Çorum", "Denizli", "Diyarbakır", "Edirne", "Elazığ", "Erzincan", "Erzurum", "Eskişehir", "Gaziantep",
        "Giresun", "Gümüşhane", "Hakkari", "Hatay", "Isparta", "Mersin", "İstanbul", "İzmir", "Kars",
        "Kastamonu", "Kayseri", "Kırklareli", "Kırşehir", "Kocaeli", "Konya", "Kütahya", "Malatya", "Manisa",
        "Kahramanmaraş", "Mardin", "Muğla", "Muş", "Nevşehir", "Niğde", "Ordu", "Rize", "Sakarya",
        "Samsun", "Siirt", "Sinop", "Sivas", "Tekirdağ", "Tokat", "Trabzon", "Tunceli", "Şanlıurfa",
        "Uşak", "Van", "Yozgat", "Zonguldak", "Aksaray", "Bayburt", "Karaman", "Kırıkkale", "Batman",
        "Şırnak", "Bartın", "Ardahan", "Iğdır", "Yalova", "Karabük", "Kilis", "Osmaniye", "Düzce"
    ]

    public static func detect(in text: String) -> String? {
        let normalized = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "tr_TR"))
        return provinces.first {
            normalized.contains($0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "tr_TR")))
        }
    }
}
