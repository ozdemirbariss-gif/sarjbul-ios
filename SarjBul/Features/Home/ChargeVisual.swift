import SwiftUI

struct ChargeVisual: View {
    @Environment(\.appAppearance) private var appearance
    var percent: Int
    var statusText: String
    var chargeLabel: String
    var selectedLevelText: String

    private var clampedPercent: Int {
        min(100, max(1, percent))
    }

    private var foreground: Color {
        appearance == .dark ? SBColor.onActionPrimary : SBColor.contentPrimary
    }

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(foreground.opacity(0.1), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: Double(clampedPercent) / 100)
                    .stroke(SBColor.actionPrimary, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("%\(clampedPercent)")
                        .font(.title.weight(.heavy))
                        .foregroundStyle(foreground)
                        .contentTransition(.numericText())
                    Text(chargeLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(foreground.opacity(0.5))
                }
            }
            .frame(width: 108, height: 108)

            VStack(alignment: .leading, spacing: 12) {
                Text(selectedLevelText)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(foreground.opacity(0.5))
                Text(statusText)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(foreground)
                BatteryBar(percent: clampedPercent)
            }
        }
        .padding(18)
        .background(appearance == .dark ? SBColor.surfaceInverted : SBColor.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous)
                .stroke(SBColor.dividerStrong, lineWidth: 1)
        )
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: clampedPercent)
    }
}

private struct BatteryBar: View {
    @Environment(\.appAppearance) private var appearance
    var percent: Int

    private var foreground: Color {
        appearance == .dark ? SBColor.onActionPrimary : SBColor.contentPrimary
    }

    var body: some View {
        GeometryReader { proxy in
            let fillWidth = max(18, proxy.size.width * CGFloat(percent) / 100)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(foreground.opacity(0.1))
                Capsule()
                    .fill(LinearGradient.sbPrimary)
                    .frame(width: fillWidth)
                Capsule()
                    .stroke(foreground.opacity(0.16), lineWidth: 1)
            }
        }
        .frame(height: 30)
        .animation(.spring(response: 0.38, dampingFraction: 0.8), value: percent)
        .overlay(alignment: .trailing) {
            Capsule()
                .fill(foreground.opacity(0.28))
                .frame(width: 8, height: 18)
                .offset(x: 6)
        }
    }
}
