import SarjBulCore
import SwiftUI

struct StationFeedView: View {
    @Environment(AppState.self) private var appState
    @State private var filterSheetPresented = false
    @State private var mode: FeedMode = .cards
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            SBScreenBackground()
            content

            HStack(spacing: 10) {
                SBBackButton(accessibilityLabel: appState.t("nav.back")) {
                    appState.tab = .home
                }

                Spacer()

                if !appState.routeCandidates.isEmpty {
                    Picker(appState.t("feed.view_mode"), selection: $mode) {
                        Label(appState.t("feed.cards"), systemImage: "rectangle.stack").tag(FeedMode.cards)
                        Label(appState.t("feed.map"), systemImage: "map").tag(FeedMode.map)
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
                    .accessibilityLabel(appState.t("feed.filters"))
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
        }
        .sheet(isPresented: $filterSheetPresented) {
            StationFilterSheet(
                filters: Binding(
                    get: { appState.filters },
                    set: { appState.filters = $0 }
                ),
                language: appState.language
            ) {
                Haptic.tap()
                filterSheetPresented = false
                Task { await appState.findStations() }
            }
            .sbMediumSheet()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch appState.search {
        case .idle:
            emptyState(
                appState.t("route.idle"),
                icon: "bolt.car",
                message: appState.t("route.idle_hint")
            )
        case .searching:
            VStack(spacing: 18) {
                ProgressView()
                    .tint(SBColor.accent)
                    .scaleEffect(1.2)
                Text(appState.t("route.searching"))
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(SBColor.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            emptyState(appState.t("route.failed"), icon: "exclamationmark.triangle", message: message)
        case .results(let candidates):
            if candidates.isEmpty {
                emptyState(
                    appState.t("route.empty"),
                    icon: "magnifyingglass",
                    message: appState.t("route.empty_hint")
                )
            } else {
                let shouldReduceMotion = reduceMotion
                Group {
                    if mode == .cards {
                        ScrollView {
                            LazyVStack(spacing: 24) {
                                Color.clear.frame(height: 84)
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
                    SBDarkButton(title: appState.t("route.back_home"), systemImage: "house") {
                        appState.tab = .home
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
