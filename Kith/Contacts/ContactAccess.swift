import Contacts

/// The one place Kith asks to read Contacts.
///
/// `CNContactPickerViewController` runs out of process, so picking someone
/// never prompts and never grants anything. Without asking here, a fresh
/// install sits at `.notDetermined` for good: `linkedContactID` is saved but
/// can never be read back, so photos and phone numbers both come back empty
/// with nothing on screen to explain why.
///
/// The ask is deferred to the first read that actually needs it — opening a
/// linked person, or drawing their row — rather than fired at launch, so the
/// prompt lands next to the thing it pays for.
@MainActor
enum ContactAccess {
    /// Held for the life of the launch so a roster drawing twenty rows at once
    /// produces one prompt and nineteen awaits, not twenty prompts.
    private static var pending: Task<Bool, Never>?

    /// True when the store can be read. Prompts at most once per launch, and
    /// only when the user has never been asked — after a denial iOS wouldn't
    /// show the prompt again anyway, so there is nothing to gain by retrying.
    static func ensureGranted() async -> Bool {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized, .limited:
            return true
        case .notDetermined:
            break
        default:
            return false
        }

        if let pending { return await pending.value }

        let request = Task<Bool, Never> {
            (try? await CNContactStore().requestAccess(for: .contacts)) ?? false
        }
        pending = request
        return await request.value
    }
}
