import SwiftUI

/// Birthday plus anniversaries and custom dates: view + inline add.
/// Tapping a row edits it; swipe deletes it (Contact Detail §5.2).
struct DatesSection: View {
    /// Already ordered via `ordered(_:now:)`.
    let keyDates: [KeyDate]
    let now: Date
    let onAdd: (KeyDateType) -> Void
    let onEdit: (KeyDate) -> Void
    let onDelete: (KeyDate) -> Void

    private var hasBirthday: Bool {
        keyDates.contains { $0.type == .birthday }
    }

    var body: some View {
        Section("Dates") {
            if !hasBirthday {
                Button("Add birthday", systemImage: "gift") {
                    onAdd(.birthday)
                }
            }

            ForEach(keyDates) { keyDate in
                Button {
                    onEdit(keyDate)
                } label: {
                    KeyDateRow(keyDate: keyDate, now: now)
                }
                .buttonStyle(.plain)   // row text keeps primary/secondary, not the button tint
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        onDelete(keyDate)
                    }
                }
            }

            Button("Add date", systemImage: "plus.circle") {
                onAdd(.anniversary)
            }
        }
    }

    /// Birthday first, then by next occurrence, then by label.
    static func ordered(_ keyDates: [KeyDate], now: Date, calendar: Calendar = .current) -> [KeyDate] {
        keyDates.sorted { lhs, rhs in
            if (lhs.type == .birthday) != (rhs.type == .birthday) {
                return lhs.type == .birthday
            }
            let lo = lhs.nextOccurrence(from: now, calendar: calendar) ?? .distantFuture
            let ro = rhs.nextOccurrence(from: now, calendar: calendar) ?? .distantFuture
            if lo != ro { return lo < ro }
            return lhs.label.localizedStandardCompare(rhs.label) == .orderedAscending
        }
    }
}
