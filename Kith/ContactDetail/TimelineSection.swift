import SwiftUI

/// Reverse-chronological touches and skip markers. View-only: entries are
/// created from Upcoming and read here for context (Contact Detail §5.5).
struct TimelineSection: View {
    let entries: [TimelineEntry]

    var body: some View {
        // No header: the segmented picker above already says "Timeline".
        Section {
            if entries.isEmpty {
                Text("No touches logged yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries) { entry in
                    TimelineRow(entry: entry)
                }
            }
        }
    }
}
