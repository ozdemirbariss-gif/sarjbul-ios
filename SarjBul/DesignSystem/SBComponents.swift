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
            .clipShape(RoundedRectangle(cornerRadius: SBRadius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SBRadius.xl, style: .continuous)
                    .stroke(SBColor.line, lineWidth: 1)
            )
            .sbSoftShadow()
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
            .clipShape(RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous))
            .sbGlowShadow()
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
            .background(SBColor.glass)
            .clipShape(RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous)
                    .stroke(SBColor.line, lineWidth: 1)
            )
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
    func sbEmailInput() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .submitLabel(.next)
        #else
        autocorrectionDisabled()
        #endif
    }

    @ViewBuilder
    func sbPasswordInput(isNewPassword: Bool) -> some View {
        #if os(iOS)
        textContentType(isNewPassword ? .newPassword : .password)
            .submitLabel(.go)
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

    @ViewBuilder
    func sbMediumSheet() -> some View {
        #if os(iOS)
        presentationDetents([.medium])
            .presentationBackground(.ultraThinMaterial)
        #else
        self
        #endif
    }
}
