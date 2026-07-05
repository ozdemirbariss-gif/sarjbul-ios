import Foundation
import SarjBulCore

struct AppConfiguration {
    var firebaseDatabaseURL: URL?
    var firebaseAPIKey: String

    static func load(bundle: Bundle = .main) -> AppConfiguration {
        guard
            let url = bundle.url(forResource: "AppConfig", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let raw = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
            let values = raw as? [String: Any]
        else {
            return AppConfiguration(firebaseDatabaseURL: nil, firebaseAPIKey: "")
        }

        let databaseString = (values["firebaseDatabaseURL"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = (values["firebaseAPIKey"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return AppConfiguration(
            firebaseDatabaseURL: databaseString.flatMap(Self.normalizedFirebaseURL),
            firebaseAPIKey: apiKey
        )
    }

    var firebaseClient: FirebaseRESTClient? {
        guard let firebaseDatabaseURL, !firebaseAPIKey.isEmpty else { return nil }
        return FirebaseRESTClient(databaseURL: firebaseDatabaseURL, apiKey: firebaseAPIKey)
    }

    private static func normalizedFirebaseURL(_ raw: String) -> URL? {
        guard !raw.isEmpty else { return nil }
        let normalized = raw.hasSuffix("/") ? raw : "\(raw)/"
        return URL(string: normalized)
    }
}
