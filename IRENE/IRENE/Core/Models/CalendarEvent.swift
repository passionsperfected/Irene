import Foundation
import EventKit

struct CalendarEvent: Identifiable, Sendable {
    let id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var location: String?
    var notes: String?
    var calendarName: String
    var calendarColor: String?
    var isAllDay: Bool

    init(from event: EKEvent) {
        self.id = event.eventIdentifier ?? UUID().uuidString
        self.title = event.title ?? "Untitled"
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.location = event.location
        self.notes = event.notes
        self.calendarName = event.calendar?.title ?? "Unknown"
        if let components = event.calendar?.cgColor?.components, components.count >= 3 {
            self.calendarColor = String(format: "#%02X%02X%02X", Int(components[0]*255), Int(components[1]*255), Int(components[2]*255))
        } else {
            self.calendarColor = nil
        }
        self.isAllDay = event.isAllDay
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        startDate: Date,
        endDate: Date,
        location: String? = nil,
        notes: String? = nil,
        calendarName: String = "",
        calendarColor: String? = nil,
        isAllDay: Bool = false
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.notes = notes
        self.calendarName = calendarName
        self.calendarColor = calendarColor
        self.isAllDay = isAllDay
    }

    var durationString: String {
        if isAllDay { return "All Day" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: startDate, to: endDate) ?? ""
    }
}
