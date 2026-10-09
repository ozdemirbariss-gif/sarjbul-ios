import SarjBulCore
import SwiftUI

struct StationDataEvidenceView: View {
    @Environment(UserSettingsStore.self) private var settings
    let candidate: StationCandidate

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let evidence = StationEvidenceText(station: candidate.station, insight: candidate.communityInsight,
                                               live: candidate.liveAvailability, risky: candidate.hasRiskyStatus,
                                               language: settings.language, now: context.date)
            VStack(alignment: .leading, spacing: 6) {
                Label(settings.t("feed.price") + ": " + evidence.price, systemImage: "tag")
                    .font(.subheadline.weight(.semibold))
                Text(evidence.priceSource)
                Text(settings.t("evidence.price_verify"))
                Text(evidence.availability)
            }
            .font(.caption)
            .foregroundStyle(SBColor.contentSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("station-data-evidence")
        }
    }
}
