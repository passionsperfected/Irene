import Foundation
import UserNotifications

struct NotificationService: Sendable {
    static let categoryIdentifier = "IRENE_REMINDER"
    static let completeActionIdentifier = "COMPLETE_REMINDER"

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func registerCategories() {
        let completeAction = UNNotificationAction(
            identifier: Self.completeActionIdentifier,
            title: "Complete",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [completeAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func scheduleReminder(_ reminder: Reminder) async {
        let center = UNUserNotificationCenter.current()

        // Remove existing notification for this reminder
        center.removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])

        guard !reminder.isCompleted, reminder.reminderDate > Date() else {
            print("[IRENE Notify] Skipping: completed=\(reminder.isCompleted), date=\(reminder.reminderDate), now=\(Date())")
            return
        }

        // Check permission
        let settings = await center.notificationSettings()
        print("[IRENE Notify] Authorization status: \(settings.authorizationStatus.rawValue) (0=notDetermined, 1=denied, 2=authorized, 3=provisional)")

        if settings.authorizationStatus == .notDetermined {
            let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            print("[IRENE Notify] Requested permission: \(granted ?? false)")
        }

        let content = UNMutableNotificationContent()
        content.title = "IRENE Reminder"
        content.body = reminder.title
        if !reminder.notes.isEmpty {
            content.subtitle = String(reminder.notes.prefix(100))
        }
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier
        content.userInfo = ["reminderId": reminder.id.uuidString]

        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: reminder.reminderDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            print("[IRENE Notify] Scheduled: '\(reminder.title)' at \(reminder.reminderDate)")

            // Verify it was added
            let pending = await center.pendingNotificationRequests()
            print("[IRENE Notify] Total pending notifications: \(pending.count)")
        } catch {
            print("[IRENE Notify] Failed to schedule: \(error)")
        }
    }

    func cancelReminder(_ reminder: Reminder) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
    }

    func rescheduleAll(_ reminders: [Reminder]) async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        for reminder in reminders where !reminder.isCompleted && reminder.reminderDate > Date() {
            await scheduleReminder(reminder)
        }
    }
}
