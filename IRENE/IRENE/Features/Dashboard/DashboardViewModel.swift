import Foundation

@MainActor @Observable
final class DashboardViewModel {
    private(set) var recentNotes: [Note] = []
    private(set) var recentStickies: [StickyNote] = []
    private(set) var openTodos: [ToDoItem] = []
    private(set) var upcomingReminders: [Reminder] = []
    private(set) var recentChats: [ChatConversation] = []
    private(set) var isLoading = false

    private let vaultManager: VaultManager
    private let markdownStorage = MarkdownStorage()

    init(vaultManager: VaultManager) {
        self.vaultManager = vaultManager
    }

    var inboxCount: Int {
        openTodos.filter(\.inbox).count
    }

    var todayTodoCount: Int {
        openTodos.filter(\.isDueToday).count
    }

    var overdueReminderCount: Int {
        upcomingReminders.filter(\.isOverdue).count
    }

    func loadSummary() async {
        isLoading = true
        defer { isLoading = false }

        async let notes = loadRecentNotes()
        async let stickies = loadRecentStickies()
        async let todos = loadOpenTodos()
        async let reminders = loadUpcomingReminders()
        async let chats = loadRecentChats()

        recentNotes = await notes
        recentStickies = await stickies
        openTodos = await todos
        upcomingReminders = await reminders
        recentChats = await chats
    }

    /// Builds a context string for the dashboard chat system prompt
    func buildContextSummary() -> String {
        var parts: [String] = []

        parts.append("Today is \(Date().formatted(date: .complete, time: .omitted)).")

        if !openTodos.isEmpty {
            let inbox = openTodos.filter(\.inbox)
            let today = openTodos.filter(\.isDueToday)
            let overdue = openTodos.filter(\.isOverdue)
            parts.append("To Do: \(openTodos.count) open tasks (\(inbox.count) in inbox, \(today.count) due today, \(overdue.count) overdue).")
            for todo in openTodos.prefix(10) {
                let due = todo.dueDate.map { " due \($0.formatted(date: .abbreviated, time: .omitted))" } ?? ""
                parts.append("  - [\(todo.priority.rawValue)] \(todo.title)\(due)")
            }
        }

        if !upcomingReminders.isEmpty {
            parts.append("Reminders: \(upcomingReminders.count) upcoming.")
            for reminder in upcomingReminders.prefix(5) {
                parts.append("  - \(reminder.title) at \(reminder.reminderDate.formatted())")
            }
        }

        if !recentNotes.isEmpty {
            parts.append("Recent notes: \(recentNotes.count) recently modified.")
            for note in recentNotes.prefix(5) {
                parts.append("  - \"\(note.title)\" (\(note.content.count) chars)")
            }
        }

        if !recentStickies.isEmpty {
            parts.append("Stickies: \(recentStickies.count) recent.")
        }

        if !recentChats.isEmpty {
            parts.append("Recent conversations: \(recentChats.count).")
        }

        return parts.joined(separator: "\n")
    }

    // MARK: - Loaders

    private func loadRecentNotes() async -> [Note] {
        guard let dir = try? vaultManager.directoryURL(for: .note) else { return [] }
        let fm = FileManager.default
        guard fm.fileExists(atPath: dir.path) else { return [] }

        do {
            let files = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])
                .filter { $0.pathExtension == "md" }
                .sorted { (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast >
                          (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast }
                .prefix(5)

            var notes: [Note] = []
            for file in files {
                if let doc = try? await markdownStorage.load(from: file) {
                    notes.append(Note.fromMarkdownDocument(doc, fileURL: file))
                }
            }
            return notes
        } catch { return [] }
    }

    private func loadRecentStickies() async -> [StickyNote] {
        guard let dir = try? vaultManager.directoryURL(for: .stickyNote) else { return [] }
        let storage = JSONStorage<StickyNote>()
        return (try? await storage.loadAll(in: dir))?.sorted(by: { $0.modified > $1.modified }).prefix(5).map { $0 } ?? []
    }

    private func loadOpenTodos() async -> [ToDoItem] {
        guard let dir = try? vaultManager.directoryURL(for: .toDo) else { return [] }
        let storage = JSONStorage<ToDoItem>()
        return (try? await storage.loadAll(in: dir))?.filter { !$0.isCompleted } ?? []
    }

    private func loadUpcomingReminders() async -> [Reminder] {
        guard let dir = try? vaultManager.directoryURL(for: .reminder) else { return [] }
        let storage = JSONStorage<Reminder>()
        return (try? await storage.loadAll(in: dir))?.filter { !$0.isCompleted }.sorted(by: { $0.reminderDate < $1.reminderDate }).prefix(5).map { $0 } ?? []
    }

    private func loadRecentChats() async -> [ChatConversation] {
        guard let dir = try? vaultManager.directoryURL(for: .chat) else { return [] }
        let storage = JSONStorage<ChatConversation>()
        return (try? await storage.loadAll(in: dir))?.sorted(by: { $0.modified > $1.modified }).prefix(3).map { $0 } ?? []
    }
}
