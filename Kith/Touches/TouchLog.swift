import Foundation
import SwiftData

/// The one place a catch-up is written and reversed.
///
/// Logging used to be Upcoming's alone. Contact Detail's quick actions log too
/// now, and the clock rules — reset `lastLoggedAt`, clear the hold, cancel the
/// nudges — have to be identical wherever the tap happened, so they live here
/// rather than in either screen's actions.
struct TouchLog {
    let context: ModelContext
    let notifications: NotificationScheduler

    /// Writes the touch and advances the clock.
    func apply(_ record: TouchUndoRecord) {
        let person = record.person
        record.touch.person = person
        context.insert(record.touch)
        person.lastLoggedAt = record.touch.date
        person.remindOn = nil
        notifications.cancel(ids: [person.reachOutNotificationID, person.remindTomorrowNotificationID])
        save()
    }

    /// Reverses a check. Safe to call once per record.
    func undo(_ record: TouchUndoRecord) {
        let person = record.person
        person.lastLoggedAt = record.previousLastLoggedAt
        person.remindOn = record.previousRemindOn
        record.keyDate?.lastHandledAt = record.previousLastHandledAt
        context.delete(record.touch)
        save()
    }

    /// Whether this person already has a logged touch on the given day.
    ///
    /// A quick action that doesn't connect is usually followed by another —
    /// a call, then a WhatsApp — and that's one catch-up, not two. Skip
    /// markers are deliberately not counted: a skip is the opposite of a touch.
    func hasTouch(for person: Person, on day: Date, calendar: Calendar) -> Bool {
        (person.touches ?? []).contains { calendar.isDate($0.date, inSameDayAs: day) }
    }

    private func save() {
        do {
            try context.save()
        } catch {
            assertionFailure("Touch log save failed: \(error)")
        }
    }
}
