import Foundation

public struct ChargingSocket: Codable, Hashable, Sendable {
    public var id: String
    public var type: String

    public init(id: String, type: String) {
        self.id = id
        self.type = type
    }
}

public struct ChargingUnit: Codable, Hashable, Sendable {
    public var id: String
    public var powerKW: Double?
    public var sockets: [ChargingSocket]

    public init(id: String, powerKW: Double?, sockets: [ChargingSocket]) {
        self.id = id
        self.powerKW = powerKW
        self.sockets = sockets
    }
}

public struct Station: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var address: String
    public var latitude: Double
    public var longitude: Double
    public var power: String
    public var operatorName: String
    public var socket: String
    public var chargingUnits: [ChargingUnit]
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
        chargingUnits: [ChargingUnit] = [],
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
        self.chargingUnits = chargingUnits.isEmpty
            ? Station.legacyUnits(power: power, socket: socket) : chargingUnits
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
        case chargingUnits = "sarj_uniteleri"
        case epdkSockets = "epdk_sockets"
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
        if let units = try container.decodeIfPresent([ChargingUnit].self, forKey: .chargingUnits), !units.isEmpty {
            chargingUnits = units
        } else if let sockets = try container.decodeIfPresent([EPDKSocket].self, forKey: .epdkSockets), !sockets.isEmpty {
            // EPDK has socket IDs and powers, but no charging-unit ID. A unit per
            // socket preserves every known pairing without inventing shared hardware.
            chargingUnits = sockets.enumerated().map { index, item in
                let id = item.number ?? "socket-\(index)"
                return ChargingUnit(
                    id: id,
                    powerKW: NumberParser.firstDecimal(in: item.power ?? ""),
                    sockets: [ChargingSocket(id: id, type: Self.socketName(item.kind))]
                )
            }
        } else {
            chargingUnits = Self.legacyUnits(power: power, socket: socket)
        }
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

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(address, forKey: .address)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(power, forKey: .power)
        try container.encode(operatorName, forKey: .operatorName)
        try container.encode(socket, forKey: .socket)
        try container.encode(chargingUnits, forKey: .chargingUnits)
        try container.encode(price, forKey: .price)
        try container.encode(source, forKey: .source)
        try container.encode(sources, forKey: .sources)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encode(confidenceScore, forKey: .confidenceScore)
    }

    private struct EPDKSocket: Decodable {
        let number: String?
        let power: String?
        let kind: String?

        enum CodingKeys: String, CodingKey {
            case number = "soketNo"
            case power = "soketGucu"
            case kind = "soketTuru"
        }
    }

    private static func socketName(_ kind: String?) -> String {
        switch kind {
        case "AC_TYPE2": "Type 2"
        case "DC_CCS": "CCS"
        case "DC_CHADEMO": "CHAdeMO"
        default: kind ?? "Bilinmiyor"
        }
    }

    private static func legacyUnits(power: String, socket: String) -> [ChargingUnit] {
        let types = socket.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.localizedCaseInsensitiveCompare("Bilinmiyor") != .orderedSame }
        // A station-wide maximum cannot be assigned to several socket types.
        let knownPower = types.count == 1 ? NumberParser.firstDecimal(in: power) : nil
        return types.enumerated().map { index, type in
            ChargingUnit(id: "legacy-\(index)", powerKW: knownPower,
                         sockets: [ChargingSocket(id: "legacy-\(index)", type: type)])
        }
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
    var statusKey: String {
        let folded = id
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "tr_TR"))
            .replacingOccurrences(of: "ı", with: "i")
        let allowed = folded.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar)
                || scalar == " "
                || scalar == "_"
                || scalar == "-" {
                return Character(scalar)
            }
            return " "
        }
        let key = String(allowed).split(separator: " ").joined(separator: "_")
        return key.isEmpty ? id : String(key.prefix(80))
    }

    var powerKW: Double {
        chargingUnits.compactMap(\.powerKW).max() ?? 0
    }

    func matchingPowerKW(socketFilters: Set<String>) -> Double {
        chargingUnits.filter { unit in
            socketFilters.isEmpty || unit.sockets.contains { socket in
                socketFilters.contains { socket.type.localizedCaseInsensitiveContains($0) }
            }
        }.compactMap(\.powerKW).max() ?? 0
    }

    func matches(minimumPowerKW: Double, socketFilters: Set<String>) -> Bool {
        if minimumPowerKW <= 0 && socketFilters.isEmpty { return true }
        return chargingUnits.contains { unit in
            (minimumPowerKW <= 0 || (unit.powerKW ?? 0) >= minimumPowerKW)
                && (socketFilters.isEmpty || unit.sockets.contains { socket in
                    socketFilters.contains { socket.type.localizedCaseInsensitiveContains($0) }
                })
        }
    }

    var priceValue: Double {
        NumberParser.firstDecimal(in: price) ?? 9999
    }

    var hasKnownPower: Bool {
        chargingUnits.contains { $0.powerKW != nil }
    }

    var hasKnownSocket: Bool {
        chargingUnits.contains { !$0.sockets.isEmpty }
    }

    var hasValidCoordinate: Bool {
        (-90...90).contains(latitude)
            && (-180...180).contains(longitude)
            && !(abs(latitude) < 0.000001 && abs(longitude) < 0.000001)
    }

    var searchableText: String { searchKey }
}
