import Foundation
import SwiftData
import Testing
@testable import Kith

struct TagActionsTests {
    let container = ModelContainerCoordinator.inMemory()
    let defaults: UserDefaults

    init() {
        // A throwaway suite per run, so the seeding flag never leaks between
        // tests or into the real App Group.
        defaults = UserDefaults(suiteName: "TagActionsTests-\(UUID().uuidString)")!
    }

    private var actions: TagActions {
        TagActions(context: container.mainContext, defaults: defaults)
    }

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

    private var names: [String] {
        TagVocabulary.names(in: (try? container.mainContext.fetch(FetchDescriptor<Kith.Tag>())) ?? [])
    }

    // MARK: Create

    @Test func createTrimsAndKeepsTheTypedSpelling() {
        #expect(actions.create("  Weekend cricket "))
        #expect(names == ["Weekend cricket"])
    }

    @Test func createRejectsBlankAndDuplicates() {
        #expect(actions.create("Work"))
        #expect(!actions.create("work"))       // folded duplicate
        #expect(!actions.create("  WORK  "))
        #expect(!actions.create("   "))
        #expect(!actions.create(""))
        #expect(names == ["Work"])
    }

    @Test func existsIgnoresCaseAndSurroundingSpace() {
        actions.create("Close friends")

        #expect(actions.exists("close friends"))
        #expect(actions.exists("  CLOSE FRIENDS "))
        #expect(!actions.exists("Work"))
    }

    // MARK: Delete

    @Test func deleteStripsTheTagFromEveryoneCarryingItInAnyCasing() {
        actions.create("Work")
        person("A", tags: ["work", "mentors"])
        person("B", tags: ["WORK"])
        person("C", tags: ["Family"])

        actions.delete("Work")

        #expect(names.isEmpty)
        let byName = Dictionary(uniqueKeysWithValues: people.map { ($0.name, $0.tags) })
        #expect(byName["A"] == ["mentors"])   // their other tags are untouched
        #expect(byName["B"] == [])
        #expect(byName["C"] == ["Family"])
    }

    @Test func deleteTakesEveryRowSharingTheFoldedName() {
        // What a second device's seeding looks like once iCloud catches up.
        container.mainContext.insert(Kith.Tag(name: "Work"))
        container.mainContext.insert(Kith.Tag(name: "work"))

        actions.delete("WORK")

        #expect(names.isEmpty)
    }

    @Test func deletingATagNobodyCarriesTouchesNoOne() {
        actions.create("Work")
        person("A", tags: ["Family"])

        actions.delete("Work")

        #expect(names.isEmpty)
        #expect(people.first?.tags == ["Family"])
    }

    // MARK: Counting

    @Test func peopleCarryingCountsCaseInsensitively() {
        person("A", tags: ["work"])
        person("B", tags: ["WORK"])
        person("C", tags: ["Family"])

        #expect(actions.peopleCarrying("Work") == 2)
        #expect(actions.peopleCarrying("Family") == 1)
        #expect(actions.peopleCarrying("mentors") == 0)
    }

    // MARK: Seeding

    @Test func seedWritesTheStartersPlusWhatIsAlreadyCarried() {
        person("A", tags: ["mentors"])
        person("B", tags: ["work"])   // folds onto the starter, so no second row

        actions.seedIfNeeded()

        #expect(names == ["Close friends", "Family", "Friends", "mentors", "Work"])
    }

    @Test func seedRunsOnceSoDeletingEveryStarterSticks() {
        actions.seedIfNeeded()
        for name in TagVocabulary.defaults {
            actions.delete(name)
        }
        #expect(names.isEmpty)

        actions.seedIfNeeded()   // a later launch

        #expect(names.isEmpty)
    }

    @Test func seedIsIdempotentWithinOneRun() {
        actions.seedIfNeeded()
        let afterFirst = names
        actions.seedIfNeeded()

        #expect(names == afterFirst)
    }
}
