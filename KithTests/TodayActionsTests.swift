import Foundation
import SwiftData
import Testing
@testable import Kith

struct TodayActionsTests {
    let calendar = Calendar(identifier: .gregorian)
    let container = ModelContainerCoordinator.inMemory()

    var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 10))!
    }

    private var actions: TodayActions {
        TodayActions(context: container.mainContext, notifications: NotificationScheduler(), now: { now })
    }

    private func overduePerson() -> Person {
        let person = Person(name: "Maya", linkedContactID: "")
        person.cadence = .weekly
        person.lastLoggedAt = calendar.date(byAdding: .day, value: -20, to: now)
        container.mainContext.insert(person)
        return person
    }

    @Test func logCreatesTouchResetsClockAndUndoReverses() throws {
        let person = overduePerson()
        let before = person.lastLoggedAt
        #expect(person.isOverdue(at: now))

        let record = actions.log(person)
        #expect(person.lastLoggedAt == now)
        #expect(!person.isOverdue(at: now))
        #expect(person.touches?.count == 1)

        actions.undo(record)
        #expect(person.lastLoggedAt == before)
        #expect(person.isOverdue(at: now))
        let touches = try container.mainContext.fetch(FetchDescriptor<Touch>())
        #expect(touches.isEmpty)
    }

    @Test func handlingKeyDateMarksItAndLogsTouch() {
        let person = overduePerson()
        let keyDate = KeyDate()
        keyDate.month = 9
        keyDate.day = 9
        keyDate.person = person
        container.mainContext.insert(keyDate)

        let record = actions.handle(keyDate, for: person)
        #expect(keyDate.isHandled(occurrence: calendar.startOfDay(for: now), calendar: calendar))
        #expect(person.lastLoggedAt == now)

        actions.undo(record)
        #expect(keyDate.lastHandledAt == nil)
        #expect(!keyDate.isHandled(occurrence: calendar.startOfDay(for: now), calendar: calendar))
    }

    @Test func remindTomorrowHoldsUntilTomorrow() {
        let person = overduePerson()
        actions.remindTomorrow(person)
        #expect(!person.isOverdue(at: now))
        let tomorrowNoon = calendar.date(byAdding: .hour, value: 26, to: calendar.startOfDay(for: now))!
        #expect(person.isOverdue(at: tomorrowNoon))
    }

    @Test func skipAdvancesOneCycleWithoutTouch() throws {
        let person = overduePerson()
        let previousDue = person.nextDue
        actions.skip(person)
        #expect(person.lastLoggedAt == previousDue)
        #expect(person.skipMarkers?.count == 1)
        let touches = try container.mainContext.fetch(FetchDescriptor<Touch>())
        #expect(touches.isEmpty)
    }
}
