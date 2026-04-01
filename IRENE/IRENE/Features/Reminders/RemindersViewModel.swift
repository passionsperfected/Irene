import Foundation

@MainActor @Observable
final class RemindersViewModel {
    private(set) var reminders: [Reminder] = []
    private(set) var isLoading = false
    var searchText: String = ""
    var showCompleted = false
    var errorMessage: String?

    private let vaultManager: VaultManager
    private let storage = JSONStorage<Reminder>()
    private let notificationService = NotificationService()

    init(vaultManager: VaultManager) {
        self.vaultManager = vaultManager
    }

    // MARK: - Filtered Lists

    var overdueReminders: [Reminder] {
        filtered.filter(\.isOverdue)
            .sorted { $0.reminderDate < $1.reminderDate }
    }

    var todayReminders: [Reminder] {
        filtered.filter { $0.isDueToday && !$0.isCompleted }
            .sorted { $0.reminderDate < $1.reminderDate }
    }

    var upcomingReminders: [Reminder] {
        filtered.filter(\.isUpcoming)
            .sorted { $0.reminderDate < $1.reminderDate }
    }

    var completedReminders: [Reminder] {
        filtered.filter(\.isCompleted)
            .sorted { $0.modified > $1.modified }
    }

    var upcomingCount: Int {
        reminders.filter { !$0.isCompleted }.count
    }

    private var filtered: [Reminder] {
        guard !searchText.isEmpty else { return reminders }
        let query = searchText.lowercased()
        return reminders.filter {
            $0.title.lowercased().contains(query) ||
            $0.notes.lowercased().contains(query)
        }
    }

    // MARK: - CRUD

    func loadReminders() async {
        guard let dir = try? vaultManager.directoryURL(for: .reminder) else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            reminders = try await storage.loadAll(in: dir)
            // Reschedule notifications on load
            await notificationService.rescheduleAll(reminders)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createReminder(title: String, date: Date) async -> Reminder? {
        _ = await notificationService.requestPermission()

        let reminder = Reminder(title: title, reminderDate: date)
        do {
            try await saveReminder(reminder)
            reminders.append(reminder)
            await notificationService.scheduleReminder(reminder)
            return reminder
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func saveReminder(_ reminder: Reminder) async throws {
        let dir = try vaultManager.directoryURL(for: .reminder)
        let fileURL = dir.appendingPathComponent(reminder.fileName)
        try await storage.save(reminder, to: fileURL)
    }

    func updateReminder(_ reminder: Reminder) async {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        var updated = reminder
        updated.touch()
        reminders[index] = updated
        try? await saveReminder(updated)
        await notificationService.scheduleReminder(updated)
    }

    func toggleCompletion(_ reminder: Reminder) async {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        reminders[index].isCompleted.toggle()
        reminders[index].touch()
        try? await saveReminder(reminders[index])

        if reminders[index].isCompleted {
            notificationService.cancelReminder(reminders[index])
        } else {
            await notificationService.scheduleReminder(reminders[index])
        }
    }

    func deleteReminder(_ reminder: Reminder) async {
        do {
            let dir = try vaultManager.directoryURL(for: .reminder)
            let fileURL = dir.appendingPathComponent(reminder.fileName)
            try await storage.delete(at: fileURL)
            notificationService.cancelReminder(reminder)
            reminders.removeAll { $0.id == reminder.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
