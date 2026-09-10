import SwiftUI

/// Opens the tag vocabulary (Manage tags). A row in the Other section, drawn
/// like a navigation row but presenting a sheet — the same shape `AboutSection`
/// uses, and for the same reason: Settings has no navigation destinations.
struct ManageTagsRow: View {
    let onShow: () -> Void

    var body: some View {
        Button(action: onShow) {
            HStack {
                Label("Manage tags", systemImage: "tag")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.bold())
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.primary)
        }
        // The icon pushes the separator inward to align with the label's text,
        // which leaves this row's rule short of the ones below it. Pull it back
        // to the row's own leading edge.
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
    }
}
