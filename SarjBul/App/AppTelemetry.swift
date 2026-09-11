import FirebaseCrashlytics
import Foundation

@MainActor
enum AppTelemetry {
    private static var lastCaptureAt: [String: Date] = [:]
    private static let operations: Set<String> = [
        "favorites_load", "station_catalog_load", "station_automation_refresh",
        "station_status_refresh", "station_insight_refresh", "context_calendar_deferral",
        "journey_route_fallback", "offline_mutation_queued", "offline_mutation_rejected",
        "offline_sync_deferred", "offline_sync_rejected", "context_calendar_authorization",
        "context_health_authorization", "context_weather"
    ]

    static func capture(_ error: Error, operation: String) {
        let operation = safeOperation(operation)
        let sanitized = sanitizedError(error, operation: operation)
        AppLogger.data.error("\(operation, privacy: .public) failed: code \(sanitized.code)")
        if let last = lastCaptureAt[operation], Date().timeIntervalSince(last) < 60 { return }
        lastCaptureAt[operation] = Date()
        guard FirebaseBootstrap.isConfigured else { return }
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCustomValue(operation, forKey: "operation")
        crashlytics.record(error: sanitized)
    }

    // NSError userInfo and descriptions may contain URLs, auth tokens, coordinates,
    // station identifiers or EventKit content. Never forward the original error.
    static func sanitizedError(_ error: Error, operation: String) -> NSError {
        let original = error as NSError
        let isNetworkError = original.domain == NSURLErrorDomain
        return NSError(
            domain: isNetworkError ? NSURLErrorDomain : "SarjBul.OperationError",
            code: isNetworkError ? original.code : 1,
            userInfo: [NSLocalizedDescriptionKey: safeOperation(operation)]
        )
    }

    private static func safeOperation(_ operation: String) -> String {
        operations.contains(operation) ? operation : "unclassified_operation"
    }
}
