import Foundation
import Testing
@testable import SarjBulCore

@Suite
struct FirebaseRealtimeEventDecoderTests {
    @Test
    func rootPutProducesCompleteStatusSnapshot() throws {
        let data = freshStatusData(#"{"path":"/","data":{"station_a":{"durum":"aktif","toplam":2}}}"#)
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
        let data = freshStatusData(#"{"path":"/","data":{"station_a":{"durum":"riskli"},"station_b":null}}"#)
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
        let data = freshStatusData(#"{"path":"/station_a","data":null}"#)
        let events = try FirebaseRealtimeEventDecoder.decode(channel: .insights, data: data)

        guard case .insightChanged(let key, let value) = events.first else {
            Issue.record("Expected an insight deletion")
            return
        }
        #expect(key == "station_a")
        #expect(value == nil)
    }

    @Test
    func independentBackendInsightFieldsDecodeWithoutTheOtherChannel() throws {
        let decoder = JSONDecoder()
        let occupancy = try decoder.decode(StationCommunityInsight.self, from: Data(
            #"{"saatlik_yogunluk":{"2-15":{"busy":1,"available":0}}}"#.utf8
        ))
        #expect(occupancy.fields.isEmpty)
        #expect(occupancy.occupancy["2-15"]?.busy == 1)
        let fields = try decoder.decode(StationCommunityInsight.self, from: freshStatusData(#"{"alanlar":{}}"#))
        #expect(fields.occupancy.isEmpty)
    }

    @Test
    func partialAndNestedPatchesPreserveOtherInsightFields() throws {
        var accumulator = FirebaseRealtimeEventAccumulator()
        _ = try accumulator.decode(channel: .insights, data: Data(
            #"{"path":"/","data":{"a":{"saatlik_yogunluk":{"2-15":{"busy":1,"available":0}}}}}"#.utf8
        ))
        let patch = freshStatusData(#"{"path":"/a","data":{"alanlar":{},"guncelleme_tarihi":"2026-10-12T12:00:00Z"}}"#)
        let events = try accumulator.decode(channel: .insights, eventName: "patch", data: patch)
        guard case .insightChanged(_, let value) = events.first else {
            Issue.record("Expected a merged insight")
            return
        }
        #expect(value?.occupancy["2-15"]?.busy == 1)
        let nested = try accumulator.decode(channel: .insights, data: Data(
            #"{"path":"/a/saatlik_yogunluk/2-15/busy","data":3}"#.utf8
        ))
        guard case .insightChanged(_, let updated) = nested.first else {
            Issue.record("Missing nested delta")
            return
        }
        #expect(updated?.occupancy["2-15"]?.busy == 3)
        #expect(updated?.updatedAt == "2026-10-12T12:00:00Z")
    }

    @Test
    func invalidPatchCannotDeleteOrCorruptAnExistingRecord() throws {
        var accumulator = FirebaseRealtimeEventAccumulator()
        _ = try accumulator.decode(channel: .statuses, data: freshStatusData(
            #"{"path":"/","data":{"a":{"durum":"aktif","toplam":2}}}"#
        ))
        #expect(throws: (any Error).self) {
            try accumulator.decode(channel: .statuses, eventName: "patch", data: Data(
                #"{"path":"/a","data":{"toplam":"broken"}}"#.utf8
            ))
        }
        let events = try accumulator.decode(channel: .statuses, eventName: "patch", data: Data(
            #"{"path":"/","data":{"a/durum":"riskli"}}"#.utf8
        ))
        guard case .statusChanged(_, let value) = events.first else {
            Issue.record("Missing status")
            return
        }
        #expect(value?.durum == "riskli")
        #expect(value?.toplam == 2)
    }
    private func freshStatusData(_ json: String) -> Data {
        let now = Int64(Date().timeIntervalSince1970 * 1_000)
        let replacement = "\"durum\":\"" // Add observation metadata to status fixtures only.
        let stamped = json.replacingOccurrences(of: replacement, with:
            "\"observedAtMilliseconds\":\(now),\"validUntilMilliseconds\":\(now + 86_400_000)," + replacement)
        return Data(stamped.utf8)
    }

}
