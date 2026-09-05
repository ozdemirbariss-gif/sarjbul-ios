import Foundation
import Testing
@testable import SarjBulCore

@Suite
struct StationAvailabilityPipelineTests {
    @Test(arguments: [false, true])
    func localSearchDoesNotWaitForAvailability(fails: Bool) async throws {
        let station = Station(id: "test", name: "Test", address: "Test", latitude: 38.4, longitude: 27.1,
                              power: "50 kW", operatorName: "Test", socket: "CCS", price: "10 TL", source: "test")
        let client = GatedAvailabilityClient(fails: fails)
        let pipeline = StationDataPipeline(repository: AvailabilityTestRepository(station: station),
                                           statusClient: UnavailableStatusClient(), liveAvailabilityClient: client)
        _ = try await pipeline.loadStations()
        let updates = await pipeline.availabilityUpdates()
        let received = AvailabilityResults()
        let observer = Task {
            for await event in updates {
                if case .availabilitySnapshot(let values) = event {
                    await received.set(values)
                }
            }
        }
        defer { observer.cancel() }
        // This releases even a regressed, blocking implementation so the test fails instead of hanging.
        let watchdog = Task {
            try? await Task.sleep(for: .seconds(1))
            await client.release()
        }
        defer { watchdog.cancel() }
        let origin = UserLocation(latitude: station.latitude, longitude: station.longitude, source: .manual)
        let first = await pipeline.search(origin: origin, destination: nil, routePoints: [],
                                          profile: DrivingProfile(), filters: StationFilters(), limit: 24)
        #expect(first.count == 1)
        #expect(first.first?.liveAvailability == nil)
        #expect(await !client.released)
        await client.release()
        for _ in 0..<200 {
            if await client.completed { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(await client.completed)
        for _ in 0..<200 {
            let delivered = await received.values[station.statusKey] != nil
            if fails || delivered { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        let second = await pipeline.search(origin: origin, destination: nil, routePoints: [],
                                           profile: DrivingProfile(), filters: StationFilters(), limit: 24)
        if fails {
            #expect(second.first?.liveAvailability == nil)
        } else {
            #expect(await received.values[station.statusKey]?.availableConnectors == 2)
            #expect(second.first?.liveAvailability?.availableConnectors == 2)
        }
        #expect(await client.requests == 1)
    }
}

private struct AvailabilityTestRepository: StationRepository {
    let station: Station
    func loadStations() async throws -> [Station] { [station] }
}

private actor AvailabilityResults {
    var values: [String: LiveStationAvailability] = [:]
    func set(_ values: [String: LiveStationAvailability]) { self.values = values }
}

private actor GatedAvailabilityClient: LiveAvailabilityClient {
    let fails: Bool
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var released = false
    private(set) var requests = 0
    private(set) var completed = false
    init(fails: Bool) { self.fails = fails }
    func availability(stationKeys: [String]) async throws -> [String: LiveStationAvailability] {
        requests += 1
        if !released { await withCheckedContinuation { continuation = $0 } }
        defer { completed = true }
        if fails { throw URLError(.timedOut) }
        return Dictionary(uniqueKeysWithValues: stationKeys.map { key in
            (key, LiveStationAvailability(stationKey: key, availableConnectors: 2, totalConnectors: 4, updatedAt: Date()))
        })
    }
    func release() {
        released = true
        continuation?.resume()
        continuation = nil
    }
}
