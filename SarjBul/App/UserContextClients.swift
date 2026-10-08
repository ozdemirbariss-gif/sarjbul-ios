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

enum ContextClientError: Error {
    case calendarItemCannotBeChanged
}
