import Foundation

extension Person {
    /// The next-catchup state at a given moment (PRD Appendix), clock-injected for tests.
    func catchupStatus(at now: Date, calendar: Calendar = .current) -> CatchupStatus {
        guard cadence != .never, let due = nextDue else { return .none }
        if isSnoozed(at: now) { return .snoozed }
        guard now > due else { return .upcoming(due) }
        let days = CadenceEngine.daysOverdue(due: due, now: now, calendar: calendar)
        return days == 0 ? .dueToday : .overdue(days: days)
    }
}
