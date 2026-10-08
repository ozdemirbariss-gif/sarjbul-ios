import CoreLocation
import EventKit
import Foundation
import SarjBulCore

struct ContextCalendarItem: Sendable {
    var identifier: String
    var startDate: Date
    var title: String
    var canModify: Bool
}

@MainActor
final class CalendarContextClient {
    private let eventStore = EKEventStore()

    func requestAuthorization() async -> Bool {
        do {
            return try await eventStore.requestFullAccessToEvents()
        } catch {
            AppTelemetry.capture(error, operation: "context_calendar_authorization")
            return false
        }
    }

    func nextItem(now: Date = Date()) -> ContextCalendarItem? {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return nil }
        let end = now.addingTimeInterval(3 * 3_600)
        let events = eventStore.events(matching: eventStore.predicateForEvents(withStart: now, end: end, calendars: nil))
        guard let event = events
            .filter({ !$0.isAllDay && $0.startDate >= now })
            .min(by: { $0.startDate < $1.startDate }) else { return nil }
        let isOwned = event.organizer?.isCurrentUser ?? true
        return ContextCalendarItem(
            identifier: event.eventIdentifier,
            startDate: event.startDate,
            title: event.title ?? "",
            canModify: event.calendar.allowsContentModifications && isOwned
        )
    }

    func deferItem(_ item: ContextCalendarItem, by interval: TimeInterval) throws {
        guard item.canModify, let event = eventStore.event(withIdentifier: item.identifier) else {
            throw ContextClientError.calendarItemCannotBeChanged
        }
        event.startDate = event.startDate.addingTimeInterval(interval)
        event.endDate = event.endDate.addingTimeInterval(interval)
        try eventStore.save(event, span: .thisEvent, commit: true)
    }
}

struct ContextWeather: Sendable {
    var severity: ContextWeatherSeverity
    var temperatureCelsius: Double?
}

struct WeatherContextClient: Sendable {
    private struct Response: Decodable {
        struct Current: Decodable {
            var temperature2m: Double
            var weatherCode: Int

            enum CodingKeys: String, CodingKey {
                case temperature2m = "temperature_2m"
                case weatherCode = "weather_code"
            }
        }

        var current: Current
    }

    func current(at location: UserLocation) async -> ContextWeather {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.3f", location.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.3f", location.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code")
        ]
        guard let url = components?.url else { return ContextWeather(severity: .normal) }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                return ContextWeather(severity: .normal)
            }
            let value = try JSONDecoder().decode(Response.self, from: data).current
            return ContextWeather(
                severity: severity(for: value.weatherCode),
                temperatureCelsius: value.temperature2m
            )
        } catch {
            await AppTelemetry.capture(error, operation: "context_weather")
            return ContextWeather(severity: .normal)
        }
    }

    private func severity(for code: Int) -> ContextWeatherSeverity {
        if [65, 67, 75, 77, 82, 86, 95, 96, 99].contains(code) { return .severe }
        if (51...67).contains(code) || (71...77).contains(code) || (80...86).contains(code) { return .rain }
        return .normal
    }
}

enum ContextClientError: Error {
    case calendarItemCannotBeChanged
}
