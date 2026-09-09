import Foundation

enum TodaySegment: String, CaseIterable, Identifiable {
    case all = "All"
    case upcoming = "Upcoming"
    case overdue = "Overdue"

    var id: String { rawValue }
}
