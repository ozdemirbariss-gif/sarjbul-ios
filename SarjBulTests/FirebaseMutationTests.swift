import Foundation
import Testing
@testable import SarjBulCore

@Suite(.serialized) struct FirebaseMutationTests {
    @Test func reportUsesAtomicServerTimestampAndStableMutationID() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        MutationURLProtocol.handler = { request in
            #expect(request.httpMethod == "PATCH")
            #expect(request.value(forHTTPHeaderField: "X-Idempotency-Key") == "TEST-ID")
            let body = try #require(JSONSerialization.jsonObject(with: requestData(request)) as? [String: Any])
            let metadata = try #require(body["kullanici_yorum_meta/owner"] as? [String: Any])
            #expect(metadata["lastMutationPath"] as? String == "yorumlar/station-1/test-id")
            #expect((metadata["son_yorum_zamani_ms"] as? [String: String])?[".sv"] == "timestamp")
            let report = try #require(body["yorumlar/station-1/test-id"] as? [String: Any])
            #expect(report["tarih"] as? String == "2026-01-01T00:00:00Z")
            return (200, Data("null".utf8), [:])
        }
        try await sendReport(session: session)
    }

    @Test(arguments: [401, 403])
    func activeServerCooldownIsRetryable(status: Int) async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let metadata = try JSONSerialization.data(withJSONObject: [
            "lastMutationPath": "yorumlar/station-1/previous-id",
            "son_yorum_zamani_ms": 1_767_225_600_000
        ])
        MutationURLProtocol.handler = { request in
            if request.httpMethod == "PATCH" { return (status, Data("{}".utf8), [:]) }
            #expect(request.url?.path == "/kullanici_yorum_meta/owner.json")
            return (200, metadata, ["Date": "Thu, 01 Jan 2026 00:00:10 GMT"])
        }
        await expectReportError(session: session, status: 429)
    }

    @Test(arguments: ["expired", "same-mutation", "no-metadata", "denied-read"])
    func unprovenCooldownKeepsOriginalPermissionError(scenario: String) async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let metadata = try JSONSerialization.data(withJSONObject: [
            "lastMutationPath": scenario == "same-mutation" ? "yorumlar/station-1/test-id" : "yorumlar/station-1/previous-id",
            "son_yorum_zamani_ms": 1_767_225_600_000
        ])
        MutationURLProtocol.handler = { request in
            if request.httpMethod == "PATCH" || scenario == "denied-read" { return (403, Data("{}".utf8), [:]) }
            let date = scenario == "expired" ? "Thu, 01 Jan 2026 00:02:00 GMT" : "Thu, 01 Jan 2026 00:00:10 GMT"
            return (200, scenario == "no-metadata" ? Data("null".utf8) : metadata, ["Date": date])
        }
        await expectReportError(session: session, status: 403)
    }

    private func expectReportError(session: URLSession, status: Int) async {
        do {
            try await sendReport(session: session)
            Issue.record("Expected rejected mutation")
        } catch FirebaseRESTError.requestFailed(_, let actualStatus) {
            #expect(actualStatus == status)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MutationURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func sendReport(session: URLSession) async throws {
        let client = FirebaseRESTClient(
            databaseURL: try #require(URL(string: "https://fixture.firebaseio.com/")),
            apiKey: "fixture-key", session: session
        )
        try await client.sendStationReport(
            stationKey: "station-1", status: "Uygun", comment: "Çalışıyor", uid: "owner", idToken: "fixture-token",
            context: ServiceMutationContext(idempotencyKey: "TEST-ID", createdAt: Date(timeIntervalSince1970: 1_767_225_600))
        )
    }
}

private func requestData(_ request: URLRequest) throws -> Data {
    if let body = request.httpBody { return body }
    let stream = try #require(request.httpBodyStream)
    stream.open()
    defer { stream.close() }
    var result = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count < 0 { throw stream.streamError ?? URLError(.cannotDecodeRawData) }
        if count == 0 { break }
        result.append(contentsOf: buffer.prefix(count))
    }
    return result
}

private final class MutationURLProtocol: URLProtocol, @unchecked Sendable {
    // Access is scoped to this serialized suite; each awaited request completes before replacement.
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Int, Data, [String: String]))?

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let handler = try #require(Self.handler)
            let (status, body, headers) = try handler(request)
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(
                url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers
            ))
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
