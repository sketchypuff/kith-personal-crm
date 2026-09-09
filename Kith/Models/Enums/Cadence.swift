import Foundation

/// How often to reach out. Stored on `Person` as its raw value (`cadenceRaw`).
nonisolated enum Cadence: String, Codable, CaseIterable {
    case never, daily, weekly, monthly, quarterly, annually

    var label: String {
        switch self {
        case .never: "Never"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .annually: "Annually"
        }
    }

    /// Weekly and longer cadences are aligned onto the person's `notifyDay`.
    var usesNotifyDay: Bool {
        switch self {
        case .never, .daily: false
        case .weekly, .monthly, .quarterly, .annually: true
        }
    }
}
