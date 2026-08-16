import MapKit
import SarjBulCore
import SwiftUI

struct StationCard: View {
    @Environment(UserSettingsStore.self) private var settings
    @Environment(SearchCoordinator.self) private var search
    @Environment(FavoritesStore.self) private var favorites
    @Environment(StationDataStore.self) private var stationData
    @Environment(ChargingSessionStore.self) private var chargingSession
    @Environment(NavigationCoordinator.self) private var navigation
    @Environment(RouteStore.self) private var routeStore
    @Environment(HabitStore.self) private var habits
    @Environment(FrictionTelemetryStore.self) private var frictionTelemetry
    var candidate: StationCandidate
    var rank: Int
    var total: Int

    @State private var route: StationRoute?
    @State private var fullMapPresented = false
    @State private var detailsPresented = false
    @State private var contributionPresented = false
    @State private var storyShareItem: StationStoryShareItem?
    @State private var isGeneratingStory = false
    @State private var storyErrorPresented = false
    @State private var navigationPickerPresented = false
    @ScaledMetric(relativeTo: .largeTitle) private var distanceTextSize = 54
    @ScaledMetric(relativeTo: .title) private var stationTitleSize = 25

    var body: some View {
        VStack(spacing: 0) {
            mapHero
            zeroUIDetails
        }
        .background(SBColor.surfaceSolid)
        .clipShape(RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous)
                .stroke(SBColor.line, lineWidth: 1)
        )
        .sbCardShadow()
        .accessibilityIdentifier("station-route-card")
        .task(id: routeTaskID) {
            guard let origin = search.userLocation else { return }
            route = await routeStore.route(origin: origin, station: candidate.station)
        }
        .sheet(isPresented: $fullMapPresented) {
            FullRouteMapView(candidate: candidate, route: route)
                .environment(settings)
                .environment(search)
        }
        .sheet(isPresented: $detailsPresented) {
            detailsSheet
        }
        .sheet(isPresented: $contributionPresented) {
            StationContributionSheet(candidate: candidate)
                .environment(settings)
                .environment(stationData)
        }
        .sheet(item: $storyShareItem) { item in
            StationStoryPreviewSheet(item: item)
                .environment(settings)
        }
        .alert(settings.t("story.error"), isPresented: $storyErrorPresented) {
            Button(settings.t("status.ok"), role: .cancel) {}
        }
        .onAppear { habits.recordImpression(candidate) }
        .onDisappear { habits.recordIgnored(candidate) }
    }

    private var mapHero: some View {
        StationMapPreview(
            station: candidate.station,
            origin: search.userLocation,
            route: route
        )
        .frame(height: 236)
        .clipped()
        .preferredColorScheme(.dark)
        .overlay(alignment: .top) {
            HStack(alignment: .top) {
                Text("\(rank) / \(total)")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(SBColor.ink)
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .sbPremiumGlass(radius: 21)

                Spacer(minLength: 12)
                actionsMenu
            }
            .padding(14)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Haptic.tap()
            habits.recordInteraction(candidate, signal: .mapExpanded)
            fullMapPresented = true
        }
        .accessibilityLabel(settings.t("feed.expand_map"))
        .accessibilityAddTraits(.isButton)
    }

    private var zeroUIDetails: some View {
        VStack(alignment: .leading, spacing: 18) {
            stationIdentity
            journeyDecision
            primaryRouteAction
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 18)
    }

    private var stationIdentity: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(rank == 1 ? settings.t("feed.best_match") : settings.t("feed.nearby_option"))
                .font(.caption.weight(.heavy))
                .foregroundStyle(SBColor.electricBlue)

            Text(candidate.station.name)
                .font(SBFont.display(size: min(stationTitleSize, 32), weight: .heavy))
                .foregroundStyle(SBColor.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            HStack(spacing: 6) {
                Text(candidate.station.operatorName)
                if hasUsefulAddress {
                    Text("·")
                    Text(candidate.station.address)
                        .lineLimit(1)
                }
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(SBColor.textSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var journeyDecision: some View {
        let summary = decisionSummaryValue
        return HStack(alignment: .bottom, spacing: 16) {
            Text(String(format: "%.1f km", displayDistanceKm))
                .font(SBFont.display(size: min(distanceTextSize, 64), weight: .heavy))
                .foregroundStyle(SBColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.66)

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 6) {
                Text("\(displayMinutes) \(settings.t("feed.minute"))")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(SBColor.ink)

                HStack(spacing: 7) {
                    Circle()
                        .fill(availabilityColor(summary.availability))
                        .frame(width: 7, height: 7)
                    Text("%\(summary.arrivalChargePercent) · \(availabilityText(summary.availability))")
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .font(.caption.weight(.heavy))
                .foregroundStyle(SBColor.textSoft)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var primaryRouteAction: some View {
        HStack(spacing: 0) {
            Button {
                Haptic.tap()
                startPreferredNavigation()
            } label: {
                HStack(spacing: 10) {
                    Text(settings.t("feed.start_route"))
                        .font(.headline.weight(.heavy))
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.right")
                        .font(.headline.weight(.heavy))
                }
                .foregroundStyle(SBColor.onSignal)
                .padding(.leading, 18)
                .padding(.trailing, 14)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
            }
            .buttonStyle(SBPremiumButtonStyle())
            .accessibilityIdentifier("station-primary-route-button")
            .confirmationDialog(
                settings.t("feed.choose_navigation"),
                isPresented: $navigationPickerPresented,
                titleVisibility: .visible
            ) {
                navigationButton(.appleMaps)
                navigationButton(.googleMaps)
                Button(settings.t("status.cancel"), role: .cancel) {}
            } message: {
                Text(settings.t("feed.choose_navigation_hint"))
            }

            Rectangle()
                .fill(.black.opacity(0.14))
                .frame(width: 1, height: 30)

            Menu {
                navigationButton(.appleMaps)
                navigationButton(.googleMaps)
            } label: {
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(SBColor.onSignal)
                    .frame(width: 54, height: 58)
            }
            .accessibilityLabel(settings.t("feed.route_options"))
        }
        .background(SBColor.signal)
        .clipShape(RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous))
        .sbGlowShadow()
    }

    private var actionsMenu: some View {
        Menu {
            Button {
                habits.recordInteraction(candidate, signal: .detailsOpened)
                detailsPresented = true
            } label: {
                Label(settings.t("feed.more_details"), systemImage: "info.circle")
            }

            Button {
                if !favorites.isFavorite(candidate.station.statusKey) {
                    habits.recordInteraction(candidate, signal: .favoriteAdded)
                }
                Task { await favorites.toggle(candidate.station.statusKey) }
            } label: {
                Label(
                    favorites.isFavorite(candidate.station.statusKey)
                        ? settings.t("feed.favorite_remove")
                        : settings.t("feed.favorite_add"),
                    systemImage: favorites.isFavorite(candidate.station.statusKey) ? "heart.slash" : "heart"
                )
            }

            Button {
                habits.recordInteraction(candidate, signal: .shared)
                Task { await createStoryShare() }
            } label: {
                Label(settings.t("feed.share"), systemImage: "square.and.arrow.up")
                    .accessibilityIdentifier("station-story-share-button")
            }
            .disabled(isGeneratingStory)

            Button {
                habits.recordInteraction(candidate, signal: .mapExpanded)
                fullMapPresented = true
            } label: {
                Label(settings.t("feed.expand_map"), systemImage: "arrow.up.left.and.arrow.down.right")
            }

            Divider()

            Menu(settings.t("feed.report_status"), systemImage: "waveform.path.ecg") {
                reportMenuButton(settings.t("actions.available"), status: "Uygun", icon: "checkmark.circle")
                reportMenuButton(
                    settings.t("actions.issue_value"),
                    status: "Sorun var",
                    icon: "exclamationmark.triangle"
                )
                reportMenuButton(settings.t("actions.queue_value"), status: "Sıra var", icon: "clock")
            }

            Button {
                navigation.select(.lounge)
                Task {
                    await chargingSession.start(
                        station: candidate.station,
                        initialPercent: settings.profile.chargePercent,
                        languageCode: settings.language.rawValue
                    )
                }
            } label: {
                Label(settings.t("break.start"), systemImage: "cup.and.saucer")
            }

            Button {
                contributionPresented = true
            } label: {
                Label(settings.t("data_quality.improve"), systemImage: "checkmark.seal")
            }
        } label: {
            Group {
                if isGeneratingStory {
                    ProgressView()
                        .tint(SBColor.ink)
                } else {
                    Image(systemName: "ellipsis")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(SBColor.ink)
                }
            }
            .frame(width: 44, height: 44)
            .sbPremiumGlass(radius: 22, interactive: true)
            .accessibilityIdentifier("station-actions-menu")
        }
        .accessibilityLabel(settings.t("actions.station_tools"))
    }

    private var detailsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    stationIdentity
                    detailedDecisionSummary

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                        spacing: 8
                    ) {
                        metric(settings.t("feed.power"), candidate.station.power)
                        metric(settings.t("feed.socket"), effectiveSocket)
                        metric(settings.t("feed.price"), effectivePrice)
                    }

                    stationIntelligence
                    statusActions

                    if reportCooldownRemaining > 0 {
                        Text(settings.t(
                            "service.report_cooldown",
                            ["seconds": "\(reportCooldownRemaining)"]
                        ))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SBColor.textSoft)
                    }
                }
                .padding(20)
            }
            .background(SBScreenBackground())
            .navigationTitle(settings.t("feed.more_details"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(settings.t("status.ok")) { detailsPresented = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var detailedDecisionSummary: some View {
        let summary = decisionSummaryValue
        return HStack(spacing: 0) {
            decisionMetric(
                title: settings.t("decision.arrival"),
                value: "%\(summary.arrivalChargePercent)",
                icon: "battery.50percent"
            )
            decisionDivider
            decisionMetric(
                title: settings.t("decision.availability"),
                value: availabilityText(summary.availability),
                icon: availabilityIcon(summary.availability)
            )
            decisionDivider
            decisionMetric(
                title: settings.t("decision.charge_target", ["percent": "\(summary.targetChargePercent)"]),
                value: summary.chargeToTargetMinutes.map {
                    settings.t("decision.minutes", ["minutes": "\($0)"])
                } ?? settings.t("decision.unknown"),
                icon: "bolt.fill"
            )
        }
        .padding(.vertical, 14)
        .background(SBColor.surface.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func decisionMetric(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.heavy))
                .foregroundStyle(SBColor.electricBlue)
            Text(value)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(SBColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(SBColor.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var decisionDivider: some View {
        Rectangle()
            .fill(SBColor.line)
            .frame(width: 1, height: 54)
    }

    private var stationIntelligence: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let availability = candidate.liveAvailability {
                Label(
                    settings.t("insight.live_availability", [
                        "available": "\(availability.availableConnectors)",
                        "total": "\(availability.totalConnectors)"
                    ]),
                    systemImage: availability.availableConnectors > 0
                        ? "bolt.circle.fill"
                        : "clock.badge.exclamationmark"
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

            Label(
                settings.t("insight.data_confidence", [
                    "percent": "\(Int((candidate.station.confidenceScore * 100).rounded()))"
                ]),
                systemImage: "checkmark.shield"
            )
            .foregroundStyle(SBColor.textSoft)

            if !nightSafetyText.isEmpty {
                Label(nightSafetyText, systemImage: "moon.stars.fill")
                    .foregroundStyle(SBColor.electricBlue)
            }
        }
        .font(.caption.weight(.heavy))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusActions: some View {
        HStack(spacing: 8) {
            reportButton(settings.t("actions.available"), status: "Uygun", icon: "checkmark.circle.fill")
            reportButton(
                settings.t("actions.issue_value"),
                status: "Sorun var",
                icon: "exclamationmark.triangle.fill"
            )
            reportButton(settings.t("actions.queue_value"), status: "Sıra var", icon: "clock.fill")
        }
    }

    private func reportMenuButton(_ title: String, status: String, icon: String) -> some View {
        Button {
            Task {
                _ = await stationData.reportStatus(
                    stationKey: candidate.station.statusKey,
                    status: status
                )
            }
        } label: {
            Label(title, systemImage: icon)
        }
        .disabled(!stationData.canReportStatus(for: candidate.station.statusKey))
    }

    private func reportButton(_ title: String, status: String, icon: String) -> some View {
        Button {
            Haptic.tap()
            Task {
                _ = await stationData.reportStatus(
                    stationKey: candidate.station.statusKey,
                    status: status
                )
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

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(SBColor.muted)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(SBColor.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.76)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .frame(minHeight: 62)
        .background(SBColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous))
    }

    private var decisionSummaryValue: StationDecisionSummary {
        StationDecisionEngine.summarize(candidate: decisionCandidate, profile: settings.profile)
    }

    private var decisionCandidate: StationCandidate {
        var value = candidate
        value.arrivalChargePercent = displayArrivalCharge
        return value
    }

    private func availabilityText(_ availability: StationDecisionSummary.Availability) -> String {
        switch availability {
        case .risky:
            settings.t("decision.risky")
        case .live(let available, let total):
            settings.t("decision.live_count", ["available": "\(available)", "total": "\(total)"])
        case .predictedBusy(let percent):
            settings.t("decision.busy", ["percent": "\(percent)"])
        case .predictedAvailable(let percent):
            settings.t("decision.available", ["percent": "\(percent)"])
        case .unknown:
            settings.t("decision.unknown")
        }
    }

    private func availabilityIcon(_ availability: StationDecisionSummary.Availability) -> String {
        switch availability {
        case .risky: "exclamationmark.triangle.fill"
        case .live(let available, _): available > 0 ? "bolt.circle.fill" : "clock.fill"
        case .predictedBusy: "clock.fill"
        case .predictedAvailable: "checkmark.circle.fill"
        case .unknown: "questionmark.circle"
        }
    }

    private func availabilityColor(_ availability: StationDecisionSummary.Availability) -> Color {
        switch availability {
        case .risky, .predictedBusy:
            SBColor.warning
        case .live(let available, _):
            available > 0 ? SBColor.electricBlue : SBColor.warning
        case .predictedAvailable:
            SBColor.electricBlue
        case .unknown:
            SBColor.muted
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

    private func startPreferredNavigation() {
        if settings.navigationAppPreference == nil {
            frictionTelemetry.navigationChoicePresented()
            navigationPickerPresented = true
        } else {
            search.startNavigation(to: candidate)
        }
    }

    private func navigationButton(_ preference: NavigationAppPreference) -> some View {
        let isApple = preference == .appleMaps
        return Button {
            search.startNavigation(to: candidate, using: preference)
        } label: {
            Label(
                settings.t(isApple ? "feed.apple_maps" : "feed.google_maps"),
                systemImage: isApple ? "apple.logo" : "map"
            )
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

    @MainActor
    private func createStoryShare() async {
        guard !isGeneratingStory else { return }
        isGeneratingStory = true
        defer { isGeneratingStory = false }

        let content = StationStoryContent(
            coordinate: CLLocationCoordinate2D(
                latitude: candidate.station.latitude,
                longitude: candidate.station.longitude
            ),
            headline: settings.t("story.headline"),
            stationLabel: settings.t("feed.detail_card"),
            stationName: candidate.station.name,
            operatorName: candidate.station.operatorName,
            distanceText: String(format: "%.1f km", displayDistanceKm),
            arrivalText: "\(settings.t("feed.arrival")) %\(Int(displayArrivalCharge.rounded()))",
            scoreText: "\(candidate.score) \(settings.t("feed.score"))",
            footer: settings.t("story.footer")
        )

        do {
            let image = try await StationStoryRenderer.render(content)
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-testing-story"),
               let data = image.pngData() {
                let outputURL = FileManager.default.temporaryDirectory.appending(path: "station-story.png")
                try? data.write(to: outputURL)
            }
            #endif
            storyShareItem = StationStoryShareItem(image: image, title: candidate.station.name)
        } catch {
            storyErrorPresented = true
        }
    }

    private var hasUsefulAddress: Bool {
        let normalized = candidate.station.address
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "tr_TR"))
        return !normalized.isEmpty
            && !normalized.contains("adres bilgisi yok")
            && !normalized.contains("unknown")
    }
}
