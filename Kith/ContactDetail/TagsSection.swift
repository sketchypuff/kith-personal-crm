import SwiftUI

/// Free-form labels, one per row, with inline add and swipe-to-remove.
/// Labels only — tags never affect cadence (PRD P0-3).
struct TagsSection: View {
    let tags: [String]
    /// Returns true when the tag was added, so the field can clear.
    let onAdd: (String) -> Bool
    let onRemove: (String) -> Void

    @State private var newTag = ""
    @FocusState private var isEntryFocused: Bool

    private var canAdd: Bool {
        !newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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

            HStack {
                TextField("Add tag", text: $newTag)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    .focused($isEntryFocused)
                    .onSubmit(add)
                if canAdd {
                    Button("Add tag", systemImage: "plus.circle.fill", action: add)
                        .labelStyle(.iconOnly)
                }
            }
        } header: {
            Text("Tags")
        } footer: {
            Text("Labels for grouping only. Tags never change cadence.")
        }
    }

    private func add() {
        if onAdd(newTag) {
            newTag = ""
        }
    }
}
