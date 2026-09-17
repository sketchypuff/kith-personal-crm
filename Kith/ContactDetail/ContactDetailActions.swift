import Foundation
import SwiftData

/// The contact sheet's mutations: configure cadence, manage dates and tags,
/// write notes, and log the one thing this screen does advance — a quick
/// action's catch-up. Snoozing and skipping remain Upcoming-only.
struct ContactDetailActions {
    let context: ModelContext
    let notifications: NotificationScheduler
    var now: () -> Date = { .now }
    var calendar: Calendar = .current
    var defaultReminderTime: () -> Date = { AppPreferences.defaultReminderTime }
    var notificationsEnabled: () -> Bool = { AppPreferences.notificationsEnabled }

    /// The shared scheduling rules; Settings' all-people pass uses the same planner.
    private var planner: NotificationPlanner {
        NotificationPlanner(
            notifications: notifications,
            now: now,
            calendar: calendar,
            defaultReminderTime: defaultReminderTime,
            notificationsEnabled: notificationsEnabled
        )
    }

    /// The same clock rules Upcoming's check uses, so a catch-up means the
    /// same thing wherever it was tapped.
    private var touchLog: TouchLog {
        TouchLog(context: context, notifications: notifications)
    }

    // MARK: - Quick actions

    /// Records a catch-up for a tapped Call / Message / WhatsApp.
    ///
    /// Returns nil — writing nothing — when this person already has a touch
    /// today: a call that rings out followed by a WhatsApp is one catch-up,
    /// and the timeline shouldn't fill with attempts. The caller still opens
    /// the other app either way.
    @discardableResult
    func logQuickAction(_ action: QuickAction, for person: Person) -> TouchUndoRecord? {
        let date = now()
        guard !touchLog.hasTouch(for: person, on: date, calendar: calendar) else { return nil }

        let touch = Touch(date: date)
        touch.kind = action.touchKind
        let record = TouchUndoRecord(
            person: person,
            touch: touch,
            previousLastLoggedAt: person.lastLoggedAt,
            previousRemindOn: person.remindOn
        )
        touchLog.apply(record)
        return record
    }

    /// Reverses a quick action's catch-up. Safe to call once per record.
    func undo(_ record: TouchUndoRecord) {
        touchLog.undo(record)
    }

    // MARK: - Notify

    /// Call after any Notify control changes. The binding has already written
    /// the new value; this persists it and realigns the reach-out nudge.
    func notifyDidChange(_ person: Person) {
        rescheduleReachOut(for: person)
        save()
    }

    /// See `NotificationPlanner.rescheduleReachOut(for:)`.
    func rescheduleReachOut(for person: Person) {
        planner.rescheduleReachOut(for: person)
    }

    /// Call after the timezone changes. Display-only: a person's local time
    /// says nothing about when their reminder should fire, so nothing is
    /// rescheduled — the nudge still arrives at the hour the reader picked, in
    /// the reader's own day.
    func timeZoneDidChange(_ person: Person) {
        save()
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

    /// See `NotificationPlanner.rescheduleReminders(for:person:)`.
    func rescheduleReminders(for keyDate: KeyDate, person: Person) {
        planner.rescheduleReminders(for: keyDate, person: person)
    }

    // MARK: - Tags

    /// Adds a tag once (case-insensitive match), spelled the way the starter
    /// set spells it. Returns false when nothing was added. Tags are labels
    /// only and never touch cadence.
    @discardableResult
    func addTag(_ raw: String, to person: Person) -> Bool {
        let tag = TagVocabulary.canonical(raw)
        guard !tag.isEmpty else { return false }
        guard !TagVocabulary.matches(tag, in: person) else { return false }
        person.tags.append(tag)
        save()
        return true
    }

    func removeTag(_ tag: String, from person: Person) {
        // Matched the way it was added, so a tag whose spelling was settled by
        // the starter set can still be removed by the row that shows it.
        let key = TagVocabulary.fold(tag)
        person.tags.removeAll { TagVocabulary.fold($0) == key }
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
