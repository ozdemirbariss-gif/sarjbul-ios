import MapKit
import SarjBulCore
import SwiftUI

struct StationCard: View {
    @Environment(UserSettingsStore.self) private var settings
    @Environment(SearchCoordinator.self) private var search
    @Environment(AuthStore.self) private var auth
    @Environment(FavoritesStore.self) private var favorites
    @Environment(StationDataStore.self) private var stationData
    @Environment(ChargingSessionStore.self) private var chargingSession
    @Environment(NavigationCoordinator.self) private var navigation
    @Environment(RouteStore.self) private var routeStore
    @Environment(\.openURL) private var openURL
    var candidate: StationCandidate
    var rank: Int
    var total: Int
    @State private var route: StationRoute?
    @State private var fullMapPresented = false
    @State private var contributionPresented = false
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
            guard let origin = search.userLocation else { return }
            route = await routeStore.route(origin: origin, station: candidate.station)
        }
        .sheet(isPresented: $fullMapPresented) {
            FullRouteMapView(candidate: candidate, route: route)
                .environment(settings)
                .environment(search)
        }
        .sheet(isPresented: $contributionPresented) {
            StationContributionSheet(candidate: candidate)
                .environment(settings)
                .environment(auth)
                .environment(stationData)
        }
    }

    private var mapPreview: some View {
        StationMapPreview(
            station: candidate.station,
            origin: search.userLocation,
            route: route
        )
            .frame(height: 164)
            .clipped()
            .overlay(alignment: .topLeading) {
                routePill {
                    HStack(spacing: 6) {
                        Text("\(candidate.score)")
                            .font(.title2.weight(.heavy))
                        Text(settings.t("feed.score"))
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
                    .accessibilityLabel(settings.t("feed.expand_map"))
                }
                    .padding(16)
            }
            .overlay(alignment: .bottomLeading) {
                routePill {
                    Text(route == nil ? settings.t("feed.route_approximate") : settings.t("feed.route_live"))
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(SBColor.electricBlue)
                }
                .padding(16)
            }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline, spacing: 14) {
                Text(String(format: "%.1f km", displayDistanceKm))
                    .font(SBFont.display(size: min(distanceTextSize, 66), weight: .heavy))
                    .foregroundStyle(SBColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                Spacer(minLength: 0)
                Text("\(displayMinutes) \(settings.t("feed.minute")) · \(settings.t("feed.arrival")) %\(Int(displayArrivalCharge.rounded()))")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(SBColor.textSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            HStack(spacing: 10) {
                chip("\(settings.t("feed.arrival_charge")) %\(Int(displayArrivalCharge.rounded()))")
                chip(String(format: "\(settings.t("feed.deviation")) +%.1f km", displayDeviationKm))
            }

            stationPanel

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                spacing: 8
            ) {
                metric(settings.t("feed.power"), candidate.station.power)
                metric(settings.t("feed.socket"), effectiveSocket)
                metric(settings.t("feed.price"), effectivePrice)
            }

            stationIntelligence

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

            if auth.isAuthenticated {
                statusActions
                if reportCooldownRemaining > 0 {
                    Text(settings.t("service.report_cooldown", ["seconds": "\(reportCooldownRemaining)"]))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SBColor.textSoft)
                }
            }
        }
        .padding(12)
    }

    private var stationPanel: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(settings.t("feed.detail_card"))
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(SBColor.muted)
                Spacer(minLength: 8)
                stationToolsMenu

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
                .accessibilityLabel(settings.t("feed.share"))

                favoriteButton
            }
            Text(candidate.station.name)
                .font(SBFont.display(size: min(stationTitleSize, 32), weight: .heavy))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
            Text(candidate.station.operatorName)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(SBColor.textSoft)
            if hasUsefulAddress {
                Text(candidate.station.address)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SBColor.textSoft)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sbPremiumGlass(radius: SBRadius.lg)
    }

    private var stationIntelligence: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let availability = candidate.liveAvailability {
                Label(
                    settings.t("insight.live_availability", [
                        "available": "\(availability.availableConnectors)",
                        "total": "\(availability.totalConnectors)"
                    ]),
                    systemImage: availability.availableConnectors > 0 ? "bolt.circle.fill" : "clock.badge.exclamationmark"
                )
                .foregroundStyle(availability.availableConnectors > 0 ? SBColor.electricBlue : SBColor.warning)
            } else {
                let prediction = OccupancyPredictor.predict(
                    station: candidate.station,
                    insight: candidate.communityInsight
                )
                Label(
                    settings.t("insight.busy_prediction", [
                        "percent": "\(Int((prediction.busyProbability * 100).rounded()))"
                    ]),
                    systemImage: "chart.xyaxis.line"
                )
                .foregroundStyle(SBColor.muted)
            }

            HStack(spacing: 8) {
                Label(
                    settings.t("insight.data_confidence", [
                        "percent": "\(Int((candidate.station.confidenceScore * 100).rounded()))"
                    ]),
                    systemImage: "checkmark.shield"
                )
                if LicensedOperatorRegistry.contains(candidate.station.operatorName) {
                    Label(settings.t("insight.operator_match"), systemImage: "building.columns.fill")
                }
            }
            .foregroundStyle(SBColor.textSoft)

            if !nightSafetyText.isEmpty {
                Label(nightSafetyText, systemImage: "moon.stars.fill")
                    .foregroundStyle(SBColor.electricBlue)
            }
        }
        .font(.caption.weight(.heavy))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sbPremiumGlass(radius: SBRadius.md)
    }

    private var stationToolsMenu: some View {
        Menu {
            Button {
                Task {
                    await chargingSession.start(station: candidate.station)
                    navigation.select(.lounge)
                }
            } label: {
                Label(settings.t("break.start"), systemImage: "cup.and.saucer.fill")
            }

            Button {
                if auth.isAuthenticated {
                    contributionPresented = true
                } else {
                    navigation.select(.account)
                }
            } label: {
                Label(
                    settings.t(auth.isAuthenticated ? "data_quality.improve" : "data_quality.login_to_improve"),
                    systemImage: "checkmark.seal"
                )
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.headline.weight(.bold))
                .foregroundStyle(SBColor.electricBlue)
                .frame(width: 40, height: 40)
                .sbPremiumGlass(radius: 20, interactive: true)
        }
        .accessibilityLabel(settings.t("actions.station_tools"))
    }

    private var favoriteButton: some View {
        let stationKey = candidate.station.statusKey
        return Button {
            Haptic.tap()
            Task { await favorites.toggle(stationKey) }
        } label: {
            Image(systemName: favorites.isFavorite(stationKey) ? "heart.fill" : "heart")
                .font(.headline.weight(.bold))
                .foregroundStyle(favorites.isFavorite(stationKey) ? SBColor.danger : SBColor.electricBlue)
                .frame(width: 40, height: 40)
                .sbPremiumGlass(radius: 20, interactive: true)
        }
        .buttonStyle(SBPremiumButtonStyle())
        .accessibilityLabel(favorites.isFavorite(stationKey) ? settings.t("feed.favorite_remove") : settings.t("feed.favorite_add"))
    }

    private var routeButtons: some View {
        HStack(spacing: 8) {
            Text(settings.t("feed.open_route"))
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            routeMapButton(settings.t("feed.apple_maps_short"), icon: "apple.logo", action: openInAppleMaps)
            routeMapButton(settings.t("feed.google_maps_short"), icon: "map", action: openInGoogleMaps)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(SBColor.electricBlue)
        .clipShape(RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var statusActions: some View {
        HStack(spacing: 8) {
            reportButton(settings.t("actions.available"), status: "Uygun", icon: "checkmark.circle.fill")
            reportButton(settings.t("actions.issue_value"), status: "Sorun var", icon: "exclamationmark.triangle.fill")
            reportButton(settings.t("actions.queue_value"), status: "Sıra var", icon: "clock.fill")
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
            Task {
                if await stationData.reportStatus(
                    stationKey: candidate.station.statusKey,
                    status: status,
                    auth: auth
                ) {
                    await search.findStations()
                }
            }
        } label: {
            Label(title, systemImage: icon)
                .font(.caption.weight(.heavy))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .sbPremiumGlass(radius: 20, interactive: true)
        }
        .buttonStyle(SBPremiumButtonStyle())
        .disabled(!stationData.canReportStatus(for: candidate.station.statusKey))
        .opacity(stationData.canReportStatus(for: candidate.station.statusKey) ? 1 : 0.48)
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
        .frame(minHeight: 58)
        .sbPremiumGlass(radius: SBRadius.lg)
    }

    private func localizedBadgeTitle(_ badge: StationBadge) -> String {
        switch badge.kind {
        case .risk:
            settings.t("badge.risk")
        case .lastPositive:
            settings.t("badge.last_positive")
        case .noLiveData:
            settings.t("badge.no_live")
        case .arrivalSafe:
            settings.t("badge.arrival_safe")
        case .arrivalLow:
            settings.t("badge.arrival_low")
        case .fastDC:
            settings.t("badge.fast_dc")
        case .dc:
            settings.t("badge.dc")
        case .sources(let count):
            settings.t("badge.sources", ["count": "\(count)"])
        case .highConfidence:
            settings.t("badge.high_confidence")
        }
    }

    private var routeTaskID: String {
        guard let origin = search.userLocation else { return candidate.id }
        return "\(candidate.id)-\(origin.latitude)-\(origin.longitude)"
    }

    private var displayDistanceKm: Double {
        route?.distanceKm ?? candidate.distanceKm
    }

    private var displayMinutes: Int {
        route?.estimatedMinutes ?? candidate.estimatedMinutes
    }

    private var displayArrivalCharge: Double {
        settings.profile.arrivalChargePercent(distanceKm: displayDistanceKm)
    }

    private var displayDeviationKm: Double {
        max(0, displayDistanceKm - candidate.straightLineDistanceKm)
    }

    private func openInAppleMaps() {
        favorites.recordRouteOpened(candidate.station)
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(
            latitude: candidate.station.latitude,
            longitude: candidate.station.longitude
        )))
        destination.name = candidate.station.name
        destination.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    private func openInGoogleMaps() {
        favorites.recordRouteOpened(candidate.station)
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
        stationData.reportCooldownRemaining(for: candidate.station.statusKey)
    }

    private var effectivePrice: String {
        StationDataQuality.displayValue(
            sourceValue: candidate.station.price,
            field: .price,
            insight: candidate.communityInsight
        )
    }

    private var effectiveSocket: String {
        StationDataQuality.displayValue(
            sourceValue: candidate.station.socket,
            field: .socket,
            insight: candidate.communityInsight
        )
    }

    private var nightSafetyText: String {
        let fields: [(StationDataField, String)] = [
            (.lighting, settings.t("data_quality.lighting")),
            (.camera, settings.t("data_quality.camera")),
            (.open24Hours, settings.t("data_quality.open_24h"))
        ]
        let positives = fields.compactMap { field, title -> String? in
            guard candidate.communityInsight?.verification(for: field)?.verified == true,
                  ["yes", "evet", "true"].contains(
                    candidate.communityInsight?.verification(for: field)?.value.lowercased() ?? ""
                  ) else { return nil }
            return title
        }
        return positives.joined(separator: " · ")
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
