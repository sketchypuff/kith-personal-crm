import Foundation

/// Which field a roster search hit (People §6). Only non-name hits get a hint.
enum SearchMatch: Equatable {
    case name
    case tag(String)
    case notes

    var hint: String? {
        switch self {
        case .name: nil
        case .tag(let tag): "matches: #\(tag)"
        case .notes: "matches notes"
        }
    }
}
