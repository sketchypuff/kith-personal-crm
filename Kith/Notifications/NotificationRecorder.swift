import Foundation

/// Test hook for `NotificationScheduler`: a ledger of what is pending and
/// what was cancelled, keyed by the deterministic notification identifiers.
final class NotificationRecorder {
    /// Requests scheduled and not cancelled since, with their fire dates.
    private(set) var pending: [String: Date] = [:]
    /// Every identifier passed to `cancel`, in order.
    private(set) var cancelled: [String] = []

    init() {}

    func recordSchedule(id: String, at fireAt: Date) {
        pending[id] = fireAt
    }

    func recordCancel(_ ids: [String]) {
        cancelled.append(contentsOf: ids)
        for id in ids {
            pending.removeValue(forKey: id)
        }
    }
}
