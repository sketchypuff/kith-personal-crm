import Foundation

nonisolated enum AddContactError: LocalizedError {
    case missingName
    case missingContact
    case invalidBirthday

    var errorDescription: String? {
        switch self {
        case .missingName: "Enter a name for this person."
        case .missingContact: "Choose a person from Contacts to continue."
        case .invalidBirthday: "Choose a valid birthday."
        }
    }
}
