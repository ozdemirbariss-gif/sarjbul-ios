import Foundation

public enum StationScorer {
    public static func score(candidate: StationCandidate) -> Int {
        let total = distanceScore(candidate.distanceKm)
            + powerScore(candidate.station.powerKW)
            + arrivalChargeScore(candidate.arrivalChargePercent)
            + priceScore(candidate.station.priceValue)
            + dataScore(candidate.station)
        return min(100, max(1, total))
    }

    public static func badges(for candidate: StationCandidate) -> [StationBadge] {
        var badges: [StationBadge] = []

        if candidate.arrivalChargePercent >= 15 {
            badges.append(.init(title: "Varış güvenli", tone: .good))
        } else {
            badges.append(.init(title: "Varış düşük", tone: .warning))
        }

        if candidate.station.powerKW >= 150 {
            badges.append(.init(title: "Hızlı DC", tone: .info))
        } else if candidate.station.powerKW >= 50 {
            badges.append(.init(title: "DC", tone: .info))
        }

        if Set(candidate.station.sources).count > 1 {
            badges.append(.init(title: "\(Set(candidate.station.sources).count) kaynak", tone: .good))
        } else if candidate.station.confidenceScore >= 0.8 {
            badges.append(.init(title: "Yüksek veri güveni", tone: .good))
        } else {
            badges.append(.init(title: "Canlı veri yok", tone: .warning))
        }

        return Array(badges.prefix(5))
    }

    private static func distanceScore(_ distanceKm: Double) -> Int {
        if distanceKm <= 2 { return 22 }
        if distanceKm <= 5 { return 20 }
        if distanceKm <= 10 { return 16 }
        if distanceKm <= 20 { return 11 }
        return max(4, Int(12 - min(distanceKm, 60) / 7))
    }

    private static func powerScore(_ powerKW: Double) -> Int {
        if powerKW >= 150 { return 18 }
        if powerKW >= 50 { return 14 }
        if powerKW >= 22 { return 10 }
        if powerKW >= 7 { return 7 }
        return 4
    }

    private static func arrivalChargeScore(_ percent: Double) -> Int {
        if percent >= 25 { return 13 }
        if percent >= 15 { return 10 }
        if percent >= 8 { return 6 }
        return 2
    }

    private static func priceScore(_ price: Double) -> Int {
        if price >= 9999 { return 4 }
        if price <= 8 { return 9 }
        if price <= 12 { return 7 }
        if price <= 18 { return 5 }
        return 3
    }

    private static func dataScore(_ station: Station) -> Int {
        let sourceBonus = min(6, max(0, Set(station.sources).count - 1) * 3)
        return min(15, Int((station.confidenceScore * 9).rounded()) + sourceBonus)
    }
}

