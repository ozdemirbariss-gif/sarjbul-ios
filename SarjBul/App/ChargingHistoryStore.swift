import Foundation
import Observation
import SarjBulCore

@MainActor
@Observable
final class ChargingHistoryStore {
    private let persistence: any AppPersistence
    private(set) var records: [ChargingSessionRecord]

    init(persistence: any AppPersistence) {
        self.persistence = persistence
        records = persistence.chargingSessions
    }

    func add(_ record: ChargingSessionRecord) {
        records.insert(record, at: 0)
        records = Array(records.prefix(500))
        persistence.chargingSessions = records
    }

    func delete(at offsets: IndexSet) {
        for offset in offsets.sorted(by: >) where records.indices.contains(offset) {
            records.remove(at: offset)
        }
        persistence.chargingSessions = records
    }

    func summary(profile: DrivingProfile, year: Int = Calendar.current.component(.year, from: Date())) -> ChargingYearSummary {
        ChargingHistoryAnalytics.summary(records: records, profile: profile, year: year)
    }
}
