import Foundation

/// One letter section of the roster; "#" collects non-letter names.
struct RosterSection: Identifiable {
    let letter: String
    let entries: [RosterEntry]

    var id: String { letter }
}
