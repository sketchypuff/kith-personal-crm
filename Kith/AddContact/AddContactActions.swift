import Foundation
import SwiftData

struct AddContactActions {
    let context: ModelContext
    var saveChanges: (() throws -> Void)?

    func existingPerson(contactID: String) throws -> Person? {
        var descriptor = FetchDescriptor<Person>(predicate: #Predicate { $0.linkedContactID == contactID })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func save(contact: PickedContact, draft: AddContactDraft) throws -> AddContactResult {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw AddContactError.missingName }
        guard !contact.id.isEmpty else { throw AddContactError.missingContact }
        if let existing = try existingPerson(contactID: contact.id) {
            return .existing(existing)
        }
        if let birthday = draft.birthday {
            guard let month = birthday.month, let day = birthday.day,
                  (1...12).contains(month), (1...31).contains(day) else {
                throw AddContactError.invalidBirthday
            }
        }

        let person = Person(name: name, linkedContactID: contact.id)
        person.cadence = draft.cadence
        person.notifyDay = draft.notifyDay
        person.notifyTime = draft.notifyTime
        person.tags = draft.tags
        context.insert(person)

        var keyDate: KeyDate?
        if let birthday = draft.birthday, let month = birthday.month, let day = birthday.day {
            let date = KeyDate()
            date.type = .birthday
            date.month = month
            date.day = day
            date.year = birthday.year
            date.person = person
            context.insert(date)
            keyDate = date
        }

        do {
            if let saveChanges {
                try saveChanges()
            } else {
                try context.save()
            }
            return .created(person)
        } catch {
            // Roll back only this insertion, not unrelated pending edits.
            if let keyDate { context.delete(keyDate) }
            context.delete(person)
            throw error
        }
    }
}
