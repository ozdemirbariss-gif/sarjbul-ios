import Foundation

public struct Station: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var address: String
    public var latitude: Double
    public var longitude: Double
    public var power: String
    public var operatorName: String
    public var socket: String
    public var price: String
    public var source: String
    public var sources: [String]
    public var updatedAt: String?
    public var confidenceScore: Double
    public let searchKey: String

    public init(
        id: String,
        name: String,
        address: String,
        latitude: Double,
        longitude: Double,
        power: String,
        operatorName: String,
        socket: String,
        price: String,
        source: String,
        sources: [String] = [],
        updatedAt: String? = nil,
        confidenceScore: Double = 0.62
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.power = power
        self.operatorName = operatorName
        self.socket = socket
        self.price = price
        self.source = source
        self.sources = sources
        self.updatedAt = updatedAt
        self.confidenceScore = confidenceScore
        searchKey = Station.makeSearchKey(
            name: name,
            address: address,
            operatorName: operatorName,
            socket: socket,
            power: power
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name = "isim"
        case address = "adres"
        case latitude = "enlem"
        case longitude = "boylam"
        case power = "hiz"
        case operatorName = "operator"
        case socket = "soket"
        case price = "fiyat"
        case source = "kaynak"
        case sources = "kaynaklar"
        case updatedAt = "guncelleme_tarihi"
        case confidenceScore = "guven_skoru"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "İstasyon"
        address = try container.decodeIfPresent(String.self, forKey: .address) ?? "Adres Bilgisi Yok"
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        power = try container.decodeIfPresent(String.self, forKey: .power) ?? "Bilinmiyor"
        operatorName = try container.decodeIfPresent(String.self, forKey: .operatorName) ?? "Operatör bilinmiyor"
        socket = try container.decodeIfPresent(String.self, forKey: .socket) ?? "Bilinmiyor"
        price = try container.decodeIfPresent(String.self, forKey: .price) ?? "Bilinmiyor"
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? ""
        sources = try container.decodeIfPresent([String].self, forKey: .sources) ?? []
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        confidenceScore = try container.decodeIfPresent(Double.self, forKey: .confidenceScore) ?? 0.62
        searchKey = Station.makeSearchKey(
            name: name,
            address: address,
            operatorName: operatorName,
            socket: socket,
            power: power
        )
    }

    private static func makeSearchKey(
        name: String,
        address: String,
        operatorName: String,
        socket: String,
        power: String
    ) -> String {
        "\(name) \(address) \(operatorName) \(socket) \(power)".folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "tr_TR")
        )
    }
}

public extension Station {
    var powerKW: Double {
        NumberParser.firstDecimal(in: power) ?? 0
    }

    var priceValue: Double {
        NumberParser.firstDecimal(in: price) ?? 9999
    }

    var searchableText: String { searchKey }
}
