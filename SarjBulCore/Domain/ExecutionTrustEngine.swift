import Foundation

public enum ExecutedActionKind: String, Codable, CaseIterable, Sendable {
    case stationSearch
    case routePrepared
    case routeOpened
    case calendarDeferred
    case stationDataRefreshed
    case chargingVerified
}

public enum ExecutionProofStatus: String, Codable, Sendable {
    case completed
    case failed
    case rolledBack
}

public enum ExecutionEvidenceSource: String, Codable, Hashable, Sendable {
    case deterministicEngine
    case stationDataset
    case realtimeAvailability
    case deviceLocation
    case manualLocation
    case vehicleTelemetry
    case systemCalendar
    case userAction
    case chargingReceipt
}

public struct ExecutionEvidence: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var source: ExecutionEvidenceSource
    public var reliability: Double
    public var observedAt: Date
    public var maximumAge: TimeInterval

    public init(
        id: UUID = UUID(),
        source: ExecutionEvidenceSource,
        reliability: Double,
        observedAt: Date,
        maximumAge: TimeInterval
    ) {
        self.id = id
        self.source = source
        self.reliability = min(1, max(0, reliability))
        self.observedAt = observedAt
        self.maximumAge = max(1, maximumAge)
    }

    public func freshness(at date: Date) -> Double {
        let age = date.timeIntervalSince(observedAt)
        guard age >= -5 else { return 0 }
        return min(1, max(0, 1 - age / maximumAge))
    }
}

public struct HistoricalActionStats: Codable, Equatable, Sendable {
    public var attempts: Int
    public var successes: Int

    public init(attempts: Int = 0, successes: Int = 0) {
        self.attempts = max(0, attempts)
        self.successes = min(max(0, successes), max(0, attempts))
    }

    public var bayesianSuccessRate: Double {
        (Double(successes) + 2) / (Double(attempts) + 3)
    }
}

public struct ActionTrustAssessment: Equatable, Sendable {
    public var score: Double
    public var isVerified: Bool
    public var evidenceScore: Double
    public var historicalSuccessRate: Double
    public var deterministicChecksPassed: Bool

    public init(
        score: Double,
        isVerified: Bool,
        evidenceScore: Double,
        historicalSuccessRate: Double,
        deterministicChecksPassed: Bool
    ) {
        self.score = score
        self.isVerified = isVerified
        self.evidenceScore = evidenceScore
        self.historicalSuccessRate = historicalSuccessRate
        self.deterministicChecksPassed = deterministicChecksPassed
    }
}

public struct ExecutionProof: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var action: ExecutedActionKind
    public var intentKey: String
    public var resultKey: String
    public var status: ExecutionProofStatus
    public var evidence: [ExecutionEvidence]
    public var deterministicChecks: [String: Bool]
    public var trustScore: Double
    public var verified: Bool
    public var startedAt: Date
    public var completedAt: Date
    public var estimatedTimeSavedSeconds: Int

    public init(
        id: UUID = UUID(),
        action: ExecutedActionKind,
        intentKey: String,
        resultKey: String,
        status: ExecutionProofStatus,
        evidence: [ExecutionEvidence],
        deterministicChecks: [String: Bool],
        trustScore: Double,
        verified: Bool,
        startedAt: Date,
        completedAt: Date,
        estimatedTimeSavedSeconds: Int = 0
    ) {
        self.id = id
        self.action = action
        self.intentKey = intentKey
        self.resultKey = resultKey
        self.status = status
        self.evidence = evidence
        self.deterministicChecks = deterministicChecks
        self.trustScore = min(1, max(0, trustScore))
        self.verified = verified
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.estimatedTimeSavedSeconds = max(0, estimatedTimeSavedSeconds)
    }
}

public enum ExecutionTrustEngine {
    public static let verificationThreshold = 0.80

    public static func assess(
        status: ExecutionProofStatus,
        evidence: [ExecutionEvidence],
        deterministicChecks: [String: Bool],
        history: HistoricalActionStats,
        now: Date = Date()
    ) -> ActionTrustAssessment {
        let checksPassed = !deterministicChecks.isEmpty && deterministicChecks.values.allSatisfy { $0 }
        let evidenceScore = weightedEvidenceScore(evidence, now: now)
        let historyScore = history.bayesianSuccessRate
        let statusScore = status == .completed ? 1.0 : 0.0
        let score = min(1, max(0,
            evidenceScore * 0.50
                + historyScore * 0.20
                + (checksPassed ? 1.0 : 0.0) * 0.20
                + statusScore * 0.10
        ))
        let distinctSources = Set(evidence.map(\.source)).count
        let verified = status == .completed
            && checksPassed
            && distinctSources >= 2
            && evidenceScore >= 0.72
            && score >= verificationThreshold
        return ActionTrustAssessment(
            score: score,
            isVerified: verified,
            evidenceScore: evidenceScore,
            historicalSuccessRate: historyScore,
            deterministicChecksPassed: checksPassed
        )
    }

    private static func weightedEvidenceScore(_ evidence: [ExecutionEvidence], now: Date) -> Double {
        guard !evidence.isEmpty else { return 0 }
        let total = evidence.reduce(0.0) { result, item in
            result + item.reliability * item.freshness(at: now)
        }
        return total / Double(evidence.count)
    }
}

public struct ContextRelationEdge: Codable, Equatable, Identifiable, Sendable {
    public var contextKey: String
    public var intentKey: String
    public var outcomeKey: String
    public var attempts: Int
    public var verifiedSuccesses: Int
    public var lastObservedAt: Date

    public var id: String { "\(contextKey)|\(intentKey)|\(outcomeKey)" }

    public init(
        contextKey: String,
        intentKey: String,
        outcomeKey: String,
        attempts: Int = 0,
        verifiedSuccesses: Int = 0,
        lastObservedAt: Date
    ) {
        self.contextKey = contextKey
        self.intentKey = intentKey
        self.outcomeKey = outcomeKey
        self.attempts = attempts
        self.verifiedSuccesses = verifiedSuccesses
        self.lastObservedAt = lastObservedAt
    }

    public var confidence: Double {
        (Double(verifiedSuccesses) + 1) / (Double(attempts) + 2)
    }
}

public struct ContextualOutcomePrediction: Equatable, Sendable {
    public var intentKey: String
    public var outcomeKey: String
    public var confidence: Double
    public var supportingSuccesses: Int
}

public struct ContextualRelationGraph: Codable, Equatable, Sendable {
    public private(set) var edges: [ContextRelationEdge]

    public init(edges: [ContextRelationEdge] = []) {
        self.edges = edges
    }

    public mutating func record(
        contextKeys: [String],
        intentKey: String,
        outcomeKey: String,
        verifiedSuccess: Bool,
        at date: Date = Date()
    ) {
        for contextKey in Set(contextKeys) where !contextKey.isEmpty {
            let edgeID = "\(contextKey)|\(intentKey)|\(outcomeKey)"
            if let index = edges.firstIndex(where: { $0.id == edgeID }) {
                edges[index].attempts += 1
                if verifiedSuccess { edges[index].verifiedSuccesses += 1 }
                edges[index].lastObservedAt = date
            } else {
                edges.append(ContextRelationEdge(
                    contextKey: contextKey,
                    intentKey: intentKey,
                    outcomeKey: outcomeKey,
                    attempts: 1,
                    verifiedSuccesses: verifiedSuccess ? 1 : 0,
                    lastObservedAt: date
                ))
            }
        }
        edges = Array(edges.sorted { $0.lastObservedAt > $1.lastObservedAt }.prefix(300))
    }

    public func prediction(
        contextKeys: [String],
        minimumSuccesses: Int = 3,
        minimumConfidence: Double = 0.80
    ) -> ContextualOutcomePrediction? {
        let activeContexts = Set(contextKeys)
        let matching = edges.filter {
            activeContexts.contains($0.contextKey)
                && $0.verifiedSuccesses >= minimumSuccesses
                && $0.confidence >= minimumConfidence
        }
        let grouped = Dictionary(grouping: matching) { "\($0.intentKey)|\($0.outcomeKey)" }
        guard let winner = grouped.values.max(by: { score($0) < score($1) }),
              let edge = winner.first else { return nil }
        let attempts = winner.reduce(0) { $0 + $1.attempts }
        let successes = winner.reduce(0) { $0 + $1.verifiedSuccesses }
        let confidence = (Double(successes) + 1) / (Double(attempts) + 2)
        guard confidence >= minimumConfidence else { return nil }
        return ContextualOutcomePrediction(
            intentKey: edge.intentKey,
            outcomeKey: edge.outcomeKey,
            confidence: confidence,
            supportingSuccesses: successes
        )
    }

    private func score(_ edges: [ContextRelationEdge]) -> Double {
        edges.reduce(0) { $0 + Double($1.verifiedSuccesses) * $1.confidence }
    }
}
