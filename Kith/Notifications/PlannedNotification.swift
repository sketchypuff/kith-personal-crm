import Foundation

/// One local notification the planner has decided should exist, before it is
/// handed to the scheduler. Keeping the plan separate from the scheduling lets
/// the all-people pass sort by fire date and stop at the pending-request cap.
struct PlannedNotification {
    enum Kind {
        case reachOut(Person)
        case remindTomorrow(Person)
        case keyDateLead(KeyDate, Person, daysAhead: Int)
        case keyDateDay(KeyDate, Person)
    }

    let kind: Kind
    let fireAt: Date

    func schedule(with scheduler: NotificationScheduler) {
        scheduler.schedule(request)
    }

    var request: ReminderRequest {
        switch kind {
        case .reachOut(let person):
            ReminderRequest(
                id: person.reachOutNotificationID, title: person.name,
                body: "Time to reach out.", fireAt: fireAt
            )
        case .remindTomorrow(let person):
            ReminderRequest(
                id: person.remindTomorrowNotificationID, title: person.name,
                body: "You asked to be reminded to reach out today.", fireAt: fireAt
            )
        case .keyDateLead(let keyDate, let person, let daysAhead):
            ReminderRequest(
                id: keyDate.leadNotificationID, title: person.name,
                body: "\(keyDate.label) is \(daysAhead == 1 ? "tomorrow" : "in \(daysAhead) days").",
                fireAt: fireAt
            )
        case .keyDateDay(let keyDate, let person):
            ReminderRequest(
                id: keyDate.dayOfNotificationID, title: person.name,
                body: "\(keyDate.label) is today.", fireAt: fireAt
            )
        }
    }
}
