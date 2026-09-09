import SwiftUI

/// The running note. Autosaves on a pause in typing, on losing focus, and
/// on leaving the screen — never on every keystroke (Contact Detail §6).
struct NotesSection: View {
    let person: Person
    let onCommit: (String) -> Void

    @State private var draft: String
    @FocusState private var isFocused: Bool

    init(person: Person, onCommit: @escaping (String) -> Void) {
        self.person = person
        self.onCommit = onCommit
        _draft = State(initialValue: person.notes)
    }

    var body: some View {
        Section("Notes") {
            TextField("What did you last talk about?", text: $draft, axis: .vertical)
                .lineLimit(3...)
                .focused($isFocused)
                .task(id: draft) {
                    await commitAfterPause()
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused { commit() }
                }
                .onChange(of: person.notes) { _, notes in
                    adoptRemoteEdit(notes)
                }
                .onDisappear(perform: commit)
        }
    }

    private func commit() {
        onCommit(draft)
    }

    private func commitAfterPause() async {
        try? await Task.sleep(for: .seconds(0.8))
        guard !Task.isCancelled else { return }
        commit()
    }

    /// A value edited on another device may land while the screen is open
    /// (Contact Detail §7); adopt it unless the user is mid-edit here.
    private func adoptRemoteEdit(_ notes: String) {
        guard !isFocused, notes != draft else { return }
        draft = notes
    }
}
