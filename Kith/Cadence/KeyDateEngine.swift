import Foundation

/// Occurrence math for annual key dates. Kept next to `CadenceEngine` so all
/// date derivation lives in one place.
nonisolated enum KeyDateEngine {

    /// The next occurrence of `month/day` on or after the start of `now`'s day.
    /// A Feb 29 date resolves to Mar 1 in non-leap years via `.nextTime`.
    static func nextOccurrence(month: Int, day: Int, from now: Date, calendar: Calendar = .current) -> Date? {
        let startOfToday = calendar.startOfDay(for: now)
        // `nextDate(after:)` is exclusive, so step back a second to include today.
        let justBefore = startOfToday.addingTimeInterval(-1)
        return calendar.nextDate(
            after: justBefore,
            matching: DateComponents(month: month, day: day),
            matchingPolicy: .nextTime
        )
    }

    /// Whole calendar days from the start of `now`'s day to `occurrence` (0 = today).
    static func daysUntil(_ occurrence: Date, from now: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: occurrence)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// The first day of the lead window for an occurrence.
    static func windowStart(for occurrence: Date, leadTimeDays: Int, calendar: Calendar = .current) -> Date {
        let day = calendar.startOfDay(for: occurrence)
        return calendar.date(byAdding: .day, value: -max(0, leadTimeDays), to: day) ?? day
    }
}
