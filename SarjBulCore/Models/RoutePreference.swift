import Foundation

public enum RoutePreference: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case balanced
    case nearest
    case fastest
    case economical

    public var id: String { rawValue }

    // Price strings in the published inventory contain no comparable tariffs.
    // Keep the case for persisted preferences, but do not offer it in the UI.
    public static var selectableCases: [RoutePreference] { [.balanced, .nearest, .fastest] }
    public var supportedValue: RoutePreference { self == .economical ? .balanced : self }

    public var title: String {
        switch self {
        case .balanced: "Dengeli"
        case .nearest: "Yakın"
        case .fastest: "Hızlı"
        case .economical: "Uygun"
        }
    }
}
