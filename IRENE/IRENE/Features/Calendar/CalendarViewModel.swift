import Foundation
import EventKit

@MainActor @Observable
final class CalendarViewModel {
    private(set) var events: [CalendarEvent] = []
    private(set) var hasAccess = false
    private(set) var isLoading = false
    var selectedDate: Date = Date()
    var errorMessage: String?

    private let eventStore = EKEventStore()

    var eventsForSelectedDate: [CalendarEvent] {
        let calendar = Calendar.current
        return events.filter { event in
            if event.isAllDay {
                return calendar.isDate(event.startDate, inSameDayAs: selectedDate)
            }
            let start = calendar.startOfDay(for: selectedDate)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return event.startDate < end && event.endDate > start
        }
        .sorted { $0.startDate < $1.startDate }
    }

    var todayEvents: [CalendarEvent] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return events.filter { $0.startDate < end && $0.endDate > start }
            .sorted { $0.startDate < $1.startDate }
    }

    func requestAccess() async {
        do {
            hasAccess = try await eventStore.requestFullAccessToEvents()
            if hasAccess {
                await loadEvents()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadEvents() async {
        isLoading = true
        defer { isLoading = false }

        let calendar = Calendar.current
        let start = calendar.date(byAdding: .month, value: -1, to: Date())!
        let end = calendar.date(byAdding: .month, value: 3, to: Date())!

        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let ekEvents = eventStore.events(matching: predicate)
        events = ekEvents.map { CalendarEvent(from: $0) }
    }

    func createEvent(title: String, startDate: Date, endDate: Date, isAllDay: Bool, location: String?, notes: String?) async throws {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.isAllDay = isAllDay
        event.location = location
        event.notes = notes
        event.calendar = eventStore.defaultCalendarForNewEvents

        try eventStore.save(event, span: .thisEvent)
        await loadEvents()
    }

    func deleteEvent(id: String) async throws {
        guard let event = eventStore.event(withIdentifier: id) else {
            throw IRENEError.fileNotFound(URL(fileURLWithPath: id))
        }
        try eventStore.remove(event, span: .thisEvent)
        await loadEvents()
    }

    // MARK: - Date Navigation

    func goToToday() {
        selectedDate = Date()
    }

    func previousMonth() {
        selectedDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
    }

    func nextMonth() {
        selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
    }

    func datesWithEvents(in month: Date) -> Set<DateComponents> {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else {
            return []
        }

        var dates = Set<DateComponents>()
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                let hasEvent = events.contains { event in
                    calendar.isDate(event.startDate, inSameDayAs: date) ||
                    (event.startDate <= date && event.endDate >= date)
                }
                if hasEvent {
                    dates.insert(calendar.dateComponents([.year, .month, .day], from: date))
                }
            }
        }
        return dates
    }
}
