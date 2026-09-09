import Foundation

/// A person's next-catchup state, derived once so every surface phrases it
/// identically (Contact Detail Appendix; People §4).
enum CatchupStatus: Equatable {
    /// Cadence is Never: no reach-out clock at all.
    case none
    /// Held by "Remind me tomorrow".
    case snoozed
    /// Past due by whole calendar days (always > 0).
    case overdue(days: Int)
    /// Past due earlier today.
    case dueToday
    /// Due in the future.
    case upcoming(Date)

    /// True whenever the due date has passed and no hold applies.
    var isOverdue: Bool {
        switch self {
        case .overdue, .dueToday: true
        case .none, .snoozed, .upcoming: false
        }
    }

    /// The terse roster line (People §4).
    func rosterLabel(now: Date, calendar: Calendar = .current) -> String {
        switch self {
        case .none: "No catchup scheduled"
        case .snoozed: "Snoozed to tomorrow"
        case .overdue(let days): "\(days)d overdue"
        case .dueToday: "Due today"
        case .upcoming(let due): "Next · \(Self.relativeDay(due, now: now, calendar: calendar))"
        }
    }

    /// The fuller Contact Detail line (Contact Detail Appendix).
    func detailLabel(now: Date, calendar: Calendar = .current) -> String {
        switch self {
        case .upcoming(let due):
            let day = Self.relativeDay(due, now: now, calendar: calendar)
            let time = due.formatted(date: .omitted, time: .shortened)
            return "Next catchup · \(day), \(time)"
        default:
            return rosterLabel(now: now, calendar: calendar)
        }
    }

    /// "Today" / "Tomorrow" / "Sat" (within the coming week) / "12 Sep".
    static func relativeDay(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        let today = calendar.startOfDay(for: now)
        let target = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case 2...6: return date.formatted(Date.FormatStyle(calendar: calendar).weekday(.abbreviated))
        default: return date.formatted(Date.FormatStyle(calendar: calendar).day().month(.abbreviated))
        }
    }
}
