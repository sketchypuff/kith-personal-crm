import SwiftUI

/// The notifications switch plus the seed for every new contact: frequency,
/// day, and the default time (which also drives key-date reminders). Each
/// write lands in the App Group suite immediately; the switch and the time
/// ask the parent for the coalesced reschedule pass, while frequency and day
/// only affect the next add. The switch stays visible but inert while
/// iOS-level permission is denied, so intent is preserved for when it's
/// re-granted.
struct NotificationDefaultsSection: View {
    let notificationsDenied: Bool
    let onChange: () -> Void

    @AppStorage(AppPreferences.Key.notificationsEnabled, store: AppPreferences.store)
    private var notificationsEnabled = true

    @AppStorage(AppPreferences.Key.newContactCadence, store: AppPreferences.store)
    private var cadence: Cadence = .weekly

    @AppStorage(AppPreferences.Key.newContactNotifyDay, store: AppPreferences.store)
    private var notifyDay: Weekday = .saturday

    /// The stored form (seconds since the reference date); `reminderTime` is
    /// the `Date` the picker binds to, written through on change.
    @AppStorage(AppPreferences.Key.defaultReminderTime, store: AppPreferences.store)
    private var reminderTimeInterval = 0.0

    @State private var reminderTime: Date

    init(notificationsDenied: Bool, onChange: @escaping () -> Void) {
        self.notificationsDenied = notificationsDenied
        self.onChange = onChange
        _reminderTime = State(initialValue: AppPreferences.defaultReminderTime)
    }

    var body: some View {
        Section {
            Toggle("Notifications", isOn: $notificationsEnabled)
                .disabled(notificationsDenied)

            Picker("Frequency", selection: $cadence) {
                ForEach(Cadence.allCases, id: \.self) { cadence in
                    Text(cadence.label).tag(cadence)
                }
            }
            .pickerStyle(.menu)

            Picker("Day", selection: $notifyDay) {
                ForEach(Weekday.allCases, id: \.self) { day in
                    Text(day.label).tag(day)
                }
            }
            .pickerStyle(.menu)
            .disabled(!cadence.usesNotifyDay)

            DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
        } header: {
            Text("Notification defaults")
        } footer: {
            if notificationsDenied {
                Text("Turned off for Kith in iOS Settings.")
            }
        }
        .onChange(of: reminderTime) { _, time in
            reminderTimeDidChange(time)
        }
        .onChange(of: notificationsEnabled) {
            onChange()
        }
    }

    private func reminderTimeDidChange(_ time: Date) {
        reminderTimeInterval = time.timeIntervalSinceReferenceDate
        onChange()
    }
}
