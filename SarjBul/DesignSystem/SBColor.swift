import Foundation
import SwiftUI

struct SBDesignTokens: Decodable {
    struct ColorToken: Decodable {
        let hex: String
        let opacity: Double
    }

    struct Colors: Decodable {
        let background: ColorToken
        let surface: ColorToken
        let surfaceSoft: ColorToken
        let line: ColorToken
        let lineStrong: ColorToken
        let text: ColorToken
        let textSoft: ColorToken
        let textMuted: ColorToken
        let primary: ColorToken
        let primaryDeep: ColorToken
        let danger: ColorToken
        let warning: ColorToken
        let electricBlue: ColorToken
        let glass: ColorToken
        let glassStrong: ColorToken
    }

    struct Radius: Decodable {
        let sm: Double
        let md: Double
        let lg: Double
        let xl: Double
        let card: Double
        let screen: Double
        let pill: Double
    }

    struct ShadowToken: Decodable {
        let color: String
        let opacity: Double
        let radius: Double
        let x: Double
        let y: Double
    }

    struct Shadows: Decodable {
        let soft: ShadowToken
        let glow: ShadowToken
        let card: ShadowToken
    }

    struct Fonts: Decodable {
        let display: String
        let body: String
        let iosDisplayDesign: String
    }

    let source: String
    let colors: Colors
    let radius: Radius
    let shadows: Shadows
    let fonts: Fonts

    static let shared = load()

    private static func load() -> SBDesignTokens {
        guard
            let url = Bundle.main.url(forResource: "design-tokens", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let tokens = try? JSONDecoder().decode(SBDesignTokens.self, from: data)
        else {
            return fallback
        }
        return tokens
    }

    private static let fallback = SBDesignTokens(
        source: "fallback",
        colors: Colors(
            background: ColorToken(hex: "#FFFFFF", opacity: 1.0),
            surface: ColorToken(hex: "#F4F5F2", opacity: 1.0),
            surfaceSoft: ColorToken(hex: "#F4F5F2", opacity: 0.86),
            line: ColorToken(hex: "#0E1012", opacity: 0.10),
            lineStrong: ColorToken(hex: "#9FE000", opacity: 0.34),
            text: ColorToken(hex: "#0E1012", opacity: 1.0),
            textSoft: ColorToken(hex: "#0E1012", opacity: 0.68),
            textMuted: ColorToken(hex: "#0E1012", opacity: 0.52),
            primary: ColorToken(hex: "#C8FF2E", opacity: 1.0),
            primaryDeep: ColorToken(hex: "#9FE000", opacity: 1.0),
            danger: ColorToken(hex: "#E68484", opacity: 1.0),
            warning: ColorToken(hex: "#D8B46A", opacity: 1.0),
            electricBlue: ColorToken(hex: "#0E1012", opacity: 1.0),
            glass: ColorToken(hex: "#FFFFFF", opacity: 0.82),
            glassStrong: ColorToken(hex: "#FFFFFF", opacity: 0.94)
        ),
        radius: Radius(sm: 8, md: 18, lg: 24, xl: 28, card: 30, screen: 42, pill: 999),
        shadows: Shadows(
            soft: ShadowToken(color: "#0E1012", opacity: 0.08, radius: 24, x: 0, y: 14),
            glow: ShadowToken(color: "#C8FF2E", opacity: 0.22, radius: 22, x: 0, y: 12),
            card: ShadowToken(color: "#0E1012", opacity: 0.12, radius: 24, x: 0, y: 16)
        ),
        fonts: Fonts(display: "Space Grotesk", body: "Inter", iosDisplayDesign: "rounded")
    )
}

private extension SBDesignTokens.ColorToken {
    var color: Color {
        Color(hex: hex, opacity: opacity)
    }
}

private extension SBDesignTokens.ShadowToken {
    var shadowColor: Color {
        Color(hex: color, opacity: opacity)
    }
}

private extension Color {
    init(hex: String, opacity: Double = 1.0) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

enum SBColor {
    private static let tokens = SBDesignTokens.shared.colors

    static let background = tokens.background.color
    static let surface = tokens.surfaceSoft.color
    static let surfaceSolid = tokens.surface.color
    static let line = tokens.line.color
    static let lineStrong = tokens.lineStrong.color
    static let ink = tokens.text.color
    static let muted = tokens.textMuted.color
    static let textSoft = tokens.textSoft.color
    static let accent = tokens.primary.color
    static let primaryDeep = tokens.primaryDeep.color
    static let danger = tokens.danger.color
    static let warning = tokens.warning.color
    static let electricBlue = tokens.electricBlue.color
    static let glass = tokens.glass.color
    static let glassStrong = tokens.glassStrong.color

    static let navy = electricBlue
    static let purple = primaryDeep
}

enum SBRadius {
    private static let tokens = SBDesignTokens.shared.radius

    static let sm = CGFloat(tokens.sm)
    static let md = CGFloat(tokens.md)
    static let lg = CGFloat(tokens.lg)
    static let xl = CGFloat(tokens.xl)
    static let card = CGFloat(tokens.card)
    static let screen = CGFloat(tokens.screen)
    static let pill = CGFloat(tokens.pill)
}

enum SBShadow {
    private static let tokens = SBDesignTokens.shared.shadows

    static let soft = tokens.soft
    static let glow = tokens.glow
    static let card = tokens.card
}

enum SBFont {
    private static let tokens = SBDesignTokens.shared.fonts

    static let displayName = tokens.display
    static let bodyName = tokens.body

    static func display(size: CGFloat, weight: Font.Weight) -> Font {
        .system(size: size, weight: weight, design: displayDesign)
    }

    private static var displayDesign: Font.Design {
        switch tokens.iosDisplayDesign {
        case "rounded":
            .rounded
        case "serif":
            .serif
        case "monospaced":
            .monospaced
        default:
            .default
        }
    }
}

extension View {
    func sbSoftShadow() -> some View {
        let shadow = SBShadow.soft
        return self.shadow(
            color: shadow.shadowColor,
            radius: CGFloat(shadow.radius),
            x: CGFloat(shadow.x),
            y: CGFloat(shadow.y)
        )
    }

    func sbGlowShadow() -> some View {
        let shadow = SBShadow.glow
        return self.shadow(
            color: shadow.shadowColor,
            radius: CGFloat(shadow.radius),
            x: CGFloat(shadow.x),
            y: CGFloat(shadow.y)
        )
    }

    func sbCardShadow() -> some View {
        let shadow = SBShadow.card
        return self.shadow(
            color: shadow.shadowColor,
            radius: CGFloat(shadow.radius),
            x: CGFloat(shadow.x),
            y: CGFloat(shadow.y)
        )
    }
}

extension LinearGradient {
    static var sbPrimary: LinearGradient {
        LinearGradient(
            colors: [SBColor.accent, SBColor.electricBlue],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var sbNeon: LinearGradient {
        LinearGradient(
            colors: [SBColor.accent, SBColor.primaryDeep.opacity(0.92)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var sbSoftPanel: LinearGradient {
        LinearGradient(
            colors: [SBColor.glassStrong, SBColor.surfaceSolid.opacity(0.78)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
