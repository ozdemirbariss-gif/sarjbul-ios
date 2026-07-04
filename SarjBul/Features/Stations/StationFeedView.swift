import SarjBulCore
import SwiftUI

struct StationFeedView: View {
    @Environment(AppState.self) private var appState
    @State private var filterSheetPresented = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Rotalar")
                .searchable(text: Binding(
                    get: { appState.filters.searchText },
                    set: { appState.filters.searchText = $0 }
                ), prompt: "İstasyon ara")
                .onSubmit(of: .search) {
                    Task { await appState.findStations() }
                }
                .toolbar {
                    Button {
                        Haptic.tap()
                        filterSheetPresented = true
                    } label: {
                        Label("Filtreler", systemImage: "slider.horizontal.3")
                    }
                }
                .sheet(isPresented: $filterSheetPresented) {
                    StationFilterSheet(
                        filters: Binding(
                            get: { appState.filters },
                            set: { appState.filters = $0 }
                        )
                    ) {
                        Haptic.tap()
                        filterSheetPresented = false
                        Task { await appState.findStations() }
                    }
                    .sbMediumSheet()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch appState.search {
        case .idle:
            ContentUnavailableView(
                "Rota hazır değil",
                systemImage: "bolt.car",
                description: Text("Ana sayfadan konumunu seçip Şarj Bul'a bas.")
            )
        case .searching:
            ProgressView("En iyi duraklar hesaplanıyor")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(SBColor.background.ignoresSafeArea())
        case .failed(let message):
            ContentUnavailableView(
                "Rota hesaplanamadı",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
        case .results(let candidates):
            if candidates.isEmpty {
                ContentUnavailableView(
                    "Uygun istasyon bulunamadı",
                    systemImage: "magnifyingglass",
                    description: Text("Filtreleri gevşetip tekrar deneyebilirsin.")
                )
            } else {
                    ScrollView {
                        LazyVStack(spacing: 18) {
                            ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                                StationCard(candidate: candidate, rank: index + 1)
                                    .containerRelativeFrame(.vertical, count: 1, spacing: 18)
                                    .scrollTransition { content, phase in
                                        content
                                            .opacity(phase.isIdentity ? 1 : 0.55)
                                            .scaleEffect(phase.isIdentity ? 1 : 0.94)
                                    }
                            }
                        }
                        .scrollTargetLayout()
                        .padding(18)
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .background(SBColor.background.ignoresSafeArea())
            }
        }
    }
}

private struct StationFilterSheet: View {
    @Binding var filters: StationFilters
    var apply: () -> Void

    private let sockets = ["CCS", "Type 2", "CHAdeMO", "Schuko"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Öncelik") {
                    Picker("Öncelik", selection: $filters.preference) {
                        ForEach(RoutePreference.allCases) { preference in
                            Text(preference.title).tag(preference)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Güç") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Minimum \(Int(filters.minimumPowerKW)) kW")
                            .font(.headline)
                        Slider(value: $filters.minimumPowerKW, in: 0...180, step: 10)
                            .tint(SBColor.accent)
                    }
                }

                Section("Soket") {
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
                                    .background(filters.socketFilters.contains(socket) ? SBColor.accent : .white.opacity(0.7))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    Toggle("Menzil dışını gizle", isOn: $filters.rangeFilterEnabled)
                }
            }
            .navigationTitle("Filtreler")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Uygula", action: apply)
                }
            }
        }
    }
}
