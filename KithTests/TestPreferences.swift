import Foundation
import Testing

final class TestPreferences {
    let name = "KithTests.onboarding.\(UUID().uuidString)"
    let store: UserDefaults

    init() throws {
        store = try #require(UserDefaults(suiteName: name))
    }

    deinit {
        UserDefaults(suiteName: name)?.removePersistentDomain(forName: name)
    }
}
