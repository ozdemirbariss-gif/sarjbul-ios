import Foundation

public struct FirebaseRESTClient: Sendable {
    public var databaseURL: URL
    public var apiKey: String
    public var session: URLSession

    public init(databaseURL: URL, apiKey: String, session: URLSession = .shared) {
        self.databaseURL = databaseURL
        self.apiKey = apiKey
        self.session = session
    }

    public func stationStatuses(idToken: String? = nil) async throws -> [String: StationStatusSummary] {
        var components = URLComponents(url: databaseURL.appending(path: "station_status.json"), resolvingAgainstBaseURL: false)
        if let idToken, !idToken.isEmpty {
            components?.queryItems = [URLQueryItem(name: "auth", value: idToken)]
        }
        guard let url = components?.url else { return [:] }
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode ?? 500 < 300 else { return [:] }
        return try JSONDecoder().decode([String: StationStatusSummary].self, from: data)
    }
}

public struct StationStatusSummary: Codable, Hashable, Sendable {
    public var durum: String?
    public var etiket: String?
    public var toplam: Int?

    public init(durum: String? = nil, etiket: String? = nil, toplam: Int? = nil) {
        self.durum = durum
        self.etiket = etiket
        self.toplam = toplam
    }
}

