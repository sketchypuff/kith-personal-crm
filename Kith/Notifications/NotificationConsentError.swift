import Foundation

nonisolated enum NotificationConsentError: LocalizedError {
    case requestInProgress

    var errorDescription: String? {
        "A notification request is already in progress."
    }
}
