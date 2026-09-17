import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import Kith

struct NotificationConsentTests {
    let preferences: TestPreferences
    let container = ModelContainerCoordinator.inMemory()
    let client = NotificationClientStub()

    init() throws {
        preferences = try TestPreferences()
    }

    private var defaults: UserDefaults { preferences.store }

    private func consent() -> NotificationConsent {
        NotificationConsent(defaults: defaults, notifications: NotificationScheduler(client: client.client))
    }

    private func person(withBirthday: Bool = false) throws -> Person {
        let person = Person(name: "Maya", linkedContactID: "new")
        person.cadence = .daily
        container.mainContext.insert(person)
        if withBirthday {
            let date = KeyDate()
            date.month = 4
            date.day = 12
            date.person = person
            container.mainContext.insert(date)
        }
        try container.mainContext.save()
        return person
    }

    @Test func preparingAndConsideringDoNotRequestSystemPermission() throws {
        let consent = consent()
        consent.prepareFirstRun()
        consent.considerReminder(for: try person())
        #expect(consent.invitation != nil)
        #expect(client.authorizationRequests == 0)
        #expect(client.added.isEmpty)
        #expect(!AppPreferences.notificationsEnabled(in: defaults))
    }

    @Test func neverWaitsForARealReminder() throws {
        let consent = consent()
        consent.prepareFirstRun()
        let person = try person()
        person.cadence = .never
        consent.considerReminder(for: person)
        #expect(consent.invitation == nil)
        person.cadence = .weekly
        consent.considerReminder(for: person)
        #expect(consent.invitation?.personID == person.id)
    }

    @Test func birthdayAloneCanMakeTheInvitationEligible() throws {
        let consent = consent()
        consent.prepareFirstRun()
        let person = try person(withBirthday: true)
        person.cadence = .never
        consent.considerReminder(for: person)
        #expect(consent.invitation?.personID == person.id)
    }

    @Test func answeringNotNowPreventsFutureInvitations() throws {
        let consent = consent()
        consent.prepareFirstRun()
        let person = try person()
        consent.considerReminder(for: person)
        consent.decline()
        consent.considerReminder(for: person)
        #expect(consent.choice == .declined)
        #expect(consent.invitation == nil)
        #expect(client.authorizationRequests == 0)
        #expect(client.removeAllCount == 1)
        #expect(!AppPreferences.notificationsEnabled(in: defaults))
        #expect(person.nextDue != nil)
    }

    @Test func enableSchedulesTheSavedReachOutAndBirthday() async throws {
        let consent = consent()
        consent.prepareFirstRun()
        let person = try person(withBirthday: true)
        #expect(try await consent.enable(in: container.mainContext))
        let birthday = try #require(person.keyDates?.first)
        let ids = Set(client.added.map(\.identifier))
        #expect(ids.contains(person.reachOutNotificationID))
        #expect(ids.contains(birthday.leadNotificationID))
        #expect(ids.contains(birthday.dayOfNotificationID))
        #expect(client.authorizationRequests == 1)
        #expect(consent.choice == .enabled)
        #expect(AppPreferences.notificationsEnabled(in: defaults))
        #expect(consent.invitation == nil)
        #expect(!consent.isWorking)
    }

    @Test func alreadyGrantedPermissionIsNotRequestedAgain() async throws {
        client.status = .authorized
        let consent = consent()
        consent.prepareFirstRun()
        _ = try person()
        #expect(try await consent.enable(in: container.mainContext))
        #expect(client.authorizationRequests == 0)
        #expect(!client.added.isEmpty)
    }

    @Test func denialFinishesWithoutSchedulingOrRepeatingTheInvitation() async throws {
        client.grantsPermission = false
        let consent = consent()
        consent.prepareFirstRun()
        let person = try person()
        #expect(try await consent.enable(in: container.mainContext) == false)
        consent.considerReminder(for: person)
        #expect(consent.choice == .declined)
        #expect(consent.invitation == nil)
        #expect(client.added.isEmpty)
        #expect(client.authorizationRequests == 1)
    }

    @Test func authorizationErrorsRemainRetryable() async throws {
        client.authorizationError = CocoaError(.featureUnsupported)
        let consent = consent()
        consent.prepareFirstRun()
        await #expect(throws: CocoaError.self) {
            try await consent.enable(in: container.mainContext)
        }
        #expect(consent.choice == .pending)
        #expect(!consent.isWorking)
        #expect(!AppPreferences.notificationsEnabled(in: defaults))
        #expect(client.added.isEmpty)
    }

    @Test func schedulingFailureCancelsThePartialPassAndDoesNotClaimEnablement() async throws {
        client.failAfterAdds = 1
        let consent = consent()
        consent.prepareFirstRun()
        let person = try person(withBirthday: true)
        await #expect(throws: CocoaError.self) {
            try await consent.enable(in: container.mainContext)
        }
        #expect(consent.choice == .pending)
        #expect(!AppPreferences.notificationsEnabled(in: defaults))
        #expect(client.removed.contains(person.reachOutNotificationID))
        #expect(!consent.isWorking)

        client.failAfterAdds = nil
        #expect(try await consent.enable(in: container.mainContext))
        #expect(client.authorizationRequests == 1)
        #expect(consent.choice == .enabled)
    }

    @Test func settingsCanEnableAfterAnEarlierDecline() async throws {
        let consent = consent()
        consent.prepareFirstRun()
        consent.decline()
        client.status = .authorized
        _ = try person()
        #expect(try await consent.enable(in: container.mainContext))
        #expect(AppPreferences.notificationsEnabled(in: defaults))
        #expect(consent.choice == .enabled)
        #expect(client.authorizationRequests == 0)
    }

    @Test func invitationIsReservedBeforeTheSetupSheetCloses() throws {
        let consent = consent()
        consent.prepareFirstRun()
        let person = try person()
        consent.reserveReminder(for: person)
        #expect(consent.invitation == nil)
        let relaunched = self.consent()
        relaunched.reconcileInvitation(with: [person])
        #expect(relaunched.invitation?.personID == person.id)
    }

    @Test func removedPersonDoesNotLeaveAStaleInvitation() throws {
        let consent = consent()
        consent.prepareFirstRun()
        consent.considerReminder(for: try person())
        consent.reconcileInvitation(with: [])
        #expect(consent.invitation == nil)
        #expect(defaults.string(forKey: AppPreferences.Key.notificationInvitationPersonID) == nil)
        #expect(consent.choice == .pending)
    }

    @Test func interruptedPresentationCanResumeAfterUnlockWithoutRenaggingADecline() throws {
        let consent = consent()
        consent.prepareFirstRun()
        let person = try person()
        consent.considerReminder(for: person)
        consent.invitation = nil
        consent.restoreInvitation(with: [person])
        #expect(consent.invitation?.personID == person.id)
        consent.decline()
        consent.restoreInvitation(with: [person])
        #expect(consent.invitation == nil)
    }

    @Test func establishedUsersAreNotEnrolledIntoInvitations() throws {
        let consent = consent()
        consent.considerReminder(for: try person())
        #expect(consent.choice == .legacy)
        #expect(consent.invitation == nil)
        #expect(AppPreferences.notificationsEnabled(in: defaults))
    }

    @Test func optInUsesTheExistingPendingLimit() async throws {
        for index in 0..<(NotificationPlanner.pendingLimit + 5) {
            let person = Person(name: "Person \(index)", linkedContactID: "\(index)")
            person.cadence = .daily
            container.mainContext.insert(person)
        }
        try container.mainContext.save()
        let consent = consent()
        consent.prepareFirstRun()
        #expect(try await consent.enable(in: container.mainContext))
        #expect(client.added.count == NotificationPlanner.pendingLimit)
    }

    @Test func schedulingCannotBypassAPendingOrDeclinedChoice() async throws {
        let scheduler = NotificationScheduler(client: client.client, defaults: defaults)
        let consent = NotificationConsent(defaults: defaults, notifications: scheduler)
        consent.prepareFirstRun()
        let request = PlannedNotification(kind: .reachOut(try person()), fireAt: .now.addingTimeInterval(86_400)).request
        try await scheduler.sendIfAllowed(request)
        #expect(client.authorizationRequests == 0)
        #expect(client.added.isEmpty)

        consent.decline()
        // Even a stale write to the old switch cannot override the choice.
        defaults.set(true, forKey: AppPreferences.Key.notificationsEnabled)
        try await scheduler.sendIfAllowed(request)
        #expect(client.authorizationRequests == 0)
        #expect(client.added.isEmpty)
    }

    @Test func legacyAuthorizedSchedulingStillWorks() async throws {
        client.status = .authorized
        let scheduler = NotificationScheduler(client: client.client, defaults: defaults)
        let request = PlannedNotification(kind: .reachOut(try person()), fireAt: .now.addingTimeInterval(86_400)).request
        try await scheduler.sendIfAllowed(request)
        #expect(client.added.map(\.identifier) == [request.id])
        #expect(client.authorizationRequests == 0)
    }
}
