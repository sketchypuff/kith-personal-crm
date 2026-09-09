import Foundation
import SwiftData

/// A recurring date. Month/day/optional-year are stored as integers, not a
/// `Date`, so the annual recurrence is intrinsic and timezone-stable.
@Model
final class KeyDate {
    var id: UUID = UUID()

    var typeRaw: String = KeyDateType.birthday.rawValue
    var customLabel: String? = nil     // used when type == .custom

    var month: Int = 1                 // 1...12
    var day: Int = 1                   // 1...31
    var year: Int? = nil               // nil = year unknown

    var recurrenceRaw: String = Recurrence.annual.rawValue
    var leadTimeDays: Int = 3
    var reminderEnabled: Bool = true

    /// When Today's check last marked an occurrence handled. An occurrence is
    /// handled while this falls inside its lead window (Home §5: "handled
    /// until next recurrence"). Optional, so it is CloudKit-safe.
    var lastHandledAt: Date? = nil

    var person: Person?   // inverse declared on Person.keyDates

    init() {}

    var type: KeyDateType {
        get { KeyDateType(rawValue: typeRaw) ?? .custom }
        set { typeRaw = newValue.rawValue }
    }

    /// "Birthday", "Anniversary", or the custom label.
    var label: String {
        switch type {
        case .custom:
            let custom = customLabel?.trimmingCharacters(in: .whitespaces) ?? ""
            return custom.isEmpty ? "Date" : custom
        default:
            return type.label
        }
    }
}
