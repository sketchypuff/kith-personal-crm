import Foundation
import UserNotifications

/// Thin wrapper over `UNUserNotificationCenter` using the deterministic
/// identifiers from the Data Model spec, so scheduling is idempotent.
struct NotificationScheduler {
    var center: UNUserNotificationCenter = .current()

    func cancel(ids: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// The single next-day nudge behind "Remind me tomorrow".
    func scheduleRemindTomorrow(for person: Person, at fireAt: Date) {
        let content = UNMutableNotificationContent()
        content.title = person.name
        content.body = "You asked to be reminded to reach out today."
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: person.remindTomorrowNotificationID,
            content: content,
            trigger: trigger
        )

        Task {
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            }
            try? await center.add(request)
        }
    }
}
