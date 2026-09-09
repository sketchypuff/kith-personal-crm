import Foundation

/// The editable form state behind the key-date editor. Holds exactly what
/// persists — month, day, and an optional year — so the wheel picker can offer
/// a "no year" choice the way Contacts does.
struct KeyDateDraft: Equatable {
    var type: KeyDateType
    var customLabel = ""
    var month: Int
    var day: Int
    var year: Int?
    var leadTimeDays = 3
    var reminderEnabled = true

    init(type: KeyDateType, month: Int, day: Int, year: Int? = nil) {
        self.type = type
        self.month = month
        self.day = day
        self.year = year
    }

    init(keyDate: KeyDate) {
        type = keyDate.type
        customLabel = keyDate.customLabel ?? ""
        month = keyDate.month
        day = keyDate.day
        year = keyDate.year
        leadTimeDays = keyDate.leadTimeDays
        reminderEnabled = keyDate.reminderEnabled
    }

    var trimmedLabel: String {
        customLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A custom date needs a label; the built-in types name themselves.
    var isValid: Bool {
        type != .custom || !trimmedLabel.isEmpty
    }

    /// Days in the chosen month. With no year, a leap year is assumed so
    /// 29 February stays selectable.
    static func daysIn(month: Int, year: Int?, calendar: Calendar = .current) -> Int {
        let components = DateComponents(year: year ?? 2000, month: month, day: 1)
        guard let date = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: date) else { return 31 }
        return range.count
    }

    /// Keeps the day inside the month after a month or year change.
    mutating func clampDay(calendar: Calendar = .current) {
        day = min(max(1, day), Self.daysIn(month: month, year: year, calendar: calendar))
    }

    /// Writes the draft onto a model.
    func apply(to keyDate: KeyDate, calendar: Calendar) {
        var clamped = self
        clamped.clampDay(calendar: calendar)
        keyDate.type = type
        keyDate.customLabel = type == .custom ? trimmedLabel : nil
        keyDate.month = clamped.month
        keyDate.day = clamped.day
        keyDate.year = year
        keyDate.leadTimeDays = max(0, leadTimeDays)
        keyDate.reminderEnabled = reminderEnabled
    }
}
