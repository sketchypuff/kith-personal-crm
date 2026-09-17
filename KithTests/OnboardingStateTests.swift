import Foundation
import Testing
@testable import Kith

struct OnboardingStateTests {
    let preferences: TestPreferences

    init() throws {
        preferences = try TestPreferences()
    }

    private var defaults: UserDefaults { preferences.store }

    @Test func freshInstallStartsWithPeopleAndNoPermissionRequest() {
        let state = OnboardingState(defaults: defaults)
        let consent = NotificationConsent(defaults: defaults)
        state.prepare(people: [], consent: consent)
        #expect(state.step == .people)
        #expect(consent.choice == .pending)
        #expect(consent.invitation == nil)
        #expect(!AppPreferences.notificationsEnabled(in: defaults))
        #expect(AppPreferences.newContactCadence(in: defaults) == .weekly)
        #expect(AppPreferences.newContactNotifyDay(in: defaults) == .saturday)
    }

    @Test func existingEmptyInstallBypassesWithoutChangingPreferences() {
        AppPreferences.setTagsSeeded(true, in: defaults)
        let state = OnboardingState(defaults: defaults)
        let consent = NotificationConsent(defaults: defaults)
        state.prepare(people: [], consent: consent)
        #expect(state.step == .finished)
        #expect(consent.choice == .legacy)
        #expect(AppPreferences.notificationsEnabled(in: defaults))
        #expect(defaults.object(forKey: AppPreferences.Key.notificationsEnabled) == nil)
    }

    @Test func initiallyRestoredRosterBypassesWithoutDisablingNotifications() {
        let state = OnboardingState(defaults: defaults)
        let consent = NotificationConsent(defaults: defaults)
        state.prepare(people: [Person(name: "Maya", linkedContactID: "restored")], consent: consent)
        #expect(state.step == .finished)
        #expect(consent.choice == .legacy)
        #expect(AppPreferences.notificationsEnabled(in: defaults))
    }

    @Test func lateRestoreOffersContinuationWithoutInterruptingThePage() {
        let state = OnboardingState(defaults: defaults)
        let consent = NotificationConsent(defaults: defaults)
        state.prepare(people: [], consent: consent)
        state.show(.rhythm)
        state.peopleDidChange([Person(name: "Maya", linkedContactID: "restored")])
        #expect(state.step == .rhythm)
        #expect(state.hasRestoredPeople)
        #expect(consent.invitation == nil)
        state.finish()
        #expect(state.step == .finished)
    }

    @Test func progressSurvivesTheCurrentLaunchSeedingTags() {
        let state = OnboardingState(defaults: defaults)
        state.show(.privacy)
        AppPreferences.setTagsSeeded(true, in: defaults)
        let relaunched = OnboardingState(defaults: defaults)
        #expect(relaunched.step == .privacy)
    }

    @Test func unfinishedFormResumesAtTheInvitation() {
        OnboardingState(defaults: defaults).show(.addPerson)
        let relaunched = OnboardingState(defaults: defaults)
        relaunched.prepare(people: [], consent: NotificationConsent(defaults: defaults))
        #expect(relaunched.step == .addPerson)
        #expect(relaunched.firstPersonID == nil)
    }

    @Test func successfulSaveIsNotMistakenForRestoredData() {
        let state = OnboardingState(defaults: defaults)
        let consent = NotificationConsent(defaults: defaults)
        state.prepare(people: [], consent: consent)
        state.show(.addPerson)
        let person = Person(name: "Maya", linkedContactID: "new")
        state.recordSavedPerson(person)
        state.peopleDidChange([person])
        #expect(!state.hasRestoredPeople)
        state.saved(person, consent: consent)
        #expect(state.step == .notifications)
        #expect(state.firstPersonID == person.id)
    }

    @Test func relaunchAfterSavingButBeforeSheetDismissalResumesConsent() {
        let state = OnboardingState(defaults: defaults)
        let consent = NotificationConsent(defaults: defaults)
        state.prepare(people: [], consent: consent)
        state.show(.addPerson)
        let person = Person(name: "Maya", linkedContactID: "new")
        state.recordSavedPerson(person)

        let relaunched = OnboardingState(defaults: defaults)
        relaunched.prepare(people: [person], consent: NotificationConsent(defaults: defaults))
        #expect(relaunched.step == .notifications)
        #expect(relaunched.firstPersonID == person.id)
    }

    @Test func missingSavedPersonReturnsToSetup() {
        let state = OnboardingState(defaults: defaults)
        let consent = NotificationConsent(defaults: defaults)
        state.prepare(people: [], consent: consent)
        state.saved(Person(name: "Maya", linkedContactID: "removed"), consent: consent)
        let relaunched = OnboardingState(defaults: defaults)
        relaunched.prepare(people: [], consent: consent)
        #expect(relaunched.step == .addPerson)
        #expect(relaunched.firstPersonID == nil)
    }

    @Test func noRemindersFinishesWithoutAnsweringConsent() {
        let state = OnboardingState(defaults: defaults)
        let consent = NotificationConsent(defaults: defaults)
        state.prepare(people: [], consent: consent)
        let person = Person(name: "Maya", linkedContactID: "new")
        person.cadence = .never
        state.saved(person, consent: consent)
        #expect(state.step == .finished)
        #expect(consent.choice == .pending)
        #expect(consent.invitation == nil)
    }

    @Test func completionSurvivesAnEmptyRoster() {
        let state = OnboardingState(defaults: defaults)
        let consent = NotificationConsent(defaults: defaults)
        state.prepare(people: [], consent: consent)
        state.finish()
        let relaunched = OnboardingState(defaults: defaults)
        relaunched.prepare(people: [], consent: consent)
        #expect(relaunched.step == .finished)
        #expect(consent.choice == .pending)
    }

    @Test func sampleLaunchKeepsTheDevelopmentRosterFlow() {
        let state = OnboardingState(defaults: defaults, sampleLaunch: true)
        #expect(state.step == .finished)
        #expect(AppPreferences.notificationsEnabled(in: defaults))
    }
}
