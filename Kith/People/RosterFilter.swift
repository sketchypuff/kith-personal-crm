import Foundation

/// The roster's two filters (People §7). They combine with AND.
struct RosterFilter: Equatable {
    var overdueOnly = false
    var tag: String?

    var isActive: Bool {
        overdueOnly || tag != nil
    }

    /// Echoed in the status line and count footer, e.g. "Overdue · tag: clients".
    var summary: String? {
        var parts: [String] = []
        if overdueOnly { parts.append("Overdue") }
        if let tag { parts.append("tag: \(tag)") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Title for the filtered-empty state (People §11.3).
    var emptyTitle: String {
        switch (overdueOnly, tag) {
        case (true, let tag?): "No one overdue tagged “\(tag)”"
        case (true, nil): "No one overdue"
        case (false, let tag?): "No one tagged “\(tag)”"
        case (false, nil): "No one here"
        }
    }

    mutating func clear() {
        overdueOnly = false
        tag = nil
    }
}
