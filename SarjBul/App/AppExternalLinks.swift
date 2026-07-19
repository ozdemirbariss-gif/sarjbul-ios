import Foundation

struct AppExternalLinks: Sendable {
    var privacyPolicyURL: URL?
    var termsOfUseURL: URL?
    var supportURL: URL?
    var supportEmail: String

    static let empty = AppExternalLinks(
        privacyPolicyURL: nil,
        termsOfUseURL: nil,
        supportURL: nil,
        supportEmail: ""
    )
}
