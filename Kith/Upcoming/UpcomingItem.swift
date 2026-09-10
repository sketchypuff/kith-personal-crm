import Foundation

/// One row in the Upcoming feed. Both kinds share the same row shape.
enum UpcomingItem: Identifiable, Hashable {
    /// Where a person's next reach-out sits relative to now. Only the next one
    /// is ever modelled, so a weekly contact is one row, not four.
    enum ReachOutStatus: Hashable {
        /// Past due, in whole days (0 = due earlier today).
        case overdue(days: Int)
        /// Due today, not yet past the contact's notify time.
        case due
        /// Not due yet, in whole days ahead (1 = tomorrow).
        case upcoming(days: Int)

        /// True when the row is asking for something now, which is what the
        /// swipe actions and the duplicate-date suppression key off.
        var needsAttention: Bool {
            switch self {
            case .overdue, .due: true
            case .upcoming: false
            }
        }
    }

    /// A person's next reach-out.
    case reachOut(person: Person, status: ReachOutStatus)
    /// A key date inside the horizon, with whole days until it (0 = today).
    case keyDate(keyDate: KeyDate, person: Person, occurrence: Date, daysUntil: Int)

    var id: String {
        switch self {
        case .reachOut(let person, _): "reachout-\(person.id.uuidString)"
        case .keyDate(let keyDate, _, _, _): "keydate-\(keyDate.id.uuidString)"
        }
    }

    var person: Person {
        switch self {
        case .reachOut(let person, _): person
        case .keyDate(_, let person, _, _): person
        }
    }

    var isKeyDate: Bool {
        if case .keyDate = self { return true }
        return false
    }

    var isOverdue: Bool {
        if case .reachOut(_, .overdue) = self { return true }
        return false
    }

    /// Whether Remind me tomorrow and Skip apply to this row.
    var isActionable: Bool {
        if case .reachOut(_, let status) = self { return status.needsAttention }
        return false
    }

    /// The context line under the name.
    var subtitle: String {
        switch self {
        case .reachOut(_, let status):
            switch status {
            case .overdue(let days) where days > 0: return "\(days)d overdue"
            case .overdue, .due: return "Due today"
            case .upcoming(1): return "Due tomorrow"
            case .upcoming(let days): return "Due in \(days)d"
            }
        case .keyDate(let keyDate, _, _, let days):
            let when: String
            switch days {
            case ...0: when = "today"
            case 1: when = "tomorrow"
            default: when = "in \(days)d"
            }
            return "\(keyDate.label) · \(when)"
        }
    }

    /// VoiceOver label for the check button.
    var checkAccessibilityLabel: String {
        switch self {
        case .reachOut(let person, _): "Log reach-out with \(person.name)"
        case .keyDate(let keyDate, let person, _, _): "Mark \(person.name)'s \(keyDate.label.lowercased()) handled"
        }
    }
}
