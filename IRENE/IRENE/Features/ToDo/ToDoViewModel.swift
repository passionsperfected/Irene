import Foundation
#if os(macOS)
import AppKit
#endif

@MainActor @Observable
final class ToDoViewModel {
    private(set) var items: [ToDoItem] = []
    private(set) var isLoading = false
    var searchText: String = ""
    var selectedTag: String? = nil
    var showCompleted: Bool = false
    var errorMessage: String?

    private let vaultManager: VaultManager
    private let storage = JSONStorage<ToDoItem>()

    init(vaultManager: VaultManager) {
        self.vaultManager = vaultManager
    }

    // MARK: - Filtered Lists

    var inboxItems: [ToDoItem] {
        filteredItems.filter { $0.inbox && !$0.isCompleted }
            .sorted { $0.priority > $1.priority }
    }

    var todayItems: [ToDoItem] {
        filteredItems.filter { !$0.inbox && $0.isDueToday && !$0.isCompleted }
            .sorted { $0.priority > $1.priority }
    }

    var overdueItems: [ToDoItem] {
        filteredItems.filter { $0.isOverdue }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    var upcomingItems: [ToDoItem] {
        filteredItems.filter {
            !$0.inbox && !$0.isCompleted && !$0.isDueToday && !$0.isOverdue
        }
        .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    var completedItems: [ToDoItem] {
        filteredItems.filter(\.isCompleted)
            .sorted { ($0.completed ?? .distantPast) > ($1.completed ?? .distantPast) }
    }

    var openCount: Int {
        items.filter { !$0.isCompleted }.count
    }

    var inboxCount: Int {
        items.filter { $0.inbox && !$0.isCompleted }.count
    }

    /// All unique tags across all items, sorted alphabetically
    var allTags: [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]
        for item in items {
            for tag in item.tags {
                counts[tag, default: 0] += 1
            }
        }
        return counts.map { (tag: $0.key, count: $0.value) }
            .sorted { $0.tag.localizedCaseInsensitiveCompare($1.tag) == .orderedAscending }
    }

    private var filteredItems: [ToDoItem] {
        var result = items

        // Tag filter
        if let selectedTag {
            result = result.filter { $0.tags.contains(selectedTag) }
        }

        // Search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.description.lowercased().contains(query) ||
                $0.tags.contains(where: { $0.lowercased().contains(query) })
            }
        }

        return result
    }

    // MARK: - CRUD

    func loadItems() async {
        guard let dir = try? vaultManager.directoryURL(for: .toDo) else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await storage.loadAll(in: dir)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createItem(title: String, inbox: Bool = true) async -> ToDoItem? {
        let item = ToDoItem(title: title, inbox: inbox, sortOrder: items.count)
        do {
            try await saveItem(item)
            items.append(item)
            return item
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func saveItem(_ item: ToDoItem) async throws {
        let dir = try vaultManager.directoryURL(for: .toDo)
        let fileURL = dir.appendingPathComponent(item.fileName)
        try await storage.save(item, to: fileURL)
    }

    func updateItem(_ item: ToDoItem) async {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = item
        updated.touch()
        items[index] = updated
        try? await saveItem(updated)
    }

    func toggleCompletion(_ item: ToDoItem) async {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let wasCompleted = items[index].isCompleted
        items[index].toggleCompletion()
        try? await saveItem(items[index])

        // Play a happy sound when completing (not when uncompleting)
        if !wasCompleted && items[index].isCompleted {
            #if os(macOS)
            let soundName = vaultManager.configuration.completionSound
            NSSound(named: NSSound.Name(soundName))?.play()
            #endif
        }
    }

    func moveFromInbox(_ item: ToDoItem) async {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].inbox = false
        items[index].touch()
        try? await saveItem(items[index])
    }

    func moveItem(from source: IndexSet, to destination: Int, in sectionItems: [ToDoItem]) async {
        var ordered = sectionItems
        ordered.move(fromOffsets: source, toOffset: destination)

        for (index, item) in ordered.enumerated() {
            if let i = items.firstIndex(where: { $0.id == item.id }) {
                items[i].sortOrder = index
                try? await saveItem(items[i])
            }
        }
    }

    func deleteItem(_ item: ToDoItem) async {
        do {
            let dir = try vaultManager.directoryURL(for: .toDo)
            let fileURL = dir.appendingPathComponent(item.fileName)
            try await storage.delete(at: fileURL)
            items.removeAll { $0.id == item.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
