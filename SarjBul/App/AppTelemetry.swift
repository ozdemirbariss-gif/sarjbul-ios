import FirebaseCrashlytics
import Foundation

@MainActor
enum AppTelemetry {
    private static var lastCaptureAt: [String: Date] = [:]

    static func capture(_ error: Error, operation: String, metadata: [String: String] = [:]) {
        AppLogger.data.error("\(operation, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        if let last = lastCaptureAt[operation], Date().timeIntervalSince(last) < 60 { return }
        lastCaptureAt[operation] = Date()
        guard FirebaseBootstrap.isConfigured else { return }
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCustomValue(operation, forKey: "operation")
        for (key, value) in metadata {
            crashlytics.setCustomValue(value, forKey: key)
        }
        crashlytics.record(error: error)
    }
}
