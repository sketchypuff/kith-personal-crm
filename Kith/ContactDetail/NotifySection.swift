import SwiftUI

/// The cadence controls, identical to the Setup sheet: how often / day / time.
/// Conditional fields are disabled but never removed (Contact Detail §5.1).
/// Bindings write straight to the model; the parent observes the raw values
/// and reschedules.
struct NotifySection: View {
    @Bindable var person: Person
    /// What the phone number works out to, so the row can say what Automatic
    /// means for this person rather than leaving it abstract.
    var guessedTimeZone: TimeZone?

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

            // Below the cadence controls because it doesn't change them: the
            // reminder still arrives at the time set above, in the reader's own
            // day. This only says what the hour looks like at the other end.
            NavigationLink {
                TimeZonePickerView(identifier: $person.timeZoneIdentifier, guess: guessedTimeZone)
            } label: {
                LabeledContent("Timezone", value: timeZoneLabel)
            }
        }
    }

    private var timeZoneLabel: String {
        if let identifier = person.timeZoneIdentifier {
            return TimeZoneCatalog.city(of: identifier)
        }
        // "Automatic" would read as though it had worked, when in this case
        // nothing could be worked out. The picker says why.
        guard let guessedTimeZone else { return "Unknown" }
        return TimeZoneCatalog.city(of: guessedTimeZone.identifier)
    }
}
