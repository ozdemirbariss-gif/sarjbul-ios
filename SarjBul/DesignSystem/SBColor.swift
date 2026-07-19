import SwiftUI

private extension SBGeneratedColorToken {
    var color: Color {
        Color(hex: hex, opacity: opacity)
    }
}

private extension SBGeneratedShadowToken {
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
    static let background = SBGeneratedTokens.background.color
    static let surface = SBGeneratedTokens.surfaceSoft.color
    static let surfaceSolid = SBGeneratedTokens.surface.color
    static let line = SBGeneratedTokens.line.color
    static let lineStrong = SBGeneratedTokens.lineStrong.color
    static let ink = SBGeneratedTokens.text.color
    static let muted = SBGeneratedTokens.textMuted.color
    static let textSoft = SBGeneratedTokens.textSoft.color
    static let accent = SBGeneratedTokens.primary.color
    static let primaryDeep = SBGeneratedTokens.primaryDeep.color
    static let danger = SBGeneratedTokens.danger.color
    static let warning = SBGeneratedTokens.warning.color
    static let electricBlue = SBGeneratedTokens.electricBlue.color
    static let glass = SBGeneratedTokens.glass.color
    static let glassStrong = SBGeneratedTokens.glassStrong.color

    static let navy = electricBlue
    static let purple = primaryDeep
}

enum SBRadius {
    static let sm = CGFloat(SBGeneratedTokens.radiusSm)
    static let md = CGFloat(SBGeneratedTokens.radiusMd)
    static let lg = CGFloat(SBGeneratedTokens.radiusLg)
    static let xl = CGFloat(SBGeneratedTokens.radiusXl)
    static let card = CGFloat(SBGeneratedTokens.radiusCard)
    static let screen = CGFloat(SBGeneratedTokens.radiusScreen)
    static let pill = CGFloat(SBGeneratedTokens.radiusPill)
}

enum SBShadow {
    static let soft = SBGeneratedTokens.shadowSoft
    static let glow = SBGeneratedTokens.shadowGlow
    static let card = SBGeneratedTokens.shadowCard
}

enum SBFont {
    static let displayName = SBGeneratedTokens.displayFont
    static let bodyName = SBGeneratedTokens.bodyFont

    static func display(size: CGFloat, weight: Font.Weight) -> Font {
        .system(size: size, weight: weight, design: displayDesign)
    }

    private static var displayDesign: Font.Design {
        switch SBGeneratedTokens.iosDisplayDesign {
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
    func sbPremiumGlass(radius: CGFloat, interactive: Bool = false) -> some View {
        modifier(SBPremiumGlassModifier(radius: radius, interactive: interactive))
    }

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

private struct SBPremiumGlassModifier: ViewModifier {
    var radius: CGFloat
    var interactive: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content
                .background(LinearGradient.sbSoftPanel.opacity(0.72), in: shape)
                .glassEffect(.regular.tint(SBColor.glassStrong).interactive(interactive), in: shape)
                .overlay(
                    shape
                        .stroke(SBColor.line, lineWidth: 1)
                )
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .background(LinearGradient.sbSoftPanel, in: shape)
                .overlay(
                    shape
                        .stroke(SBColor.line, lineWidth: 1)
                )
        }
        #else
        content
            .background(.ultraThinMaterial, in: shape)
            .background(LinearGradient.sbSoftPanel, in: shape)
            .overlay(
                shape
                    .stroke(SBColor.line, lineWidth: 1)
            )
        #endif
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
