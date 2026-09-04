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
    static let canvas = SBGeneratedTokens.canvas.color
    static let surfaceBase = SBGeneratedTokens.surfaceBase.color
    static let surfaceRaised = SBGeneratedTokens.surfaceRaised.color
    static let surfaceInteractive = SBGeneratedTokens.surfaceInteractive.color
    static let surfaceInverted = SBGeneratedTokens.surfaceInverted.color
    static let surfaceGlass = SBGeneratedTokens.surfaceGlass.color
    static let surfaceGlassStrong = SBGeneratedTokens.surfaceGlassStrong.color
    static let divider = SBGeneratedTokens.divider.color
    static let dividerStrong = SBGeneratedTokens.dividerStrong.color
    static let contentPrimary = SBGeneratedTokens.contentPrimary.color
    static let contentSecondary = SBGeneratedTokens.contentSecondary.color
    static let contentTertiary = SBGeneratedTokens.contentTertiary.color
    static let actionPrimary = SBGeneratedTokens.actionPrimary.color
    static let onActionPrimary = SBGeneratedTokens.onActionPrimary.color
    static let stationHighPower = SBGeneratedTokens.stationHighPower.color
    static let stationMediumPower = SBGeneratedTokens.stationMediumPower.color
    static let stationStandardPower = SBGeneratedTokens.stationStandardPower.color
    static let statusAvailable = SBGeneratedTokens.statusAvailable.color
    static let danger = SBGeneratedTokens.danger.color
    static let warning = SBGeneratedTokens.warning.color
    static let loungeAccent = SBGeneratedTokens.loungeAccent.color
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
    static let button = SBGeneratedTokens.shadowButton
    static let contact = SBGeneratedTokens.shadowContact
    static let pressed = SBGeneratedTokens.shadowPressed
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
    func sbButtonShadow(isPressed: Bool = false, enabled: Bool = true) -> some View {
        let ambient = isPressed ? SBShadow.pressed : SBShadow.button
        let contact = SBShadow.contact
        return self
            .compositingGroup()
            .shadow(
                color: enabled ? ambient.shadowColor : .clear,
                radius: CGFloat(ambient.radius), x: CGFloat(ambient.x), y: CGFloat(ambient.y)
            )
            .shadow(
                color: enabled && !isPressed ? contact.shadowColor : .clear,
                radius: CGFloat(contact.radius), x: CGFloat(contact.x), y: CGFloat(contact.y)
            )
    }

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
                .glassEffect(.regular.tint(SBColor.surfaceGlassStrong).interactive(interactive), in: shape)
                .overlay(
                    shape
                        .stroke(SBColor.divider, lineWidth: 1)
                )
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .background(LinearGradient.sbSoftPanel, in: shape)
                .overlay(
                    shape
                        .stroke(SBColor.divider, lineWidth: 1)
                )
        }
        #else
        content
            .background(.ultraThinMaterial, in: shape)
            .background(LinearGradient.sbSoftPanel, in: shape)
            .overlay(
                shape
                    .stroke(SBColor.divider, lineWidth: 1)
            )
        #endif
    }
}

extension LinearGradient {
    static var sbPrimary: LinearGradient {
        LinearGradient(
            colors: [SBColor.actionPrimary, SBColor.actionPrimary],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var sbSoftPanel: LinearGradient {
        LinearGradient(
            colors: [SBColor.surfaceGlassStrong, SBColor.surfaceBase],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
