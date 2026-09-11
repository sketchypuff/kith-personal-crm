import SwiftUI

/// The tags applied to one person, one per row, added from a fixed list.
/// Shared by Contact Detail and the Add Contact setup sheet.
///
/// Pick-only, everywhere: no free text. The list is whatever the vocabulary
/// holds, so tagging stays a choice from a short menu rather than a spelling
/// exercise. The header's Create button is the escape hatch to Manage tags when
/// the tag you want doesn't exist yet.
/// Labels only — tags never affect cadence (PRD P0-3).
struct TagsSection: View {
    let tags: [String]
    /// Every tag that can be picked, this person's own already removed.
    let available: [String]
    let onAdd: (String) -> Void
    let onRemove: (String) -> Void
    /// Opens Manage tags. The picker only offers what the vocabulary already
    /// holds, so a tag that isn't there yet needs a way out of this screen.
    let onManageTags: () -> Void

    var body: some View {
        Section {
            ForEach(tags, id: \.self) { tag in
                HStack {
                    Text(tag)
                    Spacer()
                    Button("Remove \(tag)", systemImage: "xmark.circle.fill") {
                        onRemove(tag)
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.borderless)   // only the glyph is the target, not the whole row
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("Remove", systemImage: "trash", role: .destructive) {
                        onRemove(tag)
                    }
                }
            }

            // Nothing left to pick is a finished state, not a broken one, so
            // the row goes away rather than sitting there disabled.
            if !available.isEmpty {
                Menu {
                    ForEach(available, id: \.self) { tag in
                        Button(tag) { onAdd(tag) }
                    }
                } label: {
                    Label("Add tag", systemImage: "plus.circle.fill")
                }
            }
        } header: {
            HStack {
                Text("Tags")
                Spacer()
                // Worded, not a plus: an icon here would read as a second
                // "Add tag", when this one makes a tag rather than applying one.
                Button("Create", action: onManageTags)
                    .font(.body)   // measured to match the header's own cap height
                    .textCase(nil)   // headers uppercase their text; the button shouldn't inherit that
                    .accessibilityLabel("Create a tag")
            }
        } footer: {
            Text("Labels for grouping only. Tags never change cadence.")
        }
    }
}
