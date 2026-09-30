import SwiftUI

struct AppearancePicker: View {
    @Environment(UserSettingsStore.self) private var settings
    @Environment(\.appAppearance) private var appearance

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(settings.t("appearance.title"))
                .font(.title3.weight(.heavy))
                .foregroundStyle(appearance.canvasPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(settings.t("appearance.hint"))
                .font(.subheadline)
                .foregroundStyle(appearance.canvasSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 12) {
                ForEach(AppAppearance.allCases) { option in
                    optionButton(option)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: settings.appearance)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("appearance-picker")
    }

    private func optionButton(_ option: AppAppearance) -> some View {
        let isSelected = settings.appearance == option
        return Button {
            settings.appearance = option
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                preview(option)
                HStack(alignment: .top, spacing: 6) {
                    Text(settings.t("appearance.\(option.rawValue)"))
                        .font(.subheadline.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.body.weight(.semibold))
                        .accessibilityHidden(true)
                }
                .foregroundStyle(SBColor.contentPrimary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(SBColor.surfaceRaised, in: RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous)
                    .stroke(isSelected ? appearance.canvasPrimary : SBColor.dividerStrong, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(SBPremiumButtonStyle())
        .accessibilityLabel(settings.t("appearance.\(option.rawValue)"))
        .accessibilityValue(settings.t(isSelected ? "appearance.selected" : "appearance.not_selected"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("appearance-option-\(option.rawValue)")
    }

    private func preview(_ option: AppAppearance) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Capsule()
                .fill(option.canvasPrimary)
                .frame(width: 48, height: 5)
            ForEach(0..<2) { _ in
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(LinearGradient.sbSoftPanel)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(SBColor.contentSecondary)
                            .frame(width: 32, height: 4)
                            .padding(.leading, 10)
                    }
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 3)
            }
        }
        .padding(12)
        .frame(height: 108)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(option.canvas, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHidden(true)
    }
}
