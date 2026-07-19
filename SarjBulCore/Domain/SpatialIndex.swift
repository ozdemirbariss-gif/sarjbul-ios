import Foundation

public struct SpatialIndex: Sendable {
    private struct GridCell: Hashable, Sendable {
        let latitude: Int
        let longitude: Int
    }

    private let cellSizeDegrees: Double
    private let buckets: [GridCell: [Station]]
    public let stationCount: Int

    public init(stations: [Station], cellSizeDegrees: Double = 0.2) {
        let normalizedCellSize = max(0.02, cellSizeDegrees)
        self.cellSizeDegrees = normalizedCellSize
        stationCount = stations.count
        buckets = Dictionary(grouping: stations.filter(\.hasValidCoordinate)) { station in
            GridCell(
                latitude: Int(floor(station.latitude / normalizedCellSize)),
                longitude: Int(floor(station.longitude / normalizedCellSize))
            )
        }
    }

    public func stations(near origin: UserLocation, radiusKm: Double) -> [Station] {
        let latitudeDelta = max(0, radiusKm) / 111.0
        let cosineLatitude = max(0.18, abs(cos(origin.latitude * .pi / 180)))
        let longitudeDelta = max(0, radiusKm) / (111.0 * cosineLatitude)
        return stations(
            minimumLatitude: origin.latitude - latitudeDelta,
            maximumLatitude: origin.latitude + latitudeDelta,
            minimumLongitude: origin.longitude - longitudeDelta,
            maximumLongitude: origin.longitude + longitudeDelta
        )
    }

    public func stations(along points: [UserLocation], paddingKm: Double) -> [Station] {
        guard !points.isEmpty else { return [] }
        let latitudes = points.map(\.latitude)
        let longitudes = points.map(\.longitude)
        let latitudePadding = max(0, paddingKm) / 111.0
        let middleLatitude = ((latitudes.min() ?? 0) + (latitudes.max() ?? 0)) / 2
        let longitudePadding = max(0, paddingKm) / (111.0 * max(0.18, abs(cos(middleLatitude * .pi / 180))))
        return stations(
            minimumLatitude: (latitudes.min() ?? -90) - latitudePadding,
            maximumLatitude: (latitudes.max() ?? 90) + latitudePadding,
            minimumLongitude: (longitudes.min() ?? -180) - longitudePadding,
            maximumLongitude: (longitudes.max() ?? 180) + longitudePadding
        )
    }

    private func stations(
        minimumLatitude: Double,
        maximumLatitude: Double,
        minimumLongitude: Double,
        maximumLongitude: Double
    ) -> [Station] {
        let minimumCell = cell(latitude: minimumLatitude, longitude: minimumLongitude)
        let maximumCell = cell(latitude: maximumLatitude, longitude: maximumLongitude)
        var matches: [Station] = []

        for latitude in minimumCell.latitude...maximumCell.latitude {
            for longitude in minimumCell.longitude...maximumCell.longitude {
                guard let bucket = buckets[GridCell(latitude: latitude, longitude: longitude)] else { continue }
                matches.append(contentsOf: bucket.lazy.filter {
                    $0.latitude >= minimumLatitude && $0.latitude <= maximumLatitude
                        && $0.longitude >= minimumLongitude && $0.longitude <= maximumLongitude
                })
            }
        }
        return matches
    }

    private func cell(latitude: Double, longitude: Double) -> GridCell {
        GridCell(
            latitude: Int(floor(latitude / cellSizeDegrees)),
            longitude: Int(floor(longitude / cellSizeDegrees))
        )
    }
}
