import SwiftData
import SwiftUI

/// Requests Contacts access before presenting the picker and Setup sheet.
/// Shared by onboarding, Upcoming, and People.
struct AddContactFlowModifier: ViewModifier {
    @Bindable var state: AddContactFlowState
    let onDuplicate: (Person) -> Void
    var onCreated: ((Person) -> Void)?
    var onSaved: ((Person) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationConsent.self) private var consent
    @State private var errorMessage: String?

    func body(content: Content) -> some View {
        content
            .disabled(state.isRequestingContactAccess)
            .task(id: state.isRequestingContactAccess) {
                await state.preparePicker()
            }
            .onDisappear(perform: state.cancelContactAccessRequest)
            .sheet(isPresented: $state.isPickingContact, onDismiss: pickerDidDismiss) {
                ContactPickerView(onPick: handlePick, onCancel: dismissPicker)
                    .ignoresSafeArea()
            }
            .sheet(item: $state.pickedContact, onDismiss: setupDidDismiss) { contact in
                SetupSheetView(contact: contact, onSave: acceptResult)
            }
            .operationErrorAlert("Couldn't finish adding person", message: $errorMessage)
    }

    /// Add Contact §3: duplicate guard first — never create a second copy.
    private func handlePick(_ contact: PickedContact) {
        state.pendingContact = contact
        state.isPickingContact = false
    }

    private func dismissPicker() {
        state.pendingContact = nil
        state.isPickingContact = false
    }

    private func pickerDidDismiss() {
        guard let contact = state.pendingContact else { return }
        state.pendingContact = nil
        do {
            if let existing = try AddContactActions(context: modelContext).existingPerson(contactID: contact.id) {
                onDuplicate(existing)
            } else {
                state.pickedContact = contact
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func setupDidDismiss() {
        guard let result = state.result else { return }
        state.result = nil
        switch result {
        case .existing(let person):
            onDuplicate(person)
        case .created(let person):
            if AppPreferences.notificationsEnabled {
                do {
                    let people = try modelContext.fetch(FetchDescriptor<Person>())
                    NotificationPlanner(notifications: consent.notifications).rescheduleAll(people)
                } catch {
                    errorMessage = "The person was saved, but reminders couldn't be updated. \(error.localizedDescription)"
                }
            }
            if let onSaved {
                onSaved(person)
            } else {
                consent.considerReminder(for: person)
            }
        }
    }

    private func acceptResult(_ result: AddContactResult) {
        state.result = result
        if case .created(let person) = result {
            if let onCreated {
                onCreated(person)
            } else {
                consent.reserveReminder(for: person)
            }
        }
    }
}

extension View {
    func addContactFlow(
        _ state: AddContactFlowState,
        onDuplicate: @escaping (Person) -> Void,
        onCreated: ((Person) -> Void)? = nil,
        onSaved: ((Person) -> Void)? = nil
    ) -> some View {
        modifier(AddContactFlowModifier(
            state: state, onDuplicate: onDuplicate, onCreated: onCreated, onSaved: onSaved
        ))
    }
}
