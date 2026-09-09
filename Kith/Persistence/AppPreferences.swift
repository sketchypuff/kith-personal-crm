import Foundation

/// Device-local app preferences live in `UserDefaults` in the App Group —
/// never in the SwiftData store, so they are not synced (Settings spec §1).
enum AppPreferences {
    static let suiteName = "group.com.yash.kith"

    /// Falls back to `.standard` if the App Group is unavailable (e.g. a
    /// preview host without the entitlement) so `@AppStorage` never gets nil.
    static let store: UserDefaults = UserDefaults(suiteName: suiteName) ?? .standard

    enum Key {
        static let syncEnabled = "syncEnabled"
        static let defaultReminderTime = "defaultReminderTime"      // TimeInterval since reference date
        static let newContactCadence = "newContactCadence"          // Cadence raw value
        static let newContactNotifyDay = "newContactNotifyDay"      // Weekday raw value
        static let notifyReachOutsEnabled = "notifyReachOutsEnabled" // category switch (Settings §4.2)
        static let notifyKeyDatesEnabled = "notifyKeyDatesEnabled"   // category switch (Settings §4.2)
    }

    /// Category switches default to on. `bool(forKey:)` reads a missing key as
    /// false, so an absent value has to be treated as true explicitly.
    static var notifyReachOutsEnabled: Bool {
        store.object(forKey: Key.notifyReachOutsEnabled) as? Bool ?? true
    }

    static var notifyKeyDatesEnabled: Bool {
        store.object(forKey: Key.notifyKeyDatesEnabled) as? Bool ?? true
    }

    static var syncEnabled: Bool {
        store.bool(forKey: Key.syncEnabled)
    }

    /// Seed for a new contact's Notify time (and the key-date reminder time).
    static var defaultReminderTime: Date {
        let interval = store.double(forKey: Key.defaultReminderTime)
        return interval == 0 ? Person.defaultNotifyTime : Date(timeIntervalSinceReferenceDate: interval)
    }

    static var newContactCadence: Cadence {
        Cadence(rawValue: store.string(forKey: Key.newContactCadence) ?? "") ?? .weekly
    }

    static var newContactNotifyDay: Weekday {
        Weekday(rawValue: store.integer(forKey: Key.newContactNotifyDay)) ?? .saturday
    }
}
