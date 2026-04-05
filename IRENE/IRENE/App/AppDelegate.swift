#if os(macOS)
import AppKit
import SwiftUI
import UserNotifications

@MainActor
final class IRENEAppDelegate: NSObject, NSApplicationDelegate {
    private let hotkeyManager = GlobalHotkeyManager()
    private var panel: HotkeyPanel?

    var vaultManager: VaultManager?
    var themeManager: ThemeManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupHotkeys()
        setupNotifications()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregister()
    }

    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = NotificationDelegate.shared

        // Register notification categories (Complete action)
        NotificationService().registerCategories()

        // Request permission on launch
        Task {
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                if granted {
                    print("[IRENE] Notification permission granted")
                } else {
                    print("[IRENE] Notification permission denied")
                }
            } catch {
                print("[IRENE] Notification permission error: \(error)")
            }
        }
    }

    private func setupHotkeys() {
        hotkeyManager.onHotkey = { [weak self] action in
            Task { @MainActor in
                self?.handleHotkey(action)
            }
        }
        hotkeyManager.register()
    }

    private func handleHotkey(_ action: HotkeyAction) {
        guard let vaultManager, let themeManager else { return }

        // Dismiss any existing panel
        panel?.dismiss()
        panel = HotkeyPanel()

        switch action {
        case .stickyCapture:
            let view = StickyQuickCaptureView { [weak self] content in
                Task { @MainActor in
                    let vm = StickiesViewModel(vaultManager: vaultManager)
                    _ = await vm.createSticky(content: content)
                    self?.panel?.dismiss()
                }
            }
            panel?.show(content: view, themeManager: themeManager)

        case .todoCapture:
            let view = ToDoQuickCaptureView { [weak self] title in
                Task { @MainActor in
                    let vm = ToDoViewModel(vaultManager: vaultManager)
                    _ = await vm.createItem(title: title)
                    self?.panel?.dismiss()
                }
            }
            panel?.show(content: view, themeManager: themeManager)

        case .reminderCapture:
            let view = ReminderQuickCaptureView { [weak self] title, date in
                Task { @MainActor in
                    let vm = RemindersViewModel(vaultManager: vaultManager)
                    _ = await vm.createReminder(title: title, date: date)
                    self?.panel?.dismiss()
                }
            }
            panel?.show(content: view, themeManager: themeManager)
        }
    }
}

// MARK: - Notification Delegate (shows notifications even when app is in foreground)

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    nonisolated(unsafe) static let shared = NotificationDelegate()
    weak var vaultManager: VaultManager?

    // Show notification banner even when the app is frontmost
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // Handle notification actions (Complete button, or just tapping the notification)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if response.actionIdentifier == NotificationService.completeActionIdentifier {
            // Complete the reminder
            if let reminderIdString = userInfo["reminderId"] as? String,
               let reminderId = UUID(uuidString: reminderIdString) {
                Task { @MainActor in
                    await completeReminder(id: reminderId)
                }
            }
        }

        completionHandler()
    }

    @MainActor
    private func completeReminder(id: UUID) async {
        guard let vaultManager else { return }
        guard let dir = try? vaultManager.directoryURL(for: .reminder) else { return }

        let storage = JSONStorage<Reminder>()
        let reminders = (try? await storage.loadAll(in: dir)) ?? []

        guard var reminder = reminders.first(where: { $0.id == id }) else { return }
        reminder.isCompleted = true
        reminder.modified = Date()

        let fileURL = dir.appendingPathComponent(reminder.fileName)
        try? await storage.save(reminder, to: fileURL)
        print("[IRENE Notify] Completed reminder: \(reminder.title)")
    }
}
#endif
