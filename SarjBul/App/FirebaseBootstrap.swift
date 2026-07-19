@preconcurrency import FirebaseAppCheck
import FirebaseCore
import FirebaseCrashlytics
import Foundation

@MainActor
enum FirebaseBootstrap {
    private(set) static var isConfigured = false

    static func configureIfAvailable(bundle: Bundle = .main) {
        guard !isConfigured else { return }
        guard bundle.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else { return }

        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        AppCheck.setAppCheckProviderFactory(AppAttestProviderFactory())
        #endif

        FirebaseApp.configure()
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        isConfigured = true
    }

    static func appCheckToken() async throws -> String? {
        guard isConfigured else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            AppCheck.appCheck().token(forcingRefresh: false) { token, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: token?.token)
                }
            }
        }
    }
}
