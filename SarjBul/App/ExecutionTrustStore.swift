import Foundation
import Observation
import SarjBulCore

struct VerifiedOutcomeValue: Equatable {
    var completedActions: Int
    var estimatedMinutesSaved: Int
    var averageTrustPercent: Int
}

@MainActor
@Observable
final class ExecutionTrustStore {
    private let persistence: any AppPersistence
    private(set) var proofs: [ExecutionProof]
    private(set) var graph: ContextualRelationGraph
    private(set) var lastDecisionLatencyMilliseconds = 0.0

    var latestVerifiedProof: ExecutionProof? {
        proofs.first(where: { $0.verified && $0.status == .completed })
    }

    var value: VerifiedOutcomeValue {
        let verified = proofs.filter { $0.verified && $0.status == .completed }
        let trust = verified.isEmpty ? 0 : verified.reduce(0) { $0 + $1.trustScore } / Double(verified.count)
        return VerifiedOutcomeValue(
            completedActions: verified.count,
            estimatedMinutesSaved: verified.reduce(0) { $0 + $1.estimatedTimeSavedSeconds } / 60,
            averageTrustPercent: Int((trust * 100).rounded())
        )
    }

    init(persistence: any AppPersistence) {
        self.persistence = persistence
        proofs = persistence.executionProofs
        graph = persistence.contextualRelationGraph
    }

    @discardableResult
    func record(
        action: ExecutedActionKind,
        intentKey: String,
        resultKey: String,
        status: ExecutionProofStatus,
        evidence: [ExecutionEvidence],
        deterministicChecks: [String: Bool],
        contextKeys: [String],
        startedAt: Date,
        completedAt: Date = Date(),
        estimatedTimeSavedSeconds: Int = 0
    ) -> ExecutionProof {
        let clockStart = ContinuousClock.now
        let assessment = ExecutionTrustEngine.assess(
            status: status,
            evidence: evidence,
            deterministicChecks: deterministicChecks,
            history: history(for: action),
            now: completedAt
        )
        let proof = ExecutionProof(
            action: action,
            intentKey: intentKey,
            resultKey: resultKey,
            status: status,
            evidence: evidence,
            deterministicChecks: deterministicChecks,
            trustScore: assessment.score,
            verified: assessment.isVerified,
            startedAt: startedAt,
            completedAt: completedAt,
            estimatedTimeSavedSeconds: estimatedTimeSavedSeconds
        )
        proofs.insert(proof, at: 0)
        proofs = Array(proofs.prefix(200))
        graph.record(
            contextKeys: contextKeys,
            intentKey: intentKey,
            outcomeKey: resultKey,
            verifiedSuccess: proof.verified,
            at: completedAt
        )
        persistence.executionProofs = proofs
        persistence.contextualRelationGraph = graph
        lastDecisionLatencyMilliseconds = milliseconds(since: clockStart)
        return proof
    }

    func assess(
        action: ExecutedActionKind,
        evidence: [ExecutionEvidence],
        deterministicChecks: [String: Bool],
        now: Date = Date()
    ) -> ActionTrustAssessment {
        let clockStart = ContinuousClock.now
        let assessment = ExecutionTrustEngine.assess(
            status: .completed,
            evidence: evidence,
            deterministicChecks: deterministicChecks,
            history: history(for: action),
            now: now
        )
        lastDecisionLatencyMilliseconds = milliseconds(since: clockStart)
        return assessment
    }

    func prediction(for contextKeys: [String]) -> ContextualOutcomePrediction? {
        let clockStart = ContinuousClock.now
        let prediction = graph.prediction(contextKeys: contextKeys)
        lastDecisionLatencyMilliseconds = milliseconds(since: clockStart)
        return prediction
    }

    func contextKeys(
        location: UserLocation?,
        preference: RoutePreference,
        date: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> [String] {
        var keys = ["preference:\(preference.rawValue)"]
        let hour = calendar.component(.hour, from: date)
        keys.append("period:\(hour / 4)")
        keys.append("weekday:\(calendar.component(.weekday, from: date))")
        if let location {
            keys.append(String(format: "cell:%.2f:%.2f", location.latitude, location.longitude))
            keys.append("location-source:\(location.source.rawValue)")
        }
        return keys
    }

    func stationObservedAt(_ station: Station, fallback: Date = Date()) -> Date {
        guard let raw = station.updatedAt else {
            return persistence.stationDataLastRefreshedAt ?? fallback
        }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: raw)
            ?? ISO8601DateFormatter().date(from: raw)
            ?? persistence.stationDataLastRefreshedAt
            ?? fallback
    }

    private func history(for action: ExecutedActionKind) -> HistoricalActionStats {
        let matching = proofs.filter { $0.action == action }
        return HistoricalActionStats(
            attempts: matching.count,
            successes: matching.filter { $0.verified && $0.status == .completed }.count
        )
    }

    private func milliseconds(since start: ContinuousClock.Instant) -> Double {
        let duration = start.duration(to: .now)
        return Double(duration.components.seconds) * 1_000
            + Double(duration.components.attoseconds) / 1_000_000_000_000_000
    }
}
