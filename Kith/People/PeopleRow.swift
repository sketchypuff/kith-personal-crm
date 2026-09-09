import SwiftUI

/// A roster row: identity first, status second, and a chevron. No check CTA —
/// logging lives on Today. The row owns its own delete gesture and confirmation.
struct PeopleRow: View {
    let entry: RosterEntry
    let now: Date
    let onDelete: () -> Void

    @State private var isConfirmingDelete = false

    private var name: String { entry.person.name }

    var body: some View {
        NavigationLink(value: entry.person) {
            HStack(spacing: 12) {
                ContactAvatarView(
                    name: name,
                    initials: entry.person.initials,
                    contactID: entry.person.linkedContactID
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.body)
                    Text(entry.matchHint ?? entry.status.rosterLabel(now: now))
                        .font(.subheadline)
                        .foregroundStyle(subtitleStyle)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)
            }
            .padding(.vertical, 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens \(name)")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // Red, but deliberately not `role: .destructive`: a destructive swipe
            // button makes the List dismiss the row before the confirmation can
            // present. The confirmation dialog below carries the destructive role.
            Button("Delete", systemImage: "trash", action: confirmDelete)
                .tint(.red)
        }
        .confirmationDialog(
            "Delete \(name)?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete \(name)", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes all touches, dates, and notes for this person and can't be undone.")
        }
    }

    /// Overdue is an informative tint — secondary orange — never red.
    private var subtitleStyle: AnyShapeStyle {
        if entry.matchHint != nil { return AnyShapeStyle(.secondary) }
        switch entry.status {
        case .overdue, .dueToday: return AnyShapeStyle(.orange)
        case .none: return AnyShapeStyle(.tertiary)
        case .snoozed, .upcoming: return AnyShapeStyle(.secondary)
        }
    }

    private func confirmDelete() {
        isConfirmingDelete = true
    }
}
