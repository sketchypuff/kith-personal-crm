import Foundation

/// Device-local app preferences live in `UserDefaults` in the App Group —
/// never in the SwiftData store, so they are not synced (Settings spec §1).
///
/// Every reader comes in two forms: a static property against the App Group
/// suite, and a function taking an explicit `UserDefaults` so `SettingsActions`
/// tests can run against a throwaway suite. Both share one "missing key means
/// default" rule per key.
enum AppPreferences {
    static let suiteName = "group.com.yashshenai.kith"

    /// Falls back to `.standard` if the App Group is unavailable (e.g. a
    /// preview host without the entitlement) so `@AppStorage` never gets nil.
    static let store: UserDefaults = UserDefaults(suiteName: suiteName) ?? .standard

    enum Key {
        static let syncEnabled = "syncEnabled"
        static let defaultReminderTime = "defaultReminderTime"      // TimeInterval since reference date
        static let newContactCadence = "newContactCadence"          // Cadence raw value
        static let newContactNotifyDay = "newContactNotifyDay"      // Weekday raw value
        static let notificationsEnabled = "notificationsEnabled"     // the one notifications switch
        static let lockEnabled = "lockEnabled"                       // privacy lock (Settings §6.1)
        static let lockGracePeriod = "lockGracePeriod"               // LockGracePeriod raw value (Settings §6.2)
        static let appTheme = "appTheme"                             // AppTheme raw value; default system
    }

    // MARK: - App Group suite

    static var notificationsEnabled: Bool { notificationsEnabled(in: store) }
    static var syncEnabled: Bool { syncEnabled(in: store) }
    static var defaultReminderTime: Date { defaultReminderTime(in: store) }
    static var newContactCadence: Cadence { newContactCadence(in: store) }
    static var newContactNotifyDay: Weekday { newContactNotifyDay(in: store) }
    static var lockEnabled: Bool { lockEnabled(in: store) }
    static var lockGracePeriod: LockGracePeriod { lockGracePeriod(in: store) }
    static var appTheme: AppTheme { appTheme(in: store) }

    // MARK: - Explicit suite

    /// The notifications switch defaults to on. `bool(forKey:)` reads a missing
    /// key as false, so an absent value has to be treated as true explicitly.
    static func notificationsEnabled(in store: UserDefaults) -> Bool {
        store.object(forKey: Key.notificationsEnabled) as? Bool ?? true
    }

    /// Defaults to on when a usable iCloud account exists, off otherwise
    /// (Settings §7.1). Same missing-key pattern as the notifications switch.
    static func syncEnabled(in store: UserDefaults) -> Bool {
        store.object(forKey: Key.syncEnabled) as? Bool ?? ModelContainerCoordinator.isICloudAvailable
    }

    /// Seed for a new contact's Notify time (and the key-date reminder time).
    static func defaultReminderTime(in store: UserDefaults) -> Date {
        let interval = store.double(forKey: Key.defaultReminderTime)
        return interval == 0 ? Person.defaultNotifyTime : Date(timeIntervalSinceReferenceDate: interval)
    }

    static func newContactCadence(in store: UserDefaults) -> Cadence {
        Cadence(rawValue: store.string(forKey: Key.newContactCadence) ?? "") ?? .weekly
    }

    static func newContactNotifyDay(in store: UserDefaults) -> Weekday {
        Weekday(rawValue: store.integer(forKey: Key.newContactNotifyDay)) ?? .saturday
    }

    /// Off by default (PRD P0-13), so a missing key reading as false is right.
    static func lockEnabled(in store: UserDefaults) -> Bool {
        store.bool(forKey: Key.lockEnabled)
    }

    static func lockGracePeriod(in store: UserDefaults) -> LockGracePeriod {
        LockGracePeriod(rawValue: store.integer(forKey: Key.lockGracePeriod)) ?? .immediately
    }

    static func appTheme(in store: UserDefaults) -> AppTheme {
        AppTheme(rawValue: store.string(forKey: Key.appTheme) ?? "") ?? .system
    }
}
