import Foundation

public struct DrivingProfile: Codable, Equatable, Sendable {
    public var batteryKWh: Double
    public var chargePercent: Int
    public var consumptionKWhPer100Km: Double
    public var safetyMarginPercent: Int

    public init(
        batteryKWh: Double = 75,
        chargePercent: Int = 30,
        consumptionKWhPer100Km: Double = 16.9,
        safetyMarginPercent: Int = 25
    ) {
        self.batteryKWh = batteryKWh
        self.chargePercent = chargePercent
        self.consumptionKWhPer100Km = consumptionKWhPer100Km
        self.safetyMarginPercent = safetyMarginPercent
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
