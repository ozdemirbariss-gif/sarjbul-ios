import Foundation

actor AsyncMutationQueue {
    private var jobs: [String: Task<Void, Never>] = [:]

    func enqueue(
        id: String,
        maxAttempts: Int = 3,
        operation: @escaping @Sendable () async throws -> Void,
        completion: @escaping @MainActor @Sendable (Result<Void, Error>) -> Void
    ) {
        guard jobs[id] == nil else { return }
        jobs[id] = Task { [weak self] in
            var attempt = 0
            while !Task.isCancelled {
                attempt += 1
                do {
                    try await operation()
                    await completion(.success(()))
                    await self?.finish(id: id)
                    return
                } catch {
                    guard attempt < maxAttempts, Self.isTransient(error) else {
                        await completion(.failure(error))
                        await self?.finish(id: id)
                        return
                    }
                    try? await Task.sleep(for: .milliseconds(350 * attempt))
                }
            }
            await self?.finish(id: id)
        }
    }

    private func finish(id: String) {
        jobs[id] = nil
    }

    private static func isTransient(_ error: Error) -> Bool {
        guard let error = error as? URLError else { return false }
        return [.timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotConnectToHost]
            .contains(error.code)
    }
}
