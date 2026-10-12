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
        var accumulator = FirebaseRealtimeEventAccumulator()
        return try accumulator.decode(channel: channel, eventName: eventName, data: data)
    }
}

/// One instance per SSE connection. Firebase patch events contain only the
/// changed children, so merge them before decoding the station's full value.
public struct FirebaseRealtimeEventAccumulator {
    private var document: [String: Any] = [:]

    public init() {}

    public mutating func decode(
        channel: FirebaseRealtimeEventDecoder.Channel,
        eventName: String = "put",
        data: Data
    ) throws -> [StationRealtimeEvent] {
        guard let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let path = envelope["path"] as? String,
              let payload = envelope["data"],
              eventName == "put" || eventName == "patch" else { return [] }
        let components = path.split(separator: "/").map(String.init)
        var next = document
        var changedKeys = Set<String>()
        let isSnapshot = components.isEmpty && eventName == "put"
        if isSnapshot {
            if payload is NSNull {
                next = [:]
            } else {
                guard let values = payload as? [String: Any] else { throw FirebaseRealtimeDecodingError.invalidPayload }
                next = values
            }
        } else if eventName == "patch" {
            guard let updates = payload as? [String: Any] else { throw FirebaseRealtimeDecodingError.invalidPayload }
            for (key, value) in updates {
                let target = components + key.split(separator: "/").map(String.init)
                guard let stationKey = target.first else { continue }
                changedKeys.insert(stationKey)
                Self.set(value, at: target[...], in: &next)
            }
        } else if let key = components.first {
            changedKeys.insert(key)
            Self.set(payload, at: components[...], in: &next)
        }

        let events: [StationRealtimeEvent]
        switch channel {
        case .statuses:
            events = try decodeValues(
                next, changedKeys: changedKeys, isSnapshot: isSnapshot,
                snapshot: StationRealtimeEvent.statusesSnapshot,
                change: StationRealtimeEvent.statusChanged
            )
        case .insights:
            events = try decodeValues(
                next, changedKeys: changedKeys, isSnapshot: isSnapshot,
                snapshot: StationRealtimeEvent.insightsSnapshot,
                change: StationRealtimeEvent.insightChanged
            )
        case .availability:
            events = try decodeValues(
                next, changedKeys: changedKeys, isSnapshot: isSnapshot,
                snapshot: StationRealtimeEvent.availabilitySnapshot,
                change: StationRealtimeEvent.availabilityChanged
            )
        }
        // A malformed payload must never replace good state or masquerade as deletion.
        document = next
        return events
    }

    private func decodeValues<Value: Decodable>(
        _ values: [String: Any],
        changedKeys: Set<String>,
        isSnapshot: Bool,
        snapshot: ([String: Value]) -> StationRealtimeEvent,
        change: (String, Value?) -> StationRealtimeEvent
    ) throws -> [StationRealtimeEvent] {
        if isSnapshot {
            return [snapshot(try values.mapValues { try Self.decodeValue(Value.self, from: $0) })]
        }
        return try changedKeys.sorted().map { key in
            change(key, try values[key].map { try Self.decodeValue(Value.self, from: $0) })
        }
    }

    private static func set(_ value: Any, at path: ArraySlice<String>, in node: inout [String: Any]) {
        guard let key = path.first else { return }
        if path.count == 1 {
            node[key] = value is NSNull ? nil : value
        } else {
            var child = node[key] as? [String: Any] ?? [:]
            set(value, at: path.dropFirst(), in: &child)
            node[key] = child.isEmpty ? nil : child
        }
    }

    private static func decodeValue<Value: Decodable>(_ type: Value.Type, from value: Any) throws -> Value {
        guard JSONSerialization.isValidJSONObject(value) else { throw FirebaseRealtimeDecodingError.invalidPayload }
        let data = try JSONSerialization.data(withJSONObject: value)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Value.self, from: data)
    }
}

public enum FirebaseRealtimeDecodingError: Error {
    case invalidPayload
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
                        // Live availability comes from the configured OCPI gateway.
                        // The database has no authorized live_availability channel.
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
            } catch FirebaseRESTError.requestFailed(_, let statusCode) where statusCode == 401 || statusCode == 403 {
                // A fresh session/configuration must explicitly restart the stream.
                // Reopening a denied request cannot repair its permissions.
                return
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
        guard statusCode < 300 else {
            throw FirebaseRESTError.requestFailed("Realtime request denied or unavailable", statusCode: statusCode)
        }

        var eventName = ""
        var dataLines: [String] = []
        var accumulator = FirebaseRealtimeEventAccumulator()
        for try await line in bytes.lines {
            try Task.checkCancellation()
            if line.isEmpty {
                if eventName == "cancel" || eventName == "auth_revoked" {
                    throw FirebaseRESTError.requestFailed("Realtime authorization ended", statusCode: 403)
                }
                guard eventName == "put" || eventName == "patch" else {
                    eventName = ""
                    dataLines.removeAll(keepingCapacity: true)
                    continue
                }
                let payload = Data(dataLines.joined(separator: "\n").utf8)
                for event in try accumulator.decode(
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
