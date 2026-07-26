import Foundation

public struct HolidayTrafficAdvice: Equatable, Sendable {
    public var title: String
    public var expectedPeakStartHour: Int
    public var expectedPeakEndHour: Int
    public var alternativeDeviationKm: Double

    public init(
        title: String,
        expectedPeakStartHour: Int,
        expectedPeakEndHour: Int,
        alternativeDeviationKm: Double
    ) {
        self.title = title
        self.expectedPeakStartHour = expectedPeakStartHour
        self.expectedPeakEndHour = expectedPeakEndHour
        self.alternativeDeviationKm = alternativeDeviationKm
    }
}

public enum HolidayTrafficAdvisor {
    public static func advice(
        for date: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> HolidayTrafficAdvice? {
        let year = calendar.component(.year, from: date)
        let windows: [(ClosedRange<Date>, String)] = holidayWindows(year: year, calendar: calendar)
        guard let match = windows.first(where: { $0.0.contains(date) }) else { return nil }
        return HolidayTrafficAdvice(
            title: match.1,
            expectedPeakStartHour: 14,
            expectedPeakEndHour: 22,
            alternativeDeviationKm: 12
        )
    }

    private static func holidayWindows(
        year: Int,
        calendar: Calendar
    ) -> [(ClosedRange<Date>, String)] {
        let knownDates: [Int: [(Int, Int, String)]] = [
            2026: [(3, 19, "Ramazan Bayramı"), (5, 26, "Kurban Bayramı")],
            2027: [(3, 8, "Ramazan Bayramı"), (5, 16, "Kurban Bayramı")]
        ]
        return (knownDates[year] ?? []).compactMap { month, day, title in
            guard let start = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 0)),
                  let end = calendar.date(byAdding: .day, value: 5, to: start) else { return nil }
            return (start...end, title)
        }
    }
}
