import Foundation

/// The visible roster, built in memory from the `@Query` result (People §5–7).
/// One flat A–Z list — no letter sections. Pure and clock-injected so it can be
/// unit tested.
struct PeopleRoster {
    let entries: [RosterEntry]
    /// Every tag in use across the whole roster, for the filter picker.
    let allTags: [String]

    var isEmpty: Bool { entries.isEmpty }

    static func build(
        people: [Person],
        searchText: String = "",
        filter: RosterFilter = RosterFilter(),
        now: Date = .now,
        calendar: Calendar = .current
    ) -> PeopleRoster {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Sort in memory: localized, case- and diacritic-insensitive (never via
        // @Query). Names that don't start with a letter sort to the end, where
        // the old "#" section used to sit.
        let sorted = people.sorted { lhs, rhs in
            let lhsSymbol = startsWithSymbol(lhs.name)
            let rhsSymbol = startsWithSymbol(rhs.name)
            if lhsSymbol != rhsSymbol { return rhsSymbol }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        var entries: [RosterEntry] = []
        for person in sorted {
            guard matchesFilter(person, filter: filter, now: now) else { continue }
            guard let match = searchMatch(for: person, query: query) else { continue }
            let status = person.catchupStatus(at: now, calendar: calendar)
            entries.append(RosterEntry(person: person, status: status, matchHint: match.hint))
        }

        let tags = Set(people.flatMap(\.tags))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }

        return PeopleRoster(entries: entries, allTags: tags)
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

    /// True when the folded name starts with a digit or symbol rather than a letter.
    static func startsWithSymbol(_ name: String) -> Bool {
        let folded = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        guard let first = folded.first else { return true }
        return !first.isLetter
    }
}
