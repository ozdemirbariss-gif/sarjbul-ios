import MapKit
import SarjBulCore
import SwiftUI

struct StationCard: View {
    @Environment(AppState.self) private var appState
    @Environment(RouteStore.self) private var routeStore
    @Environment(\.openURL) private var openURL
    var candidate: StationCandidate
    var rank: Int
    var total: Int
    @State private var route: StationRoute?
    @State private var fullMapPresented = false
    @ScaledMetric(relativeTo: .largeTitle) private var distanceTextSize = 56
    @ScaledMetric(relativeTo: .title) private var stationTitleSize = 24

    var body: some View {
        VStack(spacing: 0) {
            mapPreview
            details
        }
        .background(
            LinearGradient(
                colors: [SBColor.accent, SBColor.primaryDeep.opacity(0.88)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(SBColor.accent, lineWidth: 8)
        )
        .sbCardShadow()
        .task(id: routeTaskID) {
            guard let origin = appState.userLocation else { return }
            route = await routeStore.route(origin: origin, station: candidate.station)
        }
        .sheet(isPresented: $fullMapPresented) {
            FullRouteMapView(candidate: candidate, route: route)
                .environment(appState)
        }
    }

    private var mapPreview: some View {
        StationMapPreview(
            station: candidate.station,
            origin: appState.userLocation,
            route: route
        )
            .frame(height: 184)
            .clipped()
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
                .padding(16)
            }
            .overlay(alignment: .topTrailing) {
                VStack(spacing: 16) {
                    routePill {
                        Text(String(format: "%02d / %02d", rank, total))
                            .font(.title2.weight(.heavy))
                    }

                    Button {
                        Haptic.tap()
                        fullMapPresented = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(SBColor.ink)
                            .frame(width: 48, height: 48)
                            .sbPremiumGlass(radius: 24, interactive: true)
                    }
                    .buttonStyle(SBPremiumButtonStyle())
                    .accessibilityLabel(appState.t("feed.expand_map"))
                }
                    .padding(16)
            }
            .overlay(alignment: .bottomLeading) {
                routePill {
                    Text(route == nil ? appState.t("feed.route_approximate") : appState.t("feed.route_live"))
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(SBColor.electricBlue)
                }
                .padding(16)
            }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline, spacing: 14) {
                Text(String(format: "%.1f km", displayDistanceKm))
                    .font(SBFont.display(size: min(distanceTextSize, 66), weight: .heavy))
                    .foregroundStyle(SBColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                Spacer(minLength: 0)
                Text("\(displayMinutes) \(appState.t("feed.minute")) · \(appState.t("feed.arrival")) %\(Int(displayArrivalCharge.rounded()))")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(SBColor.textSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            HStack(spacing: 10) {
                chip("\(appState.t("feed.arrival_charge")) %\(Int(displayArrivalCharge.rounded()))")
                chip(String(format: "\(appState.t("feed.deviation")) +%.1f km", displayDeviationKm))
            }

            stationPanel

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                spacing: 8
            ) {
                metric(appState.t("feed.power"), candidate.station.power)
                metric(appState.t("feed.socket"), candidate.station.socket)
                metric(appState.t("feed.price"), candidate.station.price)
            }

            HStack(alignment: .center, spacing: 8) {
                ForEach(candidate.badges.prefix(2), id: \.self) { badge in
                    Text(localizedBadgeTitle(badge))
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(badgeBackground(badge.tone))
                        .clipShape(Capsule())
                    }
                Spacer(minLength: 0)
            }

            routeButtons

            if appState.isAuthenticated {
                statusActions
                if reportCooldownRemaining > 0 {
                    Text(appState.t("service.report_cooldown", ["seconds": "\(reportCooldownRemaining)"]))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SBColor.textSoft)
                }
            }

            if hasUsefulAddress {
                Text(candidate.station.address)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SBColor.textSoft)
                    .lineLimit(1)
            }
        }
        .padding(14)
    }

    private var stationPanel: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(appState.t("feed.detail_card"))
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(SBColor.muted)
                Spacer(minLength: 8)
                ShareLink(
                    item: shareURL,
                    subject: Text(candidate.station.name),
                    message: Text(candidate.station.address)
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(SBColor.electricBlue)
                        .frame(width: 40, height: 40)
                        .sbPremiumGlass(radius: 20, interactive: true)
                }
                .buttonStyle(SBPremiumButtonStyle())
                .accessibilityLabel(appState.t("feed.share"))

                favoriteButton
            }
            Text(candidate.station.name)
                .font(SBFont.display(size: min(stationTitleSize, 32), weight: .heavy))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
            Text(candidate.station.operatorName)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(SBColor.textSoft)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sbPremiumGlass(radius: SBRadius.lg)
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
                .frame(width: 40, height: 40)
                .sbPremiumGlass(radius: 20, interactive: true)
        }
        .buttonStyle(SBPremiumButtonStyle())
        .accessibilityLabel(appState.isFavorite(stationKey) ? appState.t("feed.favorite_remove") : appState.t("feed.favorite_add"))
    }

    private var routeButtons: some View {
        HStack(spacing: 8) {
            Text(appState.t("feed.open_route"))
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            routeMapButton(appState.t("feed.apple_maps_short"), icon: "apple.logo", action: openInAppleMaps)
            routeMapButton(appState.t("feed.google_maps_short"), icon: "map", action: openInGoogleMaps)
        }
        .padding(.horizontal, 16)
        .frame(height: 58)
        .background(SBColor.electricBlue)
        .clipShape(RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var statusActions: some View {
        HStack(spacing: 8) {
            reportButton(appState.t("actions.available"), status: "Uygun", icon: "checkmark.circle.fill")
            reportButton(appState.t("actions.issue_value"), status: "Sorun var", icon: "exclamationmark.triangle.fill")
            reportButton(appState.t("actions.queue_value"), status: "Sıra var", icon: "clock.fill")
        }
    }

    private func routeMapButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.tap()
            action()
        } label: {
            Label(title, systemImage: icon)
                .font(.caption.weight(.heavy))
                .foregroundStyle(SBColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
                .padding(.horizontal, 10)
                .frame(minWidth: 72)
                .frame(height: 38)
                .sbPremiumGlass(radius: 19, interactive: true)
        }
        .buttonStyle(SBPremiumButtonStyle())
    }

    private func routePill<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .foregroundStyle(SBColor.ink)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .sbPremiumGlass(radius: 22)
    }

    private func chip(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(SBColor.electricBlue)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .sbPremiumGlass(radius: 18)
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
                .sbPremiumGlass(radius: 20, interactive: true)
        }
        .buttonStyle(SBPremiumButtonStyle())
        .disabled(!appState.canReportStatus(for: candidate.station.statusKey))
        .opacity(appState.canReportStatus(for: candidate.station.statusKey) ? 1 : 0.48)
    }

    private func badgeBackground(_ tone: StationBadge.Tone) -> Color {
        switch tone {
        case .good, .info:
            SBColor.electricBlue
        case .warning:
            SBColor.primaryDeep
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
        .padding(12)
        .frame(minHeight: 66)
        .sbPremiumGlass(radius: SBRadius.lg)
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

    private var routeTaskID: String {
        guard let origin = appState.userLocation else { return candidate.id }
        return "\(candidate.id)-\(origin.latitude)-\(origin.longitude)"
    }

    private var displayDistanceKm: Double {
        route?.distanceKm ?? candidate.distanceKm
    }

    private var displayMinutes: Int {
        route?.estimatedMinutes ?? candidate.estimatedMinutes
    }

    private var displayArrivalCharge: Double {
        appState.profile.arrivalChargePercent(distanceKm: displayDistanceKm)
    }

    private var displayDeviationKm: Double {
        max(0, displayDistanceKm - candidate.straightLineDistanceKm)
    }

    private func openInAppleMaps() {
        appState.recordRouteOpened(candidate.station)
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(
            latitude: candidate.station.latitude,
            longitude: candidate.station.longitude
        )))
        destination.name = candidate.station.name
        destination.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    private func openInGoogleMaps() {
        appState.recordRouteOpened(candidate.station)
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

    private var reportCooldownRemaining: Int {
        appState.reportCooldownRemaining(for: candidate.station.statusKey)
    }

    private var shareURL: URL {
        var components = URLComponents()
        components.scheme = "sarjbul"
        components.host = "station"
        components.path = "/\(candidate.station.statusKey)"
        return components.url ?? URL(string: "https://sarjbul.app")!
    }

    private var hasUsefulAddress: Bool {
        let normalized = candidate.station.address
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "tr_TR"))
        return !normalized.isEmpty
            && !normalized.contains("adres bilgisi yok")
            && !normalized.contains("unknown")
    }
}
