import Foundation
import Testing
@testable import SarjBulCore

struct ExecutionTrustEngineTests {
    @Test
    func freshIndependentEvidenceAndChecksProduceVerifiedOutcome() {
        let now = Date()
        let assessment = ExecutionTrustEngine.assess(
            status: .completed,
            evidence: [
                ExecutionEvidence(
                    source: .deterministicEngine,
                    reliability: 1,
                    observedAt: now,
                    maximumAge: 60
                ),
                ExecutionEvidence(
                    source: .deviceLocation,
                    reliability: 0.98,
                    observedAt: now,
                    maximumAge: 300
                ),
                ExecutionEvidence(
                    source: .stationDataset,
                    reliability: 0.92,
                    observedAt: now,
                    maximumAge: 86_400
                )
            ],
            deterministicChecks: ["location": true, "candidate": true],
            history: HistoricalActionStats(),
            now: now
        )

        #expect(assessment.isVerified)
        #expect(assessment.score >= ExecutionTrustEngine.verificationThreshold)
    }

    @Test
    func failedCheckCannotBeVerifiedEvenWithReliableEvidence() {
        let now = Date()
        let assessment = ExecutionTrustEngine.assess(
            status: .completed,
            evidence: [
                ExecutionEvidence(
                    source: .deterministicEngine,
                    reliability: 1,
                    observedAt: now,
                    maximumAge: 60
                ),
                ExecutionEvidence(
                    source: .stationDataset,
                    reliability: 1,
                    observedAt: now,
                    maximumAge: 60
                )
            ],
            deterministicChecks: ["safe": false],
            history: HistoricalActionStats(attempts: 20, successes: 20),
            now: now
        )

        #expect(!assessment.isVerified)
    }

    @Test
    func relationGraphPredictsOnlyRepeatedVerifiedOutcomes() {
        var graph = ContextualRelationGraph()
        for index in 0..<4 {
            graph.record(
                contextKeys: ["period:2", "cell:38.39:27.19"],
                intentKey: "search:fastest",
                outcomeKey: "station-a",
                verifiedSuccess: true,
                at: Date().addingTimeInterval(Double(index))
            )
        }

        let prediction = graph.prediction(contextKeys: ["period:2", "cell:38.39:27.19"])
        #expect(prediction?.intentKey == "search:fastest")
        #expect(prediction?.outcomeKey == "station-a")
        #expect(prediction?.supportingSuccesses == 8)
    }
}
