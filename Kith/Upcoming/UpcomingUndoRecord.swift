import Foundation

/// Everything needed to reverse one check tap from Upcoming.
struct UpcomingUndoRecord: Identifiable {
    let id = UUID()
    let person: Person
    let touch: Touch
    let previousLastLoggedAt: Date?
    let previousRemindOn: Date?
    let keyDate: KeyDate?
    let previousLastHandledAt: Date?

    /// One phrase for both kinds of row: "handled" described the bookkeeping
    /// rather than what the tap meant, and a key date and a reach-out are the
    /// same act to the person doing it.
    var message: String {
        "Checked in · \(person.name)"
    }
}
