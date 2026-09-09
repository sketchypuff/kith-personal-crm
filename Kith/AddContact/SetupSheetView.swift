import SwiftData
import SwiftUI

/// The mandatory add-time sheet: Name · Notify · Birthday · Tags.
/// The person is not saved until Notify is confirmed (Save).
struct SetupSheetView: View {
    let contact: PickedContact

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var cadence: Cadence
    @State private var notifyDay: Weekday
    @State private var notifyTime: Date
    @State private var hasBirthday: Bool
    @State private var birthday: Date
    @State private var tagsText = ""

    init(contact: PickedContact) {
        self.contact = contact
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
        !name.trimmingCharacters(in: .whitespaces).isEmpty
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

                Section {
                    TextField("Tags, separated by commas", text: $tagsText)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Tags")
                } footer: {
                    Text("Labels for grouping only. Tags never change cadence.")
                }
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
        .presentationDragIndicator(.visible)
    }

    private func cancel() {
        dismiss()
    }

    private func save() {
        let person = Person(name: name.trimmingCharacters(in: .whitespaces), linkedContactID: contact.id)
        person.cadence = cadence
        person.notifyDay = notifyDay
        person.notifyTime = notifyTime
        person.tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        modelContext.insert(person)

        if hasBirthday {
            let components = Calendar.current.dateComponents([.year, .month, .day], from: birthday)
            let keyDate = KeyDate()
            keyDate.type = .birthday
            keyDate.month = components.month ?? 1
            keyDate.day = components.day ?? 1
            keyDate.year = contact.birthday?.year == nil && components.year == 2000 ? nil : components.year
            keyDate.person = person
            modelContext.insert(keyDate)
        }

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    SetupSheetView(contact: PickedContact(id: "preview", name: "Maya Patel", birthday: DateComponents(month: 4, day: 12)))
        .modelContainer(ModelContainerCoordinator.inMemory())
}
