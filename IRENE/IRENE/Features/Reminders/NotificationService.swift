import Foundation
import UserNotifications

struct NotificationService: Sendable {
    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func scheduleReminder(_ reminder: Reminder) async {
        let center = UNUserNotificationCenter.current()

        // Remove existing notification for this reminder
        center.removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])

        guard !reminder.isCompleted, reminder.reminderDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "IRENE Reminder"
        content.body = reminder.title
        if !reminder.notes.isEmpty {
            content.subtitle = String(reminder.notes.prefix(100))
        }
        content.sound = .default
        content.userInfo = ["reminderId": reminder.id.uuidString]

        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminder.reminderDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString,
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
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
