import Foundation

/// Every tag in use across the whole roster, plus the starter set offered when
/// tagging someone.
///
/// Tags are free text on `Person`, written from two places that don't agree on
/// case: Contact Detail dedupes case-insensitively, the Setup sheet's
/// comma-split doesn't. Folding here keeps "Work" and "work" from showing as
/// two pills that each hide the other's people.
enum TagVocabulary {
    /// Written into the `Tag` store on first launch and ordinary from then on:
    /// deletable, and no different from a tag you create yourself. Read this
    /// only when seeding — the live vocabulary is the store.
    static let defaults = ["Close friends", "Family", "Friends", "Work"]

    /// Sorted localized, deduped case-insensitively. Derived from people, so a
    /// tag exists only while someone carries it.
    static func all(in people: [Person]) -> [String] {
        var seen: Set<String> = []
        var tags: [String] = []

        for tag in people.flatMap(\.tags) {
            let key = fold(tag)
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            tags.append(canonical(tag))
        }

        return tags.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Everything one person can be given: the whole vocabulary, minus what
    /// they already carry. Duplicate rows (two devices seeding before iCloud
    /// caught up) collapse here, so the menu never shows a name twice.
    static func options(from tags: [Tag], notIn carried: [String]) -> [String] {
        let carriedKeys = Set(carried.map(fold))
        var seen: Set<String> = []
        return tags
            .map(\.name)
            .filter { tag in
                let key = fold(tag)
                return !key.isEmpty && !carriedKeys.contains(key) && seen.insert(key).inserted
            }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// The vocabulary itself, deduped and sorted — what Manage tags lists.
    static func names(in tags: [Tag]) -> [String] {
        options(from: tags, notIn: [])
    }

    /// True when the person carries this tag, ignoring case and diacritics.
    static func matches(_ tag: String, in person: Person) -> Bool {
        let key = fold(tag)
        return person.tags.contains { fold($0) == key }
    }

    /// Trims, and settles on the starter set's spelling when it matches one, so
    /// a typed "work" and the seeded "Work" stay one tag with one spelling.
    static func canonical(_ tag: String) -> String {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = fold(trimmed)
        return defaults.first { fold($0) == key } ?? trimmed
    }

    /// The comparison key: whitespace-trimmed, case- and diacritic-insensitive.
    static func fold(_ tag: String) -> String {
        tag
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}
