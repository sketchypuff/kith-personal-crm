import SwiftData
import SwiftUI

/// Presents the contact picker, runs the duplicate guard, then the Setup sheet.
/// Attached to any screen with a + button (Upcoming, People).
struct AddContactFlowModifier: ViewModifier {
    @Binding var state: AddContactFlowState
    let onDuplicate: (Person) -> Void

    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $state.isPickingContact) {
                ContactPickerView(onPick: handlePick, onCancel: dismissPicker)
                    .ignoresSafeArea()
            }
            .sheet(item: $state.pickedContact) { contact in
                SetupSheetView(contact: contact)
            }
    }

    /// Add Contact §3: duplicate guard first — never create a second copy.
    private func handlePick(_ contact: PickedContact) {
        state.isPickingContact = false
        if let existing = existingPerson(forContactID: contact.id) {
            onDuplicate(existing)
        } else {
            state.pickedContact = contact
        }
    }

    private func dismissPicker() {
        state.isPickingContact = false
    }

    private func existingPerson(forContactID contactID: String) -> Person? {
        var descriptor = FetchDescriptor<Person>(predicate: #Predicate { $0.linkedContactID == contactID })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}

extension View {
    func addContactFlow(_ state: Binding<AddContactFlowState>, onDuplicate: @escaping (Person) -> Void) -> some View {
        modifier(AddContactFlowModifier(state: state, onDuplicate: onDuplicate))
    }
}
