import Foundation

/// Derived values — computed, never persisted (Data Model Spec §6).
extension Person {

    /// Next due date per the PRD Appendix. `nil` for a Never cadence.
    var nextDue: Date? {
        guard cadence != .never else { return nil }
        let anchor = lastLoggedAt ?? createdAt
        return CadenceEngine.advance(anchor, by: cadence, alignedTo: notifyDay, at: notifyTime)
    }

    var isOverdue: Bool {
        isOverdue(at: .now)
    }

    /// Overdue when cadence ≠ Never, the due date has passed, and the person
    /// is not currently held by "Remind me tomorrow".
    func isOverdue(at now: Date) -> Bool {
        guard let due = nextDue else { return false }
        guard now > due else { return false }
        if let remindOn, now <= remindOn { return false }
        return true
    }

    /// True while a "Remind me tomorrow" hold is active.
    func isSnoozed(at now: Date) -> Bool {
        guard let remindOn else { return false }
        return now <= remindOn
    }

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init)
        return letters.joined().uppercased()
    }
}

/// Deterministic notification identifiers (Data Model Spec §8).
extension Person {
    var reachOutNotificationID: String { "reachout-\(id.uuidString)" }
    var remindTomorrowNotificationID: String { "remind-\(id.uuidString)" }

    /// Every pending ID for this person. Build BEFORE `modelContext.delete`,
    /// since the cascade makes `keyDates` unreadable afterward.
    var pendingNotificationIDs: [String] {
        var ids = [reachOutNotificationID, remindTomorrowNotificationID]
        for keyDate in keyDates ?? [] {
            ids.append(keyDate.leadNotificationID)
            ids.append(keyDate.dayOfNotificationID)
        }
        return ids
    }
}
