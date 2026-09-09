import SwiftUI

/// The lightweight native date editor: type, date (month/day, optional
/// year), lead time, and a reminder toggle (Contact Detail §5.2).
struct KeyDateEditorView: View {
    let item: KeyDateEditorItem
    let onSave: (KeyDateDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: KeyDateDraft

    init(item: KeyDateEditorItem, onSave: @escaping (KeyDateDraft) -> Void) {
        self.item = item
        self.onSave = onSave
        _draft = State(initialValue: Self.initialDraft(for: item))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $draft.type) {
                        ForEach(KeyDateType.allCases, id: \.self) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    if draft.type == .custom {
                        TextField("Label", text: $draft.customLabel)
                    }
                }

                Section("Date") {
                    KeyDateWheelPicker(draft: $draft)
                }

                Section {
                    Stepper(value: $draft.leadTimeDays, in: 0...30) {
                        LabeledContent("Remind", value: leadLabel)
                    }
                    Toggle("Toggle", isOn: $draft.reminderEnabled)
                } header: {
                    Text("Reminder")
                } footer: {
                    Text("Reminders arrive at your default reminder time, set in Settings.")
                }
            }
            .navigationTitle(item.isNew ? "Add Date" : "Edit Date")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel, action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(item.isNew ? "Add" : "Done", action: save)
                        .disabled(!draft.isValid)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var leadLabel: String {
        switch draft.leadTimeDays {
        case 0: "On the day"
        case 1: "1 day before"
        default: "\(draft.leadTimeDays) days before"
        }
    }

    private func cancel() {
        dismiss()
    }

    private func save() {
        onSave(draft)
        dismiss()
    }

    /// A new date starts on today's month/day with no year; the year wheel
    /// is there for anyone who knows it.
    private static func initialDraft(for item: KeyDateEditorItem) -> KeyDateDraft {
        switch item {
        case .edit(let keyDate):
            return KeyDateDraft(keyDate: keyDate)
        case .new(let type):
            let today = Calendar.current.dateComponents([.month, .day], from: .now)
            return KeyDateDraft(type: type, month: today.month ?? 1, day: today.day ?? 1)
        }
    }
}

#Preview {
    KeyDateEditorView(item: .new(.anniversary)) { _ in }
}
