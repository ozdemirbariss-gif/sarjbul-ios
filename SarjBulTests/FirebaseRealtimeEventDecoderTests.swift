import Foundation
import Testing
@testable import SarjBulCore

@Suite
struct FirebaseRealtimeEventDecoderTests {
    @Test
    func rootPutProducesCompleteStatusSnapshot() throws {
        let data = Data(#"{"path":"/","data":{"station_a":{"durum":"aktif","toplam":2}}}"#.utf8)
        let events = try FirebaseRealtimeEventDecoder.decode(channel: .statuses, data: data)

        guard case .statusesSnapshot(let values) = events.first else {
            Issue.record("Expected a complete status snapshot")
            return
        }
        #expect(values["station_a"]?.durum == "aktif")
        #expect(values["station_a"]?.toplam == 2)
    }

    @Test
    func rootPatchProducesDeltasWithoutReplacingSnapshot() throws {
        let data = Data(#"{"path":"/","data":{"station_a":{"durum":"riskli"},"station_b":null}}"#.utf8)
        let events = try FirebaseRealtimeEventDecoder.decode(
            channel: .statuses,
            eventName: "patch",
            data: data
        )

        #expect(events.count == 2)
        #expect(events.contains { event in
            guard case .statusChanged(let key, let value) = event else { return false }
            return key == "station_a" && value?.durum == "riskli"
        })
        #expect(events.contains { event in
            guard case .statusChanged(let key, let value) = event else { return false }
            return key == "station_b" && value == nil
        })
    }

    @Test
    func childDeleteProducesNilDelta() throws {
        let data = Data(#"{"path":"/station_a","data":null}"#.utf8)
        let events = try FirebaseRealtimeEventDecoder.decode(channel: .insights, data: data)

        guard case .insightChanged(let key, let value) = events.first else {
            Issue.record("Expected an insight deletion")
            return
        }
        #expect(key == "station_a")
        #expect(value == nil)
    }
}
