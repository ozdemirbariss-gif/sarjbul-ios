import SwiftUI

struct ChargeVisual: View {
    var percent: Int
    var statusText: String
    var chargeLabel: String
    var selectedLevelText: String

    private var clampedPercent: Int {
        min(100, max(1, percent))
    }

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(.black.opacity(0.1), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: Double(clampedPercent) / 100)
                    .stroke(SBColor.electricBlue, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("%\(clampedPercent)")
                        .font(.title.weight(.heavy))
                        .foregroundStyle(.black)
                        .contentTransition(.numericText())
                    Text(chargeLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.black.opacity(0.5))
                }
            }
            .frame(width: 108, height: 108)

            VStack(alignment: .leading, spacing: 12) {
                Text(selectedLevelText)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.black.opacity(0.5))
                Text(statusText)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(.black)
                BatteryBar(percent: clampedPercent)
            }
        }
        .padding(18)
        .background(SBColor.ice)
        .clipShape(RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous)
                .stroke(.white.opacity(0.45), lineWidth: 1)
        )
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: clampedPercent)
    }
}

private struct BatteryBar: View {
    var percent: Int

    var body: some View {
        GeometryReader { proxy in
            let fillWidth = max(18, proxy.size.width * CGFloat(percent) / 100)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.black.opacity(0.1))
                Capsule()
                    .fill(LinearGradient.sbNeon)
                    .frame(width: fillWidth)
                Capsule()
                    .stroke(.black.opacity(0.16), lineWidth: 1)
            }
        }
        .frame(height: 30)
        .animation(.spring(response: 0.38, dampingFraction: 0.8), value: percent)
        .overlay(alignment: .trailing) {
            Capsule()
                .fill(.black.opacity(0.28))
                .frame(width: 8, height: 18)
                .offset(x: 6)
        }
    }
}
