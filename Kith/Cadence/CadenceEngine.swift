import Foundation

/// The single home for interval math. Every surface (Today, roster, contact
/// sheet, widget, notifications) derives due dates through here so they agree.
nonisolated enum CadenceEngine {

    /// PRD Appendix: `anchor` advanced by the cadence interval, then aligned
    /// onto `weekday` (Weekly and longer) at the hour/minute of `time`.
    ///
    /// Alignment moves *forward* to the first matching weekday on or after the
    /// advanced date, so a due date is never earlier than one full interval.
    /// Returns `nil` for `.never`.
    static func advance(
        _ anchor: Date,
        by cadence: Cadence,
        alignedTo weekday: Weekday,
        at time: Date,
        calendar: Calendar = .current
    ) -> Date? {
        let interval: DateComponents
        switch cadence {
        case .never: return nil
        case .daily: interval = DateComponents(day: 1)
        case .weekly: interval = DateComponents(day: 7)
        case .monthly: interval = DateComponents(month: 1)
        case .quarterly: interval = DateComponents(month: 3)
        case .annually: interval = DateComponents(year: 1)
        }

        guard let advanced = calendar.date(byAdding: interval, to: anchor) else { return nil }

        var day = calendar.startOfDay(for: advanced)
        if cadence.usesNotifyDay {
            day = nextOccurrence(of: weekday, onOrAfter: day, calendar: calendar)
        }
        return applying(time: time, to: day, calendar: calendar)
    }

    /// Whole calendar days from `due` to `now` (0 when due earlier today).
    static func daysOverdue(due: Date, now: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: due)
        let end = calendar.startOfDay(for: now)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// First date whose weekday matches, on or after the start of `date`.
    static func nextOccurrence(of weekday: Weekday, onOrAfter date: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: date)
        if calendar.component(.weekday, from: start) == weekday.rawValue {
            return start
        }
        return calendar.nextDate(
            after: start,
            matching: DateComponents(weekday: weekday.rawValue),
            matchingPolicy: .nextTime
        ) ?? start
    }

    /// Copies the hour/minute of `time` onto the calendar day of `day`.
    static func applying(time: Date, to day: Date, calendar: Calendar = .current) -> Date {
        let hm = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(
            bySettingHour: hm.hour ?? 0,
            minute: hm.minute ?? 0,
            second: 0,
            of: calendar.startOfDay(for: day)
        ) ?? day
    }
}
