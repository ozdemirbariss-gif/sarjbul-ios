import Foundation
import SarjBulCore

struct ChargingSuggestionPresentation {
    let proposal: AutonomousChargingProposal
    let language: AppLanguage
    var report: AutomationReport?
    var telemetry: VehicleTelemetrySnapshot?
    var lowChargeThreshold = 30
    var now = Date()

    var stationName: String { Self.stationName(proposal.stationName) }
    var heading: String { text("agent.suggestion") }
    var duration: String { text("agent.estimated_minutes", ["minutes": "\(proposal.estimatedMinutes)"]) }
    var arrival: String { text("agent.estimated_arrival", ["percent": "\(proposal.arrivalChargePercent)"]) }
    var source: String {
        text(proposal.telemetrySource == .manualProfile ? "agent.source_profile" : "agent.source_vehicle")
    }
    var distance: String {
        text("agent.estimated_distance", [
            "distance": proposal.distanceKm.formatted(.number.locale(language.locale).precision(.fractionLength(1)))
        ])
    }
    var reason: String {
        guard let report, report.selectedStationName == proposal.stationName else {
            return text("agent.reason_default")
        }
        switch report.rule {
        case .preparedRouteRisky: return text("agent.report_risky")
        case .preparedRouteExpired: return text("agent.report_expired")
        case .stationDataStale: return text("agent.report_refreshed")
        case .lowCharge: return text("agent.report_low_charge")
        }
    }
    var confirmedLowCharge: String? {
        guard let telemetry,
              proposal.telemetrySource != .manualProfile,
              telemetry.source == proposal.telemetrySource,
              telemetry.isVehicleConnected,
              (0...100).contains(telemetry.chargePercent),
              telemetry.chargePercent <= lowChargeThreshold,
              (0...900).contains(now.timeIntervalSince(telemetry.capturedAt)) else { return nil }
        return text("agent.vehicle_low_charge", ["percent": "\(telemetry.chargePercent)"])
    }

    func text(_ key: String, _ replacements: [String: String] = [:]) -> String {
        AppLocalization.text(key, language: language, replacements: replacements)
    }

    static func stationName(_ name: String) -> String {
        // Turkish station names retain their locale even when the interface is English.
        let locale = Locale(identifier: "tr_TR")
        guard name == name.uppercased(with: locale), name != name.lowercased(with: locale) else { return name }
        let acronyms: Set<String> = ["AC", "DC", "CCS", "CCS2", "AVM", "OSB", "BMW", "MG", "ABB", "TCDD"]
        var output = ""
        name.enumerateSubstrings(in: name.startIndex..<name.endIndex, options: .byWords) { word, _, enclosing, _ in
            guard let word else { return }
            let original = String(name[enclosing])
            output += original.replacingOccurrences(of: word, with: acronyms.contains(word) ? word : word.capitalized(with: locale))
        }
        return output.isEmpty ? name : output
    }
}
