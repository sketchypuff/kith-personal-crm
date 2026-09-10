import Foundation
import SwiftData

/// Every write to the tag vocabulary. Pure of any view so it can be tested
/// against a throwaway container, like `PeopleActions` and `SettingsActions`.
struct TagActions {
    let context: ModelContext
    var defaults: UserDefaults = AppPreferences.store

    // MARK: - Reads

    private var allTags: [Tag] {
        (try? context.fetch(FetchDescriptor<Tag>())) ?? []
    }

    private var allPeople: [Person] {
        (try? context.fetch(FetchDescriptor<Person>())) ?? []
    }

    /// How many people carry this tag. Feeds the delete confirmation, which
    /// has to say what it is about to touch.
    func peopleCarrying(_ name: String) -> Int {
        allPeople.filter { TagVocabulary.matches(name, in: $0) }.count
    }

    // MARK: - Writes

    /// Adds a name to the vocabulary once. Returns false when it was blank or
    /// already there, so the caller can leave the field alone and say so.
    @discardableResult
    func create(_ raw: String) -> Bool {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        guard !exists(name) else { return false }

        context.insert(Tag(name: name))
        save()
        return true
    }

    /// True when the vocabulary already holds this name, ignoring case. A
    /// fetch, not a `@Attribute(.unique)`: CloudKit mirroring forbids those.
    func exists(_ name: String) -> Bool {
        let key = TagVocabulary.fold(name)
        return allTags.contains { TagVocabulary.fold($0.name) == key }
    }

    /// Removes the name from the vocabulary *and* from everyone carrying it.
    ///
    /// The two are one act: leaving the name on people would resurrect it in
    /// the pill rows, which read from people rather than from here. Deletes
    /// every row matching the folded name, so a duplicate seeded by a second
    /// device goes with it.
    func delete(_ name: String) {
        let key = TagVocabulary.fold(name)

        for person in allPeople where TagVocabulary.matches(name, in: person) {
            person.tags.removeAll { TagVocabulary.fold($0) == key }
        }

        for tag in allTags where TagVocabulary.fold(tag.name) == key {
            context.delete(tag)
        }

        save()
    }

    // MARK: - Seeding

    /// Fills an empty vocabulary with the starter names plus every tag already
    /// carried by someone, so an existing roster isn't stranded without one.
    ///
    /// Runs once per device, guarded by a preference rather than by "is the
    /// table empty": deleting every starter is a legitimate end state, and an
    /// emptiness check would undo it on the next launch.
    ///
    /// On a synced account a second device can seed before iCloud delivers the
    /// first one's rows; the extra rows collapse on read and delete takes them
    /// all, so the duplicate is invisible rather than wrong.
    func seedIfNeeded() {
        guard !AppPreferences.tagsSeeded(in: defaults) else { return }
        defer { AppPreferences.setTagsSeeded(true, in: defaults) }

        var didInsert = false

        for name in TagVocabulary.defaults + allPeople.flatMap(\.tags) {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !exists(trimmed) else { continue }
            context.insert(Tag(name: TagVocabulary.canonical(trimmed)))
            didInsert = true
        }

        if didInsert { save() }
    }

    private func save() {
        try? context.save()
    }
}
