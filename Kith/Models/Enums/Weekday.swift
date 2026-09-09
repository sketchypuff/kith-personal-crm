import Foundation

/// Raw values match `Calendar`'s weekday numbering (1 = Sunday) so alignment
/// onto `notifyDay` is a direct comparison with no remapping.
nonisolated enum Weekday: Int, Codable, CaseIterable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var label: String {
        Calendar.current.weekdaySymbols[rawValue - 1]
    }
}
