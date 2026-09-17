import Foundation

/// Everything needed to reverse one logged catch-up, wherever it came from —
/// Upcoming's check or a Contact Detail quick action.
struct TouchUndoRecord: Identifiable {
    let id = UUID()
    let person: Person
    let touch: Touch
    let previousLastLoggedAt: Date?
    let previousRemindOn: Date?
    let keyDate: KeyDate?
    let previousLastHandledAt: Date?

    init(
        person: Person,
        touch: Touch,
        previousLastLoggedAt: Date?,
        previousRemindOn: Date?,
        keyDate: KeyDate? = nil,
        previousLastHandledAt: Date? = nil
    ) {
        self.person = person
        self.touch = touch
        self.previousLastLoggedAt = previousLastLoggedAt
        self.previousRemindOn = previousRemindOn
        self.keyDate = keyDate
        self.previousLastHandledAt = previousLastHandledAt
    }

    /// One phrase for every kind of check: "handled" described the bookkeeping
    /// rather than what the tap meant, and a key date, a reach-out, and a
    /// tapped Call are the same act to the person doing it.
    var message: String {
        "Checked in · \(person.name)"
    }
}
