import Foundation

public enum DeepLinkRoute: Hashable, Sendable {
    case station(key: String)
}

public enum DeepLinkRouteParser {
    public static func parse(_ url: URL) -> DeepLinkRoute? {
        guard url.scheme?.lowercased() == "sarjbul",
              url.host?.lowercased() == "station",
              let encodedKey = url.pathComponents.dropFirst().first,
              let key = encodedKey.removingPercentEncoding,
              !key.isEmpty else { return nil }
        return .station(key: key)
    }
}
