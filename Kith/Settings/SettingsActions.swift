import Foundation
import SwiftData

/// The Settings screen's side effects (Settings §9). Most rows are a plain
/// `@AppStorage` write with no effect beyond storing the value; the ones
/// that reach into the machinery come through here.
///
/// `defaults` is injected so tests can point the actions at a throwaway
/// suite instead of the App Group.
struct SettingsActions {
    let context: ModelContext
    let notifications: NotificationScheduler
    var defaults: UserDefaults = AppPreferences.store
    var now: () -> Date = { .now }
    var calendar: Calendar = .current

    private var planner: NotificationPlanner {
        NotificationPlanner(
            notifications: notifications,
            now: now,
            calendar: calendar,
            defaultReminderTime: { AppPreferences.defaultReminderTime(in: defaults) },
            notificationsEnabled: { AppPreferences.notificationsEnabled(in: defaults) }
        )
    }

    // MARK: - Notifications

    /// The all-people pass behind the default reminder time and the
    /// notifications switch: every person's requests are cancelled and re-planned
    /// under the current preferences, capped at `NotificationPlanner.pendingLimit`.
    /// Idempotent, so the view coalesces rapid changes into one call.
    func rescheduleAllNotifications() {
        let people: [Person]
        do {
            people = try context.fetch(FetchDescriptor<Person>())
        } catch {
            assertionFailure("Settings could not fetch people to reschedule: \(error)")
            return
        }
        planner.rescheduleAll(people)
    }

    // MARK: - Sync

    /// Rebuilds the container first and writes the preference only once the
    /// store reopened as requested, so a failed rebuild leaves both the
    /// container and the stored value exactly as they were (Settings §7.2).
    /// Turning sync off never touches the iCloud copy (§7.3).
    @discardableResult
    func setSyncEnabled(_ enabled: Bool, coordinator: ModelContainerCoordinator) -> Bool {
        guard coordinator.rebuild(syncEnabled: enabled) else { return false }
        defaults.set(enabled, forKey: AppPreferences.Key.syncEnabled)
        return true
    }
}
