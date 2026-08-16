import Foundation

public enum VehicleTelemetrySource: String, Codable, Sendable {
    case manualProfile
    case manufacturerAPI
    case externalAccessory
}

public struct VehicleTelemetrySnapshot: Codable, Equatable, Sendable {
    public var chargePercent: Int
    public var batteryKWh: Double
    public var consumptionKWhPer100Km: Double
    public var safetyMarginPercent: Int
    public var source: VehicleTelemetrySource
    public var isVehicleConnected: Bool
    public var capturedAt: Date

    public init(
        chargePercent: Int,
        batteryKWh: Double,
        consumptionKWhPer100Km: Double,
        safetyMarginPercent: Int = 25,
        source: VehicleTelemetrySource,
        isVehicleConnected: Bool,
        capturedAt: Date
    ) {
        self.chargePercent = chargePercent
        self.batteryKWh = batteryKWh
        self.consumptionKWhPer100Km = consumptionKWhPer100Km
        self.safetyMarginPercent = safetyMarginPercent
        self.source = source
        self.isVehicleConnected = isVehicleConnected
        self.capturedAt = capturedAt
    }

    public var drivingProfile: DrivingProfile {
        DrivingProfile(
            batteryKWh: batteryKWh,
            chargePercent: chargePercent,
            consumptionKWhPer100Km: consumptionKWhPer100Km,
            safetyMarginPercent: safetyMarginPercent
        )
    }
}

public struct AutonomousChargingPolicy: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var triggerChargePercent: Int
    public var minimumArrivalPercent: Int
    public var minimumStationScore: Int
    public var cooldownHours: Int
    public var allowsProfileFallback: Bool

    public init(
        isEnabled: Bool = false,
        triggerChargePercent: Int = 30,
        minimumArrivalPercent: Int = 12,
        minimumStationScore: Int = 45,
        cooldownHours: Int = 12,
        allowsProfileFallback: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.triggerChargePercent = triggerChargePercent
        self.minimumArrivalPercent = minimumArrivalPercent
        self.minimumStationScore = minimumStationScore
        self.cooldownHours = cooldownHours
        self.allowsProfileFallback = allowsProfileFallback
    }
}

public enum ChargingAgentTrigger: String, Codable, Sendable {
    case appLaunch
    case locationUpdate
    case backgroundRefresh
    case backgroundProcessing
    case silentPush
    case vehicleConnected
}

public struct AutonomousChargingProposal: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var stationKey: String
    public var stationName: String
    public var distanceKm: Double
    public var estimatedMinutes: Int
    public var arrivalChargePercent: Int
    public var stationScore: Int
    public var telemetrySource: VehicleTelemetrySource
    public var trigger: ChargingAgentTrigger
    public var generatedAt: Date
    public var expiresAt: Date

    public init(
        id: UUID = UUID(),
        stationKey: String,
        stationName: String,
        distanceKm: Double,
        estimatedMinutes: Int,
        arrivalChargePercent: Int,
        stationScore: Int,
        telemetrySource: VehicleTelemetrySource,
        trigger: ChargingAgentTrigger,
        generatedAt: Date,
        expiresAt: Date
    ) {
        self.id = id
        self.stationKey = stationKey
        self.stationName = stationName
        self.distanceKm = distanceKm
        self.estimatedMinutes = estimatedMinutes
        self.arrivalChargePercent = arrivalChargePercent
        self.stationScore = stationScore
        self.telemetrySource = telemetrySource
        self.trigger = trigger
        self.generatedAt = generatedAt
        self.expiresAt = expiresAt
    }
}

public enum AutonomousChargingDecision: Equatable, Sendable {
    case propose(AutonomousChargingProposal)
    case noAction(Reason)

    public enum Reason: Equatable, Sendable {
        case disabled
        case staleLocation
        case staleTelemetry
        case vehicleConnectionRequired
        case chargeSufficient
        case cooldownActive
        case noSafeStation
    }
}

public struct AutonomousChargingDecisionEngine: Sendable {
    public init() {}

    public func evaluate(
        telemetry: VehicleTelemetrySnapshot,
        candidates: [StationCandidate],
        policy: AutonomousChargingPolicy,
        trigger: ChargingAgentTrigger,
        lastProposal: AutonomousChargingProposal? = nil,
        now: Date = Date()
    ) -> AutonomousChargingDecision {
        guard policy.isEnabled else { return .noAction(.disabled) }
        guard abs(now.timeIntervalSince(telemetry.capturedAt)) <= 6 * 3_600 else {
            return .noAction(.staleTelemetry)
        }
        guard telemetry.isVehicleConnected || policy.allowsProfileFallback else {
            return .noAction(.vehicleConnectionRequired)
        }
        guard telemetry.chargePercent <= policy.triggerChargePercent else {
            return .noAction(.chargeSufficient)
        }
        if let lastProposal,
           now.timeIntervalSince(lastProposal.generatedAt) < Double(policy.cooldownHours) * 3_600 {
            return .noAction(.cooldownActive)
        }

        guard let candidate = candidates.first(where: {
            !$0.hasRiskyStatus
                && $0.arrivalChargePercent >= Double(policy.minimumArrivalPercent)
                && $0.score >= policy.minimumStationScore
        }) else {
            return .noAction(.noSafeStation)
        }

        return .propose(AutonomousChargingProposal(
            stationKey: candidate.station.statusKey,
            stationName: candidate.station.name,
            distanceKm: candidate.distanceKm,
            estimatedMinutes: candidate.estimatedMinutes,
            arrivalChargePercent: Int(candidate.arrivalChargePercent.rounded()),
            stationScore: candidate.score,
            telemetrySource: telemetry.source,
            trigger: trigger,
            generatedAt: now,
            expiresAt: now.addingTimeInterval(2 * 3_600)
        ))
    }
}
