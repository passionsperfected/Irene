import Foundation

enum SprintGoalStatus: String, Codable, CaseIterable, Sendable {
    case planned
    case inProgress = "in_progress"
    case done
    case dropped

    var displayName: String {
        switch self {
        case .planned: return "Planned"
        case .inProgress: return "In Progress"
        case .done: return "Done"
        case .dropped: return "Dropped"
        }
    }

    var iconName: String {
        switch self {
        case .planned: return "circle"
        case .inProgress: return "circle.lefthalf.filled"
        case .done: return "checkmark.circle.fill"
        case .dropped: return "xmark.circle"
        }
    }
}

struct SprintGoal: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var title: String
    var description: String
    /// Directly Responsible Individual — free-text name for now.
    var dri: String
    var status: SprintGoalStatus
    var created: Date
    var modified: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        description: String = "",
        dri: String = "",
        status: SprintGoalStatus = .planned,
        created: Date = Date(),
        modified: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.dri = dri
        self.status = status
        self.created = created
        self.modified = modified
    }

    mutating func touch() { modified = Date() }
}

struct Sprint: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var name: String
    var startDate: Date?
    var endDate: Date?
    var sortOrder: Int
    var goals: [SprintGoal]
    var created: Date
    var modified: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        startDate: Date? = nil,
        endDate: Date? = nil,
        sortOrder: Int = 0,
        goals: [SprintGoal] = [],
        created: Date = Date(),
        modified: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.sortOrder = sortOrder
        self.goals = goals
        self.created = created
        self.modified = modified
    }

    var fileName: String { "\(id).json" }

    mutating func touch() { modified = Date() }

    var completedGoalCount: Int {
        goals.filter { $0.status == .done }.count
    }

    var progressFraction: Double {
        guard !goals.isEmpty else { return 0 }
        return Double(completedGoalCount) / Double(goals.count)
    }
}
