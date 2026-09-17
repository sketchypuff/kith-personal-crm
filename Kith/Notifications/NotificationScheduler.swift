import Foundation
import OSLog
import UserNotifications

/// Thin wrapper over `UNUserNotificationCenter` using the deterministic
/// identifiers from the Data Model spec, so scheduling is idempotent.
struct NotificationScheduler {
    var client: NotificationClient = .live
    /// Optional test hook: remembers every request and cancellation.
    var recorder: NotificationRecorder? = nil
    var defaults: UserDefaults = AppPreferences.store

    func cancel(ids: [String]) {
        recorder?.recordCancel(ids)
        if recorder == nil { client.remove(ids) }
    }

    func cancelAll() {
        if let recorder {
            recorder.recordCancel(Array(recorder.pending.keys))
        } else {
            client.removeAll()
        }
    }

    /// The single next-day nudge behind "Remind me tomorrow".
    func scheduleRemindTomorrow(for person: Person, at fireAt: Date) {
        PlannedNotification(kind: .remindTomorrow(person), fireAt: fireAt).schedule(with: self)
    }

    /// The per-person overdue nudge, delivered at the contact's own
    /// notify day/time (PRD P0-6).
    func scheduleReachOut(for person: Person, at fireAt: Date) {
        PlannedNotification(kind: .reachOut(person), fireAt: fireAt).schedule(with: self)
    }

    /// The lead-time reminder for a key date, `daysAhead` days before it (PRD P0-5).
    func scheduleKeyDateLead(_ keyDate: KeyDate, for person: Person, daysAhead: Int, at fireAt: Date) {
        PlannedNotification(kind: .keyDateLead(keyDate, person, daysAhead: daysAhead), fireAt: fireAt)
            .schedule(with: self)
    }

    /// The day-of reminder for a key date (PRD P0-5).
    func scheduleKeyDateDay(_ keyDate: KeyDate, for person: Person, at fireAt: Date) {
        PlannedNotification(kind: .keyDateDay(keyDate, person), fireAt: fireAt).schedule(with: self)
    }

    func schedule(_ request: ReminderRequest) {
        if let recorder {
            recorder.recordSchedule(id: request.id, at: request.fireAt)
            return
        }
        Task {
            do {
                try await sendIfAllowed(request)
            } catch {
                Logger(subsystem: "com.yashshenai.kith", category: "notifications")
                    .error("Could not schedule reminder: \(error.localizedDescription)")
            }
        }
    }

    func sendIfAllowed(_ request: ReminderRequest) async throws {
        guard allowsDelivery else { return }
        let status = await client.authorizationStatus()
        if status == .notDetermined {
            // Preserve legacy requests; new installs opt in explicitly.
            guard AppPreferences.notificationChoice(in: defaults) == .legacy,
                  try await client.authorizeIfNeeded() else { return }
        } else if ![.authorized, .provisional, .ephemeral].contains(status) {
            return
        }
        guard allowsDelivery else { return }
        try await client.add(request.notification)
        if !allowsDelivery { client.remove([request.id]) }
    }

    func scheduleAndWait(_ requests: [ReminderRequest]) async throws {
        if let recorder {
            for request in requests {
                recorder.recordSchedule(id: request.id, at: request.fireAt)
            }
            return
        }
        do {
            for request in requests {
                try Task.checkCancellation()
                try await client.add(request.notification)
            }
            try Task.checkCancellation()
        } catch {
            client.remove(requests.map(\.id))
            throw error
        }
    }

    private var allowsDelivery: Bool {
        AppPreferences.notificationsEnabled(in: defaults)
            && ![NotificationChoice.pending, .declined].contains(AppPreferences.notificationChoice(in: defaults))
    }
}
