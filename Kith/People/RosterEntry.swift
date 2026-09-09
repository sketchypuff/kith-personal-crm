import Foundation

/// One visible roster row: the person plus what the subtitle should say.
struct RosterEntry: Identifiable {
    let person: Person
    let status: CatchupStatus
    /// Set when the search matched notes or tags but not the name (People §6),
    /// shown in place of the catchup line so the hit doesn't look like a mistake.
    let matchHint: String?

    var id: UUID { person.id }
}
