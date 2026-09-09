import SwiftUI

/// The cadence controls, identical to the Setup sheet: how often / day / time.
/// Conditional fields are disabled but never removed (Contact Detail §5.1).
/// Bindings write straight to the model; the parent observes the raw values
/// and reschedules.
struct NotifySection: View {
    @Bindable var person: Person

    var body: some View {
        Section("Notify") {
            Picker("How often", selection: $person.cadence) {
                ForEach(Cadence.allCases, id: \.self) { cadence in
                    Text(cadence.label).tag(cadence)
                }
            }
            .pickerStyle(.menu)

            Picker("Day", selection: $person.notifyDay) {
                ForEach(Weekday.allCases, id: \.self) { day in
                    Text(day.label).tag(day)
                }
            }
            .pickerStyle(.menu)
            .disabled(!person.cadence.usesNotifyDay)

            DatePicker("Time", selection: $person.notifyTime, displayedComponents: .hourAndMinute)
                .disabled(person.cadence == .never)
        }
    }
}
