import CryptoKit
import Foundation
import Testing
@testable import SarjBulCore

@Suite
struct ProductIntelligenceTests {
    @Test
    func chargingCurvePenalizesHighStateOfCharge() {
        let fastBand = ChargingCurve.minutes(from: 20, to: 40, batteryKWh: 75, stationPowerKW: 180)
        let slowBand = ChargingCurve.minutes(from: 80, to: 100, batteryKWh: 75, stationPowerKW: 180)

        #expect(slowBand > fastBand * 2)
    }

    @Test
    func tripPlannerFindsReachableFastChargingStops() {
        let profile = DrivingProfile(
            batteryKWh: 75,
            chargePercent: 30,
            consumptionKWhPer100Km: 18,
            safetyMarginPercent: 20
        )
        let candidates = [80.0, 155.0, 230.0].enumerated().map { index, distance in
            makeCandidate(id: "stop-\(index)", distance: distance, power: 180)
        }

        let plan = ChargingTripPlanner().plan(
            routeDistanceKm: 300,
            candidates: candidates,
            profile: profile,
            estimatedDrivingMinutes: 220,
            elevation: RouteElevationProfile(gainMeters: 1_200, lossMeters: 500)
        )

        #expect(plan != nil)
        #expect(plan?.stops.isEmpty == false)
        #expect(plan?.chargingMinutes ?? 0 > 0)
        #expect(plan?.elevationAdjusted == true)
    }

    @Test
    func tripPlannerSkipsChargeWhenDestinationIsReachable() {
        let plan = ChargingTripPlanner().plan(
            routeDistanceKm: 40,
            candidates: [],
            profile: DrivingProfile(chargePercent: 80)
        )

        #expect(plan?.stops.isEmpty == true)
        #expect(plan?.arrivalPercent ?? 0 > 8)
    }

    @Test
    func tripPlannerKeepsStopsDistributedAcrossLongRoutes() {
        let denseOriginCluster = (1...100).map {
            makeCandidate(id: "origin-\($0)", distance: Double($0), power: 90)
        }
        let corridorStops = [180.0, 260, 340, 420, 500].enumerated().map {
            makeCandidate(id: "corridor-\($0.offset)", distance: $0.element, power: 180)
        }
        let plan = ChargingTripPlanner().plan(
            routeDistanceKm: 580,
            candidates: denseOriginCluster + corridorStops,
            profile: DrivingProfile(
                batteryKWh: 75,
                chargePercent: 30,
                consumptionKWhPer100Km: 18,
                safetyMarginPercent: 20
            )
        )

        #expect(plan != nil)
        #expect(plan?.stops.contains { $0.candidate.distanceKm >= 180 } == true)
    }

    @Test
    func oldSourceConfidenceDecays() throws {
        let now = try #require(ISO8601DateFormatter().date(from: "2026-07-01T00:00:00Z"))
        let station = Station(
            id: "old",
            name: "Old",
            address: "Ankara",
            latitude: 39.9,
            longitude: 32.8,
            power: "120 kW",
            operatorName: "Test",
            socket: "CCS",
            price: "10 TL",
            source: "test",
            updatedAt: "2026-03-03T00:00:00Z",
            confidenceScore: 0.9
        )

        let confidence = StationDataQuality.confidence(station: station, insight: nil, now: now)

        #expect(confidence > 0.43)
        #expect(confidence < 0.47)
    }

    @Test
    func twoIndependentConfirmationsCanReplaceUnknownValue() {
        let insight = StationCommunityInsight(fields: [
            StationDataField.price.rawValue: StationFieldVerification(
                value: "12,50 TL/kWh",
                confirmationCount: 2,
                independentUserCount: 2,
                confidence: 0.78,
                verified: true
            )
        ])

        #expect(StationDataQuality.displayValue(
            sourceValue: "Bilinmiyor",
            field: .price,
            insight: insight
        ) == "12,50 TL/kWh")
    }

    @Test
    func occupancyPredictionUsesHourlyEvidenceWithoutOverconfidence() {
        let station = makeStation(id: "mall", power: 120)
        let insight = StationCommunityInsight(occupancy: [
            "2-18": OccupancyObservationBucket(busy: 8, available: 2)
        ])
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 18))!

        let prediction = OccupancyPredictor.predict(station: station, insight: insight, date: date, calendar: calendar)

        #expect(prediction.busyProbability > 0.65)
        #expect(prediction.busyProbability < 0.9)
        #expect(prediction.confidence == .medium)
    }

    @Test
    func receiptParserReadsTurkishEnergyAndTotal() {
        let receipt = ChargingReceiptParser.parse("Enerji: 32,50 kWh\nToplam: 406,25 TL")

        #expect(receipt.energyKWh == 32.5)
        #expect(receipt.totalCostTRY == 406.25)
        #expect(abs((receipt.unitPriceTRY ?? 0) - 12.5) < 0.01)
    }

    @Test
    func numberParserHandlesGeneratedTurkishDecimals() {
        for integer in stride(from: 1, through: 99, by: 7) {
            for decimal in [0, 1, 25, 50, 99] {
                let text = "\(integer),\(String(format: "%02d", decimal)) TL/kWh"
                let expected = Double(integer) + Double(decimal) / 100
                #expect(abs((NumberParser.firstDecimal(in: text) ?? -1) - expected) < 0.0001)
            }
        }
    }

    @Test
    func relativeDatasetQualityGateRejectsSilentCollapse() {
        #expect(StationDatasetQualityGate.minimumAcceptedCount(referenceCount: 12_936) == 9_055)
        #expect(StationDatasetQualityGate.accepts(candidateCount: 9_055, referenceCount: 12_936))
        #expect(!StationDatasetQualityGate.accepts(candidateCount: 1_200, referenceCount: 12_936))
    }

    @Test
    func scorerStaysInsidePublishedBounds() {
        for distance in [0.1, 2, 5, 20, 60, 500] {
            for power in [0.0, 7, 22, 50, 150, 350] {
                let score = StationScorer.score(candidate: makeCandidate(
                    id: "\(distance)-\(power)",
                    distance: distance,
                    power: power
                ))
                #expect((1...100).contains(score))
            }
        }
    }

    @Test
    func chargingHistoryBuildsWrappedAndProvinceCollection() {
        let records = [
            ChargingSessionRecord(
                date: Date(timeIntervalSince1970: 1_767_225_600),
                stationName: "İzmir",
                operatorName: "Trugo",
                province: "İzmir",
                energyKWh: 40,
                totalCostTRY: 500
            ),
            ChargingSessionRecord(
                date: Date(timeIntervalSince1970: 1_769_904_000),
                stationName: "Ankara",
                operatorName: "Trugo",
                province: "Ankara",
                energyKWh: 30,
                totalCostTRY: 390
            )
        ]
        let summary = ChargingHistoryAnalytics.summary(
            records: records,
            profile: DrivingProfile(consumptionKWhPer100Km: 17),
            year: 2026,
            calendar: Calendar(identifier: .gregorian)
        )

        #expect(summary.sessionCount == 2)
        #expect(summary.favoriteOperator == "Trugo")
        #expect(summary.visitedProvinces == ["İzmir", "Ankara"])
    }

    @Test
    func holidayAdvisorActivatesOnlyInsideKnownMigrationWindow() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let active = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 27)))
        let normal = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 19)))

        #expect(HolidayTrafficAdvisor.advice(for: active, calendar: calendar) != nil)
        #expect(HolidayTrafficAdvisor.advice(for: normal, calendar: calendar) == nil)
    }

    @Test
    func fastWidgetDeepLinkParsesAsTypedRoute() throws {
        let url = try #require(URL(string: "sarjbul://quick/fast"))
        #expect(DeepLinkRouteParser.parse(url) == .nearestFast)

        let loungeURL = try #require(URL(string: "sarjbul://lounge"))
        #expect(DeepLinkRouteParser.parse(loungeURL) == .lounge)
    }

    @Test
    func optInDemandEventNeverContainsPreciseCoordinatesOrIdentity() {
        let event = SearchDemandEvent(
            location: UserLocation(latitude: 38.3939, longitude: 27.1891, source: .device),
            preference: .fastest,
            searchRadiusKm: 82,
            resultCount: 14,
            date: Date(timeIntervalSince1970: 1_768_780_800)
        )

        #expect(event.coarseCell == "38p3_27p1")
        #expect(event.radiusBucketKm == 100)
        #expect(event.resultBucket == "6-20")
        #expect(event.preference == "fastest")
    }

    @Test
    func licensedOperatorMatchingUsesRegistryBrands() {
        let records = [LicensedOperatorRecord(
            licenseNumber: "ŞH/1",
            holder: "AYDEM PLUS ENERJİ",
            brands: ["otoWATT"]
        )]

        #expect(LicensedOperatorRegistry.match("otoWATT", records: records)?.licenseNumber == "ŞH/1")
        #expect(LicensedOperatorRegistry.match("Unrelated Charge", records: records) == nil)
    }

    @Test
    func thematicCollectionsTrackIndependentProvinceProgress() {
        let progress = ChargingCollections.progress(visitedProvinces: ["Ankara", "Erzurum", "Kars", "İzmir"])
        let east = progress.first { $0.kind == .eastExpress }
        let aegean = progress.first { $0.kind == .aegeanTour }

        #expect(east?.visitedCount == 3)
        #expect(aegean?.visitedCount == 1)
        #expect(east?.isComplete == false)
    }

    @Test
    func tiledRepositoryFallsBackWhenCachedTileIsCorrupt() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let bundle = root.appending(path: "bundle", directoryHint: .isDirectory)
        let cache = root.appending(path: "cache", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let tileFile = "station_tile_sxk.json"
        let tileData = try JSONEncoder().encode([makeStation(id: "bundled", power: 120)])
        try tileData.write(to: bundle.appending(path: tileFile))
        let digest = SHA256.hash(data: tileData).map { String(format: "%02x", $0) }.joined()
        let bundledManifest = StationTileManifest(
            schemaVersion: 1,
            generatedAt: "2026-07-19T00:00:00Z",
            totalRecords: 1,
            baseURL: "https://example.invalid/",
            tiles: [.init(geohash: "sxk", file: tileFile, recordCount: 1, sha256: digest)]
        )
        let encoder = JSONEncoder()
        try encoder.encode(bundledManifest).write(to: bundle.appending(path: "station-tiles-manifest.json"))

        var corruptManifest = bundledManifest
        corruptManifest.tiles[0].sha256 = String(repeating: "0", count: 64)
        try encoder.encode(corruptManifest).write(to: cache.appending(path: "station-tiles-manifest.json"))
        try Data("broken".utf8).write(to: cache.appending(path: tileFile))

        let repository = TiledStationRepository(
            bundledManifestURL: bundle.appending(path: "station-tiles-manifest.json"),
            remoteManifestURL: nil,
            cacheDirectory: cache
        )
        let stations = try await repository.loadStations()

        #expect(stations.map(\.id) == ["bundled"])
    }

    private func makeCandidate(id: String, distance: Double, power: Double) -> StationCandidate {
        StationCandidate(
            station: makeStation(id: id, power: power),
            distanceKm: distance,
            straightLineDistanceKm: distance,
            estimatedMinutes: Int(distance),
            arrivalChargePercent: 20,
            remainingSafeRangeKm: 50,
            score: 50,
            badges: []
        )
    }

    private func makeStation(id: String, power: Double) -> Station {
        Station(
            id: id,
            name: "AVM Hızlı Şarj",
            address: "Ankara",
            latitude: 39.9,
            longitude: 32.8,
            power: "\(power) kW",
            operatorName: "Trugo",
            socket: "CCS",
            price: "12,50 TL/kWh",
            source: "test",
            sources: ["test"],
            confidenceScore: 0.9
        )
    }
}
