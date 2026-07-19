import Foundation
import Observation
import SarjBulCore

@MainActor
@Observable
final class DeepLinkRouter {
    private let search: SearchCoordinator

    init(search: SearchCoordinator) {
        self.search = search
    }

    func handle(_ url: URL) async {
        guard let route = DeepLinkRouteParser.parse(url) else { return }
        switch route {
        case .station(let key):
            await search.openStation(withKey: key)
        }
    }
}
