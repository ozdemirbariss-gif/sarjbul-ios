import MapKit
import SarjBulCore
import SwiftUI

struct StationCard: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    var candidate: StationCandidate
    var rank: Int
    var total: Int

    var body: some View {
        VStack(spacing: 0) {
            mapPreview
            details
        }
        .background(SBColor.accent)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .stroke(SBColor.accent, lineWidth: 10)
        )
        .sbCardShadow()
    }

    private var mapPreview: some View {
        StationMapPreview(station: candidate.station)
            .overlay(alignment: .topLeading) {
                routePill {
                    HStack(spacing: 6) {
                        Text("\(candidate.score)")
                            .font(.title2.weight(.heavy))
                        Text(appState.t("feed.score"))
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(SBColor.muted)
                    }
                }
                .padding(22)
            }
            .overlay(alignment: .topTrailing) {
                VStack(spacing: 16) {
                    routePill {
                        Text(String(format: "%02d / %02d", rank, total))
                            .font(.title2.weight(.heavy))
                    }

                    Button {
                        Haptic.tap()
                        openInAppleMaps()
                    } label: {
                        Image(systemName: "arrow.up.right")
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(SBColor.ink)
                            .frame(width: 58, height: 58)
                            .background(SBColor.glassStrong)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(appState.t("feed.open_in_maps"))
                }
                .padding(22)
            }
            .overlay(alignment: .bottomLeading) {
                routePill {
                    Text(appState.t("feed.route_approximate"))
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(SBColor.electricBlue)
                }
                .padding(22)
            }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(String(format: "%.1f km", candidate.distanceKm))
                .font(SBFont.display(size: 78, weight: .heavy))
                .foregroundStyle(SBColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("\(candidate.estimatedMinutes) \(appState.t("feed.minute")) · \(appState.t("feed.arrival")) %\(Int(candidate.arrivalChargePercent.rounded()))")
                .font(.title3.weight(.heavy))
                .foregroundStyle(SBColor.textSoft)

            HStack(spacing: 10) {
                chip("\(appState.t("feed.arrival_charge")) %\(Int(candidate.arrivalChargePercent.rounded()))")
                chip(String(format: "\(appState.t("feed.deviation")) +%.1f km", max(0, candidate.distanceKm - candidate.straightLineDistanceKm)))
            }

            stationPanel

            HStack(spacing: 10) {
                metric(appState.t("feed.power"), candidate.station.power)
                metric(appState.t("feed.socket"), candidate.station.socket)
                metric(appState.t("feed.price"), candidate.station.price)
            }

            HStack(alignment: .center, spacing: 8) {
                ForEach(candidate.badges.prefix(3), id: \.self) { badge in
                    Text(localizedBadgeTitle(badge))
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(badgeColor(badge.tone))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(SBColor.primaryDeep.opacity(0.24))
                        .clipShape(Capsule())
                }
                Spacer()
                Image(systemName: "questionmark")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(SBColor.ink)
                    .frame(width: 42, height: 42)
                    .background(SBColor.primaryDeep.opacity(0.35))
                    .clipShape(Circle())
            }

            routeButtons

            if appState.isAuthenticated {
                statusActions
            }

            Text(candidate.station.address)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(SBColor.textSoft)
                .lineLimit(2)
        }
        .padding(22)
    }

    private var stationPanel: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(appState.t("feed.detail_card"))
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(SBColor.muted)
                Text(candidate.station.name)
                    .font(SBFont.display(size: 30, weight: .heavy))
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                Text(candidate.station.operatorName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(SBColor.textSoft)
            }
            Spacer(minLength: 8)
            favoriteButton
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SBColor.glass)
        .clipShape(RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous)
                .stroke(SBColor.line, lineWidth: 1)
        )
    }

    private var favoriteButton: some View {
        let stationKey = candidate.station.statusKey
        return Button {
            Haptic.tap()
            Task { await appState.toggleFavorite(stationKey) }
        } label: {
            Image(systemName: appState.isFavorite(stationKey) ? "heart.fill" : "heart")
                .font(.headline.weight(.bold))
                .foregroundStyle(appState.isFavorite(stationKey) ? SBColor.danger : SBColor.electricBlue)
                .frame(width: 44, height: 44)
                .background(SBColor.glassStrong)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(appState.isFavorite(stationKey) ? appState.t("feed.favorite_remove") : appState.t("feed.favorite_add"))
    }

    private var routeButtons: some View {
        HStack(spacing: 10) {
            Text(appState.t("feed.open_route"))
                .font(.title3.weight(.heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            routeMapButton(appState.t("feed.apple_maps"), action: openInAppleMaps)
            routeMapButton(appState.t("feed.google_maps"), action: openInGoogleMaps)
        }
        .padding(.horizontal, 22)
        .frame(height: 76)
        .background(SBColor.electricBlue)
        .clipShape(RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous))
    }

    private var statusActions: some View {
        HStack(spacing: 8) {
            reportButton(appState.t("actions.available"), status: "Uygun", icon: "checkmark.circle.fill")
            reportButton(appState.t("actions.issue_value"), status: "Sorun var", icon: "exclamationmark.triangle.fill")
            reportButton(appState.t("actions.queue_value"), status: "Sıra var", icon: "clock.fill")
        }
    }

    private func routeMapButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.tap()
            action()
        } label: {
            Text(title)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(SBColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
                .padding(.horizontal, 14)
                .frame(minWidth: 86)
                .frame(height: 42)
                .background(SBColor.glassStrong)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func routePill<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .foregroundStyle(SBColor.ink)
            .padding(.horizontal, 18)
            .frame(height: 52)
            .background(SBColor.glassStrong)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(SBColor.line, lineWidth: 1)
            )
    }

    private func chip(_ title: String) -> some View {
        Text(title)
            .font(.headline.weight(.heavy))
            .foregroundStyle(SBColor.electricBlue)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(SBColor.glass.opacity(0.62))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(SBColor.lineStrong, lineWidth: 1)
            )
    }

    private func reportButton(_ title: String, status: String, icon: String) -> some View {
        Button {
            Haptic.tap()
            Task { await appState.reportStatus(stationKey: candidate.station.statusKey, status: status) }
        } label: {
            Label(title, systemImage: icon)
                .font(.caption.weight(.heavy))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(SBColor.glass)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func badgeColor(_ tone: StationBadge.Tone) -> Color {
        switch tone {
        case .good, .info:
            SBColor.electricBlue
        case .warning:
            SBColor.warning
        case .risk:
            SBColor.danger
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(SBColor.muted)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(SBColor.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(SBColor.glass)
        .clipShape(RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous)
                .stroke(SBColor.line, lineWidth: 1)
        )
    }

    private func localizedBadgeTitle(_ badge: StationBadge) -> String {
        switch badge.title {
        case "Risk bildirildi":
            return appState.t("badge.risk")
        case "Son bildirim olumlu":
            return appState.t("badge.last_positive")
        case "Canlı veri yok":
            return appState.t("badge.no_live")
        case "Varış güvenli":
            return appState.t("badge.arrival_safe")
        case "Varış düşük":
            return appState.t("badge.arrival_low")
        case "Hızlı DC":
            return appState.t("badge.fast_dc")
        case "DC":
            return appState.t("badge.dc")
        case "Yüksek veri güveni":
            return appState.t("badge.high_confidence")
        default:
            if badge.title.hasSuffix(" kaynak"),
               let count = badge.title.split(separator: " ").first {
                return appState.t("badge.sources", ["count": String(count)])
            }
            return badge.title
        }
    }

    private func openInAppleMaps() {
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(
            latitude: candidate.station.latitude,
            longitude: candidate.station.longitude
        )))
        destination.name = candidate.station.name
        destination.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    private func openInGoogleMaps() {
        var components = URLComponents(string: "https://www.google.com/maps/dir/")
        components?.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "destination", value: "\(candidate.station.latitude),\(candidate.station.longitude)"),
            URLQueryItem(name: "travelmode", value: "driving")
        ]
        if let url = components?.url {
            openURL(url)
        }
    }
}
