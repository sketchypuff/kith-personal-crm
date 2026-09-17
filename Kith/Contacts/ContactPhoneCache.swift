import Contacts
import Foundation

/// Shared cache of the one number to reach a person on, keyed by
/// `linkedContactID`.
///
/// Kith stores no contact details of its own — only the link back to the card —
/// so the number is read live, the same way photos are, and never persisted.
/// Reads happen off the main thread and permission is never requested here.
@Observable
final class ContactPhoneCache {
    private var numbers: [String: String] = [:]
    private var misses: Set<String> = []

    func cached(_ contactID: String) -> String? {
        numbers[contactID]
    }

    /// The cached number or a single fetch. Nil when the card has no number,
    /// or when Contacts access isn't granted — the caller hides its buttons
    /// either way, which is the same outcome for the same reason.
    func number(for contactID: String) async -> String? {
        guard !contactID.isEmpty else { return nil }
        if let number = numbers[contactID] { return number }
        if misses.contains(contactID) { return nil }

        guard await ContactAccess.ensureGranted() else { return nil }

        if let number = await Self.fetchBestNumber(contactID: contactID) {
            numbers[contactID] = number
            return number
        }
        misses.insert(contactID)
        return nil
    }

    /// Forgets one card, so a number added in Contacts is picked up without a
    /// relaunch.
    func invalidate(_ contactID: String) {
        numbers[contactID] = nil
        misses.remove(contactID)
    }

    private nonisolated static func fetchBestNumber(contactID: String) async -> String? {
        let store = CNContactStore()
        let keys = [CNContactPhoneNumbersKey as CNKeyDescriptor]
        guard let contact = try? store.unifiedContact(withIdentifier: contactID, keysToFetch: keys) else {
            return nil
        }
        return PhoneNumberSelection.best(from: contact.phoneNumbers)
    }
}
