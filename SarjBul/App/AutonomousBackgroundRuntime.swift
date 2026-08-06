import Foundation

@MainActor
enum AutonomousBackgroundRuntime {
    static var silentPushHandler: (() async -> Void)?
    static var processingHandler: (() async -> Void)?

    static func install(
        silentPushHandler: @escaping () async -> Void,
        processingHandler: @escaping () async -> Void
    ) {
        self.silentPushHandler = silentPushHandler
        self.processingHandler = processingHandler
    }
}
