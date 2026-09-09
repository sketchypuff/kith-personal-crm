import Foundation
import SwiftData
import Testing
@testable import Kith

/// A class suite so each test's throwaway `UserDefaults` suite is removed in
/// `deinit` instead of littering the test host's preferences.
final class SettingsActionsTests {
    let calendar = Calendar(identifier: .gregorian)
    let container = ModelContainerCoordinator.inMemory()
    let recorder = NotificationRecorder()
    let suiteName = "KithTests.settings.\(UUID().uuidString)"
    let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit {
        // `deinit` is nonisolated and `UserDefaults` isn't Sendable, so rebuild
        // the suite from its (Sendable) name rather than touching `defaults`.
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    /// Wed 9 Sep 2026, 10:00.
    var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 10))!
    }

    private var actions: SettingsActions {
        SettingsActions(
            context: container.mainContext,
            notifications: NotificationScheduler(recorder: recorder),
            defaults: defaults,
            now: { self.now },
            calendar: calendar
        )
    }

    private func date(_ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private func setReminderTime(hour: Int, minute: Int) {
        let time = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now)!
        defaults.set(time.timeIntervalSinceReferenceDate, forKey: AppPreferences.Key.defaultReminderTime)
    }

    // MARK: - Fixtures

    /// Weekly / Saturday / 6:00 PM, logged yesterday → due Sat 12 Sep 18:00.
    /// Carries an anniversary on 20 Sep with a 3-day lead (17 Sep).
    private func maya() -> (Person, KeyDate) {
        let person = Person(name: "Maya", linkedContactID: "")
        person.notifyTime = date(9, 9, hour: 18)
        person.lastLoggedAt = calendar.date(byAdding: .day, value: -1, to: now)
        container.mainContext.insert(person)

        let keyDate = KeyDate()
        keyDate.type = .anniversary
        keyDate.month = 9
        keyDate.day = 20
        keyDate.leadTimeDays = 3
        keyDate.person = person
        container.mainContext.insert(keyDate)
        return (person, keyDate)
    }

    /// Overdue and snoozed: held through the end of today, nudge tomorrow 18:00.
    private func noor() -> Person {
        let person = Person(name: "Noor", linkedContactID: "")
        person.notifyTime = date(9, 9, hour: 18)
        person.lastLoggedAt = calendar.date(byAdding: .day, value: -20, to: now)
        person.remindOn = date(9, 10).addingTimeInterval(-1)
        container.mainContext.insert(person)
        return person
    }

    // MARK: - Notifications switch

    @Test func notificationsOffCancelsEveryPendingID() throws {
        let (maya, anniversary) = maya()
        let noor = noor()
        setReminderTime(hour: 9, minute: 30)

        actions.rescheduleAllNotifications()
        let mayaDue = try #require(maya.nextDue)
        #expect(recorder.pending[maya.reachOutNotificationID] == mayaDue)
        #expect(recorder.pending[noor.remindTomorrowNotificationID] == date(9, 10, hour: 18))
        #expect(recorder.pending[anniversary.leadNotificationID] == date(9, 17, hour: 9, minute: 30))
        #expect(recorder.pending[anniversary.dayOfNotificationID] == date(9, 20, hour: 9, minute: 30))

        defaults.set(false, forKey: AppPreferences.Key.notificationsEnabled)
        actions.rescheduleAllNotifications()

        for id in [maya.reachOutNotificationID, maya.remindTomorrowNotificationID,
                   noor.reachOutNotificationID, noor.remindTomorrowNotificationID,
                   anniversary.leadNotificationID, anniversary.dayOfNotificationID] {
            #expect(recorder.cancelled.contains(id))
        }
        #expect(recorder.pending.isEmpty)
    }

    @Test func notificationsOnReschedulesEverything() throws {
        let (maya, anniversary) = maya()
        let noor = noor()
        setReminderTime(hour: 9, minute: 30)
        defaults.set(false, forKey: AppPreferences.Key.notificationsEnabled)
        actions.rescheduleAllNotifications()
        #expect(recorder.pending.isEmpty)

        defaults.set(true, forKey: AppPreferences.Key.notificationsEnabled)
        actions.rescheduleAllNotifications()

        let mayaDue = try #require(maya.nextDue)
        #expect(recorder.pending[maya.reachOutNotificationID] == mayaDue)
        #expect(recorder.pending[noor.remindTomorrowNotificationID] == date(9, 10, hour: 18))
        #expect(recorder.pending[anniversary.leadNotificationID] == date(9, 17, hour: 9, minute: 30))
        #expect(recorder.pending[anniversary.dayOfNotificationID] == date(9, 20, hour: 9, minute: 30))
        // Noor is already overdue: no past-dated reach-out request.
        #expect(recorder.pending[noor.reachOutNotificationID] == nil)
    }

    // MARK: - Default reminder time

    @Test func reminderTimeChangeMovesKeyDatesButNotReachOuts() throws {
        let (maya, anniversary) = maya()
        setReminderTime(hour: 9, minute: 30)
        actions.rescheduleAllNotifications()
        let reachOutBefore = try #require(recorder.pending[maya.reachOutNotificationID])
        #expect(recorder.pending[anniversary.dayOfNotificationID] == date(9, 20, hour: 9, minute: 30))

        setReminderTime(hour: 7, minute: 15)
        actions.rescheduleAllNotifications()

        #expect(recorder.pending[anniversary.leadNotificationID] == date(9, 17, hour: 7, minute: 15))
        #expect(recorder.pending[anniversary.dayOfNotificationID] == date(9, 20, hour: 7, minute: 15))
        #expect(recorder.pending[maya.reachOutNotificationID] == reachOutBefore)
        #expect(calendar.component(.hour, from: reachOutBefore) == 18)
    }

    // MARK: - New-contact defaults

    @Test func newContactDefaultsChangeNothingElse() throws {
        let (maya, _) = maya()
        try container.mainContext.save()
        setReminderTime(hour: 9, minute: 30)
        actions.rescheduleAllNotifications()
        let pendingBefore = recorder.pending
        let cadenceBefore = (maya.cadenceRaw, maya.notifyDayRaw, maya.notifyTime, maya.nextDue)

        // What the two pickers write.
        defaults.set(Cadence.monthly.rawValue, forKey: AppPreferences.Key.newContactCadence)
        defaults.set(Weekday.tuesday.rawValue, forKey: AppPreferences.Key.newContactNotifyDay)

        #expect(AppPreferences.newContactCadence(in: defaults) == .monthly)
        #expect(AppPreferences.newContactNotifyDay(in: defaults) == .tuesday)
        #expect(maya.cadenceRaw == cadenceBefore.0)
        #expect(maya.notifyDayRaw == cadenceBefore.1)
        #expect(maya.notifyTime == cadenceBefore.2)
        #expect(maya.nextDue == cadenceBefore.3)
        #expect(recorder.pending == pendingBefore)
        #expect(!container.mainContext.hasChanges)

        // Even a later pass sees the same requests: the seed is not an input.
        actions.rescheduleAllNotifications()
        #expect(recorder.pending == pendingBefore)
    }

    @Test func missingKeysReadAsTheDocumentedDefaults() {
        #expect(AppPreferences.notificationsEnabled(in: defaults))
        #expect(AppPreferences.newContactCadence(in: defaults) == .weekly)
        #expect(AppPreferences.newContactNotifyDay(in: defaults) == .saturday)
        #expect(AppPreferences.lockEnabled(in: defaults) == false)
        #expect(AppPreferences.lockGracePeriod(in: defaults) == .immediately)
        #expect(calendar.component(.hour, from: AppPreferences.defaultReminderTime(in: defaults)) == 18)
    }

    // MARK: - Pending cap

    @Test func allPeoplePassStopsAtThePendingLimitKeepingTheNearest() {
        // Daily cadence: due tomorrow at each person's own minute, so fire
        // dates are distinct and ordered by index.
        var people: [Person] = []
        for minute in 0..<(NotificationPlanner.pendingLimit + 10) {
            let person = Person(name: "Person \(minute)", linkedContactID: "")
            person.cadence = .daily
            person.lastLoggedAt = now
            person.notifyTime = date(9, 9, hour: 10, minute: minute)
            container.mainContext.insert(person)
            people.append(person)
        }

        actions.rescheduleAllNotifications()

        #expect(recorder.pending.count == NotificationPlanner.pendingLimit)
        #expect(recorder.pending[people[0].reachOutNotificationID] != nil)
        #expect(recorder.pending[people[NotificationPlanner.pendingLimit - 1].reachOutNotificationID] != nil)
        #expect(recorder.pending[people[NotificationPlanner.pendingLimit].reachOutNotificationID] == nil)
    }

    // MARK: - Sync

    @Test func turningSyncOffRebuildsLocallyAndLeavesTheStoreIntact() throws {
        let storeURL = URL.temporaryDirectory.appending(path: "KithTests-\(UUID().uuidString).store")
        defer { removeStore(at: storeURL) }

        let coordinator = ModelContainerCoordinator(syncEnabled: false, storeURL: storeURL)
        let context = coordinator.container.mainContext
        context.insert(Person(name: "Maya", linkedContactID: "ABC"))
        try context.save()
        let before = ObjectIdentifier(coordinator.container)

        let actions = SettingsActions(
            context: context,
            notifications: NotificationScheduler(recorder: recorder),
            defaults: defaults
        )
        #expect(actions.setSyncEnabled(false, coordinator: coordinator))

        #expect(ObjectIdentifier(coordinator.container) != before)
        #expect(coordinator.syncEnabled == false)
        #expect(AppPreferences.syncEnabled(in: defaults) == false)
        #expect(try coordinator.container.mainContext.fetchCount(FetchDescriptor<Person>()) == 1)
        #expect(recorder.cancelled.isEmpty)   // sync never touches notifications
    }

    /// A `.private` container opens on the simulator even with no iCloud
    /// account (mirroring just never connects), so this covers the on path:
    /// same store, preference written only after the rebuild. The §7.2
    /// rollback path can't be forced here and is exercised only by `SyncSection`.
    @Test func turningSyncOnRebuildsWithTheStoreIntactAndWritesThePreference() throws {
        let storeURL = URL.temporaryDirectory.appending(path: "KithTests-\(UUID().uuidString).store")
        defer { removeStore(at: storeURL) }

        let coordinator = ModelContainerCoordinator(syncEnabled: false, storeURL: storeURL)
        let context = coordinator.container.mainContext
        context.insert(Person(name: "Maya", linkedContactID: "ABC"))
        try context.save()
        #expect(defaults.object(forKey: AppPreferences.Key.syncEnabled) == nil)

        let actions = SettingsActions(
            context: context,
            notifications: NotificationScheduler(recorder: recorder),
            defaults: defaults
        )
        #expect(actions.setSyncEnabled(true, coordinator: coordinator))

        #expect(coordinator.syncEnabled)
        #expect(AppPreferences.syncEnabled(in: defaults))
        #expect(try coordinator.container.mainContext.fetchCount(FetchDescriptor<Person>()) == 1)
    }

    private func removeStore(at url: URL) {
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(filePath: url.path + suffix))
        }
    }
}
