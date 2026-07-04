import SarjBulCore
import SwiftUI

struct StationFeedView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            Group {
                if appState.candidates.isEmpty {
                    ContentUnavailableView(
                        "Rota hazır değil",
                        systemImage: "bolt.car",
                        description: Text("Ana sayfadan konumunu seçip Şarj Bul'a bas.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 18) {
                            ForEach(Array(appState.candidates.enumerated()), id: \.element.id) { index, candidate in
                                StationCard(candidate: candidate, rank: index + 1)
                                    .containerRelativeFrame(.vertical, count: 1, spacing: 18)
                            }
                        }
                        .scrollTargetLayout()
                        .padding(18)
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .background(SBColor.background.ignoresSafeArea())
                }
            }
            .navigationTitle("Rotalar")
        }
    }
}

