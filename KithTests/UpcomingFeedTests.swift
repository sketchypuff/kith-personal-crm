import Foundation
import SwiftData
import Testing
@testable import Kith

struct UpcomingFeedTests {
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
        // Never, so this person contributes the date row and nothing else.
        let birthdayPerson = person("Birthday", cadence: .never, lastLogged: nil)
        keyDate(.birthday, for: birthdayPerson, daysAhead: 2)

        let feed = UpcomingFeed.build(people: people, now: now, calendar: calendar)
        let names = feed.allItems.map(\.person.name)
        #expect(names == ["Birthday", "Very", "Slightly"])
        #expect(feed.hasOverdue)
        _ = slightly; _ = very
    }

    /// The two modes partition the feed: nothing shows twice, nothing is lost.
    @Test func upcomingAndOverdueModesPartitionTheFeed() {
        let overdue = person("Overdue", lastLogged: daysAgo(20))
        keyDate(.anniversary, for: overdue, daysAhead: 1)
        person("OnTrack", lastLogged: daysAgo(1))

        let feed = UpcomingFeed.build(people: people, now: now, calendar: calendar)
        // The date, the overdue person, and the on-track person's next due date.
        #expect(feed.allItems.count == 3)
        #expect(feed.items(for: .overdue).map(\.person.name) == ["Overdue"])
        #expect(feed.items(for: .upcoming).map(\.person.name) == ["Overdue", "OnTrack"])
        #expect(feed.items(for: .upcoming).allSatisfy { !$0.isOverdue })

        let split = feed.items(for: .upcoming).count + feed.items(for: .overdue).count
        #expect(split == feed.allItems.count)
    }

    @Test func nextDueInsideTheHorizonShowsBeforeItIsDue() {
        person("Soon", cadence: .weekly, lastLogged: daysAgo(1))

        let feed = UpcomingFeed.build(people: people, now: now, calendar: calendar)
        #expect(!feed.hasOverdue)
        guard case .reachOut(_, .upcoming(let days)) = feed.reachOuts.first else {
            Issue.record("expected one upcoming reach-out")
            return
        }
        #expect(feed.reachOuts.count == 1)
        #expect(days > 0 && days <= UpcomingHorizon.default.days)
    }

    @Test func onlyTheNextOccurrenceOfARepeatingCadenceShows() {
        // Weekly recurs four times inside a 30-day horizon; only the first counts.
        person("Weekly", cadence: .weekly, lastLogged: daysAgo(1))
        person("Daily", cadence: .daily, lastLogged: daysAgo(0))

        let feed = UpcomingFeed.build(people: people, now: now, calendar: calendar)
        #expect(feed.reachOuts.count == 2)
        #expect(Set(feed.reachOuts.map(\.person.name)) == ["Weekly", "Daily"])
    }

    @Test func dueBeyondTheHorizonIsExcluded() {
        // Quarterly from yesterday lands roughly three months out.
        person("Distant", cadence: .quarterly, lastLogged: daysAgo(1))

        let feed = UpcomingFeed.build(people: people, now: now, calendar: calendar)
        #expect(feed.reachOuts.isEmpty)
    }

    @Test func reachOutsAreOrderedMostOverdueThenSoonestDue() {
        person("Later", cadence: .weekly, lastLogged: daysAgo(1))    // next Saturday
        person("Sooner", cadence: .daily, lastLogged: daysAgo(0))    // tomorrow
        person("Late", cadence: .weekly, lastLogged: daysAgo(20))    // overdue

        let feed = UpcomingFeed.build(people: people, now: now, calendar: calendar)
        #expect(feed.reachOuts.map(\.person.name) == ["Late", "Sooner", "Later"])
    }

    @Test func dateTodaySuppressesDuplicateReachOut() {
        let overdue = person("Both", lastLogged: daysAgo(20))
        keyDate(.birthday, for: overdue, daysAhead: 0)

        let feed = UpcomingFeed.build(people: people, now: now, calendar: calendar)
        let items = feed.allItems
        #expect(items.count == 1)
        #expect(items.first?.isKeyDate == true)
        #expect(!feed.hasOverdue)
    }

    @Test func neverCadenceNeverAppearsAsReachOutButDatesStillDo() {
        let never = person("Never", cadence: .never, lastLogged: nil)
        keyDate(.birthday, for: never, daysAhead: 3)

        let feed = UpcomingFeed.build(people: people, now: now, calendar: calendar)
        #expect(feed.reachOuts.isEmpty)
        #expect(feed.dates.count == 1)
        #expect(feed.coverage == nil)
    }

    @Test func snoozedAndHandledItemsAreHeldOut() {
        let snoozed = person("Snoozed", lastLogged: daysAgo(20))
        snoozed.remindOn = calendar.date(byAdding: .day, value: 1, to: now)
        let handled = person("Handled", cadence: .never, lastLogged: nil)
        let birthday = keyDate(.birthday, for: handled, daysAhead: 1)
        birthday.lastHandledAt = now

        let feed = UpcomingFeed.build(people: people, now: now, calendar: calendar)
        #expect(feed.isEmpty)
    }

    /// The per-date lead time now only drives the notification. Visibility is
    /// the feed's own 30-day horizon.
    @Test func datesShowAcrossTheHorizonRegardlessOfTheirLeadTime() {
        let soon = person("Soon", cadence: .never, lastLogged: nil)
        keyDate(.birthday, for: soon, daysAhead: 10, lead: 3)

        let feed = UpcomingFeed.build(people: people, now: now, calendar: calendar)
        #expect(feed.dates.count == 1)
    }

    @Test func datesBeyondTheHorizonAreExcluded() {
        let later = person("Later", cadence: .never, lastLogged: nil)
        keyDate(.birthday, for: later, daysAhead: 40, lead: 3)

        let feed = UpcomingFeed.build(people: people, now: now, calendar: calendar)
        #expect(feed.dates.isEmpty)
    }

    @Test func coverageIsShareOfPeopleOnTrack() {
        person("A", lastLogged: daysAgo(1))
        person("B", lastLogged: daysAgo(1))
        person("C", lastLogged: daysAgo(1))
        person("D", lastLogged: daysAgo(30))
        person("E", cadence: .never, lastLogged: nil)

        let feed = UpcomingFeed.build(people: people, now: now, calendar: calendar)
        #expect(feed.coverage == 0.75)
    }

    @Test func subtitlesFollowTheSpec() {
        let overdue = person("O", lastLogged: daysAgo(15))
        let feed = UpcomingFeed.build(people: people, now: now, calendar: calendar)
        guard case .reachOut(_, .overdue(let days)) = feed.reachOuts.first else {
            Issue.record("expected an overdue reach-out row")
            return
        }
        #expect(days > 0)
        #expect(feed.reachOuts.first?.subtitle == "\(days)d overdue")

        #expect(UpcomingItem.reachOut(person: overdue, status: .overdue(days: 0)).subtitle == "Due today")
        #expect(UpcomingItem.reachOut(person: overdue, status: .due).subtitle == "Due today")
        #expect(UpcomingItem.reachOut(person: overdue, status: .upcoming(days: 1)).subtitle == "Due tomorrow")
        #expect(UpcomingItem.reachOut(person: overdue, status: .upcoming(days: 12)).subtitle == "Due in 12d")

        let birthday = keyDate(.birthday, for: overdue, daysAhead: 0)
        let today = UpcomingItem.keyDate(keyDate: birthday, person: overdue, occurrence: now, daysUntil: 0)
        #expect(today.subtitle == "Birthday · today")
        let soon = UpcomingItem.keyDate(keyDate: birthday, person: overdue, occurrence: now, daysUntil: 3)
        #expect(soon.subtitle == "Birthday · in 3d")
    }

    // MARK: - Horizon filter

    /// The horizon bounds what is still ahead. An overdue reach-out sits before
    /// now, so no forward window contains it and narrowing must not hide it.
    @Test func narrowingTheHorizonDropsDistantRowsButKeepsOverdue() {
        let near = person("Near", cadence: .never, lastLogged: nil)
        keyDate(.birthday, for: near, daysAhead: 3)
        let far = person("Far", cadence: .never, lastLogged: nil)
        keyDate(.birthday, for: far, daysAhead: 20)
        person("Late", cadence: .weekly, lastLogged: daysAgo(20))

        let month = UpcomingFeed.build(people: people, now: now, calendar: calendar, horizon: .month)
        #expect(month.dates.map(\.person.name) == ["Near", "Far"])
        #expect(month.reachOuts.map(\.person.name) == ["Late"])

        let week = UpcomingFeed.build(people: people, now: now, calendar: calendar, horizon: .week)
        #expect(week.dates.map(\.person.name) == ["Near"])
        #expect(week.reachOuts.map(\.person.name) == ["Late"])
        #expect(week.hasOverdue)
    }

    /// Today answers "what needs me now": today's rows, plus anything late.
    @Test func todayKeepsOnlyTodaysRowsAndOverdue() {
        let today = person("Today", cadence: .never, lastLogged: nil)
        keyDate(.birthday, for: today, daysAhead: 0)
        let tomorrow = person("Tomorrow", cadence: .never, lastLogged: nil)
        keyDate(.birthday, for: tomorrow, daysAhead: 1)
        person("Late", cadence: .weekly, lastLogged: daysAgo(20))
        person("Soon", cadence: .daily, lastLogged: daysAgo(0))   // due tomorrow

        let feed = UpcomingFeed.build(people: people, now: now, calendar: calendar, horizon: .today)
        #expect(feed.dates.map(\.person.name) == ["Today"])
        #expect(feed.reachOuts.map(\.person.name) == ["Late"])
    }

    /// The empty state and the navigation subtitle both read the horizon back
    /// off the feed, so it has to survive the build.
    @Test func theFeedCarriesTheHorizonItWasBuiltFor() {
        person("A", lastLogged: daysAgo(1))

        #expect(UpcomingFeed.build(people: people, now: now, calendar: calendar).horizon == .month)
        let today = UpcomingFeed.build(people: people, now: now, calendar: calendar, horizon: .today)
        #expect(today.horizon == .today)
    }

    @Test func horizonNamesMatchTheMenu() {
        #expect(UpcomingHorizon.allCases.map(\.label) == ["Today", "Next 7 days", "Next 30 days"])
        #expect(UpcomingHorizon.default == .month)
        #expect(UpcomingHorizon.week.days == 7)
    }

    @Test func modeNamesMatchTheTitleDropdown() {
        #expect(UpcomingMode.allCases.map(\.rawValue) == ["Upcoming", "Overdue"])
        #expect(UpcomingMode.upcoming.usesHorizon)
        #expect(!UpcomingMode.overdue.usesHorizon)
    }

    // MARK: Tag scope

    /// A tag picks a group of people, so it narrows key dates and reach-outs
    /// together — the coverage figure with them.
    @Test func aTagScopesDatesReachOutsAndCoverage() {
        let arjun = person("Arjun", lastLogged: daysAgo(20))
        arjun.tags = ["work"]
        keyDate(.birthday, for: arjun, daysAhead: 2)

        let bob = person("Bob", lastLogged: daysAgo(20))
        bob.tags = ["friends"]
        keyDate(.anniversary, for: bob, daysAhead: 3)

        let scoped = UpcomingFeed.build(people: people, now: now, calendar: calendar, tag: "work")
        #expect(scoped.allItems.map(\.person.name) == ["Arjun", "Arjun"])
        #expect(scoped.coverage == 0)   // one person with a cadence, and they're overdue

        let all = UpcomingFeed.build(people: people, now: now, calendar: calendar)
        #expect(all.allItems.count == 4)
    }

    @Test func aTagScopeIgnoresCaseAndNoTagLeavesTheFeedWhole() {
        let arjun = person("Arjun", lastLogged: daysAgo(20))
        arjun.tags = ["Work"]
        person("Bob", lastLogged: daysAgo(20))

        let scoped = UpcomingFeed.build(people: people, now: now, calendar: calendar, tag: "work")
        #expect(scoped.allItems.map(\.person.name) == ["Arjun"])
        #expect(UpcomingFeed.build(people: people, now: now, calendar: calendar, tag: nil).allItems.count == 2)
    }
}
