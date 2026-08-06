import Foundation
import Testing
@testable import SarjBulCore

@Suite struct ServiceResilienceTests {
    @Test func circuitOpensAfterConfiguredErrorThreshold() async {
        let controller = ServiceResilienceController(policy: CircuitBreakerPolicy(
            window: 60,
            errorThreshold: 0.5,
            minimumRequestCount: 2,
            openDuration: 60,
            maximumConcurrentRequests: 2
        ))

        for _ in 0..<2 {
            do {
                let _: Void = try await controller.execute(partition: .userWrites) {
                    throw URLError(.timedOut)
                }
            } catch {}
        }

        let snapshot = await controller.snapshot(for: .userWrites)
        #expect(snapshot.isCircuitOpen)
        #expect(snapshot.recentErrorRate == 1)

        do {
            let _: Void = try await controller.execute(partition: .userWrites) {}
            Issue.record("An open circuit must reject traffic before calling the operation")
        } catch {
            #expect(error as? ServiceResilienceError == .circuitOpen(.userWrites))
        }
    }

    @Test func healthyPartitionRemainsClosed() async throws {
        let controller = ServiceResilienceController(policy: CircuitBreakerPolicy(
            minimumRequestCount: 2
        ))

        let result = try await controller.execute(partition: .communityReads) { "cached-or-live" }
        let snapshot = await controller.snapshot(for: .communityReads)

        #expect(result == "cached-or-live")
        #expect(!snapshot.isCircuitOpen)
        #expect(snapshot.recentErrorRate == 0)
    }
}
