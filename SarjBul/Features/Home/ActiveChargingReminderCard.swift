import SwiftUI

struct ActiveChargingReminderCard: View {
    @Environment(UserSettingsStore.self) private var settings
    @Environment(ChargingSessionStore.self) private var chargingSession
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .headline) private var timerWidth = 72
    @State private var isStopping = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(SBColor.onActionPrimary)
                    .frame(width: 44, height: 44)
                    .background(SBColor.actionPrimary, in: RoundedRectangle(cornerRadius: SBRadius.md))

                VStack(alignment: .leading, spacing: 4) {
                    Text(settings.t("context.charging_kicker"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SBColor.contentSecondary)
                    Text(ChargingSuggestionPresentation.stationName(
                        chargingSession.station?.name ?? settings.t("context.charging_title")
                    ))
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(SBColor.contentPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    Text(settings.t("context.charging_target", ["percent": "\(chargingSession.targetPercent)"]))
                        .font(.caption)
                        .foregroundStyle(SBColor.contentSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(spacing: 12))
            layout {
                if let endDate = chargingSession.endDate {
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .accessibilityLabel(settings.t("context.charging_remaining"))
                        Text(timerInterval: Date()...max(Date(), endDate), countsDown: true)
                            .monospacedDigit()
                            .frame(width: timerWidth, alignment: .leading)
                    }
                    .font(.headline)
                    .foregroundStyle(SBColor.contentPrimary)
                    .accessibilityElement(children: .combine)
                }
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 0)
                }
                Button {
                    isStopping = true
                    Haptic.tap()
                    Task { await chargingSession.stop() }
                } label: {
                    Label(settings.t("reminder.cancel"), systemImage: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SBColor.contentPrimary)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(SBColor.surfaceRaised, in: Capsule())
                }
                .buttonStyle(SBPremiumButtonStyle())
                .disabled(isStopping)
                .accessibilityLabel(settings.t("context.charging_cancel"))
                .accessibilityIdentifier("cancel-charging-reminder-button")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SBColor.surfaceBase, in: RoundedRectangle(cornerRadius: SBRadius.card))
        .overlay(RoundedRectangle(cornerRadius: SBRadius.card).stroke(SBColor.dividerStrong))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("active-charging-context-card")
    }
}
