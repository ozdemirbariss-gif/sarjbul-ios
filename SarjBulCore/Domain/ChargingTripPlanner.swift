import Foundation

public struct RouteElevationProfile: Equatable, Sendable {
    public var gainMeters: Double
    public var lossMeters: Double

    public init(gainMeters: Double = 0, lossMeters: Double = 0) {
        self.gainMeters = max(0, gainMeters)
        self.lossMeters = max(0, lossMeters)
    }
}

public struct PlannedChargingStop: Identifiable, Equatable, Sendable {
    public var candidate: StationCandidate
    public var arrivalPercent: Int
    public var departurePercent: Int
    public var chargingMinutes: Int

    public var id: String { candidate.id }

    public init(
        candidate: StationCandidate,
        arrivalPercent: Int,
        departurePercent: Int,
        chargingMinutes: Int
    ) {
        self.candidate = candidate
        self.arrivalPercent = arrivalPercent
        self.departurePercent = departurePercent
        self.chargingMinutes = chargingMinutes
    }
}

public struct ChargingTripPlan: Equatable, Sendable {
    public var distanceKm: Double
    public var drivingMinutes: Int
    public var chargingMinutes: Int
    public var arrivalPercent: Int
    public var stops: [PlannedChargingStop]
    public var elevationAdjusted: Bool

    public init(
        distanceKm: Double,
        drivingMinutes: Int,
        chargingMinutes: Int,
        arrivalPercent: Int,
        stops: [PlannedChargingStop],
        elevationAdjusted: Bool
    ) {
        self.distanceKm = distanceKm
        self.drivingMinutes = drivingMinutes
        self.chargingMinutes = chargingMinutes
        self.arrivalPercent = arrivalPercent
        self.stops = stops
        self.elevationAdjusted = elevationAdjusted
    }

    public var totalMinutes: Int { drivingMinutes + chargingMinutes }
}

public enum ChargingCurve {
    public static func minutes(
        from startPercent: Int,
        to endPercent: Int,
        batteryKWh: Double,
        stationPowerKW: Double
    ) -> Double {
        guard endPercent > startPercent, batteryKWh > 0, stationPowerKW > 0 else { return 0 }
        var minutes = 0.0
        for percent in startPercent..<endPercent {
            let effectivePower = min(stationPowerKW, batteryKWh * 3) * multiplier(at: Double(percent) + 0.5)
            let energy = batteryKWh / 100
            minutes += energy / max(3.6, effectivePower) * 60
        }
        return minutes
    }

    public static func multiplier(at percent: Double) -> Double {
        switch percent {
        case ..<10: 0.58
        case ..<50: 1
        case ..<80: 0.74
        default: 0.34
        }
    }
}

public struct ChargingTripPlanner: Sendable {
    private let socStep = 5
    private let minimumArrivalPercent = 8
    private let maximumSOC = 95

    public init() {}

    public func plan(
        routeDistanceKm: Double,
        candidates: [StationCandidate],
        profile: DrivingProfile,
        estimatedDrivingMinutes: Int? = nil,
        elevation: RouteElevationProfile = .init()
    ) -> ChargingTripPlan? {
        guard routeDistanceKm > 0, profile.batteryKWh > 0, profile.consumptionKWhPer100Km > 0 else {
            return nil
        }

        let eligibleStations = candidates
            .filter { $0.distanceKm > 0.5 && $0.distanceKm < routeDistanceKm - 0.5 && !$0.hasRiskyStatus }
            .sorted { $0.distanceKm < $1.distanceKm }
        let usableStations = distributedCandidates(
            eligibleStations,
            routeDistanceKm: routeDistanceKm,
            maximumCount: 60
        )
        let nodes = [PlannerNode.origin] + usableStations.map(PlannerNode.station) + [.destination(routeDistanceKm)]
        let startSOC = max(socStep, min(maximumSOC, profile.chargePercent / socStep * socStep))
        let start = PlannerState(node: 0, soc: startSOC)
        var distances: [PlannerState: Double] = [start: 0]
        var previous: [PlannerState: Transition] = [:]
        var queue = MinPriorityQueue<(PlannerState, Double)>()
        queue.push((start, 0), priority: 0)
        var destinationState: PlannerState?

        while let (state, knownCost) = queue.pop() {
            guard knownCost <= (distances[state] ?? .infinity) + 0.0001 else { continue }
            if state.node == nodes.count - 1 {
                destinationState = state
                break
            }

            if state.node > 0, state.node < nodes.count - 1, state.soc < maximumSOC {
                let nextSOC = min(maximumSOC, state.soc + socStep)
                let power = max(7.4, nodes[state.node].powerKW)
                let chargeMinutes = ChargingCurve.minutes(
                    from: state.soc,
                    to: nextSOC,
                    batteryKWh: profile.batteryKWh,
                    stationPowerKW: power
                )
                relax(
                    from: state,
                    to: PlannerState(node: state.node, soc: nextSOC),
                    addedCost: chargeMinutes,
                    transition: .charge(minutes: chargeMinutes),
                    distances: &distances,
                    previous: &previous,
                    queue: &queue
                )
            }

            for nextNode in (state.node + 1)..<nodes.count {
                let segmentDistance = nodes[nextNode].distanceKm - nodes[state.node].distanceKm
                let energy = segmentEnergy(
                    distanceKm: segmentDistance,
                    routeDistanceKm: routeDistanceKm,
                    profile: profile,
                    elevation: elevation
                )
                let spentPercent = Int(ceil(energy / profile.batteryKWh * 100 / Double(socStep))) * socStep
                let arrivalSOC = state.soc - spentPercent
                guard arrivalSOC >= (nextNode == nodes.count - 1 ? minimumArrivalPercent : socStep) else {
                    if nextNode == state.node + 1 { continue }
                    break
                }
                let driveMinutes = segmentDistance / 82 * 60
                relax(
                    from: state,
                    to: PlannerState(node: nextNode, soc: arrivalSOC),
                    addedCost: driveMinutes,
                    transition: .drive,
                    distances: &distances,
                    previous: &previous,
                    queue: &queue
                )
            }
        }

        guard let destinationState else { return nil }
        var transitions: [(PlannerState, PlannerState, Transition.Kind)] = []
        var cursor = destinationState
        while cursor != start, let item = previous[cursor] {
            transitions.append((item.from, cursor, item.transition))
            cursor = item.from
        }
        transitions.reverse()

        var stops: [PlannedChargingStop] = []
        var chargingMinutes = 0.0
        var index = 0
        while index < transitions.count {
            let transition = transitions[index]
            guard case .charge = transition.2,
                  case .station(let candidate) = nodes[transition.0.node] else {
                index += 1
                continue
            }
            let arrivalSOC = transition.0.soc
            var departureSOC = transition.1.soc
            var stopMinutes = 0.0
            while index < transitions.count,
                  transitions[index].0.node == transition.0.node,
                  case .charge(let minutes) = transitions[index].2 {
                stopMinutes += minutes
                departureSOC = transitions[index].1.soc
                index += 1
            }
            chargingMinutes += stopMinutes
            stops.append(PlannedChargingStop(
                candidate: candidate,
                arrivalPercent: arrivalSOC,
                departurePercent: departureSOC,
                chargingMinutes: Int(ceil(stopMinutes))
            ))
        }

        return ChargingTripPlan(
            distanceKm: routeDistanceKm,
            drivingMinutes: estimatedDrivingMinutes ?? Int(ceil(routeDistanceKm / 82 * 60)),
            chargingMinutes: Int(ceil(chargingMinutes)),
            arrivalPercent: destinationState.soc,
            stops: stops,
            elevationAdjusted: elevation.gainMeters > 0 || elevation.lossMeters > 0
        )
    }

    private func segmentEnergy(
        distanceKm: Double,
        routeDistanceKm: Double,
        profile: DrivingProfile,
        elevation: RouteElevationProfile
    ) -> Double {
        let share = distanceKm / max(0.1, routeDistanceKm)
        let base = distanceKm * profile.consumptionKWhPer100Km / 100
        let climbing = elevation.gainMeters * share * 0.0015
        let regeneration = elevation.lossMeters * share * 0.0006
        return max(0, base + climbing - regeneration)
    }

    private func distributedCandidates(
        _ candidates: [StationCandidate],
        routeDistanceKm: Double,
        maximumCount: Int
    ) -> [StationCandidate] {
        guard candidates.count > maximumCount else { return candidates }
        let bucketWidth = max(1, routeDistanceKm / Double(maximumCount))
        let groups = Dictionary(grouping: candidates) {
            min(maximumCount - 1, Int($0.distanceKm / bucketWidth))
        }
        return groups.values.compactMap { bucket in
            bucket.max {
                if $0.station.powerKW != $1.station.powerKW {
                    return $0.station.powerKW < $1.station.powerKW
                }
                if $0.routeDeviationKm != $1.routeDeviationKm {
                    return $0.routeDeviationKm > $1.routeDeviationKm
                }
                return $0.score < $1.score
            }
        }
        .sorted { $0.distanceKm < $1.distanceKm }
    }

    private func relax(
        from: PlannerState,
        to: PlannerState,
        addedCost: Double,
        transition: Transition.Kind,
        distances: inout [PlannerState: Double],
        previous: inout [PlannerState: Transition],
        queue: inout MinPriorityQueue<(PlannerState, Double)>
    ) {
        let newCost = (distances[from] ?? .infinity) + addedCost
        guard newCost < (distances[to] ?? .infinity) else { return }
        distances[to] = newCost
        previous[to] = Transition(from: from, transition: transition)
        queue.push((to, newCost), priority: newCost)
    }
}

private enum PlannerNode {
    case origin
    case station(StationCandidate)
    case destination(Double)

    var distanceKm: Double {
        switch self {
        case .origin: 0
        case .station(let candidate): candidate.distanceKm
        case .destination(let distance): distance
        }
    }

    var powerKW: Double {
        if case .station(let candidate) = self { return candidate.station.powerKW }
        return 0
    }
}

private struct PlannerState: Hashable {
    var node: Int
    var soc: Int
}

private struct Transition {
    enum Kind {
        case drive
        case charge(minutes: Double)
    }

    var from: PlannerState
    var transition: Kind
}

private struct MinPriorityQueue<Element> {
    private var heap: [(priority: Double, element: Element)] = []

    mutating func push(_ element: Element, priority: Double) {
        heap.append((priority, element))
        var child = heap.count - 1
        while child > 0 {
            let parent = (child - 1) / 2
            guard heap[child].priority < heap[parent].priority else { break }
            heap.swapAt(child, parent)
            child = parent
        }
    }

    mutating func pop() -> Element? {
        guard !heap.isEmpty else { return nil }
        if heap.count == 1 { return heap.removeLast().element }
        let result = heap[0].element
        heap[0] = heap.removeLast()
        var parent = 0
        while true {
            let left = parent * 2 + 1
            let right = left + 1
            var smallest = parent
            if left < heap.count, heap[left].priority < heap[smallest].priority { smallest = left }
            if right < heap.count, heap[right].priority < heap[smallest].priority { smallest = right }
            guard smallest != parent else { break }
            heap.swapAt(parent, smallest)
            parent = smallest
        }
        return result
    }
}
