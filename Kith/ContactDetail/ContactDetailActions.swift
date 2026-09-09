import Foundation
import SwiftData

/// The contact sheet's mutations: configure cadence, manage dates and tags,
/// write notes. Nothing here advances the relationship clock — logging,
/// snoozing, and skipping are Today-only (Contact Detail §8).
struct ContactDetailActions {
    let context: ModelContext
    let notifications: NotificationScheduler
    var now: () -> Date = { .now }
    var calendar: Calendar = .current
    var defaultReminderTime: () -> Date = { AppPreferences.defaultReminderTime }
    var reachOutRemindersEnabled: () -> Bool = { AppPreferences.notifyReachOutsEnabled }
    var keyDateRemindersEnabled: () -> Bool = { AppPreferences.notifyKeyDatesEnabled }

    // MARK: - Notify

    /// Call after any Notify control changes. The binding has already written
    /// the new value; this persists it and realigns the reach-out nudge.
    func notifyDidChange(_ person: Person) {
        rescheduleReachOut(for: person)
        save()
    }

    /// Idempotent: cancels the reach-out request, then re-adds it at the next
    /// due moment. A past due date gets no request (the person is already
    /// overdue and surfaces on Today); Never cancels every reach-out nudge.
    func rescheduleReachOut(for person: Person) {
        guard person.cadence != .never else {
            notifications.cancel(ids: [person.reachOutNotificationID, person.remindTomorrowNotificationID])
            return
        }
        notifications.cancel(ids: [person.reachOutNotificationID])
        guard reachOutRemindersEnabled(), let due = person.nextDue, due > now() else { return }
        notifications.scheduleReachOut(for: person, at: due)
    }

    // MARK: - Key dates

    @discardableResult
    func addKeyDate(_ draft: KeyDateDraft, to person: Person) -> KeyDate {
        let keyDate = KeyDate()
        draft.apply(to: keyDate, calendar: calendar)
        keyDate.person = person
        context.insert(keyDate)
        rescheduleReminders(for: keyDate, person: person)
        save()
        return keyDate
    }

    func updateKeyDate(_ keyDate: KeyDate, with draft: KeyDateDraft) {
        draft.apply(to: keyDate, calendar: calendar)
        if let person = keyDate.person {
            rescheduleReminders(for: keyDate, person: person)
        }
        save()
    }

    /// Cancels the date's notifications first: the identifiers are still
    /// readable here, and the delete is final.
    func deleteKeyDate(_ keyDate: KeyDate) {
        notifications.cancel(ids: [keyDate.leadNotificationID, keyDate.dayOfNotificationID])
        context.delete(keyDate)
        save()
    }

    /// Lead and day-of requests for the next occurrence, at the Settings
    /// default reminder time, subject to the date's own toggle and the
    /// Settings key-date category switch. Fire times already in the past are
    /// skipped rather than delivered immediately.
    func rescheduleReminders(for keyDate: KeyDate, person: Person) {
        notifications.cancel(ids: [keyDate.leadNotificationID, keyDate.dayOfNotificationID])
        guard keyDate.reminderEnabled, keyDateRemindersEnabled(),
              let occurrence = keyDate.nextOccurrence(from: now(), calendar: calendar) else { return }

        let current = now()
        let time = defaultReminderTime()

        if keyDate.leadTimeDays > 0 {
            let leadDay = KeyDateEngine.windowStart(for: occurrence, leadTimeDays: keyDate.leadTimeDays, calendar: calendar)
            let leadFireAt = CadenceEngine.applying(time: time, to: leadDay, calendar: calendar)
            if leadFireAt > current {
                notifications.scheduleKeyDateLead(keyDate, for: person, daysAhead: keyDate.leadTimeDays, at: leadFireAt)
            }
        }

        let dayFireAt = CadenceEngine.applying(time: time, to: occurrence, calendar: calendar)
        if dayFireAt > current {
            notifications.scheduleKeyDateDay(keyDate, for: person, at: dayFireAt)
        }
    }

    // MARK: - Tags

    /// Adds a trimmed tag once (case-insensitive match). Returns false when
    /// nothing was added. Tags are labels only and never touch cadence.
    @discardableResult
    func addTag(_ raw: String, to person: Person) -> Bool {
        let tag = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return false }
        guard !person.tags.contains(where: { $0.localizedCaseInsensitiveCompare(tag) == .orderedSame }) else {
            return false
        }
        person.tags.append(tag)
        save()
        return true
    }

    func removeTag(_ tag: String, from person: Person) {
        person.tags.removeAll { $0 == tag }
        save()
    }

    // MARK: - Notes

    /// The debounced commit target. A no-op when nothing changed, so the
    /// focus-loss and disappear commits never dirty the context needlessly.
    func commitNotes(_ notes: String, for person: Person) {
        guard person.notes != notes else { return }
        person.notes = notes
        save()
    }

    private func save() {
        do {
            try context.save()
        } catch {
            assertionFailure("Contact Detail save failed: \(error)")
        }
    }
}
