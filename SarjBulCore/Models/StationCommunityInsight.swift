import Foundation

public enum StationDataField: String, Codable, CaseIterable, Hashable, Sendable {
    case price
    case socket
    case address
    case operatorName = "operator"
    case lighting
    case camera
    case open24Hours = "open_24_hours"
}

public struct StationFieldVerification: Codable, Hashable, Sendable {
    public var value: String
    public var confirmationCount: Int
    public var independentUserCount: Int
    public var confidence: Double
    public var verified: Bool
    public var lastConfirmedAt: String?

    public init(
        value: String,
        confirmationCount: Int = 0,
        independentUserCount: Int = 0,
        confidence: Double = 0,
        verified: Bool = false,
        lastConfirmedAt: String? = nil
    ) {
        self.value = value
        self.confirmationCount = confirmationCount
        self.independentUserCount = independentUserCount
        self.confidence = confidence
        self.verified = verified
        self.lastConfirmedAt = lastConfirmedAt
    }

    private enum CodingKeys: String, CodingKey {
        case value = "deger"
        case confirmationCount = "onay_sayisi"
        case independentUserCount = "bagimsiz_kullanici_sayisi"
        case confidence = "guven"
        case verified = "dogrulandi"
        case lastConfirmedAt = "son_onay_zamani"
    }
}

public struct OccupancyObservationBucket: Codable, Hashable, Sendable {
    public var busy: Int
    public var available: Int

    public init(busy: Int = 0, available: Int = 0) {
        self.busy = busy
        self.available = available
    }

    public var total: Int { busy + available }
}

public struct StationCommunityInsight: Codable, Hashable, Sendable {
    public var fields: [String: StationFieldVerification]
    public var occupancy: [String: OccupancyObservationBucket]
    public var updatedAt: String?

    public init(
        fields: [String: StationFieldVerification] = [:],
        occupancy: [String: OccupancyObservationBucket] = [:],
        updatedAt: String? = nil
    ) {
        self.fields = fields
        self.occupancy = occupancy
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case fields = "alanlar"
        case occupancy = "saatlik_yogunluk"
        case updatedAt = "guncelleme_tarihi"
    }

    public func verification(for field: StationDataField) -> StationFieldVerification? {
        fields[field.rawValue]
    }
}

public struct StationContribution: Codable, Hashable, Sendable {
    public var values: [StationDataField: String]

    public init(values: [StationDataField: String]) {
        self.values = values
    }
}

public enum StationDataQuality {
    public static func isUnknown(_ value: String) -> Bool {
        let normalized = value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "tr_TR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty
            || normalized.contains("bilinmiyor")
            || normalized.contains("unknown")
            || normalized.contains("adres bilgisi yok")
    }

    public static func displayValue(
        sourceValue: String,
        field: StationDataField,
        insight: StationCommunityInsight?
    ) -> String {
        guard let verification = insight?.verification(for: field), verification.verified else {
            return sourceValue
        }
        return verification.value
    }

    public static func confidence(
        station: Station,
        insight: StationCommunityInsight?,
        now: Date = Date(),
        halfLifeDays: Double = 120
    ) -> Double {
        let sourceAgeFactor = decayFactor(timestamp: station.updatedAt, now: now, halfLifeDays: halfLifeDays)
        let sourceConfidence = station.confidenceScore * sourceAgeFactor
        let verifiedFields = insight?.fields.values.filter(\.verified) ?? []
        guard !verifiedFields.isEmpty else { return min(1, max(0, sourceConfidence)) }

        let community = verifiedFields.reduce(0.0) { $0 + $1.confidence } / Double(verifiedFields.count)
        let communityAge = verifiedFields.reduce(0.0) { result, field in
            result + decayFactor(timestamp: field.lastConfirmedAt, now: now, halfLifeDays: 90)
        } / Double(verifiedFields.count)
        return min(1, max(0, sourceConfidence * 0.45 + community * communityAge * 0.55))
    }

    public static func decayFactor(
        timestamp: String?,
        now: Date = Date(),
        halfLifeDays: Double
    ) -> Double {
        guard halfLifeDays > 0, let timestamp, let date = parseISO8601(timestamp) else { return 1 }
        let ageDays = max(0, now.timeIntervalSince(date) / 86_400)
        return pow(0.5, ageDays / halfLifeDays)
    }

    private static func parseISO8601(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

public struct LicensedOperatorRecord: Codable, Hashable, Sendable {
    public var licenseNumber: String
    public var holder: String
    public var brands: [String]
    public var validFrom: String
    public var validUntil: String

    public init(
        licenseNumber: String,
        holder: String,
        brands: [String],
        validFrom: String = "",
        validUntil: String = ""
    ) {
        self.licenseNumber = licenseNumber
        self.holder = holder
        self.brands = brands
        self.validFrom = validFrom
        self.validUntil = validUntil
    }

    private enum CodingKeys: String, CodingKey {
        case licenseNumber = "license_number"
        case holder
        case brands
        case validFrom = "valid_from"
        case validUntil = "valid_until"
    }
}

public struct LicensedOperatorSnapshot: Codable, Sendable {
    public var generatedAt: String
    public var source: String
    public var licenseCount: Int
    public var licenses: [LicensedOperatorRecord]

    private enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case source
        case licenseCount = "license_count"
        case licenses
    }
}

public enum LicensedOperatorRegistry {
    public static let snapshot: LicensedOperatorSnapshot? = {
        guard let url = Bundle.main.url(
            forResource: "epdk-licensed-operators",
            withExtension: "json"
        ), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(LicensedOperatorSnapshot.self, from: data)
    }()

    public static func contains(_ operatorName: String) -> Bool {
        match(operatorName) != nil
    }

    public static func match(
        _ operatorName: String,
        records: [LicensedOperatorRecord]? = nil
    ) -> LicensedOperatorRecord? {
        let candidate = normalize(operatorName)
        guard candidate.count >= 3 else { return nil }
        return (records ?? snapshot?.licenses ?? fallbackRecords).first { record in
            ([record.holder] + record.brands).contains { alias in
                let normalizedAlias = normalize(alias)
                guard normalizedAlias.count >= 3 else { return false }
                return candidate == normalizedAlias
                    || candidate.contains(normalizedAlias)
                    || normalizedAlias.contains(candidate)
            }
        }
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "tr_TR"))
            .lowercased(with: Locale(identifier: "tr_TR"))
            .unicodeScalars
            .filter(CharacterSet.alphanumerics.contains)
            .map(String.init)
            .joined()
            .replacingOccurrences(of: "ı", with: "i")
    }

    private static let fallbackRecords = [
        LicensedOperatorRecord(licenseNumber: "", holder: "Zorlu Energy Solutions", brands: ["ZES"]),
        LicensedOperatorRecord(licenseNumber: "", holder: "Eşarj", brands: ["Eşarj"]),
        LicensedOperatorRecord(licenseNumber: "", holder: "Trugo", brands: ["Trugo"]),
        LicensedOperatorRecord(licenseNumber: "", holder: "Voltrun", brands: ["Voltrun"]),
        LicensedOperatorRecord(licenseNumber: "", holder: "Aydem Plus", brands: ["otoWATT"]),
        LicensedOperatorRecord(licenseNumber: "", holder: "Beefull", brands: ["Beefull"])
    ]
}
