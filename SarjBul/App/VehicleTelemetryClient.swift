import Foundation
import SarjBulCore

protocol VehicleTelemetryClient: Sendable {
    func latestSnapshot(fallbackProfile: DrivingProfile) async -> VehicleTelemetrySnapshot?
}

struct ProfileVehicleTelemetryClient: VehicleTelemetryClient {
    func latestSnapshot(fallbackProfile: DrivingProfile) async -> VehicleTelemetrySnapshot? {
        VehicleTelemetrySnapshot(
            chargePercent: fallbackProfile.chargePercent,
            batteryKWh: fallbackProfile.batteryKWh,
            consumptionKWhPer100Km: fallbackProfile.consumptionKWhPer100Km,
            safetyMarginPercent: fallbackProfile.safetyMarginPercent,
            source: .manualProfile,
            isVehicleConnected: false,
            capturedAt: Date()
        )
    }
}

// Manufacturer and MFi integrations implement VehicleTelemetryClient without
// changing the decision engine or presentation layer.
