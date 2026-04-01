import Foundation

enum ModuleType: String, Codable, CaseIterable, Sendable {
    case note
    case stickyNote = "sticky_note"
    case toDo = "to_do"
    case reminder
    case chat
    case recording
}

struct ItemMetadata: Codable, Identifiable, Sendable {
    let id: UUID
    var created: Date
    var modified: Date
    var completed: Date?
    var tags: [String]
    var moduleType: ModuleType
    var title: String
    var summary: String?

    init(
        id: UUID = UUID(),
        created: Date = Date(),
        modified: Date = Date(),
        completed: Date? = nil,
        tags: [String] = [],
        moduleType: ModuleType,
        title: String,
        summary: String? = nil
    ) {
        self.id = id
        self.created = created
        self.modified = modified
        self.completed = completed
        self.tags = tags
        self.moduleType = moduleType
        self.title = title
        self.summary = summary
    }

    mutating func touch() {
        modified = Date()
    }

    mutating func markCompleted() {
        completed = Date()
        modified = Date()
    }
}
