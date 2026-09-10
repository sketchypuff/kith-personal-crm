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

    private func build(search: String = "", tag: String? = nil) -> PeopleRoster {
        PeopleRoster.build(people: people, searchText: search, tag: tag, now: now, calendar: calendar)
    }

    private func names(_ roster: PeopleRoster) -> [String] {
        roster.entries.map(\.person.name)
    }

    // MARK: Sort

    @Test func sortsLocalizedIntoOneFlatList() {
        person("angela Two")
        person("Ángela One")
        person("Zed")
        person("Bob")

        let roster = build()
        #expect(names(roster) == ["Ángela One", "angela Two", "Bob", "Zed"])
        #expect(roster.entries.count == 4)
    }

    @Test func nonLetterNamesSortToTheEnd() {
        person("42 Crew")
        person("Zed")
        person("Alice")

        let roster = build()
        #expect(names(roster) == ["Alice", "Zed", "42 Crew"])
    }

    // MARK: Search

    @Test func searchIsUnionOfNameNotesAndTagsWithHintsForNonNameHits() {
        person("Client Carla")
        person("Bob", tags: ["clients"])
        person("Dana", notes: "Met at the client dinner")
        person("Eve")

        let roster = build(search: "client")
        let entries = roster.entries
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
        #expect(roster.entries.count == 0)
    }

    // MARK: Tag filter

    @Test func tagFilterKeepsOnlyPeopleCarryingIt() {
        person("Carla", tags: ["clients"])
        person("Arjun", tags: ["clients", "work"])
        person("Bob", tags: ["friends"])
        person("Dana")

        #expect(names(build(tag: "clients")) == ["Arjun", "Carla"])
        #expect(names(build()) == ["Arjun", "Bob", "Carla", "Dana"])
    }

    @Test func tagFilterIgnoresCase() {
        person("Carla", tags: ["Clients"])
        person("Bob", tags: ["clients"])

        #expect(names(build(tag: "clients")) == ["Bob", "Carla"])
        #expect(names(build(tag: "CLIENTS")) == ["Bob", "Carla"])
    }

    @Test func tagFilterComposesWithSearch() {
        person("Arjun", tags: ["work"])
        person("Leah", tags: ["work"])
        person("Leo", tags: ["friends"])

        #expect(names(build(search: "le", tag: "work")) == ["Leah"])
    }

    @Test func filteredOutPeopleLeaveTheList() {
        person("Alice", tags: ["work"])
        person("Bob")

        #expect(names(build(tag: "work")) == ["Alice"])
    }

    @Test func allTagsIsDerivedFromEveryoneAndSorted() {
        person("A", tags: ["work", "clients"])
        person("B", tags: ["family", "work"])
        person("C")

        let roster = build(search: "zzz")   // search hides everyone; tags still come from the whole roster
        #expect(roster.allTags == ["clients", "Family", "Work"])
    }

    @Test func allTagsFoldsCaseIntoOnePill() {
        // One person, so the order the spellings are seen in is deterministic.
        // A custom tag keeps the first spelling seen; a starter takes its own.
        person("A", tags: ["Mentors", "mentors", "work"])

        #expect(build().allTags == ["Mentors", "Work"])
    }
}
