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

    public func signIn(email: String, password: String) async throws -> FirebaseAuthSession {
        try await authRequest(
            endpoint: "accounts:signInWithPassword",
            body: ["email": email, "password": password, "returnSecureToken": true]
        )
    }

    public func signUp(email: String, password: String) async throws -> FirebaseAuthSession {
        try await authRequest(
            endpoint: "accounts:signUp",
            body: ["email": email, "password": password, "returnSecureToken": true]
        )
    }

    public func sendPasswordReset(email: String) async throws {
        _ = try await authRequestData(
            endpoint: "accounts:sendOobCode",
            body: ["requestType": "PASSWORD_RESET", "email": email]
        )
    }

    public func refreshSession(refreshToken: String) async throws -> FirebaseAuthSession {
        var components = URLComponents(string: "https://securetoken.googleapis.com/v1/token")
        components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components?.url else {
            throw FirebaseRESTError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=refresh_token&refresh_token=\(refreshToken)".data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(FirebaseAuthSession.self, from: data)
    }

    public func favoriteIDs(uid: String, idToken: String) async throws -> Set<String> {
        var components = URLComponents(url: databaseURL.appending(path: "favoriler/\(uid).json"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "auth", value: idToken)]
        guard let url = components?.url else { return [] }

        let (data, response) = try await session.data(from: url)
        try validate(response: response, data: data)
        guard !data.isEmpty, String(data: data, encoding: .utf8) != "null" else { return [] }

        let values = try JSONDecoder().decode([String: Bool].self, from: data)
        return Set(values.compactMap { $0.value ? $0.key : nil })
    }

    public func setFavorite(uid: String, stationKey: String, isFavorite: Bool, idToken: String) async throws {
        var components = URLComponents(url: databaseURL.appending(path: "favoriler/\(uid)/\(stationKey).json"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "auth", value: idToken)]
        guard let url = components?.url else {
            throw FirebaseRESTError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = isFavorite ? "PUT" : "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if isFavorite {
            request.httpBody = try JSONEncoder().encode(true)
        }

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    public func sendStationReport(
        stationKey: String,
        status: String,
        comment: String,
        uid: String,
        idToken: String
    ) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        let statusClass = Self.statusClass(status: status, comment: comment)
        let report = StationReportPayload(
            kullanici: "Doğrulanmış Sürücü",
            yorum: comment,
            durum: status,
            durum_sinifi: statusClass,
            sinif_kaynagi: "ios_write_rule_v1",
            tarih: now,
            uid: uid
        )

        try await postJSON(path: "yorumlar/\(stationKey).json", idToken: idToken, body: report)
        try await patchJSON(
            path: "kullanici_yorum_meta/\(uid).json",
            idToken: idToken,
            body: ["son_yorum_zamani": now]
        )
        try await patchJSON(
            path: "station_status/\(stationKey).json",
            idToken: idToken,
            body: StationStatusSummary(
                durum: statusClass == "bos" ? "aktif" : statusClass == "mesgul" ? "riskli" : "belirsiz",
                etiket: status,
                toplam: 1
            )
        )
    }

    private func authRequest(endpoint: String, body: [String: Any]) async throws -> FirebaseAuthSession {
        let data = try await authRequestData(endpoint: endpoint, body: body)
        return try JSONDecoder().decode(FirebaseAuthSession.self, from: data)
    }

    private func authRequestData(endpoint: String, body: [String: Any]) async throws -> Data {
        var components = URLComponents(string: "https://identitytoolkit.googleapis.com/v1/\(endpoint)")
        components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components?.url else {
            throw FirebaseRESTError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    private func postJSON<T: Encodable>(path: String, idToken: String, body: T) async throws {
        try await sendJSON(method: "POST", path: path, idToken: idToken, body: body)
    }

    private func patchJSON<T: Encodable>(path: String, idToken: String, body: T) async throws {
        try await sendJSON(method: "PATCH", path: path, idToken: idToken, body: body)
    }

    private func sendJSON<T: Encodable>(method: String, path: String, idToken: String, body: T) async throws {
        var components = URLComponents(url: databaseURL.appending(path: path), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "auth", value: idToken)]
        guard let url = components?.url else {
            throw FirebaseRESTError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard statusCode < 300 else {
            let message = (try? JSONDecoder().decode(FirebaseErrorEnvelope.self, from: data).error.message)
                ?? HTTPURLResponse.localizedString(forStatusCode: statusCode)
            throw FirebaseRESTError.requestFailed(message)
        }
    }

    private static func statusClass(status: String, comment: String) -> String {
        let text = "\(status) \(comment)"
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "tr_TR"))
        if ["sorun", "ariza", "bozuk", "calismiyor"].contains(where: text.contains) {
            return "mesgul"
        }
        if ["sira", "dolu", "bekleme", "mesgul"].contains(where: text.contains) {
            return "mesgul"
        }
        if ["uygun", "bos", "sorunsuz", "aktif"].contains(where: text.contains) {
            return "bos"
        }
        return "belirsiz"
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

public struct FirebaseAuthSession: Codable, Equatable, Sendable {
    public var idToken: String
    public var email: String?
    public var refreshToken: String
    public var expiresIn: String?
    public var localId: String?
    public var userId: String?

    public var uid: String {
        localId ?? userId ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case idToken
        case idTokenSnake = "id_token"
        case email
        case refreshToken
        case refreshTokenSnake = "refresh_token"
        case expiresIn
        case expiresInSnake = "expires_in"
        case localId
        case userId = "user_id"
    }

    public init(
        idToken: String,
        email: String? = nil,
        refreshToken: String,
        expiresIn: String? = nil,
        localId: String? = nil,
        userId: String? = nil
    ) {
        self.idToken = idToken
        self.email = email
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
        self.localId = localId
        self.userId = userId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        idToken = try container.decodeIfPresent(String.self, forKey: .idToken)
            ?? container.decode(String.self, forKey: .idTokenSnake)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)
            ?? container.decode(String.self, forKey: .refreshTokenSnake)
        expiresIn = try container.decodeIfPresent(String.self, forKey: .expiresIn)
            ?? container.decodeIfPresent(String.self, forKey: .expiresInSnake)
        localId = try container.decodeIfPresent(String.self, forKey: .localId)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(idToken, forKey: .idToken)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encode(refreshToken, forKey: .refreshToken)
        try container.encodeIfPresent(expiresIn, forKey: .expiresIn)
        try container.encodeIfPresent(localId, forKey: .localId)
        try container.encodeIfPresent(userId, forKey: .userId)
    }
}

public enum FirebaseRESTError: LocalizedError, Equatable {
    case invalidURL
    case requestFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Firebase adresi geçersiz."
        case .requestFailed(let message):
            message
        }
    }
}

private struct FirebaseErrorEnvelope: Decodable {
    struct Body: Decodable {
        var message: String
    }

    var error: Body
}

private struct StationReportPayload: Encodable {
    var kullanici: String
    var yorum: String
    var durum: String
    var durum_sinifi: String
    var sinif_kaynagi: String
    var tarih: String
    var uid: String
}
