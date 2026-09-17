import SwiftUI

/// The identity band: photo or monogram, name, the Next-catchup line, and —
/// when we know where they are — what time it is for them. Scrolls with the
/// content, and appears on Info only: the timeline is history, and none of
/// this describes it.
///
/// The catch-up line is still the only *status* here. Local time says nothing
/// about the relationship; it sits under the status because it answers the
/// question the status provokes — whether now is a reasonable hour to try.
struct ContactDetailHeader: View {
    let person: Person
    let status: CatchupStatus
    let now: Date
    /// Resolved by the parent from the number it already loads. Nil when the
    /// number is local, the country keeps several times, or a guess would only
    /// repeat the reader's own clock.
    var timeZone: TimeZone?

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
            VStack(spacing: 2) {
                Text(status.detailLabel(now: now))
                    .font(.subheadline)
                    .foregroundStyle(statusStyle)
                    .contentTransition(.opacity)
                    .animation(.default, value: status)
                if let timeZone {
                    LocalTimeLabel(timeZone: timeZone)
                }
            }
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
