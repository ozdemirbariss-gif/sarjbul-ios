import Foundation

public enum DeepLinkRoute: Hashable, Sendable {
    case station(key: String)
    case nearestFast
    case home
}

public enum DeepLinkRouteParser {
    public static func parse(_ url: URL) -> DeepLinkRoute? {
        guard url.scheme?.lowercased() == "sarjbul" else { return nil }
        if url.host?.lowercased() == "quick", url.pathComponents.dropFirst().first == "fast" {
            return .nearestFast
        }
        if url.host?.lowercased() == "home" {
            return .home
        }
        guard url.host?.lowercased() == "station",
              let encodedKey = url.pathComponents.dropFirst().first,
              let key = encodedKey.removingPercentEncoding,
              !key.isEmpty else { return nil }
        return .station(key: key)
    }
}
