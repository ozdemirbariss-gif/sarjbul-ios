import Foundation

/// Both the iPhone and CarPlay scenes use one catalog, settings and favorites store.
@MainActor
enum AppRuntime {
    static let state = AppState.bootstrap()
}
