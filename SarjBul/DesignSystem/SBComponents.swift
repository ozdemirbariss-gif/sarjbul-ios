import SwiftUI

struct SBPanel<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(SBColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 14)
    }
}

struct SBPrimaryButton: View {
    var title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(.headline.weight(.bold))
            }
            .foregroundStyle(SBColor.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(LinearGradient.sbPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: SBColor.accent.opacity(0.28), radius: 22, x: 0, y: 12)
        }
        .buttonStyle(.plain)
    }
}

struct MetricInput: View {
    var title: String
    var unit: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(SBColor.muted)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField(title, value: $value, format: .number.precision(.fractionLength(step < 1 ? 1 : 0)))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(SBColor.ink)
                    .sbDecimalKeyboard()
                    .onChange(of: value) { _, newValue in
                        value = min(range.upperBound, max(range.lowerBound, newValue))
                    }
                Text(unit)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(SBColor.muted)
            }
            .padding(.horizontal, 14)
            .frame(height: 54)
            .background(.white.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

extension View {
    @ViewBuilder
    func sbDecimalKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.decimalPad)
        #else
        self
        #endif
    }

    @ViewBuilder
    func sbInlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
