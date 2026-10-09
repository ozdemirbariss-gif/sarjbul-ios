import Foundation
import SarjBulCore

/// Shared by the phone and CarPlay so both surfaces use the same evidence rules.
struct StationEvidenceText {
    let station: Station
    let insight: StationCommunityInsight?
    let live: LiveStationAvailability?
    let risky: Bool
    let language: AppLanguage
    var now = Date()

    var price: String {
        let value = StationDataQuality.displayValue(sourceValue: station.price, field: .price, insight: insight)
        return StationDataQuality.isUnknown(value) ? t("evidence.unknown") : value
    }

    var priceSource: String {
        let verification = insight?.verification(for: .price)
        let communityPrice = verification?.verified == true
        let source = communityPrice ? t("evidence.community") : station.source
        let date = communityPrice ? Station.parseSourceDate(verification?.lastConfirmedAt) : nil
        return AppLocalization.text("evidence.price_source", language: language, replacements: [
            "source": source.isEmpty ? t("evidence.unknown") : source,
            "date": dateText(date)
        ])
    }

    var availability: String {
        if risky { return t("evidence.risk_report") }
        if let live, live.isCurrent(at: now) {
            return AppLocalization.text("evidence.live", language: language, replacements: [
                "operator": station.operatorName, "available": "\(live.availableConnectors)",
                "total": "\(live.totalConnectors)", "date": dateText(live.updatedAt)
            ])
        }
        let prediction = OccupancyPredictor.predict(station: station, insight: insight, date: now)
        return t(prediction.confidence == .low ? "evidence.availability_unknown" : "evidence.prediction")
    }

    private func dateText(_ date: Date?) -> String {
        guard let date else { return t("evidence.date_unknown") }
        return date.formatted(.dateTime.locale(language.locale).day().month().year().hour().minute())
    }

    private func t(_ key: String) -> String { AppLocalization.text(key, language: language) }
}
