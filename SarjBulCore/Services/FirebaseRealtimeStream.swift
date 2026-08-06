import Foundation

public enum StationRealtimeEvent: Sendable {
    case statusesSnapshot([String: StationStatusSummary])
    case statusChanged(key: String, value: StationStatusSummary?)
    case insightsSnapshot([String: StationCommunityInsight])
    case insightChanged(key: String, value: StationCommunityInsight?)
    case availabilitySnapshot([String: LiveStationAvailability])
    case availabilityChanged(key: String, value: LiveStationAvailability?)
}

public enum FirebaseRealtimeEventDecoder {
    public enum Channel: Sendable {
        case statuses
        case insights
        case availability
    }

    public static func decode(
        channel: Channel,
        eventName: String = "put",
        data: Data
    ) throws -> [StationRealtimeEvent] {
        guard let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let path = envelope["path"] as? String else { return [] }
        let payload = envelope["data"]

        switch channel {
        case .statuses:
            return decode(
                path: path,
                payload: payload,
                isPatch: eventName == "patch",
                snapshot: StationRealtimeEvent.statusesSnapshot,
                change: StationRealtimeEvent.statusChanged
            )
        case .insights:
            return decode(
                path: path,
                payload: payload,
                isPatch: eventName == "patch",
                snapshot: StationRealtimeEvent.insightsSnapshot,
                change: StationRealtimeEvent.insightChanged
            )
        case .availability:
            return decode(
                path: path,
                payload: payload,
                isPatch: eventName == "patch",
                snapshot: StationRealtimeEvent.availabilitySnapshot,
                change: StationRealtimeEvent.availabilityChanged
            )
        }
    }

    private static func decode<Value: Decodable>(
        path: String,
        payload: Any?,
        isPatch: Bool,
        snapshot: ([String: Value]) -> StationRealtimeEvent,
        change: (String, Value?) -> StationRealtimeEvent
    ) -> [StationRealtimeEvent] {
        let components = path.split(separator: "/").map(String.init)
        if components.isEmpty {
            guard let dictionary = payload as? [String: Any] else { return [snapshot([:])] }
            if isPatch {
                return dictionary.map { key, value in
                    change(key, value is NSNull ? nil : decodeValue(Value.self, from: value))
                }
            }
            let values = dictionary.compactMapValues { decodeValue(Value.self, from: $0) }
            return [snapshot(values)]
        }

        guard components.count == 1 else { return [] }
        let key = components[0]
        if payload == nil || payload is NSNull { return [change(key, nil)] }
        return [change(key, decodeValue(Value.self, from: payload as Any))]
    }

    private static func decodeValue<Value: Decodable>(_ type: Value.Type, from value: Any) -> Value? {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Value.self, from: data)
    }
}

public extension FirebaseRESTClient {
    func events(idToken: String?) -> AsyncThrowingStream<StationRealtimeEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        group.addTask {
                            try await consumeFirebaseStream(
                                path: "station_status.json",
                                channel: .statuses,
                                idToken: idToken,
                                continuation: continuation
                            )
                        }
                        group.addTask {
                            try await consumeFirebaseStream(
                                path: "station_insights.json",
                                channel: .insights,
                                idToken: idToken,
                                continuation: continuation
                            )
                        }
                        group.addTask {
                            try await consumeFirebaseStream(
                                path: "live_availability.json",
                                channel: .availability,
                                idToken: idToken,
                                continuation: continuation
                            )
                        }
                        try await group.waitForAll()
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func consumeFirebaseStream(
        path: String,
        channel: FirebaseRealtimeEventDecoder.Channel,
        idToken: String?,
        continuation: AsyncThrowingStream<StationRealtimeEvent, any Error>.Continuation
    ) async throws {
        var retrySeconds: UInt64 = 1
        while !Task.isCancelled {
            do {
                try await consumeFirebaseStreamOnce(
                    path: path,
                    channel: channel,
                    idToken: idToken,
                    continuation: continuation
                )
                retrySeconds = 1
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                try await Task.sleep(for: .seconds(retrySeconds))
                retrySeconds = min(30, retrySeconds * 2)
            }
        }
    }

    private func consumeFirebaseStreamOnce(
        path: String,
        channel: FirebaseRealtimeEventDecoder.Channel,
        idToken: String?,
        continuation: AsyncThrowingStream<StationRealtimeEvent, any Error>.Continuation
    ) async throws {
        var components = URLComponents(
            url: databaseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        )
        if let idToken, !idToken.isEmpty {
            components?.queryItems = [URLQueryItem(name: "auth", value: idToken)]
        }
        guard let url = components?.url else { throw FirebaseRESTError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 70
        if let token = try await appCheckTokenProvider?(), !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: "X-Firebase-AppCheck")
        }
        let (bytes, response) = try await session.bytes(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard statusCode < 300 else { throw URLError(.badServerResponse) }

        var eventName = ""
        var dataLines: [String] = []
        for try await line in bytes.lines {
            try Task.checkCancellation()
            if line.isEmpty {
                guard eventName == "put" || eventName == "patch" else {
                    eventName = ""
                    dataLines.removeAll(keepingCapacity: true)
                    continue
                }
                let payload = Data(dataLines.joined(separator: "\n").utf8)
                for event in try FirebaseRealtimeEventDecoder.decode(
                    channel: channel,
                    eventName: eventName,
                    data: payload
                ) {
                    continuation.yield(event)
                }
                eventName = ""
                dataLines.removeAll(keepingCapacity: true)
            } else if line.hasPrefix("event:") {
                eventName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
            }
        }
    }
}
