import Foundation

public enum RoutePreference: String, CaseIterable, Identifiable, Sendable {
    case balanced
    case nearest
    case fastest
    case economical

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .balanced: "Dengeli"
        case .nearest: "Yakın"
        case .fastest: "Hızlı"
        case .economical: "Uygun"
        }
    }
}

