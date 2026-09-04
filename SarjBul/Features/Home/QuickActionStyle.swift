import SwiftUI

struct QuickActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var active: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(active ? SBColor.onActionPrimary : SBColor.contentSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(active ? SBColor.actionPrimary : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(active ? SBColor.onActionPrimary.opacity(0.12) : .clear, lineWidth: 1)
            )
            .sbButtonShadow(isPressed: configuration.isPressed, enabled: active && isEnabled)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
