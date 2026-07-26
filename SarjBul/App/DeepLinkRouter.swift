import Foundation
import Observation
import SarjBulCore

@MainActor
@Observable
final class DeepLinkRouter {
    private let search: SearchCoordinator
    private let navigation: NavigationCoordinator

    init(search: SearchCoordinator, navigation: NavigationCoordinator) {
        self.search = search
        self.navigation = navigation
    }

    func handle(_ url: URL) async {
        guard let route = DeepLinkRouteParser.parse(url) else { return }
        switch route {
        case .station(let key):
            await search.openStation(withKey: key)
        case .nearestFast:
            await search.openNearestFast()
        case .lounge:
            navigation.select(.lounge)
        }
    }
}
