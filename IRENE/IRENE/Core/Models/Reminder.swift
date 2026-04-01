import Foundation

enum RecurrenceFrequency: String, Codable, CaseIterable, Sendable {
    case daily
    case weekly
    case monthly
    case yearly

    var displayName: String { rawValue.capitalized }
}

struct RecurrenceRule: Codable, Sendable, Hashable {
    var frequency: RecurrenceFrequency
    var interval: Int

    init(frequency: RecurrenceFrequency = .daily, interval: Int = 1) {
        self.frequency = frequency
        self.interval = interval
    }

    var displayString: String {
        if interval == 1 {
            return frequency.displayName
        }
        return "Every \(interval) \(frequency.rawValue)"
    }
}

struct Reminder: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var title: String
    var notes: String
    var reminderDate: Date
    var isRecurring: Bool
    var recurrenceRule: RecurrenceRule?
    var isCompleted: Bool
    var created: Date
    var modified: Date
    var tags: [String]

    init(
        id: UUID = UUID(),
        title: String = "",
        notes: String = "",
        reminderDate: Date = Date().addingTimeInterval(3600),
        isRecurring: Bool = false,
        recurrenceRule: RecurrenceRule? = nil,
        isCompleted: Bool = false,
        created: Date = Date(),
        modified: Date = Date(),
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.reminderDate = reminderDate
        self.isRecurring = isRecurring
        self.recurrenceRule = recurrenceRule
        self.isCompleted = isCompleted
        self.created = created
        self.modified = modified
        self.tags = tags
    }

    var fileName: String { "\(id).json" }

    mutating func touch() { modified = Date() }

    var isOverdue: Bool {
        !isCompleted && reminderDate < Date()
    }

    var isDueToday: Bool {
        Calendar.current.isDateInToday(reminderDate)
    }

    var isUpcoming: Bool {
        !isCompleted && !isOverdue && !isDueToday
    }

    func toMetadata() -> ItemMetadata {
        ItemMetadata(
            id: id,
            created: created,
            modified: modified,
            tags: tags,
            moduleType: .reminder,
            title: title,
            summary: notes.isEmpty ? nil : String(notes.prefix(200))
        )
    }
}
