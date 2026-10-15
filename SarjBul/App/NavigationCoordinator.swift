import Observation
import SarjBulCore
import SwiftUI

enum AppTab: Hashable, Sendable {
    case home
    case routes
    case saved
    case account
}

enum AppRoute: Hashable, Sendable {
    case station(key: String)
}

struct ActiveRouteMap {
    let candidate: StationCandidate
    let origin: UserLocation
    let route: StationRoute
    var externalApp: NavigationAppPreference?
}

@MainActor
@Observable
final class NavigationCoordinator {
    var tab: AppTab = .home
    var homePath = NavigationPath()
    var routesPath = NavigationPath()
    var savedPath = NavigationPath()
    var accountPath = NavigationPath()
    private(set) var activeRouteMap: ActiveRouteMap?
    var routeMapPresented = false

    func openRouteMap(candidate: StationCandidate, origin: UserLocation, route: StationRoute) {
        activeRouteMap = ActiveRouteMap(candidate: candidate, origin: origin, route: route)
        routeMapPresented = true
    }

    func expandRouteMap() {
        guard activeRouteMap != nil else { return }
        routeMapPresented = true
    }

    func collapseRouteMap() {
        routeMapPresented = false
    }

    func recordExternalMap(_ preference: NavigationAppPreference, stationID: String) {
        guard activeRouteMap?.candidate.id == stationID else { return }
        activeRouteMap?.externalApp = preference
    }

    func closeRouteMap() {
        routeMapPresented = false
        activeRouteMap = nil
    }

    func select(_ tab: AppTab) {
        self.tab = tab
    }

    func push(_ route: AppRoute, on tab: AppTab) {
        self.tab = tab
        switch tab {
        case .home: homePath.append(route)
        case .routes: routesPath.append(route)
        case .saved: savedPath.append(route)
        case .account: accountPath.append(route)
        }
    }

    func reset(_ tab: AppTab) {
        switch tab {
        case .home: homePath = NavigationPath()
        case .routes: routesPath = NavigationPath()
        case .saved: savedPath = NavigationPath()
        case .account: accountPath = NavigationPath()
        }
    }
}
