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

    var message: String {
        if let keyDate {
            return "\(keyDate.label) handled · \(person.name)"
        }
        return "Logged · \(person.name)"
    }
}
