import Contacts
import Foundation

/// The fields Kith reads from a picked Apple Contact.
struct PickedContact: Identifiable, Hashable {
    let id: String            // CNContact.identifier → Person.linkedContactID
    let name: String
    let birthday: DateComponents?

    init(contact: CNContact) {
        id = contact.identifier
        let formatted = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
        name = formatted.isEmpty ? [contact.givenName, contact.familyName].joined(separator: " ").trimmingCharacters(in: .whitespaces) : formatted
        birthday = contact.isKeyAvailable(CNContactBirthdayKey) ? contact.birthday : nil
    }

    init(id: String, name: String, birthday: DateComponents? = nil) {
        self.id = id
        self.name = name
        self.birthday = birthday
    }
}
