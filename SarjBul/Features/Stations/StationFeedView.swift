import SarjBulCore
import SwiftUI

struct StationFeedView: View {
    @Environment(AppState.self) private var appState
    @State private var filterSheetPresented = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            SBScreenBackground()
            content

            SBBackButton {
                appState.tab = .home
            }
            .padding(.leading, 18)
            .padding(.top, 6)
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

    @ViewBuilder
    private var content: some View {
        switch appState.search {
        case .idle:
            emptyState(
                "Rota hazır değil",
                icon: "bolt.car",
                message: "Ana sayfadan konumunu seçip En Uygun İstasyonu Bul'a bas."
            )
        case .searching:
            VStack(spacing: 18) {
                ProgressView()
                    .tint(SBColor.accent)
                    .scaleEffect(1.2)
                Text("En iyi duraklar hesaplanıyor")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(SBColor.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            emptyState("Rota hesaplanamadı", icon: "exclamationmark.triangle", message: message)
        case .results(let candidates):
            if candidates.isEmpty {
                emptyState(
                    "Uygun istasyon bulunamadı",
                    icon: "magnifyingglass",
                    message: "Filtreleri gevşetip tekrar deneyebilirsin."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 24) {
                        Color.clear.frame(height: 84)
                        ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                            StationCard(candidate: candidate, rank: index + 1)
                                .containerRelativeFrame(.vertical, count: 1, spacing: 22)
                                .scrollTransition { content, phase in
                                    content
                                        .opacity(phase.isIdentity ? 1 : 0.72)
                                        .scaleEffect(phase.isIdentity ? 1 : 0.92)
                                }
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, 18)
                }
                .scrollTargetBehavior(.viewAligned)
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
                    SBDarkButton(title: "Ana Sayfaya Dön", systemImage: "house") {
                        appState.tab = .home
                    }
                }
            }
            .padding(22)
            Spacer()
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
                                    .background(filters.socketFilters.contains(socket) ? SBColor.accent : SBColor.glass)
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
