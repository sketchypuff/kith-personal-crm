import Foundation

/// One row in the Today feed. Both kinds share the same row shape.
enum TodayItem: Identifiable, Hashable {
    /// An overdue person, with whole days overdue (0 = due earlier today).
    case reachOut(person: Person, daysOverdue: Int)
    /// A key date inside its lead window, with whole days until it (0 = today).
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

    /// The context line under the name.
    var subtitle: String {
        switch self {
        case .reachOut(_, let days):
            return days <= 0 ? "Due today" : "\(days)d overdue"
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
