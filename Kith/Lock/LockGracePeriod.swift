import Foundation

/// How long after the app last resigned active it may be re-foregrounded
/// without re-authenticating (Settings §6.2). Raw value is the grace window in
/// seconds, stored in the App Group defaults.
nonisolated enum LockGracePeriod: Int, CaseIterable {
    case immediately = 0
    case afterOneMinute = 60
    case afterFiveMinutes = 300

    var label: String {
        switch self {
        case .immediately: "Immediately"
        case .afterOneMinute: "After 1 minute"
        case .afterFiveMinutes: "After 5 minutes"
        }
    }

    var duration: TimeInterval {
        TimeInterval(rawValue)
    }
}
