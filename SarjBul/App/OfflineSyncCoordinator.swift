import Foundation
import Observation
import SarjBulCore

enum OfflineSubmissionResult {
    case synced
    case queued
    case rejected(Error)
}

@MainActor
@Observable
final class OfflineSyncCoordinator {
    private let auth: AuthStore
    private let favoritesClient: any FavoritesClient
    private let statusClient: any StatusClient
    private let demandClient: any DemandAnalyticsClient
    private let persistence: any AppPersistence
    private let queue: AsyncMutationQueue
    private let rateLimiter = OfflineMutationRateLimiter()

    private(set) var pendingCount = 0
    private(set) var isSyncing = false
    private(set) var isReadOnlySafeMode = false

    init(
        auth: AuthStore,
        favoritesClient: any FavoritesClient,
        statusClient: any StatusClient,
        demandClient: any DemandAnalyticsClient,
        persistence: any AppPersistence,
        queue: AsyncMutationQueue
    ) {
        self.auth = auth
        self.favoritesClient = favoritesClient
        self.statusClient = statusClient
        self.demandClient = demandClient
        self.persistence = persistence
        self.queue = queue
        pendingCount = persistence.pendingOfflineMutations.count
    }

    func submit(
        _ payload: OfflineMutationPayload,
        deduplicationKey: String,
        completion: @escaping @MainActor (OfflineSubmissionResult) -> Void
    ) async {
        var pending = persistence.pendingOfflineMutations
        pending.removeAll { $0.deduplicationKey == deduplicationKey }
        let mutation = PendingOfflineMutation(
            id: UUID().uuidString,
            deduplicationKey: deduplicationKey,
            payload: payload,
            createdAt: Date()
        )
        pending.append(mutation)
        persistence.pendingOfflineMutations = pending
        pendingCount = pending.count

        await queue.enqueue(id: "offline:\(mutation.id)", maxAttempts: 2) { [weak self] in
            guard let self else { return }
            try await self.send(mutation)
        } completion: { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.remove(mutation.id)
                self.isReadOnlySafeMode = false
                completion(.synced)
            case .failure(let error) where Self.isTransient(error):
                self.isReadOnlySafeMode = error is ServiceResilienceError
                AppTelemetry.capture(error, operation: "offline_mutation_queued", metadata: [
                    "mutation": mutation.deduplicationKey
                ])
                completion(.queued)
            case .failure(let error):
                self.remove(mutation.id)
                AppTelemetry.capture(error, operation: "offline_mutation_rejected", metadata: [
                    "mutation": mutation.deduplicationKey
                ])
                completion(.rejected(error))
            }
        }
    }

    func syncPending() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        for mutation in persistence.pendingOfflineMutations.sorted(by: { $0.createdAt < $1.createdAt }) {
            do {
                try await send(mutation)
                remove(mutation.id)
                isReadOnlySafeMode = false
            } catch where Self.isTransient(error) {
                isReadOnlySafeMode = error is ServiceResilienceError
                AppTelemetry.capture(error, operation: "offline_sync_deferred")
                break
            } catch {
                remove(mutation.id)
                AppTelemetry.capture(error, operation: "offline_sync_rejected")
            }
        }
    }

    func reconciledFavorites(remote: Set<String>) -> Set<String> {
        persistence.pendingOfflineMutations
            .sorted(by: { $0.createdAt < $1.createdAt })
            .reduce(into: remote) { result, mutation in
                guard case .favorite(let stationKey, let isFavorite) = mutation.payload else { return }
                if isFavorite { result.insert(stationKey) } else { result.remove(stationKey) }
            }
    }

    private func send(_ mutation: PendingOfflineMutation) async throws {
        await rateLimiter.acquire()
        let context = ServiceMutationContext(
            idempotencyKey: mutation.id,
            createdAt: mutation.createdAt
        )
        try await auth.authenticatedRequest { session in
            switch mutation.payload {
            case .favorite(let stationKey, let isFavorite):
                try await self.favoritesClient.setFavorite(
                    uid: session.uid,
                    stationKey: stationKey,
                    isFavorite: isFavorite,
                    idToken: session.idToken,
                    context: context
                )
            case .stationReport(let stationKey, let status):
                try await self.statusClient.sendStationReport(
                    stationKey: stationKey,
                    status: status,
                    comment: status,
                    uid: session.uid,
                    idToken: session.idToken,
                    context: context
                )
            case .contribution(let stationKey, let contribution):
                try await self.statusClient.sendStationContribution(
                    stationKey: stationKey,
                    contribution: contribution,
                    uid: session.uid,
                    idToken: session.idToken,
                    context: context
                )
            case .demand(let event):
                try await self.demandClient.recordSearchDemand(
                    event: event,
                    uid: session.uid,
                    idToken: session.idToken,
                    context: context
                )
            case .friction(let event):
                try await self.demandClient.recordFrictionEvent(
                    event: event,
                    uid: session.uid,
                    idToken: session.idToken,
                    context: context
                )
            }
        }
    }

    private func remove(_ id: String) {
        persistence.pendingOfflineMutations.removeAll { $0.id == id }
        pendingCount = persistence.pendingOfflineMutations.count
    }

    private static func isTransient(_ error: Error) -> Bool {
        if let error = error as? URLError {
            return [.timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotConnectToHost]
                .contains(error.code)
        }
        if let error = error as? AuthError { return error == .network || error == .sessionExpired }
        if error is ServiceResilienceError { return true }
        if let firebaseError = error as? FirebaseRESTError,
           case .requestFailed(_, let statusCode) = firebaseError {
            return statusCode == 429 || (statusCode.map { $0 >= 500 } ?? false)
        }
        return false
    }
}

private actor OfflineMutationRateLimiter {
    private var nextAllowedAt = Date.distantPast

    func acquire() async {
        let now = Date()
        let scheduled = max(now, nextAllowedAt)
        nextAllowedAt = scheduled.addingTimeInterval(0.2)
        let delay = scheduled.timeIntervalSince(now)
        if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
    }
}
