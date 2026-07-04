import SwiftUI

enum SBColor {
    static let background = Color(red: 0.92, green: 0.98, blue: 0.91)
    static let surface = Color.white.opacity(0.86)
    static let ink = Color(red: 0.02, green: 0.09, blue: 0.04)
    static let muted = Color(red: 0.42, green: 0.46, blue: 0.48)
    static let accent = Color(red: 0.61, green: 0.87, blue: 0.56)
    static let navy = Color(red: 0.14, green: 0.31, blue: 0.50)
    static let purple = Color(red: 0.30, green: 0.25, blue: 0.76)
}

extension LinearGradient {
    static var sbPrimary: LinearGradient {
        LinearGradient(
            colors: [SBColor.accent, SBColor.navy],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

