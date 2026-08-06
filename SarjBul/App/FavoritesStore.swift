import Foundation
import Observation
import SarjBulCore

@MainActor
@Observable
final class FavoritesStore {
    private let client: any FavoritesClient
    private let auth: AuthStore
    private let stationData: StationDataStore
    private let mutationQueue: AsyncMutationQueue
    private let persistence: any AppPersistence
    private let messages: AppMessagePresenter
    private var pendingKeys: Set<String> = []

    private(set) var favorites: Set<String> = []
    private(set) var recentRoutes: [RecentStationRoute]

    init(
        client: any FavoritesClient,
        auth: AuthStore,
        stationData: StationDataStore,
        mutationQueue: AsyncMutationQueue,
        persistence: any AppPersistence,
        messages: AppMessagePresenter
    ) {
        self.client = client
        self.auth = auth
        self.stationData = stationData
        self.mutationQueue = mutationQueue
        self.persistence = persistence
        self.messages = messages
        recentRoutes = persistence.recentRoutes
    }

    func handleSessionChanged(_ session: FirebaseAuthSession?) async {
        guard session != nil else {
            favorites = []
            return
        }
        await load()
    }

    func load() async {
        do {
            favorites = try await auth.authenticatedRequest { session in
                try await self.client.favoriteIDs(uid: session.uid, idToken: session.idToken)
            }
        } catch {
            AppLogger.account.error("Favorites failed: \(error.localizedDescription, privacy: .public)")
            messages.present(.auth(AuthError.map(error)))
        }
    }

    func isFavorite(_ stationKey: String) -> Bool {
        favorites.contains(stationKey)
    }

    func toggle(_ stationKey: String) async {
        guard !pendingKeys.contains(stationKey) else { return }

        pendingKeys.insert(stationKey)
        let shouldFavorite = !favorites.contains(stationKey)
        if shouldFavorite { favorites.insert(stationKey) } else { favorites.remove(stationKey) }

        await mutationQueue.enqueue(id: "favorite:\(stationKey)") { [auth, client] in
            try await auth.authenticatedRequest { session in
                try await client.setFavorite(
                    uid: session.uid,
                    stationKey: stationKey,
                    isFavorite: shouldFavorite,
                    idToken: session.idToken
                )
            }
        } completion: { [weak self] result in
            guard let self else { return }
            self.pendingKeys.remove(stationKey)
            if case .failure(let error) = result {
                if shouldFavorite { self.favorites.remove(stationKey) } else { self.favorites.insert(stationKey) }
                self.messages.present(.auth(AuthError.map(error)))
            }
        }
    }

    var favoriteStations: [Station] {
        stationData.stations.filter { favorites.contains($0.statusKey) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var recentStations: [Station] {
        recentRoutes.compactMap { recent in
            stationData.stations.first { $0.id == recent.stationID || $0.statusKey == recent.stationKey }
        }
    }

    func recordRouteOpened(_ station: Station) {
        recentRoutes.removeAll { $0.stationID == station.id || $0.stationKey == station.statusKey }
        recentRoutes.insert(
            RecentStationRoute(stationID: station.id, stationKey: station.statusKey, openedAt: Date()),
            at: 0
        )
        recentRoutes = Array(recentRoutes.prefix(12))
        persistence.recentRoutes = recentRoutes
    }
}
