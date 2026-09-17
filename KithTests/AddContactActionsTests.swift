import Foundation
import SwiftData
import Testing
@testable import Kith

struct AddContactActionsTests {
    let container = ModelContainerCoordinator.inMemory()
    let contact = PickedContact(id: "contact-id", name: "Maya")

    private var draft: AddContactDraft {
        AddContactDraft(
            name: " Maya Patel ", cadence: .monthly, notifyDay: .tuesday,
            notifyTime: Person.defaultNotifyTime, tags: ["Friends", "Work"],
            birthday: DateComponents(month: 4, day: 12)
        )
    }

    @Test func savingPreservesTheFullFormWithoutLoggingACatchUp() throws {
        let result = try AddContactActions(context: container.mainContext).save(contact: contact, draft: draft)
        guard case .created(let person) = result else {
            Issue.record("Expected a newly created person")
            return
        }
        #expect(person.name == "Maya Patel")
        #expect(person.linkedContactID == contact.id)
        #expect(person.cadence == .monthly)
        #expect(person.notifyDay == .tuesday)
        #expect(person.notifyTime == draft.notifyTime)
        #expect(person.tags == ["Friends", "Work"])
        #expect(person.lastLoggedAt == nil)
        #expect(person.touches?.isEmpty == true)
        let birthday = try #require(person.keyDates?.first)
        #expect(birthday.month == 4)
        #expect(birthday.day == 12)
        #expect(birthday.year == nil)
        #expect(birthday.reminderEnabled)
    }

    @Test func duplicateIsCheckedAgainAtSave() throws {
        let actions = AddContactActions(context: container.mainContext)
        #expect(try actions.existingPerson(contactID: contact.id) == nil)
        let restored = Person(name: "Restored Maya", linkedContactID: contact.id)
        container.mainContext.insert(restored)
        try container.mainContext.save()
        let result = try actions.save(contact: contact, draft: draft)
        guard case .existing(let person) = result else {
            Issue.record("A contact restored during setup must not be duplicated")
            return
        }
        #expect(person.id == restored.id)
        #expect(person.name == "Restored Maya")
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Person>()) == 1)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<KeyDate>()) == 0)
    }

    @Test func failedSaveRemovesOnlyTheNewInsertionAndCanBeRetried() throws {
        let context = container.mainContext
        let existing = Person(name: "Noor", linkedContactID: "existing")
        context.insert(existing)
        try context.save()
        existing.notes = "An unrelated unsaved edit"

        let failing = AddContactActions(context: context, saveChanges: {
            throw CocoaError(.fileWriteOutOfSpace)
        })
        #expect(throws: CocoaError.self) {
            try failing.save(contact: contact, draft: draft)
        }
        #expect(existing.notes == "An unrelated unsaved edit")
        #expect(context.hasChanges)
        #expect(try context.fetchCount(FetchDescriptor<Person>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<KeyDate>()) == 0)

        _ = try AddContactActions(context: context).save(contact: contact, draft: draft)
        #expect(try context.fetchCount(FetchDescriptor<Person>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<KeyDate>()) == 1)
    }

    @Test func emptyNamesAndMissingContactsNeverCreateRecords() throws {
        let actions = AddContactActions(context: container.mainContext)
        var empty = draft
        empty.name = " \n "
        #expect(throws: AddContactError.self) { try actions.save(contact: contact, draft: empty) }
        #expect(throws: AddContactError.self) {
            try actions.save(contact: PickedContact(id: "", name: "Maya"), draft: draft)
        }
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Person>()) == 0)
    }

    @Test func optingOutOfBirthdayDoesNotCreateOne() throws {
        var noBirthday = draft
        noBirthday.birthday = nil
        _ = try AddContactActions(context: container.mainContext).save(contact: contact, draft: noBirthday)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<KeyDate>()) == 0)
    }
}
