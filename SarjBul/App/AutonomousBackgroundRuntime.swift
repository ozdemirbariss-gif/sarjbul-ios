import Foundation

@MainActor
enum AutonomousBackgroundRuntime {
    static var silentPushHandler: (() async -> Bool)?
    static var processingHandler: (() async -> Bool)?

    static func install(
        silentPushHandler: @escaping () async -> Bool,
        processingHandler: @escaping () async -> Bool
    ) {
        self.silentPushHandler = silentPushHandler
        self.processingHandler = processingHandler
    }
}
