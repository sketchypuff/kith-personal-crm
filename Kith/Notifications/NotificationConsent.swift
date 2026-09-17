import Foundation
import Observation
import SwiftData

@Observable
final class NotificationConsent {
    private(set) var choice: NotificationChoice
    private(set) var isWorking = false
    var invitation: NotificationInvitation?

    let notifications: NotificationScheduler
    private let defaults: UserDefaults

    init(
        defaults: UserDefaults = AppPreferences.store,
        notifications: NotificationScheduler = NotificationScheduler()
    ) {
        self.defaults = defaults
        self.notifications = notifications
        choice = AppPreferences.notificationChoice(in: defaults)
        if choice == .pending,
           let id = defaults.string(forKey: AppPreferences.Key.notificationInvitationPersonID).flatMap(UUID.init(uuidString:)) {
            invitation = NotificationInvitation(personID: id)
        }
    }

    static func hasReminder(_ person: Person) -> Bool {
        person.cadence != .never || (person.keyDates ?? []).contains(where: \.reminderEnabled)
    }

    func prepareFirstRun() {
        guard choice == .legacy else { return }
        setChoice(.pending)
        defaults.set(false, forKey: AppPreferences.Key.notificationsEnabled)
    }

    func considerReminder(for person: Person) {
        guard choice == .pending, invitation == nil, !isWorking, Self.hasReminder(person) else { return }
        reserveReminder(for: person)
        invitation = NotificationInvitation(personID: person.id)
    }

    func reserveReminder(for person: Person) {
        guard choice == .pending, Self.hasReminder(person) else { return }
        defaults.set(person.id.uuidString, forKey: AppPreferences.Key.notificationInvitationPersonID)
    }

    func reconcileInvitation(with people: [Person]) {
        guard let invitation else { return }
        if !people.contains(where: { $0.id == invitation.personID && Self.hasReminder($0) }) {
            dismissInvitation()
        }
    }

    func restoreInvitation(with people: [Person]) {
        if choice == .pending, invitation == nil,
           let id = defaults.string(forKey: AppPreferences.Key.notificationInvitationPersonID).flatMap(UUID.init(uuidString:)) {
            invitation = NotificationInvitation(personID: id)
        }
        reconcileInvitation(with: people)
    }

    func enable(in context: ModelContext) async throws -> Bool {
        guard !isWorking else { throw NotificationConsentError.requestInProgress }
        isWorking = true
        defer { isWorking = false }

        guard try await notifications.client.authorizeIfNeeded() else {
            decline()
            return false
        }
        let people = try context.fetch(FetchDescriptor<Person>())
        let planner = NotificationPlanner(
            notifications: notifications,
            defaultReminderTime: { AppPreferences.defaultReminderTime(in: self.defaults) },
            notificationsEnabled: { true }
        )
        try await planner.rescheduleAllAndWait(people)
        defaults.set(true, forKey: AppPreferences.Key.notificationsEnabled)
        setChoice(.enabled)
        dismissInvitation()
        return true
    }

    func decline() {
        defaults.set(false, forKey: AppPreferences.Key.notificationsEnabled)
        setChoice(.declined)
        notifications.cancelAll()
        dismissInvitation()
    }

    func dismissInvitation() {
        defaults.removeObject(forKey: AppPreferences.Key.notificationInvitationPersonID)
        invitation = nil
    }

    private func setChoice(_ choice: NotificationChoice) {
        self.choice = choice
        defaults.set(choice.rawValue, forKey: AppPreferences.Key.notificationChoice)
    }
}
