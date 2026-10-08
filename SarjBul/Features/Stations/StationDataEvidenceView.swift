import SarjBulCore
import SwiftUI

struct StationDataEvidenceView: View {
    @Environment(UserSettingsStore.self) private var settings
    let candidate: StationCandidate

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { _ in
            evidenceContent
        }
    }

    private var evidenceContent: some View {
        let price = candidate.communityInsight?.verification(for: .price)
        let communityPrice = price?.verified == true
        let source = communityPrice ? settings.t("evidence.community") : candidate.station.source
        let priceDate = communityPrice ? Station.parseSourceDate(price?.lastConfirmedAt) : nil
        return VStack(alignment: .leading, spacing: 6) {
            Label(settings.t("feed.price") + ": " + localizedPrice, systemImage: "tag")
                .font(.subheadline.weight(.semibold))
            Text(settings.t("evidence.price_source", [
                "source": source.isEmpty ? settings.t("evidence.unknown") : source,
                "date": evidenceDate(priceDate)
            ]))
            Text(settings.t("evidence.price_verify"))
            Text(availabilityEvidence)
        }
        .font(.caption)
        .foregroundStyle(SBColor.contentSecondary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("station-data-evidence")
    }

    private var effectivePrice: String {
        StationDataQuality.displayValue(sourceValue: candidate.station.price, field: .price, insight: candidate.communityInsight)
    }

    private var localizedPrice: String {
        StationDataQuality.isUnknown(effectivePrice) ? settings.t("evidence.unknown") : effectivePrice
    }

    private var availabilityEvidence: String {
        if candidate.hasRiskyStatus { return settings.t("evidence.risk_report") }
        if let live = candidate.liveAvailability, live.isCurrent() {
            return settings.t("evidence.live", [
                "operator": candidate.station.operatorName,
                "available": "\(live.availableConnectors)", "total": "\(live.totalConnectors)",
                "date": evidenceDate(live.updatedAt)
            ])
        }
        let prediction = OccupancyPredictor.predict(station: candidate.station, insight: candidate.communityInsight)
        let key = prediction.confidence == .low ? "evidence.availability_unknown" : "evidence.prediction"
        return settings.t(key)
    }

    private func evidenceDate(_ date: Date?) -> String {
        guard let date else { return settings.t("evidence.date_unknown") }
        return date.formatted(.dateTime.locale(settings.language.locale).day().month().year().hour().minute())
    }

}
