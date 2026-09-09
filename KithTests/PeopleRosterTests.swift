import Foundation
import SwiftData
import Testing
@testable import Kith

struct PeopleRosterTests {
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
    private func person(
        _ name: String,
        cadence: Cadence = .weekly,
        lastLogged: Date? = nil,
        tags: [String] = [],
        notes: String = ""
    ) -> Person {
        let person = Person(name: name, linkedContactID: "")
        person.cadence = cadence
        person.lastLoggedAt = lastLogged ?? daysAgo(1)
        person.createdAt = daysAgo(60)
        person.tags = tags
        person.notes = notes
        container.mainContext.insert(person)
        return person
    }

    private var people: [Person] {
        (try? container.mainContext.fetch(FetchDescriptor<Person>())) ?? []
    }

    private func build(search: String = "", filter: RosterFilter = RosterFilter()) -> PeopleRoster {
        PeopleRoster.build(people: people, searchText: search, filter: filter, now: now, calendar: calendar)
    }

    private func names(_ roster: PeopleRoster) -> [String] {
        roster.sections.flatMap(\.entries).map(\.person.name)
    }

    // MARK: Sort & sectioning

    @Test func sortsLocalizedAndSectionsByFoldedFirstLetter() {
        person("angela Two")
        person("Ángela One")
        person("Zed")
        person("Bob")

        let roster = build()
        #expect(names(roster) == ["Ángela One", "angela Two", "Bob", "Zed"])
        #expect(roster.sections.map(\.letter) == ["A", "B", "Z"])
        #expect(roster.visibleCount == 4)
    }

    @Test func nonLetterNamesCollectInTrailingSymbolSection() {
        person("42 Crew")
        person("Zed")
        person("Alice")

        let roster = build()
        #expect(roster.sections.map(\.letter) == ["A", "Z", PeopleRoster.symbolSection])
        #expect(roster.sections.last?.entries.first?.person.name == "42 Crew")
    }

    // MARK: Search

    @Test func searchIsUnionOfNameNotesAndTagsWithHintsForNonNameHits() {
        person("Client Carla")
        person("Bob", tags: ["clients"])
        person("Dana", notes: "Met at the client dinner")
        person("Eve")

        let roster = build(search: "client")
        let entries = roster.sections.flatMap(\.entries)
        #expect(entries.map(\.person.name) == ["Bob", "Client Carla", "Dana"])
        #expect(entries[0].matchHint == "matches: #clients")
        #expect(entries[1].matchHint == nil)
        #expect(entries[2].matchHint == "matches notes")
    }

    @Test func searchIsCaseAndDiacriticInsensitiveAndTrimmed() {
        person("Ángela")
        let roster = build(search: "  ANGELA ")
        #expect(names(roster) == ["Ángela"])
    }

    @Test func noMatchesYieldsEmptyRoster() {
        person("Alice")
        let roster = build(search: "zzz")
        #expect(roster.isEmpty)
        #expect(roster.visibleCount == 0)
    }

    // MARK: Filter

    @Test func overdueFilterExcludesNeverSnoozedAndOnTrack() {
        person("Overdue", lastLogged: daysAgo(20))
        person("On track", lastLogged: daysAgo(1))
        person("Never", cadence: .never)
        let snoozed = person("Snoozed", lastLogged: daysAgo(20))
        snoozed.remindOn = calendar.date(byAdding: .day, value: 1, to: now)

        let roster = build(filter: RosterFilter(overdueOnly: true))
        #expect(names(roster) == ["Overdue"])
    }

    @Test func tagFilterAndOverdueCombineWithAnd() {
        person("Overdue client", lastLogged: daysAgo(20), tags: ["clients"])
        person("On-track client", lastLogged: daysAgo(1), tags: ["clients"])
        person("Overdue friend", lastLogged: daysAgo(20), tags: ["friends"])

        #expect(names(build(filter: RosterFilter(tag: "clients"))) == ["On-track client", "Overdue client"])
        #expect(names(build(filter: RosterFilter(overdueOnly: true, tag: "clients"))) == ["Overdue client"])
    }

    @Test func filterComposesWithSearch() {
        person("Arjun", lastLogged: daysAgo(20), tags: ["work"])
        person("Leah", lastLogged: daysAgo(20), tags: ["work"])

        let roster = build(search: "le", filter: RosterFilter(overdueOnly: true))
        #expect(names(roster) == ["Leah"])
    }

    @Test func emptySectionsDisappearWhenFilteredOut() {
        person("Alice", lastLogged: daysAgo(1))
        person("Bob", lastLogged: daysAgo(20))

        let roster = build(filter: RosterFilter(overdueOnly: true))
        #expect(roster.sections.map(\.letter) == ["B"])
    }

    @Test func allTagsIsDerivedFromEveryoneAndSorted() {
        person("A", tags: ["work", "clients"])
        person("B", tags: ["family", "work"])
        person("C")

        let roster = build(search: "zzz")   // search hides everyone; tags still come from the whole roster
        #expect(roster.allTags == ["clients", "family", "work"])
    }

    // MARK: Filter summary

    @Test func filterSummaryAndEmptyTitleFollowTheSpec() {
        var filter = RosterFilter()
        #expect(!filter.isActive)
        #expect(filter.summary == nil)

        filter.overdueOnly = true
        #expect(filter.summary == "Overdue")
        #expect(filter.emptyTitle == "No one overdue")

        filter.tag = "clients"
        #expect(filter.summary == "Overdue · tag: clients")
        #expect(filter.emptyTitle == "No one overdue tagged “clients”")

        filter.clear()
        #expect(!filter.isActive)
    }
}
