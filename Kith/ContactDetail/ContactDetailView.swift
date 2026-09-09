import SwiftUI

/// Minimal pushed destination until the Contact Detail spec is implemented.
/// Read-only: no Logged action lives here by design (Contact Detail §8).
struct ContactDetailView: View {
    let person: Person
    var showsAlreadyInKithNote = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    ContactAvatarView(
                        name: person.name,
                        initials: person.initials,
                        contactID: person.linkedContactID,
                        size: 64
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(person.name)
                            .font(.title2.weight(.semibold))
                        Text(catchupLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if showsAlreadyInKithNote {
                Section {
                    Label("Already in Kith", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Notify") {
                LabeledContent("How often", value: person.cadence.label)
                if person.cadence.usesNotifyDay {
                    LabeledContent("Day", value: person.notifyDay.label)
                }
                if person.cadence != .never {
                    LabeledContent("Time", value: person.notifyTime.formatted(date: .omitted, time: .shortened))
                }
            }
        }
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Contact Detail Appendix formatting.
    private var catchupLine: String {
        guard person.cadence != .never, let due = person.nextDue else {
            return "No catchup scheduled"
        }
        let now = Date.now
        if person.isSnoozed(at: now) { return "Snoozed to tomorrow" }
        if now > due {
            let days = CadenceEngine.daysOverdue(due: due, now: now)
            return days == 0 ? "Due today" : "\(days)d overdue"
        }
        let day = due.formatted(Date.FormatStyle().weekday(.abbreviated).day().month(.abbreviated))
        let time = due.formatted(date: .omitted, time: .shortened)
        return "Next catchup · \(day), \(time)"
    }
}
