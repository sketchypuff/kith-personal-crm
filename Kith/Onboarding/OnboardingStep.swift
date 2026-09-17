import Foundation

nonisolated enum OnboardingStep: String {
    case people
    case rhythm
    case privacy
    case addPerson
    case notifications
    case finished

    var isIntroduction: Bool {
        switch self {
        case .people, .rhythm, .privacy: true
        default: false
        }
    }
}
