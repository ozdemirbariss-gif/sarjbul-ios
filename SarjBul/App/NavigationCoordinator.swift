import Observation
import SwiftUI

enum AppTab: Hashable, Sendable {
    case home
    case routes
    case lounge
    case account
}

enum AppRoute: Hashable, Sendable {
    case station(key: String)
}

@MainActor
@Observable
final class NavigationCoordinator {
    var tab: AppTab = .account
    var homePath = NavigationPath()
    var routesPath = NavigationPath()
    var loungePath = NavigationPath()
    var accountPath = NavigationPath()

    func select(_ tab: AppTab) {
        self.tab = tab
    }

    func push(_ route: AppRoute, on tab: AppTab) {
        self.tab = tab
        switch tab {
        case .home: homePath.append(route)
        case .routes: routesPath.append(route)
        case .lounge: loungePath.append(route)
        case .account: accountPath.append(route)
        }
    }

    func reset(_ tab: AppTab) {
        switch tab {
        case .home: homePath = NavigationPath()
        case .routes: routesPath = NavigationPath()
        case .lounge: loungePath = NavigationPath()
        case .account: accountPath = NavigationPath()
        }
    }
}
