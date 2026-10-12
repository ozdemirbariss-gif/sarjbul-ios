import Foundation

public struct DrivingProfile: Codable, Equatable, Sendable {
    public var batteryKWh: Double
    public var chargePercent: Int
    public var consumptionKWhPer100Km: Double
    public var safetyMarginPercent: Int
    public var maximumACPowerKW: Double
    public var maximumDCPowerKW: Double

    public init(
        batteryKWh: Double = 75,
        chargePercent: Int = 30,
        consumptionKWhPer100Km: Double = 16.9,
        safetyMarginPercent: Int = 25,
        maximumACPowerKW: Double = 11,
        maximumDCPowerKW: Double = 150
    ) {
        self.batteryKWh = batteryKWh
        self.chargePercent = chargePercent
        self.consumptionKWhPer100Km = consumptionKWhPer100Km
        self.safetyMarginPercent = safetyMarginPercent
        self.maximumACPowerKW = maximumACPowerKW
        self.maximumDCPowerKW = maximumDCPowerKW
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        batteryKWh = try values.decode(Double.self, forKey: .batteryKWh)
        chargePercent = try values.decode(Int.self, forKey: .chargePercent)
        consumptionKWhPer100Km = try values.decode(Double.self, forKey: .consumptionKWhPer100Km)
        safetyMarginPercent = try values.decode(Int.self, forKey: .safetyMarginPercent)
        maximumACPowerKW = try values.decodeIfPresent(Double.self, forKey: .maximumACPowerKW) ?? 11
        maximumDCPowerKW = try values.decodeIfPresent(Double.self, forKey: .maximumDCPowerKW) ?? 150
    }

    public func chargingPowerKW(for candidate: StationCandidate) -> Double {
        let matchingUnits = candidate.station.chargingUnits.filter {
            abs(($0.powerKW ?? 0) - candidate.chargingPowerKW) < 0.1
        }
        let socketTypes = matchingUnits.flatMap(\.sockets).map { $0.type.uppercased() }
        let onlyDC = !socketTypes.isEmpty && socketTypes.allSatisfy {
            $0.contains("CCS") || $0.contains("CHADEMO") || $0.contains("DC")
        }
        let limit = onlyDC ? maximumDCPowerKW : maximumACPowerKW
        return max(0, min(candidate.chargingPowerKW, limit))
    }

    private enum CodingKeys: String, CodingKey {
        case batteryKWh, chargePercent, consumptionKWhPer100Km, safetyMarginPercent
        case maximumACPowerKW, maximumDCPowerKW
    }

    public var safeRangeKm: Double {
        guard batteryKWh > 0, consumptionKWhPer100Km > 0 else { return 0 }
        let availableKWh = batteryKWh * (Double(chargePercent) / 100)
        let rawRange = availableKWh / consumptionKWhPer100Km * 100
        return rawRange * (1 - Double(safetyMarginPercent) / 100)
    }

    public func arrivalChargePercent(distanceKm: Double) -> Double {
        guard batteryKWh > 0 else { return 0 }
        let spentPercent = (distanceKm * consumptionKWhPer100Km / 100) / batteryKWh * 100
        return min(100, max(0, Double(chargePercent) - spentPercent))
    }
}
