import SwiftUI

/// The calm states: nobody added yet, fully caught up, or an empty segment.
struct UpcomingEmptyView: View {
    let feed: UpcomingFeed
    let segment: UpcomingSegment
    let hasPeople: Bool
    let onAdd: () -> Void

    var body: some View {
        if !hasPeople {
            ContentUnavailableView {
                Label("No one here yet", systemImage: "person.crop.circle.badge.plus")
            } description: {
                Text("Add someone from Contacts to start staying in touch.")
            } actions: {
                // First run has no toolbar +, so this is the only way in:
                // the large control size makes it the screen's obvious target.
                Button("Add Contact", action: onAdd)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .font(.headline)
            }
        } else if feed.isEmpty {
            ContentUnavailableView {
                Label("Nothing in the next 30 days.", systemImage: "checkmark.circle")
            } description: {
                if let coverage = feed.coverage {
                    Text("\(coverage, format: .percent.precision(.fractionLength(0))) on track")
                }
            }
        } else {
            switch segment {
            case .upcoming:
                ContentUnavailableView(
                    "Nothing coming up",
                    systemImage: "calendar",
                    description: Text("Dates and reach-outs appear here 30 days ahead.")
                )
            case .overdue:
                ContentUnavailableView(
                    "No one overdue",
                    systemImage: "checkmark.circle",
                    description: Text("Everyone is on track.")
                )
            }
        }
    }
}
