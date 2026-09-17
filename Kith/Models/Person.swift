import Foundation
import SwiftData

/// The aggregate root. Owns its touches, skip markers, and key dates.
///
/// Shaped for CloudKit mirroring: no unique constraints, every relationship
/// optional, every non-optional attribute defaulted, inverses declared here
/// (once) so the cascade delete propagates.
@Model
final class Person {
    // Identity — stable UUID for notification IDs and external refs.
    var id: UUID = UUID()

    // Core
    var name: String = ""
    var linkedContactID: String = ""     // Apple Contacts identifier; always set in v1
    var createdAt: Date = Date.now       // fallback anchor for nextDue when never logged

    // Cadence (the "Notify" config) — enums stored as raw values.
    var cadenceRaw: String = Cadence.weekly.rawValue
    var notifyDayRaw: Int = Weekday.saturday.rawValue
    var notifyTime: Date = Person.defaultNotifyTime   // only hour/minute are meaningful

    // Grouping + memory
    var tags: [String] = []
    var notes: String = ""

    /// An IANA identifier, set only when the guess from their phone number was
    /// absent or wrong. Nil means "work it out" — see `PersonTimeZone`.
    /// Optional, so the CloudKit mirror stays additive.
    var timeZoneIdentifier: String? = nil

    // Clock state
    var lastLoggedAt: Date? = nil        // nil until the first touch
    var remindOn: Date? = nil            // "remind me tomorrow" hold

    // Relationships — optional for CloudKit; cascade on delete; inverse declared here.
    @Relationship(deleteRule: .cascade, inverse: \Touch.person)
    var touches: [Touch]? = []

    @Relationship(deleteRule: .cascade, inverse: \SkipMarker.person)
    var skipMarkers: [SkipMarker]? = []

    @Relationship(deleteRule: .cascade, inverse: \KeyDate.person)
    var keyDates: [KeyDate]? = []

    init(name: String, linkedContactID: String) {
        self.name = name
        self.linkedContactID = linkedContactID
    }

    var cadence: Cadence {
        get { Cadence(rawValue: cadenceRaw) ?? .weekly }
        set { cadenceRaw = newValue.rawValue }
    }

    var notifyDay: Weekday {
        get { Weekday(rawValue: notifyDayRaw) ?? .saturday }
        set { notifyDayRaw = newValue.rawValue }
    }

    /// 6:00 PM (PRD default: Weekly / Saturday / 6:00 PM).
    static let defaultNotifyTime: Date =
        Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: .now) ?? .now
}
