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
    private let resilience: ServiceResilienceController
    private var cache: [String: LiveStationAvailability] = [:]
    private var cachedRequestKeys: Set<String> = []
    private var cacheStoredAt: Date?
    private var lastRequestAt: Date?

    public init(
        endpoint: URL,
        session: URLSession = .shared,
        resilience: ServiceResilienceController = ServiceResilienceController()
    ) {
        self.endpoint = endpoint
        self.session = session
        self.resilience = resilience
    }

    public func availability(stationKeys: [String]) async throws -> [String: LiveStationAvailability] {
        guard !stationKeys.isEmpty else { return [:] }
        let requestedKeys = Set(stationKeys)
        if let cacheStoredAt,
           Date().timeIntervalSince(cacheStoredAt) < 60,
           requestedKeys.isSubset(of: cachedRequestKeys) {
            return cache.filter { requestedKeys.contains($0.key) }
        }
        if let lastRequestAt {
            let delay = 1.5 - Date().timeIntervalSince(lastRequestAt)
            if delay > 0 { try await Task.sleep(for: .seconds(delay)) }
        }
        lastRequestAt = Date()
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(AvailabilityRequest(stationKeys: stationKeys))
        let finalRequest = request
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await resilience.execute(partition: .liveAvailability) {
                let result = try await session.data(for: finalRequest)
                guard let response = result.1 as? HTTPURLResponse,
                      (200..<300).contains(response.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return result
            }
        } catch {
            let fallback = cache.filter { requestedKeys.contains($0.key) }
            if !fallback.isEmpty { return fallback }
            throw error
        }
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let availability = try decoder.decode([String: LiveStationAvailability].self, from: data)
        let freshnessLimit = Date().addingTimeInterval(-15 * 60)
        let fresh = availability.filter { $0.value.updatedAt >= freshnessLimit }
        cache.merge(fresh) { _, new in new }
        cachedRequestKeys.formUnion(requestedKeys)
        cacheStoredAt = Date()
        return fresh
    }
}

private struct AvailabilityRequest: Encodable {
    var stationKeys: [String]
}
