import Foundation

/// The visible roster, built in memory from the `@Query` result (People §5–7).
/// Pure and clock-injected so it can be unit tested.
struct PeopleRoster {
    static let symbolSection = "#"

    let sections: [RosterSection]
    let visibleCount: Int
    /// Every tag in use across the whole roster, for the filter picker.
    let allTags: [String]

    var isEmpty: Bool { sections.isEmpty }

    static func build(
        people: [Person],
        searchText: String = "",
        filter: RosterFilter = RosterFilter(),
        now: Date = .now,
        calendar: Calendar = .current
    ) -> PeopleRoster {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Sort in memory: localized, case- and diacritic-insensitive (never via @Query).
        let sorted = people.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        var entries: [RosterEntry] = []
        for person in sorted {
            guard matchesFilter(person, filter: filter, now: now) else { continue }
            guard let match = searchMatch(for: person, query: query) else { continue }
            let status = person.catchupStatus(at: now, calendar: calendar)
            entries.append(RosterEntry(person: person, status: status, matchHint: match.hint))
        }

        var lettered: [String: [RosterEntry]] = [:]
        for entry in entries {
            lettered[sectionKey(for: entry.person.name), default: []].append(entry)
        }
        var sections = lettered
            .filter { $0.key != symbolSection }
            .map { RosterSection(letter: $0.key, entries: $0.value) }
            .sorted { $0.letter.localizedStandardCompare($1.letter) == .orderedAscending }
        if let symbols = lettered[symbolSection] {
            sections.append(RosterSection(letter: symbolSection, entries: symbols))
        }

        let tags = Set(people.flatMap(\.tags))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }

        return PeopleRoster(sections: sections, visibleCount: entries.count, allTags: tags)
    }

    // MARK: - Set logic

    /// Tag ∧ overdue (People Appendix).
    static func matchesFilter(_ person: Person, filter: RosterFilter, now: Date) -> Bool {
        if let tag = filter.tag, !person.tags.contains(tag) { return false }
        if filter.overdueOnly, !person.isOverdue(at: now) { return false }
        return true
    }

    /// Name ∪ notes ∪ tags, case- and diacritic-insensitive. Nil means no match.
    static func searchMatch(for person: Person, query: String) -> SearchMatch? {
        guard !query.isEmpty else { return .name }
        if person.name.localizedStandardContains(query) { return .name }
        if let tag = person.tags.first(where: { $0.localizedStandardContains(query) }) {
            return .tag(tag)
        }
        if person.notes.localizedStandardContains(query) { return .notes }
        return nil
    }

    /// First letter of the folded sort key; digits and symbols go under "#".
    static func sectionKey(for name: String) -> String {
        let folded = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        guard let first = folded.first, first.isLetter else { return symbolSection }
        return String(first).uppercased()
    }
}
