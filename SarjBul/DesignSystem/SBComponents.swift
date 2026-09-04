import SwiftUI

struct SBScreenBackground: View {
    var body: some View {
        SBColor.canvas
        .ignoresSafeArea()
    }
}

struct SBBackButton: View {
    var accessibilityLabel = "Geri"
    var action: () -> Void

    var body: some View {
        Button {
            Haptic.tap()
            action()
        } label: {
            Image(systemName: "arrow.left")
                .font(.title2.weight(.heavy))
                .foregroundStyle(SBColor.contentPrimary)
                .frame(width: 58, height: 58)
                .background(SBColor.surfaceGlassStrong)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(SBColor.divider, lineWidth: 1)
                )
        }
        .buttonStyle(SBPremiumButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

struct SBBrandMark: View {
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(LinearGradient.sbPrimary)
                .frame(width: 28, height: 28)
                .overlay(alignment: .trailing) {
                    Circle()
                        .fill(SBColor.actionPrimary)
                        .frame(width: 34, height: 34)
                        .opacity(0.22)
                        .offset(x: 22)
                }
            Circle()
                .fill(SBColor.contentPrimary)
                .frame(width: 14, height: 14)
                .padding(.leading, 8)
            Text("ŞarjBul")
                .font(SBFont.display(size: 26, weight: .heavy))
                .foregroundStyle(SBColor.contentPrimary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .background(SBColor.surfaceGlassStrong)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(SBColor.divider, lineWidth: 1)
        )
        .sbSoftShadow()
    }
}

struct SBLanguageSwitch: View {
    @Binding var selectedLanguage: String

    var body: some View {
        HStack(spacing: 0) {
            languageButton("TR")
            languageButton("EN")
        }
        .padding(6)
        .sbPremiumGlass(radius: 34, interactive: true)
    }

    private func languageButton(_ language: String) -> some View {
        Button {
            Haptic.tap()
            selectedLanguage = language
        } label: {
            Text(language)
                .font(.headline.weight(.heavy))
                .foregroundStyle(selectedLanguage == language ? SBColor.onActionPrimary : SBColor.contentTertiary)
                .frame(width: 62, height: 48)
                .background(selectedLanguage == language ? SBColor.actionPrimary : .clear)
                .clipShape(Capsule())
        }
        .buttonStyle(SBPremiumButtonStyle(elevated: selectedLanguage == language))
    }
}

struct SBPanel<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .sbPremiumGlass(radius: SBRadius.xl)
            .sbSoftShadow()
    }
}

struct SBSecondaryPanel<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .background(SBColor.surfaceInteractive, in: RoundedRectangle(cornerRadius: SBRadius.xl, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: SBRadius.xl, style: .continuous).stroke(SBColor.divider, lineWidth: 1))
            .sbSoftShadow()
    }
}

struct SBPrimaryButton: View {
    var title: String
    var systemImage: String?
    var accessibilityIdentifier: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .symbolEffect(.pulse, options: .speed(0.6), value: title)
                }
                Text(title)
                    .font(.headline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            .foregroundStyle(SBColor.onActionPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(SBColor.actionPrimary)
            .clipShape(RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous)
                    .stroke(SBColor.onActionPrimary.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(SBPremiumButtonStyle())
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}

struct SBDarkButton: View {
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
                    .font(.headline.weight(.heavy))
            }
            .foregroundStyle(SBColor.onActionPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 68)
            .background(SBColor.surfaceInverted)
            .clipShape(RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous))
        }
        .buttonStyle(SBPremiumButtonStyle())
    }
}

struct MetricInput: View {
    var title: String
    var unit: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var accessibilityIdentifier: String?

    init(
        title: String,
        unit: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        accessibilityIdentifier: String? = nil
    ) {
        self.title = title
        self.unit = unit
        _value = value
        self.range = range
        self.step = step
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline.weight(.heavy))
                .foregroundStyle(SBColor.contentTertiary)
                .lineLimit(2)
                .minimumScaleFactor(0.84)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .bottomLeading)

            HStack(alignment: .center, spacing: 8) {
                TextField(title, value: $value, format: .number.precision(.fractionLength(step < 1 ? 1 : 0)))
                    .font(SBFont.display(size: 28, weight: .heavy))
                    .foregroundStyle(SBColor.contentPrimary)
                    .multilineTextAlignment(.center)
                    .monospacedDigit()
                    .sbDecimalKeyboard()
                    .onChange(of: value) { _, newValue in
                        value = min(range.upperBound, max(range.lowerBound, newValue))
                    }
                    .accessibilityIdentifier(accessibilityIdentifier ?? "")
                Text(unit)
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(SBColor.contentTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(SBColor.surfaceInteractive)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .frame(height: 72)
            .sbPremiumGlass(radius: SBRadius.lg, interactive: true)
            .sbSoftShadow()
        }
    }
}

struct SBPremiumButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var elevated = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .sbButtonShadow(isPressed: configuration.isPressed, enabled: elevated && isEnabled)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.965 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.72), value: configuration.isPressed)
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
