import SarjBulCore
import SwiftUI

struct StationFeedView: View {
    @Environment(UserSettingsStore.self) private var settings
    @Environment(SearchCoordinator.self) private var search
    @Environment(NavigationCoordinator.self) private var navigation
    @State private var filterSheetPresented = false
    @State private var mode: FeedMode = .cards
    @State private var tripPlanPresented = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            SBScreenBackground()
            content

            HStack(spacing: 10) {
                SBBackButton(accessibilityLabel: settings.t("nav.back")) {
                    navigation.tab = .home
                }

                Spacer()

                if !search.routeCandidates.isEmpty {
                    if search.tripPlan != nil {
                        Button {
                            Haptic.tap()
                            tripPlanPresented = true
                        } label: {
                            Image(systemName: "bolt.car.fill")
                                .font(.headline.weight(.heavy))
                                .foregroundStyle(SBColor.ink)
                                .frame(width: 52, height: 52)
                                .sbPremiumGlass(radius: 26, interactive: true)
                        }
                        .buttonStyle(SBPremiumButtonStyle())
                        .accessibilityLabel(settings.t("planner.title"))
                    }

                    Picker(settings.t("feed.view_mode"), selection: $mode) {
                        Label(settings.t("feed.cards"), systemImage: "rectangle.stack").tag(FeedMode.cards)
                        Label(settings.t("feed.map"), systemImage: "map").tag(FeedMode.map)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 210)

                    Button {
                        Haptic.tap()
                        filterSheetPresented = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(SBColor.ink)
                            .frame(width: 52, height: 52)
                            .sbPremiumGlass(radius: 26, interactive: true)
                    }
                    .buttonStyle(SBPremiumButtonStyle())
                    .accessibilityLabel(settings.t("feed.filters"))
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
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
            VStack(spacing: 18) {
                ProgressView()
                    .tint(SBColor.accent)
                    .scaleEffect(1.2)
                Text(settings.t("route.searching"))
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(SBColor.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                let shouldReduceMotion = reduceMotion
                Group {
                    if mode == .cards {
                        ScrollView {
                            LazyVStack(spacing: 24) {
                                Color.clear.frame(height: 30)
                                ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                                    StationCard(candidate: candidate, rank: index + 1, total: candidates.count)
                                        .frame(maxWidth: 680)
                                        .containerRelativeFrame(.vertical, count: 1, spacing: 22)
                                        .scrollTransition { content, phase in
                                            content
                                                .opacity(shouldReduceMotion || phase.isIdentity ? 1 : 0.72)
                                                .scaleEffect(shouldReduceMotion || phase.isIdentity ? 1 : 0.92)
                                        }
                                }
                            }
                            .scrollTargetLayout()
                            .padding(.horizontal, 18)
                        }
                        .scrollTargetBehavior(.viewAligned)
                    } else {
                        StationOverviewMap(candidates: candidates)
                            .padding(.top, 82)
                    }
                }
            }
        }
    }

    private func emptyState(_ title: String, icon: String, message: String) -> some View {
        VStack {
            Spacer()
            SBSecondaryPanel {
                VStack(spacing: 16) {
                    Image(systemName: icon)
                        .font(.largeTitle.weight(.heavy))
                        .foregroundStyle(SBColor.accent)
                    Text(title)
                        .font(SBFont.display(size: 30, weight: .heavy))
                        .foregroundStyle(SBColor.ink)
                    Text(message)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(SBColor.muted)
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
                            .tint(SBColor.accent)
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
                                    .background(filters.socketFilters.contains(socket) ? SBColor.accent : SBColor.glass)
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
