import SwiftUI

/// Naming a new tag. Stacks on top of Manage tags at half height, because one
/// text field doesn't earn a full screen.
struct NewTagSheet: View {
    /// Asked as you type, so a name already in the vocabulary disables the tick
    /// instead of being silently swallowed on tap.
    let exists: (String) -> Bool
    let onAdd: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @FocusState private var isNameFocused: Bool

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDuplicate: Bool {
        !trimmed.isEmpty && exists(trimmed)
    }

    private var canAdd: Bool {
        !trimmed.isEmpty && !isDuplicate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Tag name", text: $name)
                        .focused($isNameFocused)
                        .submitLabel(.done)
                        .onSubmit(add)
                } footer: {
                    if isDuplicate {
                        Text("“\(trimmed)” is already a tag.")
                    } else {
                        Text("Labels for grouping only. Tags never change cadence.")
                    }
                }
            }
            .navigationTitle("New Tag")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", systemImage: "checkmark", action: add)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.glassProminent)   // the sheet's primary act, accent-tinted
                        .disabled(!canAdd)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .task { isNameFocused = true }
    }

    private func add() {
        guard canAdd else { return }
        onAdd(trimmed)
        dismiss()
    }
}
