import Foundation

/// The contact sheet's two views: configuration (Info) and history (Timeline).
enum ContactDetailSegment: String, CaseIterable, Identifiable {
    case info = "Info"
    case timeline = "Timeline"

    var id: String { rawValue }
}
