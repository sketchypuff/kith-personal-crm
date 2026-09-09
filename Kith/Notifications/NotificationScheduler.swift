import Foundation
import UserNotifications

/// Thin wrapper over `UNUserNotificationCenter` using the deterministic
/// identifiers from the Data Model spec, so scheduling is idempotent.
struct NotificationScheduler {
    var center: UNUserNotificationCenter = .current()
    /// Optional test hook: remembers every request and cancellation.
    var recorder: NotificationRecorder? = nil

    func cancel(ids: [String]) {
        recorder?.recordCancel(ids)
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// The single next-day nudge behind "Remind me tomorrow".
    func scheduleRemindTomorrow(for person: Person, at fireAt: Date) {
        schedule(
            id: person.remindTomorrowNotificationID,
            title: person.name,
            body: "You asked to be reminded to reach out today.",
            at: fireAt
        )
    }

    /// The per-person overdue nudge, delivered at the contact's own
    /// notify day/time (PRD P0-6).
    func scheduleReachOut(for person: Person, at fireAt: Date) {
        schedule(
            id: person.reachOutNotificationID,
            title: person.name,
            body: "Time to reach out.",
            at: fireAt
        )
    }

    /// The lead-time reminder for a key date, `daysAhead` days before it (PRD P0-5).
    func scheduleKeyDateLead(_ keyDate: KeyDate, for person: Person, daysAhead: Int, at fireAt: Date) {
        let when = daysAhead == 1 ? "tomorrow" : "in \(daysAhead) days"
        schedule(
            id: keyDate.leadNotificationID,
            title: person.name,
            body: "\(keyDate.label) is \(when).",
            at: fireAt
        )
    }

    /// The day-of reminder for a key date (PRD P0-5).
    func scheduleKeyDateDay(_ keyDate: KeyDate, for person: Person, at fireAt: Date) {
        schedule(
            id: keyDate.dayOfNotificationID,
            title: person.name,
            body: "\(keyDate.label) is today.",
            at: fireAt
        )
    }

    private func schedule(id: String, title: String, body: String, at fireAt: Date) {
        recorder?.recordSchedule(id: id, at: fireAt)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        Task {
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            }
            try? await center.add(request)
        }
    }
}
