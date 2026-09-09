import Foundation
import SwiftData
import Testing
@testable import Kith

struct TodayFeedTests {
    let calendar = Calendar(identifier: .gregorian)
    let container = ModelContainerCoordinator.inMemory()

    /// Wed 9 Sep 2026, 10:00.
    var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 10))!
    }

    private func daysAgo(_ n: Int) -> Date {
        calendar.date(byAdding: .day, value: -n, to: now)!
    }

    @discardableResult
    private func person(_ name: String, cadence: Cadence = .weekly, lastLogged: Date?) -> Person {
        let person = Person(name: name, linkedContactID: "")
        person.cadence = cadence
        person.lastLoggedAt = lastLogged
        person.createdAt = daysAgo(60)
        container.mainContext.insert(person)
        return person
    }

    @discardableResult
    private func keyDate(_ type: KeyDateType, for person: Person, daysAhead: Int, lead: Int = 3) -> KeyDate {
        let date = calendar.date(byAdding: .day, value: daysAhead, to: now)!
        let components = calendar.dateComponents([.month, .day], from: date)
        let keyDate = KeyDate()
        keyDate.type = type
        keyDate.month = components.month!
        keyDate.day = components.day!
        keyDate.leadTimeDays = lead
        keyDate.person = person
        container.mainContext.insert(keyDate)
        return keyDate
    }

    private var people: [Person] {
        (try? container.mainContext.fetch(FetchDescriptor<Person>())) ?? []
    }

    @Test func datesOutrankReachOutsAndMostOverdueComesFirst() {
        let slightly = person("Slightly", lastLogged: daysAgo(15))
        let very = person("Very", lastLogged: daysAgo(30))
        let birthdayPerson = person("Birthday", lastLogged: daysAgo(1))
        keyDate(.birthday, for: birthdayPerson, daysAhead: 2)

        let feed = TodayFeed.build(people: people, now: now, calendar: calendar)
        let names = feed.items(for: .all).map(\.person.name)
        #expect(names == ["Birthday", "Very", "Slightly"])
        #expect(feed.hasOverdue)
        _ = slightly; _ = very
    }

    @Test func upcomingHasOnlyDatesAndOverdueHasOnlyPeople() {
        let overdue = person("Overdue", lastLogged: daysAgo(20))
        keyDate(.anniversary, for: overdue, daysAhead: 1)

        let feed = TodayFeed.build(people: people, now: now, calendar: calendar)
        let upcomingAreDates = feed.items(for: .upcoming).allSatisfy(\.isKeyDate)
        let overdueArePeople = feed.items(for: .overdue).allSatisfy { !$0.isKeyDate }
        #expect(upcomingAreDates)
        #expect(overdueArePeople)
        #expect(feed.items(for: .all).count == 2)
    }

    @Test func dateTodaySuppressesDuplicateReachOut() {
        let overdue = person("Both", lastLogged: daysAgo(20))
        keyDate(.birthday, for: overdue, daysAhead: 0)

        let feed = TodayFeed.build(people: people, now: now, calendar: calendar)
        let items = feed.items(for: .all)
        #expect(items.count == 1)
        #expect(items.first?.isKeyDate == true)
        #expect(!feed.hasOverdue)
    }

    @Test func neverCadenceNeverAppearsAsReachOutButDatesStillDo() {
        let never = person("Never", cadence: .never, lastLogged: nil)
        keyDate(.birthday, for: never, daysAhead: 3)

        let feed = TodayFeed.build(people: people, now: now, calendar: calendar)
        #expect(feed.reachOuts.isEmpty)
        #expect(feed.dates.count == 1)
        #expect(feed.coverage == nil)
    }

    @Test func snoozedAndHandledItemsAreHeldOut() {
        let snoozed = person("Snoozed", lastLogged: daysAgo(20))
        snoozed.remindOn = calendar.date(byAdding: .day, value: 1, to: now)
        let handled = person("Handled", lastLogged: daysAgo(1))
        let birthday = keyDate(.birthday, for: handled, daysAhead: 1)
        birthday.lastHandledAt = now

        let feed = TodayFeed.build(people: people, now: now, calendar: calendar)
        #expect(feed.isEmpty)
    }

    @Test func datesOutsideLeadWindowAreExcluded() {
        let person = person("Later", lastLogged: daysAgo(1))
        keyDate(.birthday, for: person, daysAhead: 10, lead: 3)

        let feed = TodayFeed.build(people: people, now: now, calendar: calendar)
        #expect(feed.dates.isEmpty)
    }

    @Test func coverageIsShareOfPeopleOnTrack() {
        person("A", lastLogged: daysAgo(1))
        person("B", lastLogged: daysAgo(1))
        person("C", lastLogged: daysAgo(1))
        person("D", lastLogged: daysAgo(30))
        person("E", cadence: .never, lastLogged: nil)

        let feed = TodayFeed.build(people: people, now: now, calendar: calendar)
        #expect(feed.coverage == 0.75)
    }

    @Test func subtitlesFollowTheSpec() {
        let overdue = person("O", lastLogged: daysAgo(15))
        let feed = TodayFeed.build(people: people, now: now, calendar: calendar)
        guard case .reachOut(_, let days) = feed.reachOuts.first! else {
            Issue.record("expected a reach-out row")
            return
        }
        #expect(days > 0)
        #expect(feed.reachOuts.first?.subtitle == "\(days)d overdue")

        let birthday = keyDate(.birthday, for: overdue, daysAhead: 0)
        let today = TodayItem.keyDate(keyDate: birthday, person: overdue, occurrence: now, daysUntil: 0)
        #expect(today.subtitle == "Birthday · today")
        let soon = TodayItem.keyDate(keyDate: birthday, person: overdue, occurrence: now, daysUntil: 3)
        #expect(soon.subtitle == "Birthday · in 3d")
    }
}
