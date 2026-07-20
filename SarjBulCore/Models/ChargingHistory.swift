import Foundation

public struct ParsedChargingReceipt: Equatable, Sendable {
    public var energyKWh: Double?
    public var totalCostTRY: Double?
    public var unitPriceTRY: Double?

    public init(energyKWh: Double? = nil, totalCostTRY: Double? = nil, unitPriceTRY: Double? = nil) {
        self.energyKWh = energyKWh
        self.totalCostTRY = totalCostTRY
        self.unitPriceTRY = unitPriceTRY
    }
}

public struct ChargingSessionRecord: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var date: Date
    public var stationID: String?
    public var stationName: String
    public var operatorName: String?
    public var province: String?
    public var energyKWh: Double
    public var totalCostTRY: Double
    public var unitPriceTRY: Double?
    public var source: String

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        stationID: String? = nil,
        stationName: String,
        operatorName: String? = nil,
        province: String? = nil,
        energyKWh: Double,
        totalCostTRY: Double,
        unitPriceTRY: Double? = nil,
        source: String = "receipt_ocr"
    ) {
        self.id = id
        self.date = date
        self.stationID = stationID
        self.stationName = stationName
        self.operatorName = operatorName
        self.province = province
        self.energyKWh = energyKWh
        self.totalCostTRY = totalCostTRY
        self.unitPriceTRY = unitPriceTRY
        self.source = source
    }
}

public struct ChargingYearSummary: Equatable, Sendable {
    public var year: Int
    public var sessionCount: Int
    public var energyKWh: Double
    public var totalCostTRY: Double
    public var estimatedDistanceKm: Double
    public var avoidedCO2Kg: Double
    public var favoriteOperator: String?
    public var visitedProvinces: Set<String>

    public init(
        year: Int,
        sessionCount: Int,
        energyKWh: Double,
        totalCostTRY: Double,
        estimatedDistanceKm: Double,
        avoidedCO2Kg: Double,
        favoriteOperator: String?,
        visitedProvinces: Set<String>
    ) {
        self.year = year
        self.sessionCount = sessionCount
        self.energyKWh = energyKWh
        self.totalCostTRY = totalCostTRY
        self.estimatedDistanceKm = estimatedDistanceKm
        self.avoidedCO2Kg = avoidedCO2Kg
        self.favoriteOperator = favoriteOperator
        self.visitedProvinces = visitedProvinces
    }
}

public enum ChargingCollectionKind: String, Sendable {
    case eastExpress = "east-express"
    case aegeanTour = "aegean-tour"
    case blackSeaHighlands = "black-sea-highlands"
}

public struct ChargingCollectionProgress: Identifiable, Equatable, Sendable {
    public var kind: ChargingCollectionKind
    public var symbol: String
    public var provinces: [String]
    public var visited: Set<String>

    public init(kind: ChargingCollectionKind, symbol: String, provinces: [String], visited: Set<String>) {
        self.kind = kind
        self.symbol = symbol
        self.provinces = provinces
        self.visited = visited
    }

    public var id: String { kind.rawValue }
    public var visitedCount: Int { visited.intersection(provinces).count }
    public var isComplete: Bool { visitedCount == provinces.count }
    public var fractionComplete: Double {
        guard !provinces.isEmpty else { return 0 }
        return Double(visitedCount) / Double(provinces.count)
    }
}

public enum ChargingCollections {
    public static func progress(visitedProvinces: Set<String>) -> [ChargingCollectionProgress] {
        definitions.map { definition in
            ChargingCollectionProgress(
                kind: definition.kind,
                symbol: definition.symbol,
                provinces: definition.provinces,
                visited: visitedProvinces
            )
        }
    }

    private static let definitions: [(kind: ChargingCollectionKind, symbol: String, provinces: [String])] = [
        (
            .eastExpress,
            "tram.fill",
            ["Ankara", "Kırıkkale", "Kayseri", "Sivas", "Erzincan", "Erzurum", "Kars"]
        ),
        (
            .aegeanTour,
            "sun.max.fill",
            ["İzmir", "Manisa", "Aydın", "Denizli", "Muğla"]
        ),
        (
            .blackSeaHighlands,
            "mountain.2.fill",
            ["Samsun", "Ordu", "Giresun", "Trabzon", "Rize", "Artvin"]
        )
    ]
}
