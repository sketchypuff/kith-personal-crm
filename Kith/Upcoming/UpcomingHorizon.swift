import Foundation

/// How far ahead the Upcoming feed looks, chosen from the toolbar filter.
///
/// The horizon bounds what is still *ahead*: a key date or a reach-out shows
/// only if it falls within this many days. Overdue reach-outs sit before now
/// rather than inside any forward window, and they are the one thing the app
/// exists to surface, so they are never filtered out — narrowing to Today
/// answers "what needs me now", not "what did I miss".
enum UpcomingHorizon: Int, CaseIterable, Identifiable {
    case today = 0
    case week = 7
    case month = 30

    /// The feed's default: the widest window, and the one the screen opens on.
    static let `default` = UpcomingHorizon.month

    var id: Int { rawValue }

    /// Whole days ahead of now a row may fall and still be listed.
    var days: Int { rawValue }

    /// The menu row, and the navigation subtitle, which say the same thing.
    var label: String {
        switch self {
        case .today: "Today"
        case .week: "Next 7 days"
        case .month: "Next 30 days"
        }
    }

    /// Reads inside a sentence: "No dates or reach-outs \(span)."
    var span: String {
        switch self {
        case .today: "today"
        case .week: "in the next 7 days"
        case .month: "in the next 30 days"
        }
    }
}
