import SwiftUI

/// The identity-and-status band: photo or monogram, name, and the one status
/// element on the screen — the Next-catchup line. Scrolls with the content.
struct ContactDetailHeader: View {
    let person: Person
    let status: CatchupStatus
    let now: Date

    var body: some View {
        VStack(spacing: 8) {
            ContactAvatarView(
                name: person.name,
                initials: person.initials,
                contactID: person.linkedContactID,
                size: 64
            )
            Text(person.name)
                .font(.title2)
                .bold()
                .multilineTextAlignment(.center)
            Text(status.detailLabel(now: now))
                .font(.subheadline)
                .foregroundStyle(statusStyle)
                .contentTransition(.opacity)
                .animation(.default, value: status)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
    }

    /// Overdue is an informative tint — secondary orange — never red.
    private var statusStyle: AnyShapeStyle {
        switch status {
        case .overdue, .dueToday: AnyShapeStyle(.orange)
        case .none: AnyShapeStyle(.tertiary)
        case .snoozed, .upcoming: AnyShapeStyle(.secondary)
        }
    }
}
