import Foundation
import SarjBulCore

struct AppConfiguration {
    private static let defaultStationDataURL = URL(
        string: "https://raw.githubusercontent.com/ozdemirbariss-gif/elektriklisarj/main/stations.json"
    )
    private static let defaultPrivacyPolicyURL = URL(
        string: "https://github.com/ozdemirbariss-gif/elektriklisarj-ios/blob/main/Docs/PRIVACY_POLICY.md"
    )
    private static let defaultTermsURL = URL(
        string: "https://github.com/ozdemirbariss-gif/elektriklisarj-ios/blob/main/Docs/TERMS_OF_USE.md"
    )
    private static let defaultSupportURL = URL(
        string: "https://github.com/ozdemirbariss-gif/elektriklisarj-ios/issues"
    )
    var firebaseDatabaseURL: URL?
    var firebaseAPIKey: String
    var stationDataURL: URL?
    var privacyPolicyURL: URL?
    var termsOfUseURL: URL?
    var supportURL: URL?
    var supportEmail: String

    static func load(bundle: Bundle = .main) -> AppConfiguration {
        guard
            let url = bundle.url(forResource: "AppConfig", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let raw = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
            let values = raw as? [String: Any]
        else {
            return AppConfiguration(
                firebaseDatabaseURL: nil,
                firebaseAPIKey: "",
                stationDataURL: defaultStationDataURL,
                privacyPolicyURL: defaultPrivacyPolicyURL,
                termsOfUseURL: defaultTermsURL,
                supportURL: defaultSupportURL,
                supportEmail: ""
            )
        }

        let databaseString = (values["firebaseDatabaseURL"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = (values["firebaseAPIKey"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return AppConfiguration(
            firebaseDatabaseURL: databaseString.flatMap(Self.normalizedFirebaseURL),
            firebaseAPIKey: apiKey,
            stationDataURL: Self.urlValue(values["stationDataURL"]) ?? defaultStationDataURL,
            privacyPolicyURL: Self.urlValue(values["privacyPolicyURL"]) ?? defaultPrivacyPolicyURL,
            termsOfUseURL: Self.urlValue(values["termsOfUseURL"]) ?? defaultTermsURL,
            supportURL: Self.urlValue(values["supportURL"]) ?? defaultSupportURL,
            supportEmail: (values["supportEmail"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        )
    }

    @MainActor
    var firebaseClient: FirebaseRESTClient? {
        guard let firebaseDatabaseURL, !firebaseAPIKey.isEmpty else { return nil }
        let tokenProvider: (@Sendable () async throws -> String?)?
        if FirebaseBootstrap.isConfigured {
            tokenProvider = { @Sendable in
                try await FirebaseBootstrap.appCheckToken()
            }
        } else {
            tokenProvider = nil
        }
        return FirebaseRESTClient(
            databaseURL: firebaseDatabaseURL,
            apiKey: firebaseAPIKey,
            appCheckTokenProvider: tokenProvider
        )
    }

    private static func normalizedFirebaseURL(_ raw: String) -> URL? {
        guard !raw.isEmpty else { return nil }
        let normalized = raw.hasSuffix("/") ? raw : "\(raw)/"
        return URL(string: normalized)
    }

    private static func urlValue(_ value: Any?) -> URL? {
        guard let raw = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

    func stationRepository(bundle: Bundle = .main) -> (any StationRepository)? {
        guard let bundledURL = bundle.url(forResource: "stations", withExtension: "json") else {
            return nil
        }
        let cacheRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return CachedRemoteStationRepository(
            bundledFileURL: bundledURL,
            remoteURL: stationDataURL,
            cacheDirectory: cacheRoot.appending(path: "SarjBul", directoryHint: .isDirectory)
        )
    }
}
