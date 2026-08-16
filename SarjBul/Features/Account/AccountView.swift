import SarjBulCore
import SwiftUI

struct AccountView: View {
    @Environment(UserSettingsStore.self) private var settings
    @Environment(AuthStore.self) private var auth
    @Environment(FavoritesStore.self) private var favorites
    @Environment(SearchCoordinator.self) private var search
    @Environment(ChargingHistoryStore.self) private var chargingHistory
    @Environment(AutonomousChargingAgentStore.self) private var autonomousAgent
    @Environment(ContextIntelligenceStore.self) private var contextIntelligence
    @Environment(ExecutionTrustStore.self) private var executionTrust
    @Environment(FrictionTelemetryStore.self) private var frictionTelemetry
    @Environment(NavigationCoordinator.self) private var navigation
    @State private var isDeletingData = false
    @State private var deleteConfirmationPresented = false
    @State private var legalDocument: LegalDocument?
    @State private var automationExpanded = false
    @State private var insightsExpanded = false
    @State private var privacyExpanded = false

    var body: some View {
        NavigationStack {
            ZStack {
                SBScreenBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        profileTopBar
                        profileHeader
                        outcomeValuePanel
                        collapsibleSection(
                            title: settings.t("profile.automation_group"),
                            subtitle: settings.t("profile.automation_group_hint"),
                            icon: "sparkles",
                            accessibilityIdentifier: "profile-automation-toggle",
                            isExpanded: $automationExpanded
                        ) {
                            autonomousAssistantPanel
                            contextIntelligencePanel
                        }
                        stationLibraryPanel

                        collapsibleSection(
                            title: settings.t("profile.insights_group"),
                            subtitle: settings.t("profile.insights_group_hint"),
                            icon: "chart.line.uptrend.xyaxis",
                            accessibilityIdentifier: "profile-insights-toggle",
                            isExpanded: $insightsExpanded
                        ) {
                            ChargingInsightsView()
                                .environment(settings)
                                .environment(chargingHistory)
                                .environment(favorites)
                                .environment(auth)
                        }

                        if auth.isConfigured {
                            collapsibleSection(
                                title: settings.t("profile.privacy_group"),
                                subtitle: settings.t("profile.privacy_group_hint"),
                                icon: "hand.raised.fill",
                                accessibilityIdentifier: "profile-privacy-toggle",
                                isExpanded: $privacyExpanded
                            ) {
                                privacyPanel
                                dataPanel
                            }
                        }

                        legalFooter
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .sensoryFeedback(.selection, trigger: settings.language)
            }
            .sheet(item: $legalDocument) { document in
                LegalView(document: document)
                    .environment(settings)
            }
            .confirmationDialog(
                settings.t("profile.reset_title"),
                isPresented: $deleteConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button(settings.t("profile.reset_confirm"), role: .destructive) {
                    Task { await resetCloudData() }
                }
                Button(settings.t("status.cancel"), role: .cancel) {}
            } message: {
                Text(settings.t("profile.reset_message"))
            }
        }
    }

    private var profileTopBar: some View {
        HStack {
            SBBackButton(accessibilityLabel: settings.t("nav.back")) {
                navigation.select(.home)
            }
            .accessibilityIdentifier("profile-back-button")

            Spacer()
            SBLanguageSwitch(selectedLanguage: Binding(
                get: { settings.language.displayCode },
                set: { settings.setLanguage(code: $0) }
            ))
        }
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(settings.t("profile.eyebrow"))
                .font(.caption.weight(.heavy))
                .foregroundStyle(SBColor.signal)

            Text(settings.t("profile.title"))
                .font(SBFont.display(size: 48, weight: .heavy))
                .foregroundStyle(SBColor.ink)
                .minimumScaleFactor(0.72)

            Text(settings.t("profile.subtitle"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(SBColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    private var outcomeValuePanel: some View {
        let value = executionTrust.value
        return SBSecondaryPanel {
            VStack(alignment: .leading, spacing: 16) {
                Label(settings.t("proof.value_title"), systemImage: "checkmark.shield.fill")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(SBColor.ink)

                HStack(spacing: 10) {
                    valueMetric(
                        value: "\(value.completedActions)",
                        title: settings.t("proof.completed_actions")
                    )
                    valueMetric(
                        value: settings.t("proof.minutes_value", [
                            "minutes": "\(value.estimatedMinutesSaved)"
                        ]),
                        title: settings.t("proof.time_saved")
                    )
                    valueMetric(
                        value: "\(frictionTelemetry.summary.completedCharges)",
                        title: settings.t("proof.charges_completed")
                    )
                }

                Text(settings.t("proof.value_hint"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SBColor.textSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("verified-outcome-value")
    }

    private func valueMetric(value: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3.monospacedDigit().weight(.heavy))
                .foregroundStyle(SBColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(SBColor.textSoft)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func collapsibleSection<Content: View>(
        title: String,
        subtitle: String,
        icon: String,
        accessibilityIdentifier: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 12) {
            Button {
                Haptic.tap()
                withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(SBColor.signal)
                        .frame(width: 42, height: 42)
                        .background(SBColor.signal.opacity(0.10), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(SBColor.ink)
                        Text(subtitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(SBColor.textSoft)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(SBColor.signal)
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 180 : 0))
                }
                .padding(.horizontal, 18)
                .frame(minHeight: 68)
                .background(
                    SBColor.surfaceSolid,
                    in: RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: SBRadius.lg, style: .continuous)
                        .stroke(SBColor.line, lineWidth: 1)
                )
            }
            .buttonStyle(SBPremiumButtonStyle())
            .accessibilityIdentifier(accessibilityIdentifier)

            if isExpanded.wrappedValue {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var privacyPanel: some View {
        SBSecondaryPanel {
            VStack(alignment: .leading, spacing: 12) {
                Label(settings.t("profile.privacy_title"), systemImage: "hand.raised.fill")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(SBColor.ink)

                Toggle(settings.t("auth.demand_analytics"), isOn: Binding(
                    get: { settings.demandAnalyticsEnabled },
                    set: { settings.demandAnalyticsEnabled = $0 }
                ))
                .font(.subheadline.weight(.bold))
                .tint(SBColor.electricBlue)

                Text(settings.t("auth.demand_analytics_hint"))
                    .font(.caption)
                    .foregroundStyle(SBColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var autonomousAssistantPanel: some View {
        SBSecondaryPanel {
            VStack(alignment: .leading, spacing: 16) {
                Label(settings.t("agent.settings_title"), systemImage: "sparkles")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(SBColor.ink)

                Text(settings.t("agent.settings_hint"))
                    .font(.subheadline)
                    .foregroundStyle(SBColor.muted)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle(settings.t("agent.enable"), isOn: Binding(
                    get: { settings.autonomousChargingPolicy.isEnabled },
                    set: { enabled in Task { await autonomousAgent.setEnabled(enabled) } }
                ))
                .font(.subheadline.weight(.bold))
                .tint(SBColor.signal)

                if settings.autonomousChargingPolicy.isEnabled {
                    Divider().overlay(SBColor.line)

                    Stepper(
                        settings.t("agent.threshold", [
                            "percent": "\(settings.autonomousChargingPolicy.triggerChargePercent)"
                        ]),
                        value: autonomousThresholdBinding,
                        in: 10...50,
                        step: 5
                    )
                    .font(.subheadline.weight(.bold))

                    Toggle(settings.t("agent.profile_fallback"), isOn: profileFallbackBinding)
                        .font(.subheadline.weight(.bold))
                        .tint(SBColor.signal)

                    Text(settings.t("agent.profile_fallback_hint"))
                        .font(.caption)
                        .foregroundStyle(SBColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var autonomousThresholdBinding: Binding<Int> {
        Binding(
            get: { settings.autonomousChargingPolicy.triggerChargePercent },
            set: { value in
                var policy = settings.autonomousChargingPolicy
                policy.triggerChargePercent = value
                settings.autonomousChargingPolicy = policy
            }
        )
    }

    private var contextIntelligencePanel: some View {
        SBSecondaryPanel {
            VStack(alignment: .leading, spacing: 14) {
                Label(settings.t("context.settings_title"), systemImage: "brain.head.profile")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(SBColor.ink)

                Text(settings.t("context.settings_hint"))
                    .font(.caption)
                    .foregroundStyle(SBColor.muted)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle(settings.t("context.enable"), isOn: Binding(
                    get: { contextIntelligence.policy.isEnabled },
                    set: { enabled in Task { await contextIntelligence.setEnabled(enabled) } }
                ))
                .font(.subheadline.weight(.bold))
                .tint(SBColor.signal)

                if contextIntelligence.policy.isEnabled {
                    Divider().overlay(SBColor.line)

                    Toggle(settings.t("context.health"), isOn: Binding(
                        get: { contextIntelligence.policy.usesHealthSignals },
                        set: { enabled in Task { await contextIntelligence.setUsesHealthSignals(enabled) } }
                    ))
                    .font(.subheadline.weight(.bold))
                    .tint(SBColor.signal)

                    Toggle(settings.t("context.weather"), isOn: Binding(
                        get: { contextIntelligence.policy.usesWeather },
                        set: { contextIntelligence.setUsesWeather($0) }
                    ))
                    .font(.subheadline.weight(.bold))
                    .tint(SBColor.signal)

                    Toggle(settings.t("context.calendar_auto"), isOn: Binding(
                        get: { contextIntelligence.policy.allowsAutomaticCalendarChanges },
                        set: { enabled in Task { await contextIntelligence.setAutomaticCalendarChanges(enabled) } }
                    ))
                    .font(.subheadline.weight(.bold))
                    .tint(SBColor.signal)

                    Text(settings.t("context.calendar_auto_hint"))
                        .font(.caption2)
                        .foregroundStyle(SBColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var profileFallbackBinding: Binding<Bool> {
        Binding(
            get: { settings.autonomousChargingPolicy.allowsProfileFallback },
            set: { value in
                var policy = settings.autonomousChargingPolicy
                policy.allowsProfileFallback = value
                settings.autonomousChargingPolicy = policy
            }
        )
    }

    private var dataPanel: some View {
        SBSecondaryPanel {
            VStack(alignment: .leading, spacing: 14) {
                Label(settings.t("profile.data_title"), systemImage: "lock.shield.fill")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(SBColor.ink)

                Text(settings.t("profile.data_hint"))
                    .font(.subheadline)
                    .foregroundStyle(SBColor.muted)
                    .fixedSize(horizontal: false, vertical: true)

                Button(role: .destructive) {
                    Haptic.tap()
                    deleteConfirmationPresented = true
                } label: {
                    Label(
                        isDeletingData ? settings.t("profile.reset_loading") : settings.t("profile.reset_action"),
                        systemImage: "arrow.counterclockwise"
                    )
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .disabled(isDeletingData)
            }
        }
    }

    @ViewBuilder
    private var stationLibraryPanel: some View {
        let favoriteStations = favorites.favoriteStations
        let recent = favorites.recentStations

        if !favoriteStations.isEmpty || !recent.isEmpty {
            SBSecondaryPanel {
                VStack(alignment: .leading, spacing: 20) {
                    if !favoriteStations.isEmpty {
                        stationSection(title: settings.t("library.favorites"), stations: favoriteStations)
                    }
                    if !recent.isEmpty {
                        stationSection(title: settings.t("library.recent"), stations: recent)
                    }
                }
            }
        }
    }

    private func stationSection(title: String, stations: [Station]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline.weight(.heavy))
                .foregroundStyle(SBColor.ink)

            ForEach(Array(stations.prefix(4))) { station in
                Button {
                    Haptic.tap()
                    Task { await search.openStation(withKey: station.statusKey) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.black)
                            .frame(width: 38, height: 38)
                            .background(SBColor.electricBlue)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(station.name)
                                .font(.subheadline.weight(.heavy))
                                .foregroundStyle(SBColor.ink)
                                .lineLimit(1)
                            Text(station.operatorName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(SBColor.muted)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(SBColor.electricBlue)
                    }
                    .padding(12)
                    .sbPremiumGlass(radius: SBRadius.md, interactive: true)
                }
                .buttonStyle(SBPremiumButtonStyle())
                .accessibilityHint(settings.t("library.open_route"))
            }
        }
    }

    private var legalFooter: some View {
        VStack(spacing: 14) {
            HStack(spacing: 22) {
                legalButton(settings.t("auth.privacy"), document: .privacy)
                legalButton(settings.t("auth.terms"), document: .terms)
                legalButton(settings.t("auth.support"), document: .support)
            }

            Text(settings.t("auth.version", ["version": appVersion]))
                .font(.caption.weight(.semibold))
                .foregroundStyle(SBColor.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 110)
    }

    private func legalButton(_ title: String, document: LegalDocument) -> some View {
        Button(title) {
            Haptic.tap()
            legalDocument = document
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(SBColor.electricBlue)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private func resetCloudData() async {
        guard !isDeletingData else { return }
        isDeletingData = true
        defer { isDeletingData = false }
        _ = await auth.deleteAccount()
    }
}
