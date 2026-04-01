import Foundation

enum Priority: String, Codable, CaseIterable, Sendable, Comparable {
    case low
    case medium
    case high
    case urgent

    var displayName: String { rawValue.capitalized }

    var sortValue: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        case .urgent: return 3
        }
    }

    var iconName: String {
        switch self {
        case .low: return "arrow.down"
        case .medium: return "minus"
        case .high: return "arrow.up"
        case .urgent: return "exclamationmark.2"
        }
    }

    static func < (lhs: Priority, rhs: Priority) -> Bool {
        lhs.sortValue < rhs.sortValue
    }
}

struct ToDoItem: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var title: String
    var description: String
    var isCompleted: Bool
    var priority: Priority
    var dueDate: Date?
    var created: Date
    var modified: Date
    var completed: Date?
    var tags: [String]
    var inbox: Bool

    init(
        id: UUID = UUID(),
        title: String = "",
        description: String = "",
        isCompleted: Bool = false,
        priority: Priority = .medium,
        dueDate: Date? = nil,
        created: Date = Date(),
        modified: Date = Date(),
        completed: Date? = nil,
        tags: [String] = [],
        inbox: Bool = true
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.isCompleted = isCompleted
        self.priority = priority
        self.dueDate = dueDate
        self.created = created
        self.modified = modified
        self.completed = completed
        self.tags = tags
        self.inbox = inbox
    }

    var fileName: String { "\(id).json" }

    mutating func touch() { modified = Date() }

    mutating func toggleCompletion() {
        isCompleted.toggle()
        completed = isCompleted ? Date() : nil
        modified = Date()
    }

    var isDueToday: Bool {
        guard let dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }

    var isOverdue: Bool {
        guard let dueDate, !isCompleted else { return false }
        return dueDate < Date() && !Calendar.current.isDateInToday(dueDate)
    }

    func toMetadata() -> ItemMetadata {
        ItemMetadata(
            id: id,
            created: created,
            modified: modified,
            completed: completed,
            tags: tags,
            moduleType: .toDo,
            title: title,
            summary: description.isEmpty ? nil : String(description.prefix(200))
        )
    }
}
