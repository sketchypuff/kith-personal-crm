import SwiftData
import SwiftUI

/// The mandatory add-time sheet: Name · Notify · Birthday · Tags.
/// The person is not saved until Notify is confirmed (Save).
struct SetupSheetView: View {
    let contact: PickedContact
    var onSave: (AddContactResult) -> Void

    /// Only for the tag menu's options: the sheet picks from the vocabulary
    /// rather than growing it. Managed in Settings, not here.
    @Query private var tags: [Tag]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var cadence: Cadence
    @State private var notifyDay: Weekday
    @State private var notifyTime: Date
    @State private var hasBirthday: Bool
    @State private var birthday: Date
    @State private var selectedTags: [String] = []
    /// Presented from the Form for the same reason as Contact Detail's.
    @State private var isManagingTags = false
    @State private var errorMessage: String?

    init(contact: PickedContact, onSave: @escaping (AddContactResult) -> Void = { _ in }) {
        self.contact = contact
        self.onSave = onSave
        _name = State(initialValue: contact.name)
        _cadence = State(initialValue: AppPreferences.newContactCadence)
        _notifyDay = State(initialValue: AppPreferences.newContactNotifyDay)
        _notifyTime = State(initialValue: AppPreferences.defaultReminderTime)

        let calendar = Calendar.current
        if let components = contact.birthday,
           let month = components.month, let day = components.day,
           let date = calendar.date(from: DateComponents(year: components.year ?? 2000, month: month, day: day)) {
            _hasBirthday = State(initialValue: true)
            _birthday = State(initialValue: date)
        } else {
            _hasBirthday = State(initialValue: false)
            _birthday = State(initialValue: calendar.date(from: DateComponents(year: 1990, month: 1, day: 1)) ?? .now)
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $name)
                }

                Section("Notify") {
                    Picker("How often", selection: $cadence) {
                        ForEach(Cadence.allCases, id: \.self) { cadence in
                            Text(cadence.label).tag(cadence)
                        }
                    }
                    Picker("Day", selection: $notifyDay) {
                        ForEach(Weekday.allCases, id: \.self) { day in
                            Text(day.label).tag(day)
                        }
                    }
                    .disabled(!cadence.usesNotifyDay)
                    DatePicker("Time", selection: $notifyTime, displayedComponents: .hourAndMinute)
                        .disabled(cadence == .never)
                }

                Section("Birthday") {
                    Toggle("Birthday", isOn: $hasBirthday.animation())
                    if hasBirthday {
                        DatePicker("Date", selection: $birthday, displayedComponents: .date)
                    }
                }

                TagsSection(
                    tags: selectedTags,
                    available: TagVocabulary.options(from: tags, notIn: selectedTags),
                    onAdd: addTag,
                    onRemove: removeTag,
                    onManageTags: { isManagingTags = true }
                )
            }
            .navigationTitle("New Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel, action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
        }
        .sheet(isPresented: $isManagingTags) {
            ManageTagsView()
        }
        .presentationDragIndicator(.visible)
        .operationErrorAlert("Couldn't save person", message: $errorMessage)
    }

    private func addTag(_ tag: String) {
        withAnimation {
            selectedTags.append(tag)
        }
    }

    private func removeTag(_ tag: String) {
        withAnimation {
            selectedTags.removeAll { TagVocabulary.fold($0) == TagVocabulary.fold(tag) }
        }
    }

    private func cancel() {
        dismiss()
    }

    private func save() {
        var birthdayComponents: DateComponents?
        if hasBirthday {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: birthday)
            if contact.birthday?.year == nil && components.year == 2000 {
                components.year = nil
            }
            birthdayComponents = components
        }
        let draft = AddContactDraft(
            name: name, cadence: cadence, notifyDay: notifyDay, notifyTime: notifyTime,
            tags: selectedTags, birthday: birthdayComponents
        )
        do {
            let result = try AddContactActions(context: modelContext).save(contact: contact, draft: draft)
            onSave(result)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    SetupSheetView(contact: PickedContact(id: "preview", name: "Maya Patel", birthday: DateComponents(month: 4, day: 12)))
        .modelContainer(ModelContainerCoordinator.inMemory())
}
