import Foundation

public struct ServiceMutationContext: Codable, Hashable, Sendable {
    public var idempotencyKey: String
    public var createdAt: Date

    public init(idempotencyKey: String, createdAt: Date) {
        self.idempotencyKey = idempotencyKey
        self.createdAt = createdAt
    }
}

public enum ServicePartition: String, CaseIterable, Sendable {
    case authentication
    case communityReads
    case userWrites
    case liveAvailability
}

public struct CircuitBreakerPolicy: Sendable {
    public var window: TimeInterval
    public var errorThreshold: Double
    public var minimumRequestCount: Int
    public var openDuration: TimeInterval
    public var maximumConcurrentRequests: Int

    public init(
        window: TimeInterval = 60,
        errorThreshold: Double = 0.05,
        minimumRequestCount: Int = 10,
        openDuration: TimeInterval = 60,
        maximumConcurrentRequests: Int = 3
    ) {
        self.window = window
        self.errorThreshold = errorThreshold
        self.minimumRequestCount = minimumRequestCount
        self.openDuration = openDuration
        self.maximumConcurrentRequests = maximumConcurrentRequests
    }
}

public enum ServiceResilienceError: LocalizedError, Equatable, Sendable {
    case circuitOpen(ServicePartition)
    case bulkheadFull(ServicePartition)

    public var errorDescription: String? {
        switch self {
        case .circuitOpen(let partition):
            "Service circuit is open for \(partition.rawValue)."
        case .bulkheadFull(let partition):
            "Service bulkhead is full for \(partition.rawValue)."
        }
    }
}

public struct ServiceHealthSnapshot: Equatable, Sendable {
    public var isCircuitOpen: Bool
    public var recentRequestCount: Int
    public var recentErrorRate: Double
    public var activeRequestCount: Int
}

public actor ServiceResilienceController {
    private struct Outcome: Sendable {
        var date: Date
        var succeeded: Bool
    }

    private struct PartitionState: Sendable {
        var outcomes: [Outcome] = []
        var openUntil: Date?
        var halfOpenProbeInFlight = false
        var activeRequests = 0
    }

    private let policy: CircuitBreakerPolicy
    private var states: [ServicePartition: PartitionState] = [:]

    public init(policy: CircuitBreakerPolicy = CircuitBreakerPolicy()) {
        self.policy = policy
    }

    public func execute<T: Sendable>(
        partition: ServicePartition,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        try begin(partition: partition, now: Date())
        do {
            let value = try await operation()
            finish(partition: partition, succeeded: true, now: Date())
            return value
        } catch {
            finish(partition: partition, succeeded: false, now: Date())
            throw error
        }
    }

    public func snapshot(for partition: ServicePartition, now: Date = Date()) -> ServiceHealthSnapshot {
        let state = trimmedState(for: partition, now: now)
        states[partition] = state
        let failures = state.outcomes.count(where: { !$0.succeeded })
        return ServiceHealthSnapshot(
            isCircuitOpen: state.openUntil.map { $0 > now } ?? false,
            recentRequestCount: state.outcomes.count,
            recentErrorRate: state.outcomes.isEmpty ? 0 : Double(failures) / Double(state.outcomes.count),
            activeRequestCount: state.activeRequests
        )
    }

    private func begin(partition: ServicePartition, now: Date) throws {
        var state = trimmedState(for: partition, now: now)
        if let openUntil = state.openUntil {
            if openUntil > now {
                states[partition] = state
                throw ServiceResilienceError.circuitOpen(partition)
            }
            guard !state.halfOpenProbeInFlight else {
                states[partition] = state
                throw ServiceResilienceError.circuitOpen(partition)
            }
            state.halfOpenProbeInFlight = true
        }
        guard state.activeRequests < policy.maximumConcurrentRequests else {
            states[partition] = state
            throw ServiceResilienceError.bulkheadFull(partition)
        }
        state.activeRequests += 1
        states[partition] = state
    }

    private func finish(partition: ServicePartition, succeeded: Bool, now: Date) {
        var state = trimmedState(for: partition, now: now)
        state.activeRequests = max(0, state.activeRequests - 1)
        state.outcomes.append(Outcome(date: now, succeeded: succeeded))

        if state.halfOpenProbeInFlight {
            state.halfOpenProbeInFlight = false
            state.openUntil = succeeded ? nil : now.addingTimeInterval(policy.openDuration)
            if succeeded { state.outcomes = [] }
        } else if shouldOpen(state) {
            state.openUntil = now.addingTimeInterval(policy.openDuration)
        }
        states[partition] = state
    }

    private func trimmedState(for partition: ServicePartition, now: Date) -> PartitionState {
        var state = states[partition] ?? PartitionState()
        let cutoff = now.addingTimeInterval(-policy.window)
        state.outcomes.removeAll { $0.date < cutoff }
        return state
    }

    private func shouldOpen(_ state: PartitionState) -> Bool {
        guard state.outcomes.count >= policy.minimumRequestCount else { return false }
        let failures = state.outcomes.count(where: { !$0.succeeded })
        return Double(failures) / Double(state.outcomes.count) >= policy.errorThreshold
    }
}
