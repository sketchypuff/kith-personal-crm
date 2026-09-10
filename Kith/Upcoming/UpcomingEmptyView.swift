import SwiftUI

/// The calm states: nobody added yet, a tag that hides everyone, fully caught
/// up, or an empty mode.
struct UpcomingEmptyView: View {
    let feed: UpcomingFeed
    let mode: UpcomingMode
    let hasPeople: Bool
    let tag: String?
    let onAdd: () -> Void
    let onClearTag: () -> Void
    let onShowOverdue: () -> Void

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
        } else if mode == .overdue {
            ContentUnavailableView(
                "No one overdue",
                systemImage: "checkmark.circle",
                description: Text("Everyone\(tagPhrase) is on track.")
            )
        } else if let tag, feed.isEmpty {
            // The tag scopes the whole feed, so an empty feed here means the
            // tag hid everyone, not that there is nothing to do.
            ContentUnavailableView {
                Label("No one tagged “\(tag)”", systemImage: "tag")
            } description: {
                Text("Everyone else is hidden by the filter.")
            } actions: {
                Button("Clear tag", action: onClearTag)
            }
        } else if feed.isEmpty {
            ContentUnavailableView {
                // Says the window the feed was actually built for, so a
                // narrowed filter can't read as "nothing at all".
                Label("Nothing \(feed.horizon.span).", systemImage: "checkmark.circle")
            } description: {
                if let coverage = feed.coverage {
                    Text("\(coverage, format: .percent.precision(.fractionLength(0))) on track")
                }
            }
        } else if feed.hasOverdue {
            // The list is empty only because everything left is overdue, and
            // overdue lives behind the title dropdown. Say so, and offer the switch.
            ContentUnavailableView {
                Label("Nothing coming up", systemImage: "calendar")
            } description: {
                Text("Everyone left\(tagPhrase) is already overdue.")
            } actions: {
                Button("Show overdue", action: onShowOverdue)
            }
        } else {
            ContentUnavailableView(
                "Nothing coming up",
                systemImage: "calendar",
                description: Text("No dates or reach-outs\(tagPhrase) \(feed.horizon.span).")
            )
        }
    }

    /// " tagged “work”", or nothing at all. Reads inside a sentence either way.
    private var tagPhrase: String {
        guard let tag else { return "" }
        return " tagged “\(tag)”"
    }
}
