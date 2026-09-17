import Foundation
import SwiftData

/// The core-loop mutations. Upcoming's check is the primary place a touch is
/// logged; Contact Detail's quick actions are the only other one, and both go
/// through `TouchLog` so the clock rules can't drift apart.
struct UpcomingActions {
    let context: ModelContext
    let notifications: NotificationScheduler
    var now: () -> Date = { .now }
    /// The Settings notifications switch: off means no remind-me-tomorrow
    /// nudge is scheduled either. The hold itself still applies.
    var notificationsEnabled: () -> Bool = { AppPreferences.notificationsEnabled }

    private var touchLog: TouchLog {
        TouchLog(context: context, notifications: notifications)
    }

    /// Check on a person row: Touch dated now, clock reset, hold cleared.
    @discardableResult
    func log(_ person: Person) -> TouchUndoRecord {
        let record = TouchUndoRecord(
            person: person,
            touch: Touch(date: now()),
            previousLastLoggedAt: person.lastLoggedAt,
            previousRemindOn: person.remindOn
        )
        touchLog.apply(record)
        return record
    }

    /// Check on a key-date row: the occurrence is handled until the next
    /// recurrence *and* a touch is logged (wishing happy birthday counts).
    @discardableResult
    func handle(_ keyDate: KeyDate, for person: Person) -> TouchUndoRecord {
        let record = TouchUndoRecord(
            person: person,
            touch: Touch(date: now()),
            previousLastLoggedAt: person.lastLoggedAt,
            previousRemindOn: person.remindOn,
            keyDate: keyDate,
            previousLastHandledAt: keyDate.lastHandledAt
        )
        keyDate.lastHandledAt = record.touch.date
        touchLog.apply(record)
        return record
    }

    /// Reverses a check. Safe to call once per record.
    func undo(_ record: TouchUndoRecord) {
        touchLog.undo(record)
    }

    /// Holds the person out of Upcoming until tomorrow and schedules one next-day nudge.
    func remindTomorrow(_ person: Person) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return }
        // Held through the end of today; reappears in Upcoming from tomorrow.
        person.remindOn = tomorrow.addingTimeInterval(-1)
        let fireAt = CadenceEngine.applying(time: person.notifyTime, to: tomorrow, calendar: calendar)
        notifications.cancel(ids: [person.reachOutNotificationID])
        if notificationsEnabled() {
            notifications.scheduleRemindTomorrow(for: person, at: fireAt)
        }
        save()
    }

    /// Advances the clock one cycle with no real touch, leaving a visible marker.
    func skip(_ person: Person) {
        guard let due = person.nextDue else { return }
        person.lastLoggedAt = due
        person.remindOn = nil
        let marker = SkipMarker(date: now())
        marker.person = person
        context.insert(marker)
        notifications.cancel(ids: [person.reachOutNotificationID, person.remindTomorrowNotificationID])
        save()
    }

    private func save() {
        do {
            try context.save()
        } catch {
            assertionFailure("Upcoming save failed: \(error)")
        }
    }
}
