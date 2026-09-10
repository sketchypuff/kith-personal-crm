import Foundation

/// What the feed is showing. Picked from the title dropdown, and the raw value
/// is both the menu label and the navigation title.
enum UpcomingMode: String, CaseIterable, Identifiable {
    /// Everything not yet overdue: key dates plus reach-outs still ahead of
    /// their due date. The exact complement of `.overdue`, so the two
    /// modes together are the whole feed.
    case upcoming = "Upcoming"
    case overdue = "Overdue"

    var id: String { rawValue }

    /// Overdue is never horizon-bounded, so the window filter and the subtitle
    /// naming it have nothing to say in that mode.
    var usesHorizon: Bool { self == .upcoming }
}
