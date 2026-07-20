import Foundation

public struct LiveStationAvailability: Codable, Hashable, Sendable {
    public var stationKey: String
    public var availableConnectors: Int
    public var totalConnectors: Int
    public var updatedAt: Date

    public init(stationKey: String, availableConnectors: Int, totalConnectors: Int, updatedAt: Date) {
        self.stationKey = stationKey
        self.availableConnectors = availableConnectors
        self.totalConnectors = totalConnectors
        self.updatedAt = updatedAt
    }
}

public protocol LiveAvailabilityClient: Sendable {
    func availability(stationKeys: [String]) async throws -> [String: LiveStationAvailability]
}

public struct UnavailableLiveAvailabilityClient: LiveAvailabilityClient {
    public init() {}

    public func availability(stationKeys: [String]) async throws -> [String: LiveStationAvailability] { [:] }
}

/// Talks only to SarjBul's server-to-server gateway. Operator OCPI tokens never ship in the app.
public actor OCPIGatewayClient: LiveAvailabilityClient {
    private let endpoint: URL
    private let session: URLSession

    public init(endpoint: URL, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    public func availability(stationKeys: [String]) async throws -> [String: LiveStationAvailability] {
        guard !stationKeys.isEmpty else { return [:] }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(AvailabilityRequest(stationKeys: stationKeys))
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let availability = try decoder.decode([String: LiveStationAvailability].self, from: data)
        let freshnessLimit = Date().addingTimeInterval(-15 * 60)
        return availability.filter { $0.value.updatedAt >= freshnessLimit }
    }
}

private struct AvailabilityRequest: Encodable {
    var stationKeys: [String]
}
