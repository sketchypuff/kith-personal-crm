import Foundation

/// The one place that decides *which* notifications a person should have
/// pending and *when* they fire. Contact Detail reschedules one person at a
/// time through it; Settings runs the all-people pass through it. Both derive
/// identically because there is only one copy of the rules.
///
/// The all-people pass is the seed of the rolling scheduler (PRD §11): it
/// sorts every candidate by fire date and stops at `pendingLimit`, so the app
/// stays under the iOS ~64 pending-request ceiling.
struct NotificationPlanner {
    let notifications: NotificationScheduler
    var now: () -> Date = { .now }
    var calendar: Calendar = .current
    var defaultReminderTime: () -> Date = { AppPreferences.defaultReminderTime }
    var notificationsEnabled: () -> Bool = { AppPreferences.notificationsEnabled }

    /// Requests scheduled per pass. Leaves headroom under iOS's ~64 cap for
    /// the Upcoming actions that schedule outside a pass (remind-me-tomorrow).
    static let pendingLimit = 60

    // MARK: - One person

    /// Idempotent: cancels the reach-out request, then re-adds it at the next
    /// due moment. A past due date gets no request (the person is already
    /// overdue and surfaces on Upcoming); Never cancels every reach-out nudge.
    func rescheduleReachOut(for person: Person) {
        guard person.cadence != .never else {
            notifications.cancel(ids: [person.reachOutNotificationID, person.remindTomorrowNotificationID])
            return
        }
        notifications.cancel(ids: [person.reachOutNotificationID])
        plannedReachOut(for: person)?.schedule(with: notifications)
    }

    /// Lead and day-of requests for the next occurrence, at the Settings
    /// default reminder time, subject to the date's own toggle and the
    /// Settings notifications switch. Fire times already in the past are
    /// skipped rather than delivered immediately.
    func rescheduleReminders(for keyDate: KeyDate, person: Person) {
        notifications.cancel(ids: [keyDate.leadNotificationID, keyDate.dayOfNotificationID])
        for plan in plannedReminders(for: keyDate, person: person) {
            plan.schedule(with: notifications)
        }
    }

    // MARK: - Everyone

    /// Cancels every pending request for `people`, then schedules the nearest
    /// `pendingLimit` candidates under the current preferences. Running it
    /// twice yields the same requests (deterministic IDs), so callers can
    /// coalesce freely.
    func rescheduleAll(_ people: [Person]) {
        notifications.cancel(ids: people.flatMap(\.pendingNotificationIDs))

        let candidates = people
            .flatMap { plans(for: $0) }
            .sorted { $0.fireAt < $1.fireAt }

        for plan in candidates.prefix(Self.pendingLimit) {
            plan.schedule(with: notifications)
        }
    }

    /// Every request this person should have pending right now.
    func plans(for person: Person) -> [PlannedNotification] {
        var plans: [PlannedNotification] = []
        if let reachOut = plannedReachOut(for: person) {
            plans.append(reachOut)
        }
        if let remind = plannedRemindTomorrow(for: person) {
            plans.append(remind)
        }
        for keyDate in person.keyDates ?? [] {
            plans.append(contentsOf: plannedReminders(for: keyDate, person: person))
        }
        return plans
    }

    // MARK: - Candidates

    private func plannedReachOut(for person: Person) -> PlannedNotification? {
        guard notificationsEnabled(), person.cadence != .never,
              let due = person.nextDue, due > now() else { return nil }
        return PlannedNotification(kind: .reachOut(person), fireAt: due)
    }

    /// Reconstructs the "Remind me tomorrow" nudge from the hold: the hold ends
    /// at the end of today, and the nudge lands the next day at the person's
    /// own notify time — the same moment `UpcomingActions.remindTomorrow` chose.
    private func plannedRemindTomorrow(for person: Person) -> PlannedNotification? {
        guard notificationsEnabled(), person.cadence != .never,
              let remindOn = person.remindOn, remindOn > now() else { return nil }
        let nextDay = calendar.startOfDay(for: remindOn.addingTimeInterval(1))
        let fireAt = CadenceEngine.applying(time: person.notifyTime, to: nextDay, calendar: calendar)
        guard fireAt > now() else { return nil }
        return PlannedNotification(kind: .remindTomorrow(person), fireAt: fireAt)
    }

    private func plannedReminders(for keyDate: KeyDate, person: Person) -> [PlannedNotification] {
        guard keyDate.reminderEnabled, notificationsEnabled(),
              let occurrence = keyDate.nextOccurrence(from: now(), calendar: calendar) else { return [] }

        let current = now()
        let time = defaultReminderTime()
        var plans: [PlannedNotification] = []

        if keyDate.leadTimeDays > 0 {
            let leadDay = KeyDateEngine.windowStart(for: occurrence, leadTimeDays: keyDate.leadTimeDays, calendar: calendar)
            let leadFireAt = CadenceEngine.applying(time: time, to: leadDay, calendar: calendar)
            if leadFireAt > current {
                plans.append(PlannedNotification(
                    kind: .keyDateLead(keyDate, person, daysAhead: keyDate.leadTimeDays),
                    fireAt: leadFireAt
                ))
            }
        }

        let dayFireAt = CadenceEngine.applying(time: time, to: occurrence, calendar: calendar)
        if dayFireAt > current {
            plans.append(PlannedNotification(kind: .keyDateDay(keyDate, person), fireAt: dayFireAt))
        }
        return plans
    }
}
