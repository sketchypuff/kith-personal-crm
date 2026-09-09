import Foundation
import SwiftData
import Testing
@testable import Kith

struct PeopleActionsTests {
    let calendar = Calendar(identifier: .gregorian)
    let container = ModelContainerCoordinator.inMemory()

    var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 10))!
    }

    private var actions: PeopleActions {
        PeopleActions(context: container.mainContext, notifications: NotificationScheduler())
    }

    /// A person with one of everything the cascade must remove.
    private func fullPerson(contactID: String = "ABC-123") -> Person {
        let context = container.mainContext
        let person = Person(name: "Maya", linkedContactID: contactID)
        person.cadence = .weekly
        person.lastLoggedAt = calendar.date(byAdding: .day, value: -20, to: now)
        context.insert(person)

        let touch = Touch(date: now)
        touch.person = person
        context.insert(touch)

        let marker = SkipMarker(date: now)
        marker.person = person
        context.insert(marker)

        let keyDate = KeyDate()
        keyDate.month = 9
        keyDate.day = 9
        keyDate.person = person
        context.insert(keyDate)

        try? context.save()
        return person
    }

    private func count<T: PersistentModel>(_ type: T.Type) -> Int {
        (try? container.mainContext.fetchCount(FetchDescriptor<T>())) ?? -1
    }

    @Test func deleteCascadesToTouchesSkipMarkersAndKeyDates() {
        let person = fullPerson()
        #expect(count(Person.self) == 1)
        #expect(count(Touch.self) == 1)
        #expect(count(SkipMarker.self) == 1)
        #expect(count(KeyDate.self) == 1)

        actions.delete(person)

        #expect(count(Person.self) == 0)
        #expect(count(Touch.self) == 0)
        #expect(count(SkipMarker.self) == 0)
        #expect(count(KeyDate.self) == 0)
    }

    @Test func deleteFreesTheLinkedContactForReAdding() throws {
        let contactID = "ABC-123"
        let person = fullPerson(contactID: contactID)
        let guardDescriptor = FetchDescriptor<Person>(predicate: #Predicate { $0.linkedContactID == contactID })
        #expect(try container.mainContext.fetch(guardDescriptor).count == 1)

        actions.delete(person)

        #expect(try container.mainContext.fetch(guardDescriptor).isEmpty)
    }

    @Test func pendingNotificationIDsCoverReachOutRemindAndEveryKeyDate() throws {
        let person = fullPerson()
        let keyDate = try #require(person.keyDates?.first)
        let ids = person.pendingNotificationIDs
        #expect(ids.count == 4)
        #expect(ids.contains(person.reachOutNotificationID))
        #expect(ids.contains(person.remindTomorrowNotificationID))
        #expect(ids.contains(keyDate.leadNotificationID))
        #expect(ids.contains(keyDate.dayOfNotificationID))
    }

    @Test func deletingOnePersonLeavesOthersIntact() {
        let doomed = fullPerson(contactID: "one")
        let survivor = fullPerson(contactID: "two")

        actions.delete(doomed)

        #expect(count(Person.self) == 1)
        #expect(count(KeyDate.self) == 1)
        #expect(survivor.keyDates?.count == 1)
    }
}
