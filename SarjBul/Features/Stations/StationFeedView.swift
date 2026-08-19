import SarjBulCore
import SwiftUI

struct StationFeedView: View {
    @Environment(UserSettingsStore.self) private var settings
    @Environment(SearchCoordinator.self) private var search
    @Environment(NavigationCoordinator.self) private var navigation
    @State private var filterSheetPresented = false
    @State private var mode: FeedMode = .cards
    @State private var tripPlanPresented = false
    @State private var alternativesExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var navigation = navigation
        NavigationStack(path: $navigation.routesPath) {
            ZStack(alignment: .topLeading) {
                SBScreenBackground()
                content
                feedToolbar
            }
            .navigationDestination(for: AppRoute.self, destination: routeDestination)
        }
        .sheet(isPresented: $filterSheetPresented) {
            StationFilterSheet(
                filters: Binding(
                    get: { settings.filters },
                    set: { settings.filters = $0 }
                ),
                language: settings.language
            ) {
                Haptic.tap()
                filterSheetPresented = false
                Task { await search.findStations() }
            }
            .sbMediumSheet()
        }
        .sheet(isPresented: $tripPlanPresented) {
            if let plan = search.tripPlan {
                TripPlanView(plan: plan)
                    .environment(settings)
            }
        }
        .task(id: autoSearchReady) {
            guard autoSearchReady else { return }
            await search.findStations()
        }
    }

    private var autoSearchReady: Bool {
        guard search.canSearch else { return false }
        if case .idle = search.state { return true }
        return false
    }

    private var feedToolbar: some View {
        HStack(spacing: 12) {
            SBBackButton(accessibilityLabel: settings.t("nav.back")) {
                navigation.tab = .home
            }

            Spacer(minLength: 8)

            if !search.routeCandidates.isEmpty {
                HStack(spacing: 4) {
                    if search.tripPlan != nil {
                        toolbarButton(
                            icon: "bolt.car.fill",
                            accessibilityLabel: settings.t("planner.title")
                        ) {
                            tripPlanPresented = true
                        }
                    }

                    modeButton(.cards, icon: "rectangle.stack.fill", label: settings.t("feed.cards"))
                    modeButton(.map, icon: "map.fill", label: settings.t("feed.map"))

                    toolbarButton(
                        icon: "line.3.horizontal.decrease",
                        accessibilityLabel: settings.t("feed.filters")
                    ) {
                        filterSheetPresented = true
                    }
                }
                .padding(5)
                .background(SBColor.surfaceRaised.opacity(0.98), in: Capsule())
                .overlay(Capsule().stroke(SBColor.divider, lineWidth: 1))
                .sbCardShadow()
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
    }

    private func modeButton(_ targetMode: FeedMode, icon: String, label: String) -> some View {
        Button {
            Haptic.tap()
            mode = targetMode
        } label: {
            Image(systemName: icon)
                .font(.headline.weight(.heavy))
                .foregroundStyle(mode == targetMode ? SBColor.onActionPrimary : SBColor.contentSecondary)
                .frame(width: 46, height: 46)
                .background(mode == targetMode ? SBColor.actionPrimary : .clear, in: Circle())
        }
        .buttonStyle(SBPremiumButtonStyle())
        .accessibilityLabel(label)
        .accessibilityAddTraits(mode == targetMode ? .isSelected : [])
    }

    private func toolbarButton(
        icon: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptic.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.headline.weight(.heavy))
                .foregroundStyle(SBColor.contentSecondary)
                .frame(width: 46, height: 46)
        }
        .buttonStyle(SBPremiumButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private func routeDestination(_ route: AppRoute) -> some View {
        switch route {
        case .station(let key):
            if let index = search.routeCandidates.firstIndex(where: {
                $0.station.statusKey == key || $0.station.id == key
            }) {
                ScrollView {
                    StationCard(
                        candidate: search.routeCandidates[index],
                        rank: index + 1,
                        total: search.routeCandidates.count
                    )
                    .padding(18)
                }
                .background(SBScreenBackground())
                .navigationBarTitleDisplayMode(.inline)
            } else {
                ContentUnavailableView(
                    settings.t("deep_link.not_found"),
                    systemImage: "bolt.slash"
                )
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch search.state {
        case .idle:
            emptyState(
                settings.t("route.idle"),
                icon: "bolt.car",
                message: settings.t("route.idle_hint")
            )
        case .searching:
            if search.previousCandidates.isEmpty {
                VStack(spacing: 18) {
                    ProgressView()
                        .tint(SBColor.actionPrimary)
                        .scaleEffect(1.2)
                    Text(settings.t("route.searching"))
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(SBColor.contentTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ZStack(alignment: .top) {
                    resultContent(search.previousCandidates)
                    Label(settings.t("route.refreshing"), systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(SBColor.contentPrimary)
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .sbPremiumGlass(radius: 19)
                        .padding(.top, 70)
                }
            }
        case .failed(let message):
            emptyState(
                settings.t("route.failed"),
                icon: "exclamationmark.triangle",
                message: message.text(language: settings.language)
            )
        case .results(let candidates):
            if candidates.isEmpty {
                emptyState(
                    settings.t("route.empty"),
                    icon: "magnifyingglass",
                    message: settings.t("route.empty_hint")
                )
            } else {
                resultContent(candidates)
            }
        }
    }

    @ViewBuilder
    private func resultContent(_ candidates: [StationCandidate]) -> some View {
        if mode == .cards {
            ScrollView {
                LazyVStack(spacing: 18) {
                    Color.clear.frame(height: 22)
                    if let best = candidates.first {
                        resultCard(best, rank: 1, total: candidates.count)
                    }

                    if candidates.count > 1 {
                        Button {
                            Haptic.tap()
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                                alternativesExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "rectangle.stack")
                                    .foregroundStyle(SBColor.actionPrimary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(settings.t("feed.alternatives_title"))
                                        .font(.headline.weight(.heavy))
                                        .foregroundStyle(SBColor.contentPrimary)
                                    Text(settings.t("feed.alternatives_hint", [
                                        "count": "\(min(2, candidates.count - 1))"
                                    ]))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(SBColor.contentSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundStyle(SBColor.actionPrimary)
                                    .rotationEffect(.degrees(alternativesExpanded ? 180 : 0))
                            }
                            .padding(.horizontal, 18)
                            .frame(minHeight: 66)
                            .background(SBColor.surfaceBase, in: RoundedRectangle(
                                cornerRadius: SBRadius.lg,
                                style: .continuous
                            ))
                            .overlay(RoundedRectangle(cornerRadius: SBRadius.lg).stroke(SBColor.divider))
                        }
                        .buttonStyle(SBPremiumButtonStyle())
                        .accessibilityIdentifier("station-alternatives-toggle")
                    }

                    if alternativesExpanded {
                        ForEach(Array(candidates.dropFirst().prefix(2).enumerated()), id: \.element.id) { index, candidate in
                            resultCard(candidate, rank: index + 2, total: candidates.count)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 110)
            }
        } else {
            StationOverviewMap(candidates: candidates)
                .padding(.top, 82)
        }
    }

    private func resultCard(_ candidate: StationCandidate, rank: Int, total: Int) -> some View {
        let shouldReduceMotion = reduceMotion
        return StationCard(candidate: candidate, rank: rank, total: total)
            .frame(maxWidth: 680)
            .scrollTransition { content, phase in
                content
                    .opacity(shouldReduceMotion || phase.isIdentity ? 1 : 0.88)
                    .scaleEffect(shouldReduceMotion || phase.isIdentity ? 1 : 0.98)
            }
    }

    private func emptyState(_ title: String, icon: String, message: String) -> some View {
        VStack {
            Spacer()
            SBSecondaryPanel {
                VStack(spacing: 16) {
                    Image(systemName: icon)
                        .font(.largeTitle.weight(.heavy))
                        .foregroundStyle(SBColor.stationMediumPower)
                    Text(title)
                        .font(SBFont.display(size: 30, weight: .heavy))
                        .foregroundStyle(SBColor.contentPrimary)
                    Text(message)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(SBColor.contentTertiary)
                        .multilineTextAlignment(.center)
                    SBDarkButton(title: settings.t("route.back_home"), systemImage: "house") {
                        navigation.tab = .home
                    }
                }
            }
            .padding(22)
            Spacer()
        }
    }
}

private enum FeedMode: Hashable {
    case cards
    case map
}

private struct StationFilterSheet: View {
    @Binding var filters: StationFilters
    var language: AppLanguage
    var apply: () -> Void

    private let sockets = ["CCS", "Type 2", "CHAdeMO", "Schuko"]

    var body: some View {
        NavigationStack {
            Form {
                Section(t("filters.preference")) {
                    Picker(t("filters.preference"), selection: $filters.preference) {
                        ForEach(RoutePreference.allCases) { preference in
                            Text(preferenceTitle(preference)).tag(preference)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(t("filters.power")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(t("filters.minimum_power", ["power": "\(Int(filters.minimumPowerKW))"]))
                            .font(.headline)
                        Slider(value: $filters.minimumPowerKW, in: 0...180, step: 10)
                            .tint(SBColor.actionPrimary)
                    }
                }

                Section(t("filters.socket")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                        ForEach(sockets, id: \.self) { socket in
                            Button {
                                if filters.socketFilters.contains(socket) {
                                    filters.socketFilters.remove(socket)
                                } else {
                                    filters.socketFilters.insert(socket)
                                }
                            } label: {
                                Text(socket)
                                    .font(.subheadline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(filters.socketFilters.contains(socket) ? SBColor.actionPrimary : SBColor.surfaceGlass)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    Toggle(t("filters.range"), isOn: $filters.rangeFilterEnabled)
                }
            }
            .navigationTitle(t("filters.title"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(t("filters.apply"), action: apply)
                }
            }
        }
    }

    private func t(_ key: String, _ replacements: [String: String] = [:]) -> String {
        AppLocalization.text(key, language: language, replacements: replacements)
    }

    private func preferenceTitle(_ preference: RoutePreference) -> String {
        switch preference {
        case .balanced:
            t("intent.balanced")
        case .nearest:
            t("intent.near")
        case .fastest:
            t("intent.fast")
        case .economical:
            t("intent.economic")
        }
    }
}
