import SwiftUI

struct ArrivedAtStationCard: View {
    @Environment(UserSettingsStore.self) private var settings
    @Environment(NavigationCoordinator.self) private var navigation
    @Environment(ChargingSessionStore.self) private var chargingSession

    var journey: ActiveRouteJourney

    var body: some View {
        Button {
            navigation.select(.lounge)
            Task {
                await chargingSession.start(
                    station: journey.station,
                    initialPercent: settings.profile.chargePercent,
                    languageCode: settings.language.rawValue
                )
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "bolt.car.fill")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(SBColor.onActionPrimary)
                    .frame(width: 56, height: 56)
                    .background(SBColor.actionPrimary, in: RoundedRectangle(
                        cornerRadius: SBRadius.md,
                        style: .continuous
                    ))

                VStack(alignment: .leading, spacing: 5) {
                    Text(settings.t("journey.arrived_kicker"))
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(SBColor.actionPrimary)
                    Text(journey.station.name)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(SBColor.contentPrimary)
                        .lineLimit(2)
                    Text(settings.t("journey.start_charging"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SBColor.contentSecondary)
                }

                Spacer(minLength: 4)
                Image(systemName: "arrow.right")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(SBColor.contentPrimary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SBColor.surfaceBase, in: RoundedRectangle(
                cornerRadius: SBRadius.card,
                style: .continuous
            ))
            .overlay(RoundedRectangle(cornerRadius: SBRadius.card).stroke(SBColor.dividerStrong))
        }
        .buttonStyle(SBPremiumButtonStyle())
        .accessibilityIdentifier("arrived-start-charging-card")
    }
}
