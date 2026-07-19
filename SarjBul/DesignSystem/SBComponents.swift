import SwiftUI

struct SBScreenBackground: View {
    var body: some View {
        ZStack {
            SBColor.background
            RadialGradient(
                colors: [SBColor.accent.opacity(0.18), .clear],
                center: .top,
                startRadius: 20,
                endRadius: 460
            )
            RadialGradient(
                colors: [SBColor.primaryDeep.opacity(0.12), .clear],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 520
            )
        }
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
                .foregroundStyle(SBColor.ink)
                .frame(width: 72, height: 72)
                .background(SBColor.glassStrong)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(SBColor.line, lineWidth: 1)
                )
                .shadow(color: SBColor.accent.opacity(0.28), radius: 28, x: 0, y: 12)
        }
        .buttonStyle(.plain)
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
                        .fill(SBColor.accent)
                        .frame(width: 34, height: 34)
                        .opacity(0.22)
                        .offset(x: 22)
                }
            Circle()
                .fill(SBColor.accent)
                .frame(width: 14, height: 14)
                .padding(.leading, 8)
            Text("ŞarjBul")
                .font(SBFont.display(size: 26, weight: .heavy))
                .foregroundStyle(SBColor.ink)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .background(SBColor.glassStrong)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(SBColor.line, lineWidth: 1)
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
                .foregroundStyle(selectedLanguage == language ? .white : SBColor.muted)
                .frame(width: 72, height: 54)
                .background(selectedLanguage == language ? SBColor.electricBlue : .clear)
                .clipShape(Capsule())
        }
        .buttonStyle(SBPremiumButtonStyle())
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
            .padding(20)
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
            .padding(20)
            .sbPremiumGlass(radius: SBRadius.xl)
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
            .foregroundStyle(SBColor.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(LinearGradient.sbNeon)
            .clipShape(RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous)
                    .stroke(.white.opacity(0.55), lineWidth: 1)
            )
            .sbGlowShadow()
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
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 68)
            .background(SBColor.electricBlue)
            .clipShape(RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous))
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
                .font(.headline.weight(.heavy))
                .foregroundStyle(SBColor.muted)

            HStack(alignment: .center, spacing: 8) {
                TextField(title, value: $value, format: .number.precision(.fractionLength(step < 1 ? 1 : 0)))
                    .font(SBFont.display(size: 28, weight: .heavy))
                    .foregroundStyle(SBColor.ink)
                    .multilineTextAlignment(.center)
                    .monospacedDigit()
                    .sbDecimalKeyboard()
                    .onChange(of: value) { _, newValue in
                        value = min(range.upperBound, max(range.lowerBound, newValue))
                    }
                Text(unit)
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(SBColor.muted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(SBColor.surface)
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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: configuration.isPressed)
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
