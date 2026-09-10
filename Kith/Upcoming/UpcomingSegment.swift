import Foundation

enum UpcomingSegment: String, CaseIterable, Identifiable {
    /// Everything not yet overdue: key dates plus reach-outs still ahead of
    /// their due date. The exact complement of `.overdue`, so the two
    /// segments together are the whole feed.
    case upcoming = "Upcoming"
    case overdue = "Overdue"

    var id: String { rawValue }
}
