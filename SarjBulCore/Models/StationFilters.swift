import Foundation

public struct StationFilters: Equatable, Sendable {
    public var preference: RoutePreference
    public var searchText: String
    public var minimumPowerKW: Double
    public var socketFilters: Set<String>
    public var operatorFilters: Set<String>
    public var rangeFilterEnabled: Bool

    public init(
        preference: RoutePreference = .balanced,
        searchText: String = "",
        minimumPowerKW: Double = 0,
        socketFilters: Set<String> = [],
        operatorFilters: Set<String> = [],
        rangeFilterEnabled: Bool = true
    ) {
        self.preference = preference
        self.searchText = searchText
        self.minimumPowerKW = minimumPowerKW
        self.socketFilters = socketFilters
        self.operatorFilters = operatorFilters
        self.rangeFilterEnabled = rangeFilterEnabled
    }
}

