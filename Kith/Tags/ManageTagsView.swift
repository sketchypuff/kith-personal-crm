import SwiftData
import SwiftUI

/// The tag vocabulary, as a sheet from Settings: the one place a tag is created
/// or destroyed. Everywhere else picks from what this screen holds.
struct ManageTagsView: View {
    @Query(sort: \Tag.createdAt) private var tags: [Tag]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isAddingTag = false
    @State private var pendingDeletion: String?

    private var actions: TagActions {
        TagActions(context: modelContext)
    }

    var body: some View {
        // Deduped and sorted here, so two rows seeded by two devices read as
        // the one tag they are.
        let names = TagVocabulary.names(in: tags)

        NavigationStack {
            List {
                ForEach(names, id: \.self) { name in
                    TagRow(name: name) {
                        pendingDeletion = name
                    }
                }
            }
            .overlay {
                if names.isEmpty {
                    ContentUnavailableView {
                        Label("No tags", systemImage: "tag")
                    } description: {
                        Text("Add a tag to start grouping people by it.")
                    } actions: {
                        Button("Add Tag") { isAddingTag = true }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .font(.headline)
                    }
                }
            }
            .navigationTitle("Manage tags")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                // .cancellationAction is the leading slot natively, so the
                // cross lands top-left without hardcoding a placement.
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add tag", systemImage: "plus") { isAddingTag = true }
                }
            }
            .sheet(isPresented: $isAddingTag) {
                NewTagSheet(exists: actions.exists) { name in
                    withAnimation {
                        _ = actions.create(name)
                    }
                }
            }
            .confirmationDialog(
                pendingDeletion.map { "Delete “\($0)”?" } ?? "",
                isPresented: .init(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let name = pendingDeletion {
                    Button("Delete “\(name)”", role: .destructive) {
                        withAnimation { actions.delete(name) }
                        pendingDeletion = nil
                    }
                }
                Button("Cancel", role: .cancel) { pendingDeletion = nil }
            } message: {
                if let name = pendingDeletion {
                    Text(deletionWarning(for: name))
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    /// Says what the delete will actually touch. A tag nobody carries is a
    /// cheap delete and shouldn't be dressed up as a dangerous one.
    private func deletionWarning(for name: String) -> String {
        switch actions.peopleCarrying(name) {
        case 0: "No one is tagged with this. It will be removed from the list."
        case 1: "This removes the tag from 1 person and can't be undone."
        case let count: "This removes the tag from \(count) people and can't be undone."
        }
    }
}

private struct TagRow: View {
    let name: String
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Text(name)
            Spacer()
            // Red, but a quiet glyph rather than a filled bar, and deliberately
            // not `role: .destructive`: the confirmation dialog carries the role.
            Button("Delete \(name)", systemImage: "minus.circle.fill", action: onDelete)
                .labelStyle(.iconOnly)
                .foregroundStyle(.red)
                .buttonStyle(.borderless)   // only the glyph is the target, not the whole row
        }
    }
}

#Preview {
    ManageTagsView()
        .modelContainer(SampleData.previewContainer())
}
