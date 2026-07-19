import Observation
import SarjBulCore

enum AppMessageKind: Sendable {
    case success
    case error
    case information
}

enum AppMessage: Sendable {
    case localized(key: String, replacements: [String: String] = [:], kind: AppMessageKind)
    case auth(AuthError)
    case raw(String, kind: AppMessageKind)

    var kind: AppMessageKind {
        switch self {
        case .localized(_, _, let kind), .raw(_, let kind): kind
        case .auth: .error
        }
    }

    func text(language: AppLanguage) -> String {
        switch self {
        case .localized(let key, let replacements, _):
            AppLocalization.text(key, language: language, replacements: replacements)
        case .auth(.other(let message)):
            message
        case .auth(let error):
            AppLocalization.text(error.localizationKey, language: language)
        case .raw(let text, _):
            text
        }
    }
}

private extension AuthError {
    var localizationKey: String {
        switch self {
        case .invalidCredentials: "service.invalid_credentials"
        case .emailAlreadyExists: "service.email_exists"
        case .weakPassword: "service.weak_password"
        case .tooManyAttempts: "service.too_many_attempts"
        case .network: "service.network_error"
        case .sessionExpired: "service.no_session"
        case .serviceUnavailable: "service.firebase_missing"
        case .other: "status.error"
        }
    }
}

@MainActor
@Observable
final class AppMessagePresenter {
    private(set) var current: AppMessage?

    func present(_ message: AppMessage) {
        current = message
    }

    func dismiss() {
        current = nil
    }

    func consumeError(language: AppLanguage) -> String? {
        guard let current, current.kind == .error else { return nil }
        defer { self.current = nil }
        if case .auth(.other(let message)) = current { return message }
        return current.text(language: language)
    }
}
