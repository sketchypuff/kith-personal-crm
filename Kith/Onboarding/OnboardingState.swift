import Foundation
import Observation

@Observable
final class OnboardingState {
    private(set) var step: OnboardingStep
    private(set) var firstPersonID: UUID?
    private(set) var hasRestoredPeople = false
    private let defaults: UserDefaults

    init(defaults: UserDefaults = AppPreferences.store, sampleLaunch: Bool = false) {
        self.defaults = defaults
        firstPersonID = defaults.string(forKey: AppPreferences.Key.onboardingPersonID).flatMap(UUID.init(uuidString:))
        if let saved = defaults.string(forKey: AppPreferences.Key.onboardingStep) {
            step = OnboardingStep(rawValue: saved) ?? .finished
        } else {
            // Snapshot the legacy marker before this launch seeds its tags.
            step = AppPreferences.tagsSeeded(in: defaults) || sampleLaunch ? .finished : .people
        }
        defaults.set(step.rawValue, forKey: AppPreferences.Key.onboardingStep)
    }

    func prepare(people: [Person], consent: NotificationConsent) {
        guard step != .finished else { return }
        if firstPersonID == nil, !people.isEmpty {
            finish()
            return
        }
        consent.prepareFirstRun()
        if step == .notifications || firstPersonID != nil {
            guard let person = people.first(where: { $0.id == firstPersonID }) else {
                firstPersonID = nil
                defaults.removeObject(forKey: AppPreferences.Key.onboardingPersonID)
                show(.addPerson)
                return
            }
            saved(person, consent: consent)
        }
    }

    func peopleDidChange(_ people: [Person]) {
        guard step != .finished else { return }
        hasRestoredPeople = people.contains { $0.id != firstPersonID }
    }

    func show(_ step: OnboardingStep) {
        self.step = step
        defaults.set(step.rawValue, forKey: AppPreferences.Key.onboardingStep)
    }

    func saved(_ person: Person, consent: NotificationConsent) {
        recordSavedPerson(person)
        hasRestoredPeople = false
        if consent.choice == .pending, NotificationConsent.hasReminder(person) {
            show(.notifications)
        } else {
            finish()
        }
    }

    func recordSavedPerson(_ person: Person) {
        firstPersonID = person.id
        defaults.set(person.id.uuidString, forKey: AppPreferences.Key.onboardingPersonID)
    }

    func foundExistingPerson() {
        hasRestoredPeople = true
    }

    func finish() {
        show(.finished)
        defaults.removeObject(forKey: AppPreferences.Key.onboardingPersonID)
        firstPersonID = nil
    }
}
