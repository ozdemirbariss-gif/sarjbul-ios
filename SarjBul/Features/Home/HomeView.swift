import CoreLocation
import SarjBulCore
import SwiftUI

struct HomeView: View {
    @Environment(UserSettingsStore.self) private var settings
    @Environment(SearchCoordinator.self) private var search
    @Environment(NavigationCoordinator.self) private var navigation
    @Environment(HabitStore.self) private var habits
    @Environment(AutonomousChargingAgentStore.self) private var autonomousAgent
    @Environment(ChargingSessionStore.self) private var chargingSession
    @Environment(ContextIntelligenceStore.self) private var contextIntelligence
    @Environment(ExecutionTrustStore.self) private var executionTrust
    @Environment(FrictionTelemetryStore.self) private var frictionTelemetry
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var locationManager: LocationManager
    @State private var manualLatitude = 38.3939
    @State private var manualLongitude = 27.1891
    @State private var selectedPreset: ManualLocationPreset?
    @State private var didRequestDeviceLocation = false
    @State private var locationRequestTimedOut = false
    @State private var drivingProfileExpanded = false
    @State private var settingsExpanded = false
    @State private var advancedHomeExpanded = false
    @State private var placeSearchMode: PlaceSearchMode?
    @State private var intentPrediction: SearchIntentPrediction?
    @State private var filtersBeforePrediction: StationFilters?
    @State private var didEvaluateIntentPrediction = false
    @State private var navigationPickerPresented = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                SBScreenBackground()

                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            if search.userLocation?.source != .device || search.locationNeedsReview {
                                locationInput
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                            primaryOutcome
                            advancedHomeControls
                            if advancedHomeExpanded {
                                topControls
                                drivingProfile
                                    .id("driving-profile")
                                filtersAndSettings
                                    .id("filters-and-settings")
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 22)
                        .padding(.bottom, 150)
                        .frame(maxWidth: 720)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: drivingProfileExpanded) { _, expanded in
                        guard expanded else { return }
                        settingsExpanded = false
                        scrollExpandedPanel("driving-profile", using: scrollProxy)
                    }
                    .onChange(of: settingsExpanded) { _, expanded in
                        guard expanded else { return }
                        drivingProfileExpanded = false
                        scrollExpandedPanel("filters-and-settings", using: scrollProxy)
                    }
                }
                .sensoryFeedback(.selection, trigger: settings.filters.preference)
            }
            .animation(.easeInOut(duration: 0.24), value: search.userLocation?.source)
            .accessibilityIdentifier("home-screen")
            .sbInlineNavigationTitle()
            .onReceive(locationManager.$lastLocation.compactMap { $0 }) { location in
                guard !isDeterministicUITest else { return }
                applyLocation(location)
                Task {
                    await contextIntelligence.evaluate(
                        location: location,
                        movementSpeedMetersPerSecond: locationManager.movementSpeedMetersPerSecond
                    )
                }
            }
            .onAppear {
                settings.destination = nil
                applyIntentPrefillIfEligible()
                syncWidgetContext()
                if search.userLocation != nil {
                    frictionTelemetry.record(.locationReady)
                    Task { await search.prepareOutcome() }
                }
                guard !isDeterministicUITest else { return }
                guard !didRequestDeviceLocation, search.userLocation == nil else { return }
                requestDeviceLocation()
            }
            .onChange(of: settings.profile.chargePercent) { _, _ in syncWidgetContext() }
            .onChange(of: chargingSession.isActive) { _, _ in syncWidgetContext() }
            .onChange(of: locationManager.authorizationStatus) { _, status in
                if status == .denied || status == .restricted {
                    frictionTelemetry.record(.locationPermissionDenied)
                }
            }
            .sheet(item: $placeSearchMode) { mode in
                PlaceSearchSheet(mode: mode) { place in
                    switch mode {
                    case .origin:
                        applyLocation(UserLocation(
                            latitude: place.latitude,
                            longitude: place.longitude,
                            source: .manual
                        ))
                    case .destination:
                        settings.destination = place
                    }
                }
                .environment(settings)
            }
        }
    }

    private var topControls: some View {
        HStack(spacing: 10) {
            preferenceButton(.nearest, icon: "location.north.line")
            preferenceButton(.fastest, icon: "bolt.fill")
            preferenceButton(.economical, icon: "fuelpump")
        }
        .padding(6)
        .background(SBColor.surfaceRaised, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(SBColor.divider, lineWidth: 1)
        )
        .sbCardShadow()
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("home-preference-card")
    }

    @ViewBuilder
    private var primaryOutcome: some View {
        if chargingSession.isActive {
            activeChargingContextCard
        } else if let journey = frictionTelemetry.activeJourney, journey.arrivedAt != nil {
            ArrivedAtStationCard(journey: journey)
        } else if let proposal = autonomousAgent.proposal {
            autonomousProposalCard(proposal)
        } else if settings.profile.chargePercent <= 20 {
            criticalRangeContextCard
        } else {
            VStack(spacing: 14) {
                routeAction
                if let recommendation = contextIntelligence.recommendation {
                    contextRecommendationCard(recommendation)
                } else if contextIntelligence.recentAutomaticReport != nil {
                    contextAutomationReportCard
                } else if let suggestion = habits.suggestion() {
                    habitSuggestionCard(suggestion)
                }
            }
        }
    }

    private var advancedHomeControls: some View {
        Button {
            Haptic.tap()
            withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                advancedHomeExpanded.toggle()
                if !advancedHomeExpanded {
                    drivingProfileExpanded = false
                    settingsExpanded = false
                    Task { await search.prepareOutcome() }
                }
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "slider.horizontal.3")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(SBColor.actionPrimary)
                    .frame(width: 42, height: 42)
                    .background(SBColor.actionPrimary.opacity(0.10), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(settings.t("home.fine_tune"))
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(SBColor.contentPrimary)
                    Text(preferenceTitle(settings.filters.preference))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SBColor.contentSecondary)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(SBColor.actionPrimary)
                    .rotationEffect(.degrees(advancedHomeExpanded ? 180 : 0))
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 64)
            .background(SBColor.surfaceBase, in: RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous)
                    .stroke(SBColor.divider, lineWidth: 1)
            )
        }
        .buttonStyle(SBPremiumButtonStyle())
        .accessibilityIdentifier("home-fine-tune-toggle")
    }

    private var activeChargingContextCard: some View {
        Button {
            Haptic.tap()
            navigation.select(.lounge)
        } label: {
            contextualStatusCard(
                icon: "bolt.fill",
                kicker: settings.t("context.charging_kicker"),
                title: chargingSession.station?.name ?? settings.t("context.charging_title"),
                detail: settings.t("context.charging_target", [
                    "percent": "\(chargingSession.targetPercent)"
                ]),
                tint: SBColor.surfaceInverted
            ) {
                if let endDate = chargingSession.endDate {
                    Text(timerInterval: Date()...max(Date(), endDate), countsDown: true)
                        .font(.headline.monospacedDigit().weight(.heavy))
                        .foregroundStyle(SBColor.contentPrimary)
                }
            }
        }
        .buttonStyle(SBPremiumButtonStyle())
        .accessibilityIdentifier("active-charging-context-card")
    }

    private var criticalRangeContextCard: some View {
        Button {
            Haptic.tap()
            if search.userLocation == nil {
                requestDeviceLocation()
            } else {
                Task { await search.findStations() }
            }
        } label: {
            contextualStatusCard(
                icon: "battery.25percent",
                kicker: settings.t("context.critical_kicker"),
                title: settings.t("context.critical_title", [
                    "percent": "\(settings.profile.chargePercent)"
                ]),
                detail: settings.t("context.critical_detail", ["range": "\(safeRangeKm)"]),
                tint: SBColor.danger
            ) {
                Image(systemName: "arrow.right")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(SBColor.contentPrimary)
            }
        }
        .buttonStyle(SBPremiumButtonStyle())
        .accessibilityIdentifier("critical-range-context-card")
    }

    private func contextRecommendationCard(_ recommendation: ContextRecommendation) -> some View {
        HStack(spacing: 16) {
            Image(systemName: recommendation.elevatedPhysiologicalLoad ? "heart.text.square.fill" : "cloud.rain.fill")
                .font(.title2.weight(.heavy))
                .foregroundStyle(SBColor.onActionPrimary)
                .frame(width: 56, height: 56)
                .background(SBColor.actionPrimary, in: RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(settings.language.uppercased(settings.t("context.smart_kicker")))
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(SBColor.actionPrimary)
                Text(contextRecommendationTitle(recommendation))
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(SBColor.contentPrimary)
                    .lineLimit(2)
                Text(settings.t("context.health_disclaimer"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(SBColor.contentSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 6)

            VStack(spacing: 8) {
                Button {
                    Task { await contextIntelligence.acceptRecommendation() }
                } label: {
                    Image(systemName: recommendation.action == .suggestRecoveryPause ? "checkmark" : "clock.arrow.circlepath")
                        .frame(width: 38, height: 38)
                        .background(SBColor.actionPrimary, in: Circle())
                        .foregroundStyle(SBColor.onActionPrimary)
                }
                .buttonStyle(SBPremiumButtonStyle())
                .accessibilityLabel(settings.t("context.accept"))

                Button {
                    contextIntelligence.dismissRecommendation()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.heavy))
                        .frame(width: 32, height: 32)
                }
                .foregroundStyle(SBColor.contentSecondary)
                .accessibilityLabel(settings.t("context.dismiss"))
            }
        }
        .padding(18)
        .background(SBColor.actionPrimary.opacity(0.08), in: RoundedRectangle(cornerRadius: SBRadius.xl, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: SBRadius.xl).stroke(SBColor.actionPrimary.opacity(0.36)))
    }

    private func contextRecommendationTitle(_ recommendation: ContextRecommendation) -> String {
        switch recommendation.action {
        case .offerCalendarDeferral:
            settings.t("context.defer_offer")
        case .automaticallyDeferCalendar:
            settings.t("context.defer_completed")
        case .suggestRecoveryPause:
            settings.t("context.recovery_offer")
        }
    }

    private var contextAutomationReportCard: some View {
        contextualStatusCard(
            icon: "checkmark",
            kicker: settings.t("context.completed_kicker"),
            title: settings.t("context.defer_completed"),
            detail: settings.t("context.completed_detail"),
            tint: SBColor.actionPrimary
        ) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.headline.weight(.heavy))
                .foregroundStyle(SBColor.actionPrimary)
        }
    }

    private func contextualStatusCard<Trailing: View>(
        icon: String,
        kicker: String,
        title: String,
        detail: String,
        tint: Color,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2.weight(.heavy))
                .foregroundStyle(SBColor.onActionPrimary)
                .frame(width: 56, height: 56)
                .background(tint, in: RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(settings.language.uppercased(kicker))
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(SBColor.contentPrimary)
                    .lineLimit(2)
                Text(detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SBColor.contentSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: SBRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SBRadius.xl, style: .continuous)
                .stroke(tint.opacity(0.42), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: SBRadius.xl, style: .continuous))
    }

    private func syncWidgetContext() {
        guard !chargingSession.isActive else { return }
        guard settings.profile.chargePercent <= 20 else {
            WidgetContextSnapshotStore.clear(kind: .criticalRange)
            return
        }
        WidgetContextSnapshotStore.save(WidgetContextSnapshot(
            kind: .criticalRange,
            title: settings.t("context.critical_kicker"),
            subtitle: settings.t("context.critical_title", [
                "percent": "\(settings.profile.chargePercent)"
            ]),
            value: "\(safeRangeKm) km",
            icon: "battery.25percent",
            deepLink: "sarjbul://quick/fast",
            updatedAt: Date(),
            endDate: nil
        ))
    }

    private func habitSuggestionCard(_ suggestion: HabitSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(SBColor.onActionPrimary)
                    .frame(width: 42, height: 42)
                    .background(SBColor.actionPrimary, in: Circle())

                Text(settings.language.uppercased(settings.t("habit.kicker")))
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(SBColor.actionPrimary)

                Spacer()

                Button {
                    Haptic.tap()
                    habits.dismiss(suggestion)
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(SBColor.contentSecondary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(SBPremiumButtonStyle())
                .accessibilityLabel(settings.t("habit.dismiss"))
            }

            Text(habitSuggestionText(suggestion))
                .font(.title3.weight(.heavy))
                .foregroundStyle(SBColor.contentPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(settings.t("habit.local_note"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(SBColor.contentSecondary)

            Button {
                applyHabitSuggestion(suggestion)
            } label: {
                HStack {
                    Text(habitActionTitle(suggestion))
                        .font(.subheadline.weight(.heavy))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.heavy))
                }
                .foregroundStyle(SBColor.onActionPrimary)
                .padding(.horizontal, 18)
                .frame(height: 52)
                .background(SBColor.actionPrimary, in: RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous))
            }
            .buttonStyle(SBPremiumButtonStyle())
        }
        .padding(20)
        .background(SBColor.surfaceBase, in: RoundedRectangle(cornerRadius: SBRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SBRadius.xl, style: .continuous)
                .stroke(SBColor.actionPrimary.opacity(0.5), lineWidth: 1)
        )
        .sbGlowShadow()
        .accessibilityIdentifier("habit-suggestion-card")
    }

    private func autonomousProposalCard(_ proposal: AutonomousChargingProposal) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "bolt.car.fill")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(SBColor.onActionPrimary)
                    .frame(width: 44, height: 44)
                    .background(SBColor.actionPrimary, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(settings.t("agent.ready_kicker"))
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(SBColor.actionPrimary)
                    Text(settings.t("agent.ready_title"))
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(SBColor.contentPrimary)
                        .lineLimit(2)
                }
                Spacer()
                Button {
                    autonomousAgent.dismissProposal()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(SBColor.contentTertiary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(SBPremiumButtonStyle())
                .accessibilityLabel(settings.t("agent.dismiss"))
            }

            Text(proposal.stationName)
                .font(.title3.weight(.heavy))
                .foregroundStyle(SBColor.contentPrimary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                agentMetric("\(proposal.distanceKm.formatted(.number.precision(.fractionLength(1)))) km")
                agentMetric(settings.t("agent.minutes", ["minutes": "\(proposal.estimatedMinutes)"]))
                agentMetric(settings.t("agent.arrival", ["percent": "\(proposal.arrivalChargePercent)"]))
            }

            Text(settings.t(
                proposal.telemetrySource == .manualProfile ? "agent.source_profile" : "agent.source_vehicle"
            ))
            .font(.caption.weight(.semibold))
            .foregroundStyle(SBColor.contentTertiary)

            if let report = autonomousAgent.latestReport,
               report.selectedStationName == proposal.stationName {
                Text(automationReportText(report))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(SBColor.contentPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(SBColor.surfaceBase, in: RoundedRectangle(
                        cornerRadius: SBRadius.sm,
                        style: .continuous
                    ))
            }

            Button {
                Haptic.tap()
                Task { await autonomousAgent.acceptProposal() }
            } label: {
                HStack {
                    Text(settings.t("agent.open_route"))
                        .font(.headline.weight(.heavy))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.headline.weight(.heavy))
                }
                .foregroundStyle(SBColor.onActionPrimary)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 56)
                .background(SBColor.actionPrimary, in: RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous))
            }
            .buttonStyle(SBPremiumButtonStyle())
        }
        .padding(22)
        .background(SBColor.surfaceRaised, in: RoundedRectangle(cornerRadius: SBRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SBRadius.xl, style: .continuous)
                .stroke(SBColor.actionPrimary.opacity(0.6), lineWidth: 1)
        )
        .sbGlowShadow()
        .accessibilityIdentifier("autonomous-proposal-card")
    }

    private func automationReportText(_ report: AutomationReport) -> String {
        switch report.rule {
        case .preparedRouteRisky:
            settings.t("agent.report_risky", ["station": report.selectedStationName ?? ""])
        case .preparedRouteExpired:
            settings.t("agent.report_expired", ["station": report.selectedStationName ?? ""])
        case .stationDataStale:
            settings.t("agent.report_refreshed", ["station": report.selectedStationName ?? ""])
        case .lowCharge:
            settings.t("agent.report_low_charge", ["station": report.selectedStationName ?? ""])
        }
    }

    private func agentMetric(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.heavy))
            .foregroundStyle(SBColor.contentPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 34)
            .background(SBColor.surfaceBase, in: Capsule())
    }

    private func habitSuggestionText(_ suggestion: HabitSuggestion) -> String {
        switch suggestion {
        case .repeatedStation(_, let stationName, let period):
            settings.t("habit.station_message", [
                "period": habitPeriodTitle(period),
                "station": stationName
            ])
        case .routePreference(let preference, let period):
            settings.t("habit.preference_message", [
                "period": habitPeriodTitle(period),
                "preference": preferenceTitle(preference).lowercased(with: habitLocale)
            ])
        }
    }

    private func habitActionTitle(_ suggestion: HabitSuggestion) -> String {
        switch suggestion {
        case .repeatedStation: settings.t("habit.open_route")
        case .routePreference: settings.t("habit.apply")
        }
    }

    private func habitPeriodTitle(_ period: HabitDayPeriod) -> String {
        settings.t("habit.period_\(period.rawValue)")
    }

    private var habitLocale: Locale {
        Locale(identifier: settings.language == .tr ? "tr_TR" : "en_US")
    }

    private func applyHabitSuggestion(_ suggestion: HabitSuggestion) {
        Haptic.tap()
        switch suggestion {
        case .repeatedStation(let stationKey, _, _):
            Task { await search.openStation(withKey: stationKey) }
        case .routePreference(let preference, _):
            settings.filters.preference = preference
            Task { await search.prepareOutcome() }
            Task { await search.findStations() }
        }
    }

    private func preferenceButton(_ preference: RoutePreference, icon: String) -> some View {
        Button {
            Haptic.tap()
            intentPrediction = nil
            filtersBeforePrediction = nil
            settings.filters.preference = preference
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.headline.weight(.heavy))
                    .symbolEffect(.bounce, value: settings.filters.preference == preference)
                Text(preferenceTitle(preference))
                    .font(.caption.weight(.heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(QuickActionStyle(active: settings.filters.preference == preference))
    }

    private var locationInput: some View {
        VStack(alignment: .leading, spacing: search.locationNeedsReview ? 8 : 0) {
            if search.locationNeedsReview {
                Label(settings.t("route.location_review"), systemImage: "location.magnifyingglass")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(SBColor.contentTertiary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .accessibilityIdentifier("location-review-message")
            }
            originJourneyButton
        }
        .padding(8)
        .background(SBColor.surfaceBase, in: RoundedRectangle(cornerRadius: SBRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SBRadius.xl, style: .continuous)
                .stroke(SBColor.divider, lineWidth: 1)
        )
        .sbSoftShadow()
        .accessibilityIdentifier("location-input")
    }

    private var originJourneyButton: some View {
        journeyButton(
                title: search.userLocation?.source == .device
                    ? settings.t("place.my_location")
                    : settings.t("place.choose_origin"),
                subtitle: search.userLocation == nil ? settings.t("place.not_selected") : locationLabel,
                icon: "location.fill"
            ) {
                placeSearchMode = .origin
            }
    }

    private func journeyButton(
        title: String,
        subtitle: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptic.tap()
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(SBColor.onActionPrimary)
                    .frame(width: 38, height: 38)
                    .background(SBColor.actionPrimary)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(SBColor.contentPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(SBColor.contentTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .contentShape(RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous))
        }
        .buttonStyle(SBPremiumButtonStyle())
    }

    @ViewBuilder
    private var locationSection: some View {
        if search.userLocation?.source != .device {
            SBPanel {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "scope")
                            .font(.title2)
                            .foregroundStyle(SBColor.onActionPrimary)
                            .frame(width: 52, height: 52)
                            .background(SBColor.actionPrimary)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(settings.t("home.search_title"))
                                .font(.title3.weight(.bold))
                            Text(locationLabel)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(SBColor.contentTertiary)
                        }
                        Spacer()
                    }

                    SBPrimaryButton(title: settings.t("home.use_location"), systemImage: "location.fill") {
                        Haptic.tap()
                        requestDeviceLocation()
                    }

                    if manualLocationEntryVisible {
                        manualLocationForm
                        if locationManager.authorizationStatus == .denied {
                            Button {
                                guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                                openURL(settingsURL)
                            } label: {
                                Label(settings.t("home.open_settings"), systemImage: "gear")
                                    .font(.subheadline.weight(.bold))
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        Text(locationWaitingText)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(SBColor.contentTertiary)
                    }
                }
            }
        }
    }

    private var locationLabel: String {
        guard let location = search.userLocation else { return settings.t("home.location_selected") }
        return String(format: "%.4f, %.4f", location.latitude, location.longitude)
    }

    private var drivingProfile: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                Haptic.tap()
                withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                    drivingProfileExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Text(settings.language.uppercased(settings.t("catalog.kicker")))
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(SBColor.actionPrimary)

                    Spacer(minLength: 12)

                    Text("%\(settings.profile.chargePercent) · \(safeRangeKm) km")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(SBColor.contentSecondary)
                        .lineLimit(1)

                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(SBColor.actionPrimary)
                        .rotationEffect(.degrees(drivingProfileExpanded ? 180 : 0))
                }
                .padding(.horizontal, 18)
                .frame(height: 60)
                .background(SBColor.surfaceBase, in: RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous)
                        .stroke(SBColor.divider, lineWidth: 1)
                )
            }
            .buttonStyle(SBPremiumButtonStyle())
            .accessibilityIdentifier("driving-profile-toggle")

            if drivingProfileExpanded {
                SBPanel {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(settings.t("catalog.charge_percent"))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(SBColor.contentTertiary)
                            Spacer()
                            Text("\(settings.profile.chargePercent)")
                                .font(.title2.weight(.heavy))
                                .foregroundStyle(SBColor.contentTertiary)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(settings.profile.chargePercent) },
                                set: { settings.profile.chargePercent = Int($0.rounded()) }
                            ),
                            in: 1...100,
                            step: 1
                        )
                        .tint(SBColor.actionPrimary)
                    }

                    ChargeVisual(
                        percent: settings.profile.chargePercent,
                        statusText: chargeStatusText,
                        chargeLabel: settings.t("charge.label"),
                        selectedLevelText: settings.t("charge.selected_level")
                    )

                    Divider().overlay(SBColor.divider)

                    HStack(alignment: .top, spacing: 12) {
                        MetricInput(
                            title: settings.t("catalog.capacity"),
                            unit: "kWh",
                            value: Binding(
                                get: { settings.profile.batteryKWh },
                                set: { settings.profile.batteryKWh = $0 }
                            ),
                            range: 1...250,
                            step: 1,
                            accessibilityIdentifier: "battery-capacity-input"
                        )
                        MetricInput(
                            title: settings.t("catalog.consumption"),
                            unit: "kWh",
                            value: Binding(
                                get: { settings.profile.consumptionKWhPer100Km },
                                set: { settings.profile.consumptionKWhPer100Km = $0 }
                            ),
                            range: 5...40,
                            step: 0.1,
                            accessibilityIdentifier: "average-consumption-input"
                        )
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var filtersAndSettings: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                Haptic.tap()
                withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                    settingsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Text(settings.t("filters.title"))
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(SBColor.contentTertiary)
                    Spacer(minLength: 12)
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(SBColor.actionPrimary)
                        .rotationEffect(.degrees(settingsExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(SBPremiumButtonStyle())
            .accessibilityIdentifier("filters-and-settings-toggle")

            if settingsExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    locationSection
                    Toggle(settings.t("filters.range"), isOn: Binding(
                        get: { settings.filters.rangeFilterEnabled },
                        set: { settings.filters.rangeFilterEnabled = $0 }
                    ))
                    .font(.headline.weight(.semibold))
                    .tint(SBColor.actionPrimary)
                }
                .padding(.top, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .sbPremiumGlass(radius: SBRadius.lg, interactive: true)
        .sbSoftShadow()
    }

    private func scrollExpandedPanel(_ id: String, using proxy: ScrollViewProxy) {
        Task { @MainActor in
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(280))
            withAnimation(.easeInOut(duration: 0.32)) {
                proxy.scrollTo(id, anchor: .bottom)
            }
        }
    }

    @ViewBuilder
    private var routeAction: some View {
        if let candidate = search.preparedCandidate {
            preparedRouteAction(candidate)
        } else {
            rangeAction
        }
    }

    private func preparedRouteAction(_ candidate: StationCandidate) -> some View {
        let arrivalPercent = max(0, Int(candidate.arrivalChargePercent.rounded()))
        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: "location.fill")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(SBColor.onActionPrimary)
                        .frame(width: 58, height: 58)
                        .background(SBColor.actionPrimary, in: RoundedRectangle(
                            cornerRadius: SBRadius.md,
                            style: .continuous
                        ))

                    VStack(alignment: .leading, spacing: 5) {
                        Label(settings.t("home.ready_verified"), systemImage: "checkmark.shield.fill")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(SBColor.actionPrimary)
                            .accessibilityIdentifier("prepared-route-card")
                        Text(candidate.station.name)
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(SBColor.contentPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                        Text(candidate.station.operatorName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(SBColor.contentSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    preparedMetric(
                        value: candidate.distanceKm.formatted(.number.precision(.fractionLength(1))) + " km",
                        title: settings.t("home.ready_distance")
                    )
                    preparedMetric(
                        value: settings.t("decision.minutes", ["minutes": "\(candidate.estimatedMinutes)"]),
                        title: settings.t("home.ready_duration")
                    )
                    preparedMetric(
                        value: "%\(arrivalPercent)",
                        title: settings.t("decision.arrival")
                    )
                }
            }
            .padding(20)

            Button {
                if settings.navigationAppPreference == nil {
                    frictionTelemetry.navigationChoicePresented()
                    navigationPickerPresented = true
                } else {
                    search.startNavigation(to: candidate)
                }
            } label: {
                HStack {
                    Text(settings.t("feed.start_route"))
                        .font(.headline.weight(.heavy))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.headline.weight(.heavy))
                }
                .foregroundStyle(SBColor.onActionPrimary)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .frame(height: 68)
                .background(SBColor.actionPrimary)
            }
            .buttonStyle(SBPremiumButtonStyle())
            .accessibilityIdentifier("prepared-route-button")
            .confirmationDialog(
                settings.t("feed.choose_navigation"),
                isPresented: $navigationPickerPresented,
                titleVisibility: .visible
            ) {
                Button(settings.t("feed.apple_maps")) {
                    search.startNavigation(to: candidate, using: .appleMaps)
                }
                Button(settings.t("feed.google_maps")) {
                    search.startNavigation(to: candidate, using: .googleMaps)
                }
                Button(settings.t("status.cancel"), role: .cancel) {}
            } message: {
                Text(settings.t("feed.choose_navigation_hint"))
            }

            Button {
                Haptic.tap()
                search.presentPreparedResults()
            } label: {
                Text(settings.t("home.ready_alternatives"))
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(SBColor.contentSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 42)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("prepared-route-alternatives")
        }
        .background(SBColor.surfaceBase)
        .clipShape(RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous)
                .stroke(SBColor.actionPrimary.opacity(0.55), lineWidth: 1.5)
        )
        .sbGlowShadow()
    }

    private func preparedMetric(value: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.heavy))
                .foregroundStyle(SBColor.contentPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(SBColor.contentSecondary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SBColor.surfaceRaised, in: RoundedRectangle(cornerRadius: SBRadius.sm, style: .continuous))
    }

    private var rangeAction: some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                Image(systemName: "bolt.fill")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(SBColor.onActionPrimary)
                    .frame(width: 72, height: 72)
                    .background(SBColor.actionPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous))

                VStack(alignment: .leading, spacing: 7) {
                    Text(settings.t("home.insight_kicker"))
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(SBColor.contentTertiary)
                    Text(settings.t("home.insight_title", ["range": "\(safeRangeKm)"]))
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(SBColor.contentPrimary)
                        .lineLimit(2)
                    Text(settings.t("summary.safe_range_value", [
                        "percent": "\(settings.profile.chargePercent)",
                        "range": "\(safeRangeKm)"
                    ]))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(SBColor.contentTertiary)

                    if let proof = executionTrust.latestVerifiedProof {
                        Label(
                            settings.t("proof.verified_compact", [
                                "confidence": "\(Int((proof.trustScore * 100).rounded()))"
                            ]),
                            systemImage: "checkmark.shield.fill"
                        )
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(SBColor.actionPrimary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(22)
            .background(LinearGradient.sbSoftPanel)

            if let intentPrediction {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(SBColor.actionPrimary)
                    Text(settings.t("intent_prefill.applied", [
                        "confidence": "\(Int((intentPrediction.confidence * 100).rounded()))"
                    ]))
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(SBColor.contentSecondary)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    Button(settings.t("intent_prefill.undo"), action: undoIntentPrefill)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(SBColor.actionPrimary)
                        .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(SBColor.surfaceRaised)
                .accessibilityIdentifier("intent-prefill-indicator")
            }

            Button {
                guard search.canSearch else { return }
                Haptic.tap()
                Task {
                    await search.findStations()
                    if !search.routeCandidates.isEmpty {
                        Haptic.success()
                    }
                }
            } label: {
                Text(search.isSearching ? settings.t("location.calculating") : settings.t("location.find_charger"))
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(SBColor.onActionPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 76)
                    .background(SBColor.actionPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous))
            }
            .buttonStyle(SBPremiumButtonStyle())
            .accessibilityIdentifier("find-stations-button")
            .disabled(!search.canSearch)
            .opacity(search.canSearch ? 1 : 0.62)
        }
        .sbPremiumGlass(radius: SBRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous)
                .stroke(SBColor.actionPrimary.opacity(0.55), lineWidth: 1.5)
        )
        .sbGlowShadow()
    }

    private func applyIntentPrefillIfEligible() {
        guard !didEvaluateIntentPrediction else { return }
        didEvaluateIntentPrediction = true
        guard case .idle = search.state else { return }
        let prediction = habits.searchPrediction() ?? graphIntentPrediction()
        guard let prediction else { return }
        filtersBeforePrediction = settings.filters
        settings.filters = prediction.parameters.applying(to: settings.filters)
        intentPrediction = prediction
    }

    private func graphIntentPrediction() -> SearchIntentPrediction? {
        let contexts = executionTrust.contextKeys(
            location: search.userLocation,
            preference: settings.filters.preference
        )
        guard let prediction = executionTrust.prediction(for: contexts),
              prediction.intentKey.hasPrefix("search:"),
              let rawPreference = prediction.intentKey.split(separator: ":").last,
              let preference = RoutePreference(rawValue: String(rawPreference)) else { return nil }
        var filters = settings.filters
        filters.preference = preference
        return SearchIntentPrediction(
            parameters: SearchIntentParameters(filters: filters),
            confidence: prediction.confidence,
            supportingSamples: prediction.supportingSuccesses,
            distinctDays: 0
        )
    }

    private func undoIntentPrefill() {
        Haptic.tap()
        if let filtersBeforePrediction {
            settings.filters = filtersBeforePrediction
        }
        self.filtersBeforePrediction = nil
        intentPrediction = nil
    }

    private var safeRangeKm: Int {
        Int(settings.profile.safeRangeKm.rounded())
    }

    private var chargeStatusText: String {
        let percent = min(100, max(1, settings.profile.chargePercent))
        if percent < 25 { return settings.t("charge.low") }
        if percent < 75 { return settings.t("charge.ready") }
        return settings.t("charge.long_range")
    }

    private func preferenceTitle(_ preference: RoutePreference) -> String {
        switch preference {
        case .balanced:
            settings.t("intent.balanced")
        case .nearest:
            settings.t("home.quick_near")
        case .fastest:
            settings.t("home.quick_fast")
        case .economical:
            settings.t("home.quick_value")
        }
    }

    private var manualLocationEntryVisible: Bool {
        if search.locationNeedsReview { return true }
        if search.userLocation?.source == .manual { return true }
        if locationManager.lastError != nil || locationRequestTimedOut { return true }
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            return true
        default:
            return !didRequestDeviceLocation
        }
    }

    private var locationWaitingText: String {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            settings.t("home.location_waiting_authorized")
        case .notDetermined:
            settings.t("home.location_waiting_pending")
        default:
            settings.t("home.location_waiting_failed")
        }
    }

    private func requestDeviceLocation() {
        didRequestDeviceLocation = true
        locationRequestTimedOut = false
        locationManager.requestLocation()
        Task {
            try? await Task.sleep(for: .seconds(4))
            if search.userLocation?.source != .device {
                locationRequestTimedOut = true
            }
        }
    }

    private var isDeterministicUITest: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--ui-testing-home")
            || ProcessInfo.processInfo.arguments.contains("--ui-testing-routes")
            || ProcessInfo.processInfo.arguments.contains("--ui-testing-navigation-picker")
            || ProcessInfo.processInfo.arguments.contains("--ui-testing-arrived")
            || ProcessInfo.processInfo.arguments.contains("--ui-testing-device-location")
            || ProcessInfo.processInfo.arguments.contains("--ui-testing-habit")
            || ProcessInfo.processInfo.arguments.contains("--ui-testing-agent")
            || ProcessInfo.processInfo.arguments.contains("--ui-testing-home-en")
            || ProcessInfo.processInfo.arguments.contains("--ui-testing-filter-recovery")
            || ProcessInfo.processInfo.arguments.contains("--ui-testing-outside-coverage")
        #else
        false
        #endif
    }

    private var manualLocationForm: some View {
        VStack(spacing: 12) {
            Picker(settings.t("home.location_pick"), selection: $selectedPreset) {
                Text(settings.t("home.location_pick")).tag(Optional<ManualLocationPreset>.none)
                ForEach(ManualLocationPreset.allCases) { preset in
                    Text(preset.title).tag(Optional(preset))
                }
            }
            .pickerStyle(.menu)
            .padding(14)
            .background(SBColor.surfaceGlass)
            .clipShape(RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous)
                    .stroke(SBColor.divider, lineWidth: 1)
            )
            .onChange(of: selectedPreset) { _, preset in
                guard let preset else { return }
                manualLatitude = preset.latitude
                manualLongitude = preset.longitude
                applyLocation(UserLocation(latitude: preset.latitude, longitude: preset.longitude, source: .manual))
            }

            HStack {
                TextField(settings.t("home.latitude"), value: $manualLatitude, format: .number.precision(.fractionLength(4)))
                    .sbDecimalKeyboard()
                TextField(settings.t("home.longitude"), value: $manualLongitude, format: .number.precision(.fractionLength(4)))
                    .sbDecimalKeyboard()
            }
            .textFieldStyle(.plain)
            .padding(14)
            .background(SBColor.surfaceGlass)
            .clipShape(RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SBRadius.md, style: .continuous)
                    .stroke(SBColor.divider, lineWidth: 1)
            )

            Button {
                Haptic.tap()
                applyLocation(UserLocation(latitude: manualLatitude, longitude: manualLongitude, source: .manual))
            } label: {
                Label(settings.t("home.use_manual_location"), systemImage: "mappin.and.ellipse")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(SBColor.actionPrimary)
        }
    }

    private func applyLocation(_ location: UserLocation) {
        search.updateLocation(
            latitude: location.latitude,
            longitude: location.longitude,
            source: location.source,
            capturedAt: location.capturedAt
        )
        frictionTelemetry.record(.locationReady)
        Task {
            await search.prepareOutcome()
            if location.source == .manual {
                await autonomousAgent.updateLocation(location)
            }
        }
    }
}
