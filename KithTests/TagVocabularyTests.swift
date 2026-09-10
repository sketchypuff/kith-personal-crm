import Foundation
import SwiftData
import Testing
@testable import Kith

struct TagVocabularyTests {
    let container = ModelContainerCoordinator.inMemory()

    @discardableResult
    private func person(_ name: String, tags: [String]) -> Person {
        let person = Person(name: name, linkedContactID: "")
        person.tags = tags
        container.mainContext.insert(person)
        return person
    }

    private var people: [Person] {
        (try? container.mainContext.fetch(FetchDescriptor<Person>())) ?? []
    }

    @Test func sortsLocalizedAndIgnoresPeopleWithNoTags() {
        person("A", tags: ["work", "clients"])
        person("B", tags: ["family"])
        person("C", tags: [])

        // "clients" is custom so it keeps its spelling; the two starters take theirs.
        #expect(TagVocabulary.all(in: people) == ["clients", "Family", "Work"])
    }

    @Test func foldsCaseAndDiacriticsIntoOneEntryKeepingTheFirstSpelling() {
        person("A", tags: ["Work", "work", "WORK", "café", "cafe"])

        #expect(TagVocabulary.all(in: people) == ["café", "Work"])
    }

    @Test func dropsBlankTags() {
        person("A", tags: ["   ", "", "work"])

        #expect(TagVocabulary.all(in: people) == ["Work"])
    }

    @Test func matchingIgnoresCaseAndSurroundingSpace() {
        let arjun = person("Arjun", tags: ["Clients"])

        #expect(TagVocabulary.matches("clients", in: arjun))
        #expect(TagVocabulary.matches("  CLIENTS ", in: arjun))
        #expect(!TagVocabulary.matches("work", in: arjun))
    }

    @Test func emptyRosterHasNoTags() {
        #expect(TagVocabulary.all(in: []).isEmpty)
    }

    // MARK: Starter set

    @Test func startersAreTheFourNamedTagsInTheirOwnCasing() {
        #expect(TagVocabulary.defaults == ["Close friends", "Family", "Friends", "Work"])
    }

    /// The pill rows still read the roster, not the vocabulary, so creating a
    /// tag makes it pickable without making it visible.

    /// The whole point of requirement three: a starter nobody carries is not
    /// part of the vocabulary, so it never reaches the pill row.
    @Test func startersNobodyCarriesAreNotInTheVocabulary() {
        person("A", tags: ["Family"])
        person("B", tags: ["Friends"])

        #expect(TagVocabulary.all(in: people) == ["Family", "Friends"])
    }

    @Test func aRosterWithNoTagsHasNoVocabularyDespiteTheStarters() {
        person("A", tags: [])
        person("B", tags: ["  "])

        #expect(TagVocabulary.all(in: people).isEmpty)
    }

    // MARK: Options, read from the vocabulary store

    @Test func optionsAreTheVocabularyMinusWhatIsCarried() {
        let vocabulary = [Kith.Tag(name: "Work"), Kith.Tag(name: "mentors"), Kith.Tag(name: "Family")]

        #expect(TagVocabulary.options(from: vocabulary, notIn: [])
            == ["Family", "mentors", "Work"])
        // What this person already carries drops out, case-insensitively.
        #expect(TagVocabulary.options(from: vocabulary, notIn: ["work", "FAMILY"])
            == ["mentors"])
        #expect(TagVocabulary.options(from: [], notIn: []).isEmpty)
    }

    /// Two devices can seed before iCloud catches up. The menu must still show
    /// the name once.
    @Test func optionsCollapseDuplicateAndBlankRows() {
        let vocabulary = [Kith.Tag(name: "Work"), Kith.Tag(name: "work"), Kith.Tag(name: "  "), Kith.Tag(name: "")]

        #expect(TagVocabulary.options(from: vocabulary, notIn: []) == ["Work"])
    }

    @Test func namesIsTheWholeVocabularySortedAndDeduped() {
        let vocabulary = [Kith.Tag(name: "work"), Kith.Tag(name: "Close friends"), Kith.Tag(name: "Work")]

        #expect(TagVocabulary.names(in: vocabulary) == ["Close friends", "work"])
    }

    @Test func canonicalSettlesOnTheStarterSpellingAndLeavesCustomTagsAlone() {
        #expect(TagVocabulary.canonical("work") == "Work")
        #expect(TagVocabulary.canonical("  CLOSE FRIENDS ") == "Close friends")
        #expect(TagVocabulary.canonical("  mentors ") == "mentors")
        #expect(TagVocabulary.canonical("   ").isEmpty)
    }

    @Test func aTypedStarterAndAPickedOneAreOneTagWithOneSpelling() {
        person("A", tags: ["work"])
        person("B", tags: ["Work"])

        #expect(TagVocabulary.all(in: people) == ["Work"])
    }
}
