import Foundation

public enum AutomationRuleID: String, Codable, Sendable {
    case stationDataStale
    case preparedRouteRisky
    case preparedRouteExpired
    case lowCharge
}

public enum AutomationAction: String, Codable, Sendable {
    case refreshStationData
    case replacePreparedRoute
    case prepareChargingRoute
}

public struct AutomationSnapshot: Equatable, Sendable {
    public var isEnabled: Bool
    public var chargePercent: Int
    public var triggerChargePercent: Int
    public var stationDataAge: TimeInterval?
    public var hasPreparedRoute: Bool
    public var preparedRouteIsRisky: Bool
    public var preparedRouteIsExpired: Bool

    public init(
        isEnabled: Bool,
        chargePercent: Int,
        triggerChargePercent: Int,
        stationDataAge: TimeInterval?,
        hasPreparedRoute: Bool,
        preparedRouteIsRisky: Bool,
        preparedRouteIsExpired: Bool
    ) {
        self.isEnabled = isEnabled
        self.chargePercent = chargePercent
        self.triggerChargePercent = triggerChargePercent
        self.stationDataAge = stationDataAge
        self.hasPreparedRoute = hasPreparedRoute
        self.preparedRouteIsRisky = preparedRouteIsRisky
        self.preparedRouteIsExpired = preparedRouteIsExpired
    }
}

public struct AutomationPlan: Equatable, Sendable {
    public var rule: AutomationRuleID
    public var actions: [AutomationAction]

    public init(rule: AutomationRuleID, actions: [AutomationAction]) {
        self.rule = rule
        self.actions = actions
    }
}

public struct AutomationReport: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var rule: AutomationRuleID
    public var actions: [AutomationAction]
    public var previousStationName: String?
    public var selectedStationName: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        rule: AutomationRuleID,
        actions: [AutomationAction],
        previousStationName: String? = nil,
        selectedStationName: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.rule = rule
        self.actions = actions
        self.previousStationName = previousStationName
        self.selectedStationName = selectedStationName
        self.createdAt = createdAt
    }
}

/// Produces deterministic, safe and reversible work. Side effects are executed by the app layer.
public struct TriggerActionEngine: Sendable {
    public static let staleStationDataInterval: TimeInterval = 6 * 3_600

    public init() {}

    public func plan(for snapshot: AutomationSnapshot) -> AutomationPlan? {
        guard snapshot.isEnabled else { return nil }

        if snapshot.preparedRouteIsRisky {
            return AutomationPlan(
                rule: .preparedRouteRisky,
                actions: [.refreshStationData, .replacePreparedRoute]
            )
        }
        if snapshot.preparedRouteIsExpired {
            return AutomationPlan(
                rule: .preparedRouteExpired,
                actions: [.replacePreparedRoute]
            )
        }
        if snapshot.stationDataAge.map({ $0 >= Self.staleStationDataInterval }) ?? true {
            return AutomationPlan(
                rule: .stationDataStale,
                actions: snapshot.chargePercent > snapshot.triggerChargePercent
                    ? [.refreshStationData]
                    : snapshot.hasPreparedRoute
                        ? [.refreshStationData, .replacePreparedRoute]
                        : [.refreshStationData, .prepareChargingRoute]
            )
        }
        if snapshot.chargePercent <= snapshot.triggerChargePercent, !snapshot.hasPreparedRoute {
            return AutomationPlan(rule: .lowCharge, actions: [.prepareChargingRoute])
        }
        return nil
    }
}
