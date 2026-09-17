import SwiftUI

enum OnboardingPage: Int, CaseIterable, Identifiable {
    case people
    case rhythm
    case privacy

    var id: Int { rawValue }

    var previous: OnboardingPage? { OnboardingPage(rawValue: rawValue - 1) }
    var next: OnboardingPage? { OnboardingPage(rawValue: rawValue + 1) }

    var step: OnboardingStep {
        switch self {
        case .people: .people
        case .rhythm: .rhythm
        case .privacy: .privacy
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .people: "Make time for your people."
        case .rhythm: "Find a rhythm that feels right."
        case .privacy: "Your people. Your privacy."
        }
    }

    var message: LocalizedStringKey {
        switch self {
        case .people:
            """
            Kith helps you remember to reach out
            to your loved ones and stay close,
            one catch-up at a time.
            """
        case .rhythm:
            "Choose how often to reach out. After a catch-up, tap the checkmark in Upcoming to keep your list up to date."
        case .privacy:
            """
            Your data lives on your device and can sync privately through your own iCloud account.

            Photos and phone numbers are read from Contacts, not stored in Kith. iCloud sync is on when available; you can change it in Settings.
            """
        }
    }

    var assetName: String {
        switch self {
        case .people: "OnboardingPeople"
        case .rhythm: "OnboardingRhythm"
        case .privacy: "OnboardingPrivacy"
        }
    }

    var illustration: Image { Image(assetName) }
}
