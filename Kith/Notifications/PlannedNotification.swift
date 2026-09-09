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
        switch kind {
        case .reachOut(let person):
            scheduler.scheduleReachOut(for: person, at: fireAt)
        case .remindTomorrow(let person):
            scheduler.scheduleRemindTomorrow(for: person, at: fireAt)
        case .keyDateLead(let keyDate, let person, let daysAhead):
            scheduler.scheduleKeyDateLead(keyDate, for: person, daysAhead: daysAhead, at: fireAt)
        case .keyDateDay(let keyDate, let person):
            scheduler.scheduleKeyDateDay(keyDate, for: person, at: fireAt)
        }
    }
}
