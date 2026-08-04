import SarjBulCore
import SwiftUI

struct AccountView: View {
    @Environment(UserSettingsStore.self) private var settings
    @Environment(AuthStore.self) private var auth
    @Environment(FavoritesStore.self) private var favorites
    @Environment(SearchCoordinator.self) private var search
    @Environment(ChargingHistoryStore.self) private var chargingHistory
    @State private var isDeletingData = false
    @State private var deleteConfirmationPresented = false
    @State private var legalDocument: LegalDocument?

    var body: some View {
        NavigationStack {
            ZStack {
                SBScreenBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        languageRow
                        profileHeader
                        stationLibraryPanel

                        ChargingInsightsView()
                            .environment(settings)
                            .environment(chargingHistory)
                            .environment(favorites)
                            .environment(auth)

                        if auth.isConfigured {
                            privacyPanel
                            dataPanel
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

    private var languageRow: some View {
        HStack {
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
