import Foundation

extension KeyDate {
    var leadNotificationID: String { "keydate-\(id.uuidString)-lead" }
    var dayOfNotificationID: String { "keydate-\(id.uuidString)-day" }

    /// The next occurrence on or after today.
    func nextOccurrence(from now: Date, calendar: Calendar = .current) -> Date? {
        KeyDateEngine.nextOccurrence(month: month, day: day, from: now, calendar: calendar)
    }

    /// A `Date` on this month/day for display and `DatePicker` seeding: the
    /// stored year when known, else the year of `reference`.
    func displayDate(in reference: Date = .now, calendar: Calendar = .current) -> Date? {
        let year = year ?? calendar.component(.year, from: reference)
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    /// Whether the given occurrence was already checked off on Today. Handled
    /// means `lastHandledAt` falls inside that occurrence's lead window, so the
    /// mark naturally expires when the next year's window opens.
    func isHandled(occurrence: Date, calendar: Calendar = .current) -> Bool {
        guard let lastHandledAt else { return false }
        let windowStart = KeyDateEngine.windowStart(for: occurrence, leadTimeDays: leadTimeDays, calendar: calendar)
        let windowEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: occurrence)) ?? occurrence
        return lastHandledAt >= windowStart && lastHandledAt < windowEnd
    }
}
