import Foundation

public struct StationDecisionSummary: Equatable, Sendable {
    public enum Availability: Equatable, Sendable {
        case risky
        case live(available: Int, total: Int)
        case predictedBusy(percent: Int)
        case predictedAvailable(percent: Int)
        case unknown
    }

    public var arrivalChargePercent: Int
    public var availability: Availability
    public var chargeToTargetMinutes: Int?
    public var targetChargePercent: Int

    public init(
        arrivalChargePercent: Int,
        availability: Availability,
        chargeToTargetMinutes: Int?,
        targetChargePercent: Int
    ) {
        self.arrivalChargePercent = arrivalChargePercent
        self.availability = availability
        self.chargeToTargetMinutes = chargeToTargetMinutes
        self.targetChargePercent = targetChargePercent
    }
}

public enum StationDecisionEngine {
    public static func summarize(
        candidate: StationCandidate,
        profile: DrivingProfile,
        targetChargePercent: Int = 80,
        now: Date = Date(),
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> StationDecisionSummary {
        let arrival = max(0, min(100, Int(candidate.arrivalChargePercent.rounded())))
        let target = max(arrival, min(100, targetChargePercent))
        let chargeMinutes: Int? = if candidate.station.powerKW > 0, target > arrival {
            Int(ceil(ChargingCurve.minutes(
                from: arrival,
                to: target,
                batteryKWh: profile.batteryKWh,
                stationPowerKW: candidate.station.powerKW
            )))
        } else if target == arrival {
            0
        } else {
            nil
        }

        return StationDecisionSummary(
            arrivalChargePercent: arrival,
            availability: availability(
                candidate: candidate,
                now: now,
                calendar: calendar
            ),
            chargeToTargetMinutes: chargeMinutes,
            targetChargePercent: targetChargePercent
        )
    }

    private static func availability(
        candidate: StationCandidate,
        now: Date,
        calendar: Calendar
    ) -> StationDecisionSummary.Availability {
        if candidate.hasRiskyStatus { return .risky }

        if let live = candidate.liveAvailability,
           abs(now.timeIntervalSince(live.updatedAt)) <= 15 * 60 {
            return .live(
                available: max(0, live.availableConnectors),
                total: max(0, live.totalConnectors)
            )
        }

        let prediction = OccupancyPredictor.predict(
            station: candidate.station,
            insight: candidate.communityInsight,
            date: now,
            calendar: calendar
        )
        guard prediction.confidence != .low else { return .unknown }
        let busyPercent = Int((prediction.busyProbability * 100).rounded())
        return prediction.busyProbability >= 0.55
            ? .predictedBusy(percent: busyPercent)
            : .predictedAvailable(percent: 100 - busyPercent)
    }
}
